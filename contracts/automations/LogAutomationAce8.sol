// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTheBrackets8.sol";

struct Log {
    uint256 index; // Index of the log in the block
    uint256 timestamp; // Timestamp of the block containing the log
    bytes32 txHash; // Hash of the transaction containing the log
    uint256 blockNumber; // Number of the block containing the log
    bytes32 blockHash; // Hash of the block containing the log
    address source; // Address of the contract that emitted the log
    bytes32[] topics; // Indexed topics of the log
    bytes data; // Data of the log
}

interface ILogAutomation {
    function checkLog(
        Log calldata log,
        bytes memory checkData
    ) external returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}

interface IAutomationTop100 {
    function sendRequestNewGame(
        string calldata arg0,
        string calldata arg1,
        bytes32 contractSymbol
    ) external;
}

interface IFunctionsConsumer {
    function updateData(uint256 _gameId) external view returns (bytes memory);
}

interface ICoins100Store {
    function prepareNewGame8(
        uint8[8] memory coinIndexes
    ) external view returns (bytes memory);
}

contract LogAutomationAce8 is ILogAutomation {
    event UpdateDataStored(uint256 indexed index);
    event UpdateExecuted(uint256 indexed gameId);
    event GameTimeStarted(uint256 timeStamp);
    event NewGameRequested();
    event NewGameExecuted();

    IGamesHub public gamesHub;

    bytes private emptyBytes;

    address public forwarder;

    /**
     * @dev Constructor function
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
        uint256[8] memory emptyArray;
        emptyBytes = abi.encode(emptyArray);
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
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        uint8 updatePhase = bytes32ToUint8(log.topics[1]);
        uint256 dataId = bytes32ToUint256(log.topics[2]);

        if (updatePhase == 0) {
            //New game requested
            performData = abi.encode(updatePhase, "");
        } else if (updatePhase == 1) {
            //New game executed
            performData = abi.encode(
                updatePhase,
                ICoins100Store(gamesHub.helpers(keccak256("COINS100")))
                    .prepareNewGame8(
                        parseUint8Array(
                            IFunctionsConsumer(
                                gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                            ).updateData(dataId)
                        )
                    )
            );
        } else if (updatePhase == 2) {
            //Advance Rounds
            (
                uint256 gameId,
                uint256[8] memory pricesBegin,
                uint256[8] memory prices,
                uint256[8] memory tokensIds
            ) = pricesDataToGameUpdate(
                    IFunctionsConsumer(
                        gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                    ).updateData(dataId)
                );

            (
                uint256[8] memory winners,
                uint256[8] memory pricesWinners
            ) = determineWinners(tokensIds, pricesBegin, prices);

            performData = abi.encode(
                updatePhase,
                abi.encode(
                    gameId,
                    abi.encode(prices),
                    abi.encode(pricesWinners),
                    abi.encode(winners)
                )
            );
        } else if (updatePhase == 6) {
            //Activate game timer
            performData = abi.encode(
                updatePhase,
                abi.encode(
                    [dataId, 0, 0, 0],
                    [emptyBytes, emptyBytes, emptyBytes, emptyBytes],
                    [emptyBytes, emptyBytes, emptyBytes, emptyBytes],
                    [emptyBytes, emptyBytes, emptyBytes, emptyBytes]
                )
            );
        } else {
            upkeepNeeded = false;
        }
    }

    function testCheckLog(
        uint8 updatePhase,
        uint256 dataId
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;

        if (updatePhase == 0) {
            //New game requested
            performData = abi.encode(updatePhase, "");
        } else if (updatePhase == 1) {
            //New game executed
            performData = abi.encode(
                updatePhase,
                ICoins100Store(gamesHub.helpers(keccak256("COINS100")))
                    .prepareNewGame8(
                        parseUint8Array(
                            IFunctionsConsumer(
                                gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                            ).updateData(dataId)
                        )
                    )
            );
        } else if (updatePhase == 2) {
            //Advance Rounds
            (
                uint256 gameId,
                uint256[8] memory pricesBegin,
                uint256[8] memory prices,
                uint256[8] memory tokensIds
            ) = pricesDataToGameUpdate(
                    IFunctionsConsumer(
                        gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                    ).updateData(dataId)
                );

            (
                uint256[8] memory winners,
                uint256[8] memory pricesWinners
            ) = determineWinners(tokensIds, pricesBegin, prices);

            performData = abi.encode(
                updatePhase,
                abi.encode(
                    gameId,
                    abi.encode(prices),
                    abi.encode(pricesWinners),
                    abi.encode(winners)
                )
            );
        } else if (updatePhase == 6) {
            //Activate game timer
            performData = abi.encode(
                updatePhase,
                abi.encode(
                    [dataId, 0, 0, 0],
                    [emptyBytes, emptyBytes, emptyBytes, emptyBytes],
                    [emptyBytes, emptyBytes, emptyBytes, emptyBytes],
                    [emptyBytes, emptyBytes, emptyBytes, emptyBytes]
                )
            );
        } else {
            upkeepNeeded = false;
        }
    }

    function performUpkeep(
        bytes calldata performData
    ) external override onlyForwarder {
        if (forwarder == address(0)) {
            forwarder = msg.sender;
        }
        (uint8 updatePhase, bytes memory _updateData) = abi.decode(
            performData,
            (uint8, bytes)
        );

        if (updatePhase == 0) {
            IAutomationTop100(gamesHub.helpers(keccak256("AUTOMATION_TOP100")))
                .sendRequestNewGame("N8", "8", keccak256("FUNCTIONS_ACE8"));
            emit NewGameRequested();
        } else if (updatePhase == 1) {
            IAceTheBrackets8(gamesHub.games(keccak256("ACE8_PROXY")))
                .performGames(_updateData, "", block.timestamp);
            emit NewGameExecuted();
        } else if (updatePhase == 2) {
            (
                uint256 gameId,
                bytes memory prices,
                bytes memory pricesWinners,
                bytes memory winners
            ) = abi.decode(_updateData, (uint256, bytes, bytes, bytes));
            uint256 timeStamp = (block.timestamp / 120) * 120;

            IAceTheBrackets8(gamesHub.games(keccak256("ACE8_PROXY")))
                .performGames(
                    "",
                    abi.encode(
                        [gameId, 0, 0, 0],
                        [prices, emptyBytes, emptyBytes, emptyBytes],
                        [pricesWinners, emptyBytes, emptyBytes, emptyBytes],
                        [winners, emptyBytes, emptyBytes, emptyBytes]
                    ),
                    timeStamp
                );
            emit UpdateExecuted(gameId);
        } else if (updatePhase == 6) {
            uint256 timeStamp = (block.timestamp / 120) * 120;
            IAceTheBrackets8(gamesHub.games(keccak256("ACE8_PROXY")))
                .performGames("", _updateData, timeStamp);
            emit GameTimeStarted(timeStamp);
        }
    }

    /**
     * @dev Prepares the data for updating the game
     * @param pricesData The log data
     * @return gameId The ID of the game
     * @return pricesBegin The previous prices to compare
     * @return prices The new prices to compare
     * @return tokensIds The IDs of the tokens
     */

    function pricesDataToGameUpdate(
        bytes memory pricesData
    )
        public
        view
        returns (
            uint256,
            uint256[8] memory,
            uint256[8] memory,
            uint256[8] memory
        )
    {
        uint256[8] memory prices = parseUint256Array(pricesData);

        IAceTheBrackets8 aceTheBrackets8 = IAceTheBrackets8(
            gamesHub.games(keccak256("ACE8"))
        );

        uint256[] memory gameIds = aceTheBrackets8.getActiveGames();
        uint8 status = aceTheBrackets8.getGameStatus(gameIds[0]);

        (
            string[8] memory tokenSymbols,
            uint256[8] memory pricesBegin,
            ,
            ,

        ) = abi.decode(
                aceTheBrackets8.getRoundFullData(
                    gameIds[0],
                    status == 0 ? 0 : status - 1
                ),
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );
        return (
            gameIds[0],
            pricesBegin,
            prices,
            aceTheBrackets8.getTokensIds(abi.encode(tokenSymbols))
        );
    }

    /**
     * @dev Calculates the price variation between two values
     * @param priceBegin The starting price
     * @param priceEnd The ending price
     * @return int256 The price variation (can be positive or negative)
     */
    function calculatePriceVariation(
        uint256 priceBegin,
        uint256 priceEnd
    ) public pure returns (int256) {
        if (priceBegin == priceEnd) {
            return 0;
        }
        int256 _priceBegin = priceBegin == 0 ? int256(1) : int256(priceBegin);
        int256 variation = int256(priceEnd) - int256(priceBegin);
        return (variation * 1e18) / _priceBegin;
    }

    /**
     * @dev Determines winners based on price variations of token pairs
     * @param tokensIds Array of token IDs
     * @param pricesBegin Array of starting prices
     * @param pricesEnd Array of ending prices
     * @return winners Array of winning token IDs
     * @return pricesWinners Array of winning token prices
     */
    function determineWinners(
        uint256[8] memory tokensIds,
        uint256[8] memory pricesBegin,
        uint256[8] memory pricesEnd
    )
        public
        view
        returns (uint256[8] memory winners, uint256[8] memory pricesWinners)
    {
        for (uint256 i = 0; i < 4; i++) {
            int256 variation1 = calculatePriceVariation(
                pricesBegin[i * 2],
                pricesEnd[i * 2]
            );
            int256 variation2 = calculatePriceVariation(
                pricesBegin[i * 2 + 1],
                pricesEnd[i * 2 + 1]
            );

            if (variation1 > variation2) {
                winners[i] = tokensIds[i * 2];
                pricesWinners[i] = pricesEnd[i * 2];
            } else if (variation2 > variation1) {
                winners[i] = tokensIds[i * 2 + 1];
                pricesWinners[i] = pricesEnd[i * 2 + 1];
            } else {
                // In case of a tie, decide randomly
                if (
                    uint256(
                        keccak256(
                            abi.encodePacked(blockhash(block.number - 1), i)
                        )
                    ) %
                        2 ==
                    0
                ) {
                    winners[i] = tokensIds[i * 2];
                    pricesWinners[i] = pricesEnd[i * 2];
                } else {
                    winners[i] = tokensIds[i * 2 + 1];
                    pricesWinners[i] = pricesEnd[i * 2 + 1];
                }
            }
        }

        // Fill the remaining positions with zeros
        for (uint256 i = 4; i < 8; i++) {
            winners[i] = 0;
            pricesWinners[i] = 0;
        }

        return (winners, pricesWinners);
    }

    function bytes32ToUint256(bytes32 b) private pure returns (uint256) {
        return uint256(b);
    }

    function bytes32ToUint8(bytes32 b) private pure returns (uint8) {
        return uint8(uint256(b));
    }

    /**
     * @notice Parse a string array and return an array of uint256
     * @param stringArray Bytes from string in the format "10603,20947,4948,8119,23254,3640,1518,28321"
     * @return pricesEnd Array of 8 uint256 values
     */
    function parseUint256Array(
        bytes memory stringArray
    ) public pure returns (uint256[8] memory pricesEnd) {
        uint256 startIndex = 0;
        uint256 endIndex;

        for (uint256 i = 0; i < 8; i++) {
            for (
                endIndex = startIndex;
                endIndex < stringArray.length;
                endIndex++
            ) {
                if (
                    stringArray[endIndex] == 0x2c ||
                    endIndex == stringArray.length - 1
                ) {
                    // ',' character or end of string
                    break;
                }
            }
            pricesEnd[i] = parseUint(stringArray, startIndex, endIndex + (endIndex == stringArray.length - 1 ? 1 : 0));
            startIndex = endIndex + 1;
        }

        return pricesEnd;
    }

    /**
     * @notice Parse a string array and return an array of uint8
     * @param stringArray Bytes from string in the format "10,20,4,8,23,3,1,28"
     * @return values Array of 8 uint8 values
     */
    function parseUint8Array(
        bytes memory stringArray
    ) public pure returns (uint8[8] memory values) {
        uint256 startIndex = 0;
        uint256 endIndex;

        for (uint256 i = 0; i < 8; i++) {
            for (
                endIndex = startIndex;
                endIndex < stringArray.length;
                endIndex++
            ) {
                if (
                    stringArray[endIndex] == 0x2c ||
                    endIndex == stringArray.length - 1
                ) {
                    // ',' character or end of string
                    break;
                }
            }
            uint256 value = parseUint(stringArray, startIndex, endIndex + (endIndex == stringArray.length - 1 ? 1 : 0));
            require(value <= type(uint8).max, "Value exceeds uint8 max");
            values[i] = uint8(value);
            startIndex = endIndex + 1;
        }

        return values;
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
    ) private pure returns (string memory) {
        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            result[i] = data[start + i];
        }
        return string(result);
    }
}
