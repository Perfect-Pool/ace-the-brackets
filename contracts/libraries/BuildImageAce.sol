// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ImageParts.sol";

library BuildImageAce {
    function fullSvgImage(
        uint8 status,
        uint8[7] memory betValidator,
        string[7] memory tokens,
        string memory prize,
        bool claimed
    ) public pure returns (string memory) {
        bool victory = true;
        for (uint8 i = 0; i < 7; i++) {
            if (betValidator[i] == 2) {
                status = 4;
                victory = false;
            }
        }
        return
            string(
                abi.encodePacked(
                    ImageParts.svgPartUp(),
                    ImageParts.svgPartDown(status, victory, prize, claimed),
                    ImageParts.buildCircles(betValidator),
                    ImageParts.buildBets(tokens)
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
