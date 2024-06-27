// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FakePriceFeed {
    AggregatorV3Interface internal priceFeed;

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        uint256 roundsToGoBack = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1)))
        ) % 20;
        (uint80 _latestRound, , , , ) = priceFeed.latestRoundData();
        return priceFeed.getRoundData(_latestRound - uint80(roundsToGoBack));
    }
}
