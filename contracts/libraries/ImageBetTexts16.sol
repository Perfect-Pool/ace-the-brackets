// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library ImageBetTexts16 {
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
                    '<circle cx="139" cy="120" r="3" fill="#',
                    getColor(betValidator[0]),
                    '"/><circle cx="139" cy="144" r="3" fill="#',
                    getColor(betValidator[1]),
                    '"/><circle cx="139" cy="167" r="3" fill="#',
                    getColor(betValidator[2]),
                    '"/><circle cx="139" cy="190" r="3" fill="#',
                    getColor(betValidator[3]),
                    '"/>'
                )
            );
    }

    function buildCircles2(
        uint8[4] memory betValidator
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<circle cx="242" cy="120" r="3" fill="#',
                    getColor(betValidator[0]),
                    '"/><circle cx="242" cy="144" r="3" fill="#',
                    getColor(betValidator[1]),
                    '"/><circle cx="242" cy="167" r="3" fill="#',
                    getColor(betValidator[2]),
                    '"/><circle cx="242" cy="190" r="3" fill="#',
                    getColor(betValidator[3]),
                    '"/>'
                )
            );
    }

    function buildCircles3(
        uint8[4] memory betValidator
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<circle cx="139" cy="251" r="3" fill="#',
                    getColor(betValidator[0]),
                    '"/><circle cx="139" cy="275" r="3" fill="#',
                    getColor(betValidator[1]),
                    '"/><circle cx="242" cy="251" r="3" fill="#',
                    getColor(betValidator[2]),
                    '"/><circle cx="242" cy="275" r="3" fill="#',
                    getColor(betValidator[3]),
                    '"/>'
                )
            );
    }

    function buildCircles4(
        uint8[3] memory betValidator
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<circle cx="139" cy="335" r="3" fill="#',
                    getColor(betValidator[0]),
                    '"/><circle cx="242" cy="335" r="3" fill="#',
                    getColor(betValidator[1]),
                    '"/><circle cx="139" cy="396" r="3" fill="#',
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
                    '<text style="font-size:11px;fill:#fff;font-family:arial" x="92" y="124">',
                    tokens[0],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="92" y="148">',
                    tokens[1],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="92" y="171">',
                    tokens[2],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="92" y="194">',
                    tokens[3],
                    '</text>'
                )
            );
    }

    function buildBetsRound2(
        string[4] memory tokens
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<text style="font-size:11px;fill:#fff;font-family:arial" x="194" y="124">',
                    tokens[0],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="194" y="148">',
                    tokens[1],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="194" y="171">',
                    tokens[2],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="194" y="194">',
                    tokens[3],
                    "</text>"
                )
            );
    }

    function buildBetsRound3(
        string[4] memory tokens
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<text style="font-size:11px;fill:#fff;font-family:arial" x="92" y="255">',
                    tokens[0],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="92" y="279">',
                    tokens[1],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="194" y="255">',
                    tokens[2],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="194" y="279">',
                    tokens[3],
                    '</text>'
                )
            );
    }

    function buildBetsRound4(
        string[3] memory tokens
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<text style="font-size:11px;fill:#fff;font-family:arial" x="92" y="339">',
                    tokens[0],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="194" y="339">',
                    tokens[1],
                    '</text><text style="font-size:11px;fill:#fff;font-family:arial" x="92" y="400">',
                    tokens[2],
                    "</text>"
                )
            );
    }

    function victoryLogo() public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<g filter="url(#prefix__filter0_d_571_520)"><path d="M215.977 371l-3.765 3.929-15.169 15.169-4.42-4.256-3.929-3.929-7.694 7.694 3.929 3.929 8.185 8.185 3.765 3.929 3.929-3.929 19.098-19.098 3.929-3.929-7.858-7.694z" fill="#1DB954"/></g>'
                    )
            );
    }

    function lostLogo() public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '<g filter="url(#prefix__filter0_d_575_1231)" transform="translate(0 60)"><path d="M189.825 308L183 314.825l3.485 3.486 8.617 8.762-8.617 8.616-3.485 3.34 6.825 6.971 3.486-3.485 8.762-8.762 8.616 8.762 3.34 3.485 6.971-6.971-3.485-3.34-8.762-8.616 8.762-8.762 3.485-3.486-6.971-6.825-3.34 3.485-8.616 8.617-8.762-8.617z" fill="#ff2e47"/></g>'
                    )
            );
    }

    function svgPartDown(
        uint8 status,
        bool victory
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(status == 5 ? (victory ? victoryLogo() : lostLogo()) : "",
                    '</g><defs id="prefix__defs70"><linearGradient id="prefix__paint0_linear_571_520" x1="150" y1="0" x2="150" y2="500" gradientUnits="userSpaceOnUse"><stop stop-color="#202738" id="prefix__stop67"/><stop offset="1" stop-color="#070816" id="prefix__stop68"/></linearGradient><linearGradient id="prefix__paint1_linear_571_520" x1="108" y1="37" x2="109.881" y2="12.594" gradientUnits="userSpaceOnUse"><stop offset=".1" stop-color="#1DB954" id="prefix__stop69"/><stop offset="1" stop-color="#0062FF" id="prefix__stop70"/></linearGradient><clipPath id="prefix__clip0_571_520"><rect width="300" height="500" rx="30" fill="#fff" id="prefix__rect70"/></clipPath><filter id="prefix__filter0_d_571_520" x="177" y="371" width="50.835" height="42.65" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feFlood flood-opacity="0" result="BackgroundImageFix" id="prefix__feFlood65"/><feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha" id="prefix__feColorMatrix65"/><feOffset dy="4" id="prefix__feOffset65"/><feGaussianBlur stdDeviation="2" id="prefix__feGaussianBlur65"/><feComposite in2="hardAlpha" operator="out" id="prefix__feComposite65"/><feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.5 0" id="prefix__feColorMatrix66"/><feBlend mode="normal" in2="BackgroundImageFix" result="effect1_dropShadow_571_520" id="prefix__feBlend66"/><feBlend mode="normal" in="SourceGraphic" in2="effect1_dropShadow_571_520" result="shape" id="prefix__feBlend67"/></filter></defs></svg>'
                )
            );
    }
}
