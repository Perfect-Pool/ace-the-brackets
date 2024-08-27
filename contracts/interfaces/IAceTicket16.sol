// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAceTicket16 {
    function getBetData(
        uint256 _tokenId
    ) external view returns (uint256[15] memory);

    function betValidator(
        uint256 _tokenId
    ) external view returns (uint8[15] memory);

    function getGameId(
        uint256 tokenIndex
    ) external view returns (uint256 gameId);

    function getTokenSymbols(
        uint256 _tokenId
    ) external view returns (string[15] memory);

    function setGamePot(uint256 _gameId, bytes32 betCode) external;

    function dismissGamePot(uint256 _gameId, bytes32 betCode) external;

    function amountPrizeClaimed(
        uint256 _tokenId
    ) external view returns (uint256 amountToClaim, uint256 amountClaimed);

    function betWinQty(uint256 _tokenId) external view returns (uint8);
}
