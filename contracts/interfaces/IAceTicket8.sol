// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAceTicket8 {
    function getBetData(
        uint256 _tokenId
    ) external view returns (uint256[7] memory);

    function betValidator(
        uint256 _tokenId
    ) external view returns (uint8[7] memory);

    function getGameId(
        uint256 tokenIndex
    ) external view returns (uint256 gameId);

    function getTokenSymbols(
        uint256 _tokenId
    ) external view returns (string[7] memory);

    function setGamePot(uint256 _gameId, bytes32 betCode) external;

    function dismissGamePot(uint256 _gameId, bytes32 betCode) external;

    function amountPrizeClaimed(
        uint256 _tokenId
    ) external view returns (uint256 amountToClaim, uint256 amountClaimed);
}
