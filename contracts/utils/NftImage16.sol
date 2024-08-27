// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/Base64.sol";
import "../libraries/BuildImageAce.sol";
import "../interfaces/IAceTheBrackets8.sol";
import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTicket8.sol";

contract NftImage16 is Ownable {
    using Strings for uint16;
    using Strings for uint256;

    IGamesHub public gamesHub;

    constructor(address _gamesHub) {
        gamesHub = IGamesHub(_gamesHub);
    }

    function changeGamesHub(address _gamesHub) public onlyOwner {
        gamesHub = IGamesHub(_gamesHub);
    }

    function buildImage(
        uint256 _gameId,
        uint256 _tokenId,
        uint256 prize,
        bool claimed
    ) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '<svg width="300" height="500" viewBox="0 0 300 500" fill="none" xmlns="http://www.w3.org/2000/svg">',
                                BuildImageAce.fullSvgImage(
                                    IAceTheBrackets8(
                                        gamesHub.games(
                                            keccak256("ACE8_PROXY")
                                        )
                                    ).getGameStatus(_gameId),
                                    IAceTicket8(
                                        gamesHub.helpers(
                                            keccak256("NFT_ACE8")
                                        )
                                    ).betValidator(_tokenId),
                                    IAceTicket8(
                                        gamesHub.helpers(
                                            keccak256("NFT_ACE8")
                                        )
                                    ).getTokenSymbols(_tokenId),
                                    BuildImageAce.formatPrize(prize.toString()),
                                    claimed
                                ),
                                '<text style="font-size:15px;text-align:center;fill:#fff;font-family:arial" x="158" y="424">',
                                _tokenId.toString(),
                                "</text>"
                                '<text style="font-size:20px;font-family:arial;font-weight:750;fill:url(#d)" x="50%" y="64" text-anchor="middle">Game #',
                                IAceTicket8(
                                    gamesHub.helpers(keccak256("NFT_ACE8"))
                                ).getGameId(_tokenId).toString(),
                                "</text></svg>"
                            )
                        )
                    )
                )
            );
    }
}
