// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAceTheBrackets8 {
    function MIN_ACTIVE_TOKENS() external view returns (uint8);

    function minActiveGames() external view returns (uint8);

    function totalGames() external view returns (uint256);

    function daysToClaimPrize() external view returns (uint8);

    function paused() external view returns (bool);

    function createNewGames() external view returns (bool);

    function advanceGame(
        uint256 _lastTimeStamp,
        uint256 gameIndex,
        bytes memory _prices,
        bytes memory _pricesWinners,
        bytes memory _winners
    ) external;

    function createGame(
        bytes calldata _dataNewGame
    ) external;

    function setPaused(bool _paused) external;

    function resetGame(uint256 _gameId) external;

    function setCreateNewGames(bool _active) external;

    function setRoundDuration(uint256 _roundDuration) external;

    function setBetTime(uint256 _betTime) external;

    function setMinConcurrentGames(uint8 _minActiveGames) external;

    function changeDaysToClaimPrize(uint8 _daysToClaimPrize) external;

    function getGameStatus(
        uint256 gameIndex
    ) external view returns (uint8 status);

    function getRoundFullData(
        uint256 gameIndex,
        uint8 round
    ) external view returns (bytes memory);

    function getGameFullData(
        uint256 gameIndex
    ) external view returns (bytes memory);

    function getRoundData(
        uint256 gameIndex,
        uint8 round
    )
        external
        view
        returns (uint256[8] memory, uint256[8] memory, uint256[8] memory);

    function getActiveGames() external view returns (uint256[] memory);

    function getTokenSymbol(
        uint256 tokenIndex
    ) external view returns (string memory);

    function getTokenId(string memory _symbol) external view returns (uint256);

    function getTokensIds(
        bytes memory _symbols
    ) external view returns (uint256[8] memory);

    function getTokensSymbols(
        bytes memory _tokens
    ) external view returns (string[8] memory);

    function getActiveGamesActualCoins()
        external
        view
        returns (bytes[4] memory);

    function getGameFinishedCode(
        uint256 _gameId
    ) external view returns (bytes32);

    function getFinalResult(
        uint256 gameIndex
    ) external view returns (uint256[7] memory);
}
