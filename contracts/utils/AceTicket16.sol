// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTheBrackets16.sol";

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);
}

interface INftMetadata {
    function buildMetadata(
        uint256 _gameId,
        uint256 _tokenId
    ) external view returns (string memory);
}

contract AceTicket16 is ERC721, ReentrancyGuard {
    event BetPlaced(
        address indexed _player,
        uint256 indexed _gameId,
        uint256 indexed _tokenId,
        bytes32 _betCode
    );
    event GamePotPlaced(uint256 indexed _gameId, uint256 _pot);
    event GamePotDismissed(uint256 indexed _gameId, uint256 _amount);
    event NoWinners(uint256 indexed _gameId);
    event PrizeClaimed(uint256 indexed _tokenId, uint256 _amount);
    event PriceChanged(uint256 _newPrice);
    event ProtocolFeeChanged(uint8 _newFee);
    event IterateGameData(
        uint256 _gameId,
        uint256 _iterateStart,
        uint256 _iterateEnd
    );
    event IterationFinished(uint256 indexed _gameId);
    event GamePotDecided(uint256 indexed _gameId);

    /** STRUCT **/
    struct GameData {
        uint256[] tokenIds;
        uint256 iterateStart;
        uint256 pot;
        uint256 consolationPot;
        uint256 consolationPotClaimed;
        mapping(uint8 => uint256[]) consolationWinners;
        uint8 consolationPoints;
        bool potDismissed;
    }

    uint256 private _nextTokenId;
    IGamesHub public gamesHub;
    IERC20 public token;

    uint256 public jackpot;
    uint256 public price;
    uint256 public iterationSize = 100;
    uint8 public consolationPerc = 100; //10%
    uint8 public protocolFee = 100; //10%
    address public executionAddress;

    mapping(uint256 => uint256) private tokenToGameId;
    mapping(uint256 => uint256[15]) private nftBet;
    mapping(bytes32 => uint256[]) private betCodeToTokenIds;
    mapping(bytes32 => uint256) private gamePot;
    mapping(bytes32 => uint256) private gamePotClaimed;
    mapping(uint256 => uint256) private tokenClaimed;
    mapping(uint256 => GameData) private gameData;

    modifier onlyAdmin() {
        require(
            gamesHub.checkRole(gamesHub.ADMIN_ROLE(), msg.sender),
            "Caller is not admin"
        );
        _;
    }

    modifier onlyGameContract() {
        require(
            msg.sender == gamesHub.games(keccak256("ACE16")),
            "Caller is not game contract"
        );
        _;
    }

    modifier onlyExecutor() {
        require(msg.sender == executionAddress, "ACE-02");
        _;
    }

    constructor(
        address _gamesHub,
        address _executionAddress,
        address _token
    ) ERC721("AceTheBrackets16", "ACE16") {
        gamesHub = IGamesHub(_gamesHub);
        executionAddress = _executionAddress;
        token = IERC20(_token);

        _nextTokenId = 1;
        jackpot = 0;
        price = 5 * 10 ** token.decimals();
    }

    /**
     * @dev Function to set the forwarder address
     * @param _executionAddress Address of the Chainlink forwarder
     */
    function setExecutionAddress(address _executionAddress) external onlyAdmin {
        executionAddress = _executionAddress;
    }

    /**
     * @dev Change the price of the ticket. Only callable by the admin.
     * @param _newPrice The new price of the ticket.
     */
    function changePrice(uint256 _newPrice) public onlyAdmin {
        price = _newPrice;
        emit PriceChanged(_newPrice);
    }

    /**
     * @dev Change the protocol fee. Only callable by the admin.
     * @param _newFee The new protocol fee.
     */
    function changeProtocolFee(uint8 _newFee) public onlyAdmin {
        protocolFee = _newFee;
        emit ProtocolFeeChanged(_newFee);
    }

    /**
     * @dev Change the consolation percentage. Only callable by the admin.
     * @param _newPerc The new consolation percentage.
     */
    function changeConsolationPerc(uint8 _newPerc) public onlyAdmin {
        consolationPerc = _newPerc;
    }

    /**
     * @dev Change the GamesHub contract address. Only callable by the admin.
     * @param _gamesHub The address of the new GamesHub contract.
     */
    function changeGamesHub(address _gamesHub) public onlyAdmin {
        gamesHub = IGamesHub(_gamesHub);
    }

    /**
     * @dev Mint a new ticket and place a bet.
     * @param _gameId The ID of the game to bet on.
     * @param bets The array of bets for the game.
     */
    function safeMint(uint256 _gameId, uint256[15] memory bets) public {
        IAceTheBrackets16 aceContract = IAceTheBrackets16(
            gamesHub.games(keccak256("ACE16_PROXY"))
        );
        require(!aceContract.paused(), "Game paused.");
        require(aceContract.getGameStatus(_gameId) == 0, "Bets closed.");

        token.transferFrom(msg.sender, address(this), price);

        bytes32 betCode = keccak256(abi.encodePacked(_gameId, bets));
        gameData[_gameId].pot += price;
        tokenToGameId[_nextTokenId] = _gameId;
        nftBet[_nextTokenId] = bets;
        gameData[_gameId].tokenIds.push(_nextTokenId);
        betCodeToTokenIds[betCode].push(_nextTokenId);

        _safeMint(msg.sender, _nextTokenId);
        emit BetPlaced(msg.sender, _gameId, _nextTokenId, betCode);
        _nextTokenId++;
    }

    /**
     * @dev Claim the tokens won by a ticket. Only callable by the owner of the ticket.
     * @param _tokenId The ID of the ticket to claim tokens from.
     */
    function claimTokens(uint256 _tokenId) public nonReentrant {
        IAceTheBrackets16 aceContract = IAceTheBrackets16(
            gamesHub.games(keccak256("ACE16_PROXY"))
        );
        require(!aceContract.paused(), "Game paused.");
        require(
            getPotStatus(tokenToGameId[_tokenId]),
            "Pot still being calculated."
        );
        require(
            ownerOf(_tokenId) == msg.sender,
            "Not the owner of the ticket."
        );

        uint8 status = aceContract.getGameStatus(tokenToGameId[_tokenId]);
        require(status == 5, "Game not finished.");

        uint256 _gameId = tokenToGameId[_tokenId];
        bytes32 betCode = keccak256(
            abi.encodePacked(_gameId, aceContract.getFinalResult(_gameId))
        );

        bytes32 tokenBetCode = keccak256(
            abi.encodePacked(_gameId, nftBet[_tokenId])
        );

        (uint256 amount, uint256 amountClaimed) = amountPrizeClaimed(_tokenId);
        require(amount > 0 && amountClaimed == 0, "No prize to claim.");

        uint256 availableClaim = token.balanceOf(address(this));
        // avoid overflows
        if (availableClaim < amount) {
            amount = availableClaim;
        }

        if (betCode == tokenBetCode) {
            require(
                gamePotClaimed[betCode] < gamePot[betCode],
                "Game pot dismissed or already claimed."
            );

            gamePotClaimed[betCode] += amount;
            tokenClaimed[_tokenId] = amount;
            token.transfer(msg.sender, amount);

            emit PrizeClaimed(_tokenId, amount);
            return;
        }

        require(
            gameData[_gameId].consolationPot >
                gameData[_gameId].consolationPotClaimed,
            "Game pot dismissed or already claimed."
        );

        gameData[_gameId].consolationPotClaimed += amount;
        token.transfer(msg.sender, amount);
        tokenClaimed[_tokenId] = amount;

        emit PrizeClaimed(_tokenId, amount);
    }

    /**
     * @dev Claim all tokens on the input array. Iterates through the array, sum the amount to claim and claim it.
     * It skips the tokens where amount to claim is 0.
     * @param _tokenIds The array of token IDs to claim tokens from.
     */
    function claimAll(uint256[] memory _tokenIds) public nonReentrant {
        IAceTheBrackets16 aceContract = IAceTheBrackets16(
            gamesHub.games(keccak256("ACE16_PROXY"))
        );
        require(!aceContract.paused(), "Game paused.");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (!getPotStatus(tokenToGameId[_tokenIds[i]])) continue;
            if (ownerOf(_tokenIds[i]) != msg.sender) continue;

            uint8 status = aceContract.getGameStatus(
                tokenToGameId[_tokenIds[i]]
            );
            if (status != 5) continue;

            uint256 _gameId = tokenToGameId[_tokenIds[i]];
            bytes32 betCode = keccak256(
                abi.encodePacked(_gameId, aceContract.getFinalResult(_gameId))
            );

            bytes32 tokenBetCode = keccak256(
                abi.encodePacked(_gameId, nftBet[_tokenIds[i]])
            );

            (uint256 amount, uint256 amountClaimed) = amountPrizeClaimed(
                _tokenIds[i]
            );
            if (amount == 0 || amountClaimed > 0) continue;

            if (betCode == tokenBetCode) {
                if (gamePotClaimed[betCode] >= gamePot[betCode]) continue;

                gamePotClaimed[betCode] += amount;
                totalAmount += amount;
                tokenClaimed[_tokenIds[i]] = amount;

                emit PrizeClaimed(_tokenIds[i], amount);
                continue;
            }
            if (
                gameData[_gameId].consolationPotClaimed >=
                gameData[_gameId].consolationPot
            ) continue;

            gameData[_gameId].consolationPotClaimed += amount;
            totalAmount += amount;
            tokenClaimed[_tokenIds[i]] = amount;

            emit PrizeClaimed(_tokenIds[i], amount);
        }

        require(totalAmount > 0, "No prize to claim.");
        // avoid overflows
        uint256 availableClaim = token.balanceOf(address(this));
        if (availableClaim < totalAmount) {
            totalAmount = availableClaim;
        }
        token.transfer(msg.sender, totalAmount);
    }

    /**
     * @dev Set the game pot for a specific game. Only callable by the game contract.
     * @param _gameId The ID of the game to set the pot for.
     * @param betCode The bet code for the game.
     */
    function setGamePot(
        uint256 _gameId,
        bytes32 betCode
    ) public onlyGameContract {
        uint256 _fee = (gameData[_gameId].pot * protocolFee) / 1000;
        if (betCodeToTokenIds[betCode].length > 0) {
            gamePot[betCode] = jackpot + gameData[_gameId].pot - _fee;
            gameData[_gameId].pot = 0;
            jackpot = 0;
            gameData[_gameId].iterateStart = gameData[_gameId].tokenIds.length;

            emit GamePotPlaced(_gameId, gamePot[betCode]);
            return;
        }

        emit NoWinners(_gameId);

        if (gameData[_gameId].tokenIds.length == 0) return;

        uint256 _consolationPerc = (gameData[_gameId].pot * consolationPerc) /
            1000;

        jackpot = jackpot + gameData[_gameId].pot - _fee - _consolationPerc;

        token.transfer(gamesHub.helpers(keccak256("TREASURY")), _fee);

        gameData[_gameId].pot = 0;
        gameData[_gameId].consolationPot = _consolationPerc;

        if (gameData[_gameId].tokenIds.length > 0) {
            emit IterateGameData(_gameId, 0, (iterationSize - 1));
        }
    }

    /**
     * Iterate the game token ids for a specific game. Only callable by the executor
     * @param _gameId The ID of the game to iterate the token ids for.
     * @param _iterateStart The start iteration position.
     * @param _iterateEnd The end iteration position.
     */
    function iterateGameTokenIds(
        uint256 _gameId,
        uint256 _iterateStart,
        uint256 _iterateEnd
    ) public onlyExecutor {
        GameData storage _gameData = gameData[_gameId];
        require(
            _iterateStart < _gameData.tokenIds.length &&
                _iterateEnd >= _iterateStart,
            "Iteration index(es) out of bounds."
        );
        require(!getPotStatus(_gameId), "Iteration is finished");

        for (uint256 i = _iterateStart; i <= _iterateEnd; i++) {
            if (i >= _gameData.tokenIds.length) {
                _gameData.iterateStart = _gameData.tokenIds.length;
                emit IterationFinished(_gameId);
                return;
            }
            uint8 points = betWinQty(_gameData.tokenIds[i]);
            if (points == 0) continue;

            if (_gameData.consolationPoints < points) {
                _gameData.consolationPoints = points;
            }

            _gameData.consolationWinners[points].push(_gameData.tokenIds[i]);
        }

        _gameData.iterateStart = _iterateEnd;
        emit IterateGameData(
            _gameId,
            _iterateEnd,
            (_iterateEnd + iterationSize)
        );
    }

    /**
     * @dev Change the iteration size. Only callable by the admin.
     * @param _newSize The new iteration size.
     */
    function changeIterationSize(uint256 _newSize) public onlyAdmin {
        iterationSize = _newSize;
    }

    /**
     * @dev Dismiss the game pot for a specific game. Only callable by the game contract.
     * @param _gameId The ID of the game to dismiss the pot for.
     */
    function dismissGamePot(
        uint256 _gameId,
        bytes32 betCode
    ) public onlyExecutor {
        uint256 availableClaim = betCodeToTokenIds[betCode].length > 0
            ? gamePot[betCode] - gamePotClaimed[betCode]
            : gameData[_gameId].consolationPot -
                gameData[_gameId].consolationPotClaimed;

        if (availableClaim == 0) {
            emit GamePotDismissed(_gameId, 0);
            return;
        }

        uint256 protocolSlice = availableClaim / 2;
        if (protocolSlice > 0) {
            token.transfer(
                gamesHub.helpers(keccak256("TREASURY")),
                protocolSlice
            );
        }

        jackpot += (availableClaim - protocolSlice);
        gamePotClaimed[betCode] = gamePot[betCode];
        gameData[_gameId].consolationPotClaimed = gameData[_gameId]
            .consolationPot;
        gameData[_gameId].potDismissed = true;

        emit GamePotDismissed(_gameId, availableClaim);
    }

    /**
     * @dev Increase the pot by a certain amount. Only callable by the admin.
     * @param _amount The amount to increase the pot by.
     */
    function increaseJackpot(uint256 _amount) public onlyAdmin {
        token.transferFrom(msg.sender, address(this), _amount);
        jackpot += _amount;
    }

    /**
     * @dev Get the token URI for a specific token.
     * @param _tokenId The ID of the token.
     * @return The token URI.
     */
    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        require(_exists(_tokenId), "Token not minted.");

        INftMetadata nftMetadata = INftMetadata(
            gamesHub.helpers(keccak256("NFT_METADATA_ACE16"))
        );
        return nftMetadata.buildMetadata(tokenToGameId[_tokenId], _tokenId);
    }

    /**
     * @dev Get the bet data for a specific token.
     * @param _tokenId The ID of the token.
     * @return The array of bets for the token.
     */
    function getBetData(
        uint256 _tokenId
    ) public view returns (uint256[15] memory) {
        return nftBet[_tokenId];
    }

    /**
     * @dev Get the game ID for a specific token.
     * @param _tokenId The ID of the token.
     * @return The ID of the game the token is betting on.
     */
    function getGameId(uint256 _tokenId) public view returns (uint256) {
        return tokenToGameId[_tokenId];
    }

    /**
     * @dev Validate the bets for a specific token.
     * @param _tokenId The ID of the token.
     * @return The array of validation results for the bets.
     */
    function betValidator(
        uint256 _tokenId
    ) public view returns (uint8[15] memory) {
        IAceTheBrackets16 aceContract = IAceTheBrackets16(
            gamesHub.games(keccak256("ACE16_PROXY"))
        );
        uint256[15] memory bets = nftBet[_tokenId];
        uint256[15] memory results = aceContract.getFinalResult(
            tokenToGameId[_tokenId]
        );

        uint8 status = aceContract.getGameStatus(tokenToGameId[_tokenId]);

        return [
            status <= 1 ? 0 : (bets[0] == results[0] ? 1 : 2),
            status <= 1 ? 0 : (bets[1] == results[1] ? 1 : 2),
            status <= 1 ? 0 : (bets[2] == results[2] ? 1 : 2),
            status <= 1 ? 0 : (bets[3] == results[3] ? 1 : 2),
            status <= 1 ? 0 : (bets[4] == results[4] ? 1 : 2),
            status <= 1 ? 0 : (bets[5] == results[5] ? 1 : 2),
            status <= 1 ? 0 : (bets[6] == results[6] ? 1 : 2),
            status <= 1 ? 0 : (bets[7] == results[7] ? 1 : 2),
            status <= 2 ? 0 : (bets[8] == results[8] ? 1 : 2),
            status <= 2 ? 0 : (bets[9] == results[9] ? 1 : 2),
            status <= 2 ? 0 : (bets[10] == results[10] ? 1 : 2),
            status <= 2 ? 0 : (bets[11] == results[11] ? 1 : 2),
            status <= 3 ? 0 : (bets[12] == results[12] ? 1 : 2),
            status <= 3 ? 0 : (bets[13] == results[13] ? 1 : 2),
            status <= 4 ? 0 : (bets[14] == results[14] ? 1 : 2)
        ];
    }

    /**
     * @dev Get the quantity of winning bets for a specific token.
     * @param _tokenId The ID of the token.
     * @return The quantity of winning bets for the token.
     */
    function betWinQty(uint256 _tokenId) public view returns (uint8) {
        uint8[15] memory validator = betValidator(_tokenId);

        uint8 winQty = 0;
        for (uint8 i = 0; i < 15; i++) {
            if (validator[i] == 1) {
                winQty++;
            }
        }

        return winQty;
    }

    /**
     * @dev Get the symbols for the tokens bet on a specific token.
     * @param _tokenId The ID of the token.
     */
    function getTokenSymbols(
        uint256 _tokenId
    ) public view returns (string[15] memory) {
        IAceTheBrackets16 aceContract = IAceTheBrackets16(
            gamesHub.games(keccak256("ACE16_PROXY"))
        );
        return [
            aceContract.getTokenSymbol(nftBet[_tokenId][0]),
            aceContract.getTokenSymbol(nftBet[_tokenId][1]),
            aceContract.getTokenSymbol(nftBet[_tokenId][2]),
            aceContract.getTokenSymbol(nftBet[_tokenId][3]),
            aceContract.getTokenSymbol(nftBet[_tokenId][4]),
            aceContract.getTokenSymbol(nftBet[_tokenId][5]),
            aceContract.getTokenSymbol(nftBet[_tokenId][6]),
            aceContract.getTokenSymbol(nftBet[_tokenId][7]),
            aceContract.getTokenSymbol(nftBet[_tokenId][8]),
            aceContract.getTokenSymbol(nftBet[_tokenId][9]),
            aceContract.getTokenSymbol(nftBet[_tokenId][10]),
            aceContract.getTokenSymbol(nftBet[_tokenId][11]),
            aceContract.getTokenSymbol(nftBet[_tokenId][12]),
            aceContract.getTokenSymbol(nftBet[_tokenId][13]),
            aceContract.getTokenSymbol(nftBet[_tokenId][14])
        ];
    }

    /**
     * @dev Get the amount to claim and the amount claimed for a specific token.
     * @param _tokenId The ID of the token.
     * @return amountToClaim The amount of tokens to claim.
     * @return amountClaimed The amount of tokens already claimed.
     */
    function amountPrizeClaimed(
        uint256 _tokenId
    ) public view returns (uint256 amountToClaim, uint256 amountClaimed) {
        uint256 _gameId = tokenToGameId[_tokenId];
        bytes32 betCode = keccak256(
            abi.encodePacked(
                _gameId,
                IAceTheBrackets16(gamesHub.games(keccak256("ACE16_PROXY")))
                    .getFinalResult(_gameId)
            )
        );

        bytes32 tokenBetCode = keccak256(
            abi.encodePacked(_gameId, nftBet[_tokenId])
        );

        if (betCodeToTokenIds[betCode].length > 0 && betCode == tokenBetCode) {
            return (
                gamePot[betCode] / betCodeToTokenIds[betCode].length,
                tokenClaimed[_tokenId]
            );
        }

        uint8 points = betWinQty(_tokenId);
        if (points != gameData[_gameId].consolationPoints) {
            return (0, 0);
        }
        if (gameData[_gameId].consolationWinners[points].length == 0) {
            return (0, 0);
        }
        return (
            (gameData[_gameId].consolationPot /
                gameData[_gameId].consolationWinners[points].length),
            tokenClaimed[_tokenId]
        );
    }

    /**
     * #dev Get the potential payout for a specific game.
     * @param gameId The ID of the game
     */
    function potentialPayout(
        uint256 gameId
    ) public view returns (uint256 payout, uint256 consolationPayout) {
        uint256 _fee = (gameData[gameId].pot * protocolFee) / 1000;
        payout = jackpot + gameData[gameId].pot - _fee;
        consolationPayout = (gameData[gameId].pot * consolationPerc) / 1000;
    }

    /**
     * @dev Get the quantity of players for a specific game.
     * @param gameId The ID of the game
     */
    function playerQuantity(
        uint256 gameId
    ) public view returns (uint256 players) {
        return gameData[gameId].tokenIds.length;
    }

    /**
     * @dev Get the token IDs for a specific game.
     * @param gameId The ID of the game
     * @return The array of token IDs for the game.
     */
    function getGamePlayers(
        uint256 gameId
    ) public view returns (uint256[] memory) {
        return gameData[gameId].tokenIds;
    }

    /**
     * @dev Get the token IDs for a specific bet code.
     * @param betCode The bet code to get the token IDs for.
     * @return The array of token IDs for the bet code.
     */
    function getBetCodeToTokenIds(
        bytes32 betCode
    ) public view returns (uint256[] memory) {
        return betCodeToTokenIds[betCode];
    }

    /**
     * @dev Get the token IDs for a specific game id.
     * @param gameId The ID of the game
     * @return The array of token IDs for the game id.
     */
    function getGameWinners(
        uint256 gameId
    ) public view returns (uint256[] memory) {
        return
            betCodeToTokenIds[
                keccak256(
                    abi.encodePacked(
                        gameId,
                        IAceTheBrackets16(
                            gamesHub.games(keccak256("ACE16_PROXY"))
                        ).getFinalResult(gameId)
                    )
                )
            ];
    }

    /**
     * @dev Get the game consolation prize data for a specific game.
     * @param gameId The ID of the game
     * @return consolationWinners The quantity of consolation winners.
     * @return consolationPoints The points for the consolation winners.
     */
    function getGameConsolationData(
        uint256 gameId
    ) public view returns (uint256[] memory, uint8) {
        return (
            gameData[gameId].consolationWinners[
                gameData[gameId].consolationPoints
            ],
            gameData[gameId].consolationPoints
        );
    }

    /**
     * @dev Get the pot status for the pot of a specific game.
     * @param _gameId The ID of the game
     * @return The status of the pot. If true, the pot iteration is finished and it can be claimed.
     */
    function getPotStatus(uint256 _gameId) public view returns (bool) {
        return
            gameData[_gameId].iterateStart == gameData[_gameId].tokenIds.length;
    }
}
