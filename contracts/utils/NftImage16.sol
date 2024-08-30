// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/Base64.sol";
import "../libraries/BuildImageAce16.sol";
import "../interfaces/IAceTheBrackets16.sol";
import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTicket16.sol";

contract NftImage16 is Ownable {
    using Strings for uint8;
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
        uint256 _tokenId
    ) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(
                        bytes(
                            BuildImageAce16.fullSvgImage(
                                    IAceTheBrackets16(
                                        gamesHub.games(keccak256("ACE16_PROXY"))
                                    ).getGameStatus(_gameId),
                                    IAceTicket16(
                                        gamesHub.helpers(keccak256("NFT_ACE16"))
                                    ).betValidator(_tokenId),
                                    IAceTicket16(
                                        gamesHub.helpers(keccak256("NFT_ACE16"))
                                    ).getTokenSymbols(_tokenId),
                                    _gameId.toString(),
                                    _tokenId.toString()
                                )
                        )
                    )
                )
            );
    }
}
