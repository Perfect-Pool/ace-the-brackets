// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTheBrackets8.sol";
import "../interfaces/IAceTicket8.sol";

contract Ace8Proxy {
    /** EVENTS **/
    event GameCreated(uint256 gameIndex);
    event GameActivated(uint256 gameIndex);
    event GameAdvanced(uint256 gameIndex, uint8 round);
    event GameFinished(uint256 gameIndex); //, bytes32 result);
    event DaysToClaimPrizeChanged(uint8 daysToClaimPrize);
    event Paused(bool paused);
    event PriceFeedAdded(uint256 tokenIndex);
    event UpdatePerformed(uint256 lastTimeStamp);
    event GameReset(uint256 gameId);

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
    mapping(uint256 => address) private gameContract;
    uint256 private immutable lastGameId;
    address public executionAddress;

    /** MODIFIERS **/
    modifier onlyAdministrator() {
        require(gamesHub.checkRole(keccak256("ADMIN"), msg.sender), "ACEP-01");
        _;
    }

    modifier onlyExecutor() {
        require(msg.sender == executionAddress, "ACEP-02");
        _;
    }

    modifier gameOutOfIndex(uint256 gameIndex) {
        IAceTheBrackets8 _gameContract = IAceTheBrackets8(
            gamesHub.games(keccak256("BRACKETS"))
        );
        require(
            (gameIndex != 0) && (gameIndex <= _gameContract.totalGames()),
            "ACE-06"
        );
        _;
    }

    /**
     * @dev Constructor function
     * @param _gamesHubAddress Address of the games hub
     * @param _executorAddress Address of the executor
     */
    constructor(
        address _gamesHubAddress,
        address _executorAddress,
        uint256 _lastGameId
    ) {
        gamesHub = IGamesHub(_gamesHubAddress);
        executionAddress = _executorAddress;
        lastGameId = _lastGameId;
    }

    /** MUTATORS **/

    /**
     * @dev Function to set a contract to a specific game id
     * @param _gameId The ID of the game
     * @param _gameAddress The address of the game contract
     */
    function setGameContract(
        uint256 _gameId,
        address _gameAddress
    ) public onlyAdministrator {
        gameContract[_gameId] = _gameAddress;
    }

    /**
     * @dev Function to perform the update of the games
     * @param _dataNewGame Data for the new game
     */
    function performGames(
        bytes calldata _dataNewGame,
        bytes calldata _dataUpdate,
        uint256 _lastTimeStamp
    ) public onlyExecutor {
        IAceTheBrackets8 _gameContract = IAceTheBrackets8(
            gamesHub.games(keccak256("BRACKETS"))
        );
        if (_gameContract.paused()) return;
        uint256[] memory _activeGames = _gameContract.getActiveGames();

        if (_dataUpdate.length != 0) {
            (
                uint256[4] memory gameIds,
                bytes[4] memory _prices,
                bytes[4] memory _pricesWinners,
                bytes[4] memory _winners
            ) = abi.decode(
                    _dataUpdate,
                    (uint256[4], bytes[4], bytes[4], bytes[4])
                );

            for (uint8 i = 0; i < _activeGames.length; i++) {
                if (gameIds[i] == 0) continue;
                _gameContract.advanceGame(
                    gameIds[i],
                    _prices[i],
                    _pricesWinners[i],
                    _winners[i]
                );
                uint8 _status = _gameContract.getGameStatus(gameIds[i]);
                if (_status == 0) emit GameActivated(gameIds[i]);
                if (_status == 4) emit GameFinished(gameIds[i]);
                emit GameAdvanced(gameIds[i], _status == 0 ? 0 : _status - 1);
            }
        }

        if (
            _gameContract.getActiveGames().length <
            _gameContract.minActiveGames() &&
            _gameContract.createNewGames() &&
            _dataNewGame.length != 0
        ) {
            _gameContract = IAceTheBrackets8(
                gamesHub.games(keccak256("BRACKETS"))
            );
            _gameContract.createGame(_lastTimeStamp, _dataNewGame);
            uint256 _totalGames = _gameContract.totalGames();
            gameContract[_totalGames] = address(_gameContract);
            emit GameCreated(_totalGames);
        }
        emit UpdatePerformed(_lastTimeStamp);
    }

    /**
     * @dev Function to change the days to claim the prize
     * @param _daysToClaimPrize The new days to claim the prize
     */
    function changeDaysToClaimPrize(
        uint8 _daysToClaimPrize
    ) public onlyAdministrator {
        IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
            .changeDaysToClaimPrize(_daysToClaimPrize);
        emit DaysToClaimPrizeChanged(_daysToClaimPrize);
    }

    /**
     * @dev Function to pause / unpause the contract
     * @param _paused Boolean to pause or unpause the contract
     */
    function setPaused(bool _paused) external onlyAdministrator {
        IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS"))).setPaused(
            _paused
        );
        emit Paused(_paused);
    }

    /**
     * @dev Function to set the forwarder address
     * @param _executionAddress Address of the Chainlink forwarder
     */
    function setExecutionAddress(
        address _executionAddress
    ) external onlyAdministrator {
        executionAddress = _executionAddress;
    }

    /**
     * @dev Function to reset a game
     * @param _gameId The ID of the game to be reset
     */
    function resetGame(uint256 _gameId) external onlyAdministrator {
        IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS"))).resetGame(
            _gameId
        );
        emit GameReset(_gameId);
    }

    /**
     * @dev Function to determine if new games should be created
     * @param _active Boolean to activate or deactivate the contract
     */
    function setCreateNewGames(bool _active) public onlyAdministrator {
        IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
            .setCreateNewGames(_active);
    }

    /**
     * @dev Function to set the round duration
     * @param _roundDuration The new round duration
     */
    function setRoundDuration(uint256 _roundDuration) public onlyAdministrator {
        IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
            .setRoundDuration(_roundDuration);
    }

    /**
     * @dev Function to set the bet time in minutes
     * @param _betTime The new bet time
     */
    function setBetTime(
        uint256 _betTime
    ) public onlyAdministrator {
        IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS"))).setBetTime(
            _betTime
        );
    }

    /**
     * @dev Function to set the minimum number of concurrent games
     * @param _minActiveGames The new minimum number of concurrent games
     */
    function setMinConcurrentGames(
        uint8 _minActiveGames
    ) public onlyAdministrator {
        IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
            .setMinConcurrentGames(_minActiveGames);
    }

    /** GETTERS **/

    /**
     * @dev Function to get the game final result
     * @param gameIndex The index of the game
     * @return brackets The array of token IDs
     */
    function getFinalResult(
        uint256 gameIndex
    ) public view gameOutOfIndex(gameIndex) returns (uint256[7] memory) {
        return
            IAceTheBrackets8(getGameContract(gameIndex)).getFinalResult(
                gameIndex
            );
    }

    /**
     * @dev Status of the game. 0 = inactive, 1 ~ 3 = actual round, 4 = finished
     * @param gameIndex The index of the game
     * @return status The status of the game
     */
    function getGameStatus(
        uint256 gameIndex
    ) public view gameOutOfIndex(gameIndex) returns (uint8 status) {
        return
            IAceTheBrackets8(getGameContract(gameIndex)).getGameStatus(
                gameIndex
            );
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
    ) private view gameOutOfIndex(gameIndex) returns (bytes memory) {
        // Return: ABI-encoded string[8], uint256[8], uint256[8], uint256, uint256
        return
            IAceTheBrackets8(getGameContract(gameIndex)).getRoundFullData(
                gameIndex,
                round
            );
    }

    /**
     * @dev Function to get the data for a game
     * @param _gameId The index of the game
     * @return gameData The data for the game
     */
    function getGameFullData(
        uint256 _gameId
    ) public view gameOutOfIndex(_gameId) returns (bytes memory) {
        // Return: ABI-encoded bytes, bytes, bytes, string, uint256, uint8, uint256, uint256
        // CurrentRound 0-2: Rounds 1-3 / 3: Finished
        // Activated: 0: Inactive / 1: Active
        return
            IAceTheBrackets8(getGameContract(_gameId)).getGameFullData(_gameId);
    }

    /**
     * @dev Function to get the data for a round of a game
     * @param _gameId The index of the game
     * @param round The index of the round
     * @return tokens The array of token IDs
     * @return prices The array of prices
     */
    function getRoundData(
        uint256 _gameId,
        uint8 round
    )
        public
        view
        gameOutOfIndex(_gameId)
        returns (uint256[8] memory, uint256[8] memory, uint256[8] memory)
    {
        return
            IAceTheBrackets8(getGameContract(_gameId)).getRoundData(
                _gameId,
                round
            );
    }

    /**
     * @dev Function to get all active games indexes
     * @return activeGames The total number of active games
     */
    function getActiveGames() public view returns (uint256[] memory) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .getActiveGames();
    }

    /**
     * @dev Function to get the symbol of a token
     * @param tokenIndex The index of the token
     */
    function getTokenSymbol(
        uint256 tokenIndex
    ) public view returns (string memory) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .getTokenSymbol(tokenIndex);
    }

    /**
     * @dev Function to get the token index of a symbol
     * @param _symbol The symbol of the token
     */
    function getTokenId(string memory _symbol) public view returns (uint256) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS"))).getTokenId(
                _symbol
            );
    }

    /**
     * @dev Function to get the token index of an array of symbols
     * @param _symbols The array of symbols
     */
    function getTokensIds(
        bytes memory _symbols
    ) public view returns (uint256[8] memory) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .getTokensIds(_symbols);
    }

    /**
     * @dev Function to get the token symbol of an array of indexes
     * @param _tokens The array of token indexes
     */
    function getTokensSymbols(
        bytes memory _tokens
    ) public view returns (string[8] memory) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .getTokensSymbols(_tokens);
    }

    /**
     * @dev Function to get the active games actual coins symbols and prices
     * @return _activeGamesActualCoins The array of active games actual coins
     */
    function getActiveGamesActualCoins() public view returns (bytes[4] memory) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .getActiveGamesActualCoins();
    }

    /**
     * @dev Get the Game Finished Code from the Game ID
     * @param _gameId The Game ID
     * @return The Game Finished Code
     */
    function getGameFinishedCode(
        uint256 _gameId
    ) public view returns (bytes32) {
        return
            IAceTheBrackets8(getGameContract(_gameId)).getGameFinishedCode(
                _gameId
            );
    }

    /**
     * @dev Function to get the game contract address
     * @param _gameId The ID of the game
     * @return The address of the game contract
     */
    function getGameContract(uint256 _gameId) public view returns (address) {
        return
            (_gameId < lastGameId) || gameContract[_gameId] == address(0)
                ? gameContract[lastGameId]
                : gameContract[_gameId];
    }

    /** VARIABLES **/
    function MIN_ACTIVE_TOKENS() public view returns (uint8) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .MIN_ACTIVE_TOKENS();
    }

    function minActiveGames() public view returns (uint8) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .minActiveGames();
    }

    function totalGames() public view returns (uint256) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .totalGames();
    }

    function daysToClaimPrize() public view returns (uint8) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .daysToClaimPrize();
    }

    function paused() public view returns (bool) {
        return IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS"))).paused();
    }

    function createNewGames() public view returns (bool) {
        return
            IAceTheBrackets8(gamesHub.games(keccak256("BRACKETS")))
                .createNewGames();
    }
}
