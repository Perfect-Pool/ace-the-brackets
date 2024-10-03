// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTicket8.sol";

interface IFunctionsConsumerAce8 {
    function emitUpdateGame(uint8 updatePhase, uint256 gameDataIndex) external;
}

contract AceTheBrackets8 {
    /** STRUCTS **/
    struct Round {
        uint256[8] tokens;
        uint256[8] pricesStart;
        uint256[8] pricesEnd;
        uint256 start;
        uint256 end;
    }

    struct Game {
        Round[3] rounds;
        uint256 start;
        uint256 end;
        uint8 currentRound;
        uint256 winner;
        uint256 finalPrice;
        bool activated;
    }

    /** VARIABLES **/
    IGamesHub public gamesHub;
    mapping(uint256 => Game) public games;
    mapping(uint256 => uint256) private gameIndexToActiveIndex;
    mapping(bytes => uint256) private symbolToTokenId;
    mapping(uint256 => bytes) private tokenIdToSymbol;
    mapping(uint256 => bytes32) private gameIdToCode;

    uint256[] private activeGames;

    uint8 public constant MIN_ACTIVE_TOKENS = 8;
    uint8 public minActiveGames = 1;
    uint256 public totalGames;
    uint8 public daysToClaimPrize = 30;
    uint256 public roundDuration;
    uint256 public betTime;
    bool public paused = false;

    bool public createNewGames = true;
    address public executionAddress;

    /** MODIFIERS **/
    modifier onlyGameContract() {
        require(
            gamesHub.games(keccak256("BRACKETS_PROXY")) == msg.sender,
            "ACE-01"
        );
        _;
    }

    /**
     * @dev Constructor function
     * @param _gamesHubAddress Address of the games hub
     * @param _executorAddress Address of the Chainlink forwarder
     */
    constructor(
        address _gamesHubAddress,
        address _executorAddress,
        uint256 lastGameId
    ) {
        gamesHub = IGamesHub(_gamesHubAddress);
        totalGames = lastGameId;
        executionAddress = _executorAddress;
        roundDuration = 10 * 60; //10 minutes
        betTime = 10 * 60; //10 minutes
    }

    /** MUTATORS **/

    /**
     * @dev Function to pause / unpause the contract
     * @param _paused Boolean to pause or unpause the contract
     */
    function setPaused(bool _paused) external onlyGameContract {
        paused = _paused;
    }

    /**
     * @dev Function to reset a game
     * @param _gameId The ID of the game to be reset
     */
    function resetGame(uint256 _gameId) external onlyGameContract {
        delete games[_gameId];
    }

    /**
     * @dev Function to determine if new games should be created
     * @param _active Boolean to activate or deactivate the contract
     */
    function setCreateNewGames(bool _active) external onlyGameContract {
        createNewGames = _active;
    }

    /**
     * @dev Function to set the minimum number of concurrent games
     * @param _minActiveGames The new minimum number of concurrent games
     */
    function setMinConcurrentGames(
        uint8 _minActiveGames
    ) public onlyGameContract {
        minActiveGames = _minActiveGames;
    }

    /**
     * @dev Function to set the round duration in minutes
     * @param _roundDuration The new round duration
     */
    function setRoundDuration(
        uint256 _roundDuration
    ) external onlyGameContract {
        roundDuration = _roundDuration * 60;
    }

    /**
     * @dev Function to set the bet time in minutes
     * @param _betTime The new bet time
     */
    function setBetTime(uint256 _betTime) external onlyGameContract {
        betTime = _betTime * 60;
    }

    /**
     * @dev Function to add a new price feed to the list of active tokens
     * @param cmcId The Chainlink price feed address
     * @param symbol The symbol of the token
     */
    function addToken(uint256 cmcId, string memory symbol) private {
        symbolToTokenId[abi.encodePacked(symbol)] = cmcId;
        tokenIdToSymbol[cmcId] = abi.encodePacked(symbol);
    }

    /**
     * @dev Function to create a new game
     * @param _dataNewGame Data for the new game
     */
    function createGame(bytes calldata _dataNewGame) external onlyGameContract {
        (uint256[8] memory _cmcIds, string[8] memory _symbols) = abi.decode(
            _dataNewGame,
            (uint256[8], string[8])
        );
        require(_cmcIds.length == MIN_ACTIVE_TOKENS, "ACE-03");
        require(_symbols.length == _cmcIds.length, "ACE-04");

        totalGames++;
        for (uint8 i = 0; i < _cmcIds.length; i++) {
            require(
                _cmcIds[i] != 0 && bytes(_symbols[i]).length != 0,
                "ACE-05"
            );
            uint256 _tokenIndex = symbolToTokenId[
                abi.encodePacked(_symbols[i])
            ];
            if (_tokenIndex == 0) {
                addToken(_cmcIds[i], _symbols[i]);
            }

            games[totalGames].rounds[0].tokens[i] = _cmcIds[i];
        }

        activeGames.push(totalGames);
        gameIndexToActiveIndex[totalGames] = activeGames.length - 1;
    }

    /**
     * @dev Function to advance a game to the next round
     * @param gameIndex The index of the game
     * @param _lastTimeStamp The last timestamp
     * @param _prices The prices of the tokens
     * @param _pricesWinners The prices of the winners
     * @param _winners The winners of the round
     */
    function advanceGame(
        uint256 gameIndex,
        uint256 _lastTimeStamp,
        bytes memory _prices,
        bytes memory _pricesWinners,
        bytes memory _winners
    ) external onlyGameContract {
        uint8 currentRound = games[gameIndex].currentRound;
        if (currentRound > 2) removeGame(gameIndex);

        uint256[8] memory pricesArray = abi.decode(_prices, (uint256[8]));

        if (!games[gameIndex].activated) {
            if (games[gameIndex].start == 0) {
                _updateTimestamps(gameIndex, _lastTimeStamp);
            }

            if (pricesArray[0] == 0 && pricesArray[1] == 0) {
                return;
            }

            games[gameIndex].activated = true;
            games[gameIndex].rounds[0].pricesStart = pricesArray;
            return;
        }

        uint256[8] memory winnersArray = abi.decode(_winners, (uint256[8]));
        require(winnersArray[0] > 0, "ACE-06");

        uint8 nextRound = currentRound + 1;

        games[gameIndex].rounds[currentRound].pricesEnd = pricesArray;

        if (currentRound == 2) {
            games[gameIndex].finalPrice = abi.decode(
                _pricesWinners,
                (uint256[8])
            )[0];

            games[gameIndex].winner = winnersArray[0];

            removeGame(gameIndex);

            bytes32 gameCode = keccak256(
                abi.encodePacked(gameIndex, getFinalResult(gameIndex))
            );

            IAceTicket8(gamesHub.helpers(keccak256("ACE_TICKET"))).setGamePot(
                gameIndex,
                gameCode
            );

            gameIdToCode[gameIndex] = gameCode;

            IFunctionsConsumerAce8(
                gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
            ).emitUpdateGame(0, gameIndex);
        } else {
            if (
                (currentRound == 0 && winnersArray[4] != 0) ||
                (currentRound == 1 && winnersArray[2] != 0)
            ) revert("ACE-06");
            games[gameIndex].rounds[nextRound].tokens = abi.decode(
                _winners,
                (uint256[8])
            );

            games[gameIndex].rounds[nextRound].pricesStart = abi.decode(
                _pricesWinners,
                (uint256[8])
            );
        }

        games[gameIndex].currentRound = nextRound;
    }

    /**
     * @dev Internal function to receive a timestamp a game number and update all timestamps
     * @param _gameId The game number
     * @param _lastTimeStamp The last timestamp
     */
    function _updateTimestamps(
        uint256 _gameId,
        uint256 _lastTimeStamp
    ) internal {
        uint256 timer = _lastTimeStamp -
            (_lastTimeStamp % betTime) +
            (betTime * 2);
        uint256 _roundDuration = roundDuration;

        games[_gameId].start = timer;

        games[_gameId].rounds[0].start = timer;
        timer += _roundDuration;
        games[_gameId].rounds[0].end = timer;
        games[_gameId].rounds[1].start = timer;
        timer += _roundDuration;
        games[_gameId].rounds[1].end = timer;
        games[_gameId].rounds[2].start = timer;
        timer += _roundDuration;
        games[_gameId].rounds[2].end = timer;
        games[_gameId].end = timer;
    }

    /**
     * @dev Function to change the days to claim the prize
     * @param _daysToClaimPrize The new days to claim the prize
     */
    function changeDaysToClaimPrize(
        uint8 _daysToClaimPrize
    ) external onlyGameContract {
        daysToClaimPrize = _daysToClaimPrize;
    }

    /** AUXILIARY FUNCTIONS **/

    /**
     * @dev Function to remove a game from the list of active games
     * @param gameIndex The index of the game to be removed
     */
    function removeGame(uint256 gameIndex) internal {
        //remover o jogo da lista de jogos ativos
        uint8 activeIndex = uint8(gameIndexToActiveIndex[gameIndex]);

        activeGames[activeIndex] = activeGames[activeGames.length - 1];
        gameIndexToActiveIndex[
            activeGames[activeGames.length - 1]
        ] = activeIndex;
        activeGames.pop();
    }

    /** GETTERS **/

    /**
     * @dev Function to get the game final result
     * @param gameIndex The index of the game
     * @return brackets The array of token IDs
     */
    function getFinalResult(
        uint256 gameIndex
    ) public view returns (uint256[7] memory) {
        uint256[7] memory brackets;

        brackets[0] = games[gameIndex].rounds[1].tokens[0];
        brackets[1] = games[gameIndex].rounds[1].tokens[1];
        brackets[2] = games[gameIndex].rounds[1].tokens[2];
        brackets[3] = games[gameIndex].rounds[1].tokens[3];
        brackets[4] = games[gameIndex].rounds[2].tokens[0];
        brackets[5] = games[gameIndex].rounds[2].tokens[1];
        brackets[6] = games[gameIndex].winner;

        return brackets;
    }

    /**
     * @dev Status of the game. 0 = inactive, 1 ~ 3 = actual round, 4 = finished
     * @param gameIndex The index of the game
     * @return status The status of the game
     */
    function getGameStatus(
        uint256 gameIndex
    ) public view returns (uint8 status) {
        if (!games[gameIndex].activated) {
            return 0;
        } else {
            return games[gameIndex].currentRound + 1;
        }
    }

    /**
     * @dev Function to get the data for a round of a game
     * @param gameIndex The index of the game
     * @param round The index of the round
     * @return roundData The data for the round
     */
    function getRoundFullData(
        uint256 gameIndex,
        uint8 round
    ) public view returns (bytes memory) {
        // Return: ABI-encoded string[8], uint256[8], uint256[8], uint256, uint256
        return (
            abi.encode(
                getTokensSymbols(
                    abi.encode(games[gameIndex].rounds[round].tokens)
                ),
                games[gameIndex].rounds[round].pricesStart,
                games[gameIndex].rounds[round].pricesEnd,
                games[gameIndex].rounds[round].start,
                games[gameIndex].rounds[round].end
            )
        );
    }

    /**
     * @dev Function to get the data for a game
     * @param gameIndex The index of the game
     * @return gameData The data for the game
     */
    function getGameFullData(
        uint256 gameIndex
    ) public view returns (bytes memory) {
        // Return: ABI-encoded bytes, bytes, bytes, string, uint256, uint8, uint256, uint256
        // CurrentRound 0-2: Rounds 1-3 / 3: Finished
        // Activated: 0: Inactive / 1: Active
        return (
            abi.encode(
                getRoundFullData(gameIndex, 0),
                getRoundFullData(gameIndex, 1),
                getRoundFullData(gameIndex, 2),
                string(tokenIdToSymbol[games[gameIndex].winner]),
                games[gameIndex].finalPrice,
                games[gameIndex].currentRound,
                games[gameIndex].start,
                games[gameIndex].end,
                games[gameIndex].activated
            )
        );
    }

    /**
     * @dev Function to get the data for a round of a game
     * @param gameIndex The index of the game
     * @param round The index of the round
     * @return tokens The array of token IDs
     * @return prices The array of prices
     */
    function getRoundData(
        uint256 gameIndex,
        uint8 round
    )
        public
        view
        returns (uint256[8] memory, uint256[8] memory, uint256[8] memory)
    {
        require(round <= 2, "ACE-07");

        return (
            games[gameIndex].rounds[round].tokens,
            games[gameIndex].rounds[round].pricesStart,
            games[gameIndex].rounds[round].pricesEnd
        );
    }

    /**
     * @dev Function to get all active games indexes
     * @return activeGames The total number of active games
     */
    function getActiveGames() public view returns (uint256[] memory) {
        return activeGames;
    }

    /**
     * @dev Function to get the symbol of a token
     * @param tokenIndex The index of the token
     */
    function getTokenSymbol(
        uint256 tokenIndex
    ) public view returns (string memory) {
        return string(tokenIdToSymbol[tokenIndex]);
    }

    /**
     * @dev Function to get the token index of a symbol
     * @param _symbol The symbol of the token
     */
    function getTokenId(string memory _symbol) public view returns (uint256) {
        return symbolToTokenId[abi.encodePacked(_symbol)];
    }

    /**
     * @dev Function to get the token index of an array of symbols
     * @param _symbols The array of symbols
     */
    function getTokensIds(
        bytes memory _symbols
    ) public view returns (uint256[8] memory) {
        uint256[8] memory _tokens;
        string[8] memory _symbolsArray = abi.decode(_symbols, (string[8]));
        for (uint8 i = 0; i < 8; i++) {
            _tokens[i] = getTokenId(_symbolsArray[i]);
        }
        return _tokens;
    }

    /**
     * @dev Function to get the token symbol of an array of indexes
     * @param _tokens The array of token indexes
     */
    function getTokensSymbols(
        bytes memory _tokens
    ) public view returns (string[8] memory) {
        string[8] memory _symbols;
        uint256[8] memory _tokensArray = abi.decode(_tokens, (uint256[8]));
        for (uint8 i = 0; i < 8; i++) {
            _symbols[i] = getTokenSymbol(_tokensArray[i]);
        }
        return _symbols;
    }

    /**
     * @dev Function to get the active games actual coins symbols and prices
     * @return _activeGamesActualCoins The array of active games actual coins
     */
    function getActiveGamesActualCoins() public view returns (bytes[4] memory) {
        bytes[4] memory _activeGamesActualCoins;
        if (activeGames.length == 0) return _activeGamesActualCoins;

        for (uint8 i = 0; i < activeGames.length; i++) {
            _activeGamesActualCoins[i] = abi.encode(
                activeGames[i],
                games[activeGames[i]].currentRound,
                getTokensSymbols(
                    abi.encode(
                        games[activeGames[i]]
                            .rounds[games[activeGames[i]].currentRound]
                            .tokens
                    )
                ),
                games[activeGames[i]]
                    .rounds[games[activeGames[i]].currentRound]
                    .pricesStart
            );
        }
        return _activeGamesActualCoins;
    }

    /**
     * @dev Get the Game Finished Code from the Game ID
     * @param _gameId The Game ID
     * @return The Game Finished Code
     */
    function getGameFinishedCode(
        uint256 _gameId
    ) public view returns (bytes32) {
        return gameIdToCode[_gameId];
    }
}
