// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/Base64.sol";
import "../interfaces/IAceTheBrackets16.sol";
import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTicket16.sol";

interface INftImage {
    function buildImage(
        uint256 _gameId,
        uint256 _tokenId
    ) external view returns (string memory);
}

contract NftMetadata16 is Ownable {
    using Strings for uint8;
    using Strings for uint256;

    IGamesHub public gamesHub;

    constructor(address _gamesHub) {
        gamesHub = IGamesHub(_gamesHub);
    }

    function changeGamesHub(address _gamesHub) public onlyOwner {
        gamesHub = IGamesHub(_gamesHub);
    }

    function gameStatus(
        uint256 _gameId,
        uint256 _tokenId
    ) public view returns (string memory) {
        uint8 status = IAceTheBrackets16(
            gamesHub.games(keccak256("ACE16_PROXY"))
        ).getGameStatus(_gameId);
        if (status == 0) {
            return "Open";
        } else if (status == 5) {
            if (
                keccak256(
                    abi.encodePacked(
                        IAceTheBrackets16(
                            gamesHub.games(keccak256("ACE16_PROXY"))
                        ).getFinalResult(_gameId)
                    )
                ) ==
                keccak256(
                    abi.encodePacked(
                        IAceTicket16(gamesHub.helpers(keccak256("NFT_ACE16")))
                            .getBetData(_tokenId)
                    )
                )
            ) {
                return "Winner";
            } else {
                (uint256 prize, ) = IAceTicket16(
                    gamesHub.helpers(keccak256("NFT_ACE16"))
                ).amountPrizeClaimed(_tokenId);
                if (prize == 0) return "Loser";
                else return "High Score Winner";
            }
        } else {
            return string(abi.encodePacked("Round ", status.toString()));
        }
    }

    function buildMetadata(
        uint256 _gameId,
        uint256 _tokenId
    ) public view returns (string memory) {
        IAceTicket16 ticket = IAceTicket16(
            gamesHub.helpers(keccak256("NFT_ACE16"))
        );
        uint8 winQty = ticket.betWinQty(_tokenId);
        uint256 prize = 0;
        uint256 amountClaimed = 0;

        if (winQty > 0)
            (prize, amountClaimed) = ticket.amountPrizeClaimed(_tokenId);

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"Ace Sweet16 NFT #',
                                _tokenId.toString(),
                                '","description":"Ace The Brackets Sweet16 NFT from PerfectPool. ',
                                (
                                    (prize > 0) && (amountClaimed == 0)
                                        ? "Claim your prize "
                                        : "Check out the game "
                                ),
                                'at https://perfectpool.io/altcoins/ace-the-brackets","image":"',
                                INftImage(
                                    gamesHub.helpers(
                                        keccak256("NFT_IMAGE_ACE16")
                                    )
                                ).buildImage(_gameId, _tokenId),
                                '","attributes":[{"trait_type":"Game Status:","value":"',
                                gameStatus(_gameId, _tokenId),
                                '"},]}'
                            )
                        )
                    )
                )
            );
    }
}
