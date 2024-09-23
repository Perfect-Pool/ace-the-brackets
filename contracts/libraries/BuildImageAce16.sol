// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ImageParts16.sol";

library BuildImageAce16 {
    function fullSvgImage(
        uint8 status,
        uint8[15] memory betValidator,
        string[15] memory tokens,
        string memory _gameId,
        string memory _tokenId
    ) public pure returns (string memory) {
        bool victory = true;
        for (uint8 i = 0; i < 15; i++) {
            if (betValidator[i] == 2) {
                status = 5;
                victory = false;
            }
        }
        return
            string(
                abi.encodePacked(
                    ImageParts16.svgPartUp(),
                    '<text style="font-size:20px;font-family:arial;font-weight:750;fill:url(#paint1_linear_571_520)" x="50%" y="35" text-anchor="middle" id="text57">Game #',
                    _gameId,
                    '</text>',
                    '<text style="font-size:15.3px;fill:#fff;font-family:arial;font-weight:400" x="156" y="461" id="text62">',
                    _tokenId,
                    '</text>',
                    ImageParts16.buildCircles(betValidator),
                    ImageParts16.buildBets(tokens),
                    ImageParts16.svgPartDown(status, victory)
                )
            );
    }

    function formatPrize(
        string memory prize
    ) public pure returns (string memory) {
        uint256 len = bytes(prize).length;
        string memory normalizedPrize = len < 6
            ? appendZeros(prize, 6 - len)
            : prize;

        string memory integerPart = len > 6
            ? substring(normalizedPrize, 0, len - 6)
            : "0";
        string memory decimalPart = substring(
            normalizedPrize,
            len > 6 ? len - 6 : 0,
            2
        );

        return string(abi.encodePacked(integerPart, ".", decimalPart));
    }

    function substring(
        string memory str,
        uint startIndex,
        uint length
    ) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(length);

        for (uint i = 0; i < length; i++) {
            result[i] = strBytes[startIndex + i];
        }

        return string(result);
    }

    function appendZeros(
        string memory str,
        uint numZeros
    ) private pure returns (string memory) {
        bytes memory zeros = new bytes(numZeros);
        for (uint i = 0; i < numZeros; i++) {
            zeros[i] = "0";
        }
        return string(abi.encodePacked(zeros, str));
    }
}
