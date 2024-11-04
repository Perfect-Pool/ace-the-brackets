// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IGamesHub.sol";

contract Coins100Store {
    struct CoinData {
        bytes symbol;
        uint256 cmcId;
        bytes geckoId;
    }
    IGamesHub public gamesHub;

    /**
     * @dev Constructor function
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
    }

    mapping(uint256 => CoinData) public coinDataByID; // cmcId para CoinData
    mapping(bytes => CoinData) public coinDataBySymbol; // symbol para CoinData
    mapping(uint8 => uint256) public top100ChosenCoins;
    uint8 public lastStoredIndex;

    modifier onlyAutomation() {
        require(
            msg.sender == gamesHub.helpers(keccak256("AUTOMATIONLOG_TOP100")),
            "Restricted to Project's contracts"
        );
        _;
    }

    function storeCoin(
        uint8 index,
        CoinData memory coin
    ) public onlyAutomation {
        require(index <= 99, "Index must be less than 100");

        coinDataByID[coin.cmcId] = coin;
        coinDataBySymbol[coin.symbol] = coin;
        top100ChosenCoins[index] = coin.cmcId;

        if (index == 99) {
            lastStoredIndex = 0;
        } else if (index > lastStoredIndex) {
            lastStoredIndex = index;
        }
    }

    function prepareNewGame8(
        uint8[8] memory coinIndexes
    ) public view returns (bytes memory) {
        uint256[8] memory cmcIds;
        string[8] memory symbols;

        for (uint8 i = 0; i < 8; i++) {
            require(coinIndexes[i] <= 99, "Index must be less than 100");
            uint256 cmcId = top100ChosenCoins[coinIndexes[i]];
            CoinData memory coin = coinDataByID[cmcId];

            cmcIds[i] = coin.cmcId;
            symbols[i] = string(coin.symbol);
        }

        return abi.encode(cmcIds, symbols);
    }

    function prepareNewGame16(
        uint8[16] memory coinIndexes
    ) public view returns (bytes memory) {
        uint256[16] memory cmcIds;
        string[16] memory symbols;

        for (uint8 i = 0; i < 16; i++) {
            require(coinIndexes[i] <= 99, "Index must be less than 100");
            uint256 cmcId = top100ChosenCoins[coinIndexes[i]];
            CoinData memory coin = coinDataByID[cmcId];

            cmcIds[i] = coin.cmcId;
            symbols[i] = string(coin.symbol);
        }

        return abi.encode(cmcIds, symbols);
    }

    function coinGeckoIDs8(
        string[8] memory _symbols
    ) public view returns (string[8] memory) {
        string[8] memory geckoIds;

        for (uint8 i = 0; i < 8; i++) {
            bytes memory symbolBytes = bytes(_symbols[i]);
            CoinData memory coin = coinDataBySymbol[symbolBytes];
            geckoIds[i] = string(coin.geckoId);
        }

        return geckoIds;
    }

    function coinGeckoIDs16(
        string[16] memory _symbols
    ) public view returns (string[16] memory) {
        string[16] memory geckoIds;

        for (uint8 i = 0; i < 16; i++) {
            bytes memory symbolBytes = bytes(_symbols[i]);
            CoinData memory coin = coinDataBySymbol[symbolBytes];
            geckoIds[i] = string(coin.geckoId);
        }

        return geckoIds;
    }
}
