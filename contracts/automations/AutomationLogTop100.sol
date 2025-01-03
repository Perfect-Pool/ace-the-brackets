// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../interfaces/IGamesHub.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

struct Log {
    uint256 index;
    uint256 timestamp;
    bytes32 txHash;
    uint256 blockNumber;
    bytes32 blockHash;
    address source;
    bytes32[] topics;
    bytes data;
}

interface ILogAutomation {
    function checkLog(
        Log calldata log,
        bytes memory checkData
    ) external returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}

interface ICoins100Store {
    struct CoinData {
        bytes symbol;
        uint256 cmcId;
        bytes geckoId;
    }

    function storeCoin(uint8 index, CoinData memory coin) external;

    function lastStoredIndex() external view returns (uint8);
}

interface IAutomationTop100 {
    function setIndexIterator(uint256 newIndexIterator) external;
}

interface IFunctionsConsumer {
    function updateData(uint256) external view returns (bytes memory);
}

contract AutomationLogTop100 is ILogAutomation {
    using Strings for uint256;
    using Strings for uint8;

    IGamesHub public gamesHub;
    address public forwarder;

    /**
     * @dev Constructor function
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
    }

    /** MODIFIERS **/
    modifier onlyForwarder() {
        require(
            forwarder == address(0) || msg.sender == forwarder,
            "Restricted to forwarder"
        );
        _;
    }

    function checkLog(
        Log calldata log,
        bytes memory
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // Check if updatePhaseIndex = 5 (Top100)
        uint8 updatePhaseIndex = bytes32ToUint8(log.topics[1]);
        if (updatePhaseIndex != 5) return (false, "");

        // Get gameDataIndex from the event
        uint256 gameDataIndex = bytes32ToUint256(log.topics[2]);

        // Parse market data
        (
            uint256 lastIndex,
            ICoins100Store.CoinData[] memory coins
        ) = parseCoinsReturn(
                IFunctionsConsumer(
                    gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                ).updateData(gameDataIndex)
            );

        // Encode data for performUpkeep
        performData = abi.encode(lastIndex, coins);
        upkeepNeeded = true;
    }

    function performUpkeep(
        bytes calldata performData
    ) external override onlyForwarder {
        if (forwarder == address(0)) {
            forwarder = msg.sender;
        }

        // Decode performData
        (uint256 lastIndex, ICoins100Store.CoinData[] memory coins) = abi
            .decode(performData, (uint256, ICoins100Store.CoinData[]));

        // Get current stored index
        ICoins100Store coins100Store = ICoins100Store(
            gamesHub.helpers(keccak256("COINS100"))
        );
        uint8 currentIndex = coins100Store.lastStoredIndex();
        if (currentIndex != 0) {
            currentIndex = currentIndex + 1;
        }

        // Store each coin
        for (uint8 i = 0; i < coins.length; i++) {
            uint8 index = currentIndex + i;
            coins100Store.storeCoin(index, coins[i]);
            if (index == 99) {
                break;
            }
        }

        IAutomationTop100 automationTop100 = IAutomationTop100(
            gamesHub.helpers(keccak256("AUTOMATION_TOP100"))
        );

        // If we haven't stored all 100 coins yet, request more
        if (coins100Store.lastStoredIndex() > 0) {
            automationTop100.setIndexIterator(lastIndex);
        } else {
            automationTop100.setIndexIterator(0);
        }
    }

    /**
     * @notice Parse market data string and return two arrays
     * @param _marketData Bytes from string in the format "12;1,bitcoin,BTC;1027,ethereum,ETH;..."
     * @return bytes Encoded Array of CoinData
     */
    function parseCoinsReturn(
        bytes memory _marketData
    ) public pure returns (uint256, ICoins100Store.CoinData[] memory) {
        uint256 startIndex = 0;
        uint256 endIndex;
        uint256 commaIndex;
        uint256 secondCommaIndex;

        // Find first semicolon to get lastIndex
        for (endIndex = 0; endIndex < _marketData.length; endIndex++) {
            if (_marketData[endIndex] == 0x3b) {
                // ';' character
                break;
            }
        }
        uint256 lastIndex = parseUint(_marketData, 0, endIndex);
        startIndex = endIndex + 1;

        // Count number of coins by counting semicolons
        uint256 coinCount = 0;
        for (uint256 i = startIndex; i < _marketData.length; i++) {
            if (_marketData[i] == 0x3b) {
                coinCount++;
            }
        }
        if (_marketData[_marketData.length - 1] != 0x3b) {
            coinCount++;
        }

        ICoins100Store.CoinData[] memory coins = new ICoins100Store.CoinData[](
            coinCount
        );
        uint256 coinIndex = 0;

        while (startIndex < _marketData.length && coinIndex < coinCount) {
            // Find first comma for cmcId
            for (
                endIndex = startIndex;
                endIndex < _marketData.length;
                endIndex++
            ) {
                if (_marketData[endIndex] == 0x2c) {
                    // ',' character
                    commaIndex = endIndex;
                    break;
                }
            }

            // Find second comma for geckoId
            for (
                endIndex = commaIndex + 1;
                endIndex < _marketData.length;
                endIndex++
            ) {
                if (_marketData[endIndex] == 0x2c) {
                    // ',' character
                    secondCommaIndex = endIndex;
                    break;
                }
            }

            // Find semicolon or end of string for symbol
            for (
                endIndex = secondCommaIndex + 1;
                endIndex < _marketData.length;
                endIndex++
            ) {
                if (_marketData[endIndex] == 0x3b) {
                    // ';' character
                    break;
                }
            }

            coins[coinIndex].cmcId = parseUint(
                _marketData,
                startIndex,
                commaIndex
            );
            coins[coinIndex].geckoId = substring(
                _marketData,
                commaIndex + 1,
                secondCommaIndex
            );
            coins[coinIndex].symbol = substring(
                _marketData,
                secondCommaIndex + 1,
                endIndex
            );

            startIndex = endIndex + 1;
            coinIndex++;
        }

        return (lastIndex, coins);
    }

    function bytes32ToUint256(bytes32 b) private pure returns (uint256) {
        return uint256(b);
    }

    function bytes32ToUint8(bytes32 b) private pure returns (uint8) {
        return uint8(uint256(b));
    }

    // Optimized helper function to parse uint256 from bytes
    function parseUint(
        bytes memory data,
        uint256 start,
        uint256 end
    ) private pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = start; i < end; i++) {
            result = result * 10 + uint8(data[i]) - 48;
        }
        return result;
    }

    // Optimized helper function to extract a substring from bytes
    function substring(
        bytes memory data,
        uint256 start,
        uint256 end
    ) private pure returns (bytes memory) {
        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    function testCheckLog(
        uint8 updatePhaseIndex,
        uint256 gameDataIndex,
        bytes memory
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (updatePhaseIndex != 5) return (false, "");

        // Parse market data
        (
            uint256 lastIndex,
            ICoins100Store.CoinData[] memory coins
        ) = parseCoinsReturn(
                IFunctionsConsumer(
                    gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                ).updateData(gameDataIndex)
            );

        // Encode data for performUpkeep
        performData = abi.encode(lastIndex, coins);
        upkeepNeeded = true;
    }
}
