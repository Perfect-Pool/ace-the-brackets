// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ImageBetTexts {
    function getColor(
        uint8 statusValidator
    ) private pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    statusValidator == 0 ? "808080" : statusValidator == 1
                        ? "7ED321"
                        : "FF2E47"
                )
            );
    }

    function buildCircles1(
        uint8[4] memory betValidator
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<circle cx="140" cy="184" r="3" fill="#',
                    getColor(betValidator[0]),
                    '"/><circle cx="140" cy="208" r="3" fill="#',
                    getColor(betValidator[1]),
                    '"/><circle cx="243" cy="184" r="3" fill="#',
                    getColor(betValidator[2]),
                    '"/><circle cx="243" cy="208" r="3" fill="#',
                    getColor(betValidator[3]),
                    '"/>'
                )
            );
    }

    function buildCircles2(
        uint8[3] memory betValidator
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<circle cx="140" cy="270" r="3" fill="#',
                    getColor(betValidator[0]),
                    '"/><circle cx="243" cy="270" r="3" fill="#',
                    getColor(betValidator[1]),
                    '"/><circle cx="140" cy="333" r="3" fill="#',
                    getColor(betValidator[2]),
                    '"/>'
                )
            );
    }

    function buildBetsRound1(
        string[4] memory tokens
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<text style="font-size:11px;fill:#fff;font-family:arial" x="94" y="187.5">',
                    tokens[0],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="94" y="212">',
                    tokens[1],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="197" y="187.5">',
                    tokens[2],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="197" y="212">',
                    tokens[3],
                    "</text>"
                )
            );
    }

    function buildBetsRound2(
        string[3] memory tokens
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<text style="font-size:11px;fill:#fff;font-family:arial" x="94" y="274">',
                    tokens[0],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="197" y="274">',
                    tokens[1],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="94" y="336.5">',
                    tokens[2],
                    "</text>"
                )
            );
    }

    function buildPrizeText(
        string memory prize,
        bool claimed
    ) external pure returns (string memory) {
        return
            keccak256(abi.encodePacked(prize)) !=
                keccak256(abi.encodePacked("0.00"))
                ? claimed
                    ? string(
                        abi.encodePacked(
                            '<rect x="100" y="360" width="100" height="21" rx="4.5" fill="#1B2236" stroke="#1C253C" /><text style="font-size:11.5px;fill:#7ED321;font-family:arial" x="114" y="374">Prize Claimed</text>'
                        )
                    )
                    : string(
                        abi.encodePacked(
                            '<rect x="100" y="360" width="100" height="21" rx="4.5" fill="#1B2236" stroke="#1C253C" /><text style="font-size:11px;fill:#fff;font-family:arial" x="140" y="374">',
                            prize,
                            '</text><text style="font-size:11.5px;fill:#98A1C0;font-family:arial" x="106" y="374">Prize:</text>'
                        )
                    )
                : "";
    }

    function betTexts() external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<text style="font-size:11.5px;fill:#98A1C0;font-family:arial" x="54" y="187.5">Bet 1:</text>',
                    '<text style="font-size:11.5px;fill:#98A1C0;font-family:arial" x="54" y="212">Bet 2:</text>',
                    '<text style="font-size:11.5px;fill:#98A1C0;font-family:arial" x="157" y="187.5">Bet 3:</text>',
                    '<text style="font-size:11.5px;fill:#98A1C0;font-family:arial" x="157" y="212">Bet 4:</text>',
                    '<text style="font-size:11.5px;fill:#98A1C0;font-family:arial" x="54" y="274">Bet 1:</text>',
                    '<text style="font-size:11.5px;fill:#98A1C0;font-family:arial" x="157" y="274">Bet 2:</text>',
                    '<text style="font-size:11.5px;fill:#98A1C0;font-family:arial" x="54" y="337">Bet 1:</text>'
                )
            );
    }
}
