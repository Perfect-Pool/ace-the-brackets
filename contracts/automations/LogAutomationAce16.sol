// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTheBrackets16.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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
        string calldata arg1
    ) external;
}

interface IFunctionsConsumer {
    function updateData(uint256 _gameId) external view returns (bytes memory);
}

interface ICoins100Store {
    function prepareNewGame16(
        uint8[16] memory coinIndexes
    ) external view returns (bytes memory);
}

contract LogAutomationAce16 is ILogAutomation {
    using Strings for uint256;

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
        uint256[16] memory emptyArray;
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

        if (updatePhase == 7) {
            //New game requested
            performData = abi.encode(updatePhase, "");
        } else if (updatePhase == 3) {
            //New game executed
            performData = abi.encode(
                updatePhase,
                ICoins100Store(gamesHub.helpers(keccak256("COINS100")))
                    .prepareNewGame16(
                        parseUint8Array(
                            IFunctionsConsumer(
                                gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                            ).updateData(dataId)
                        )
                    )
            );
        } else if (updatePhase == 4) {
            //Advance Rounds
            IAceTheBrackets16 aceTheBrackets16 = IAceTheBrackets16(
                gamesHub.games(keccak256("ACE16"))
            );
            uint256[16] memory prices = parseUint256Array(
                IFunctionsConsumer(
                    gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                ).updateData(dataId)
            );

            uint256[] memory gameIds = aceTheBrackets16.getActiveGames();

            performData = abi.encode(
                updatePhase,
                abi.encode(gameIds[0], prices)
            );
        } else if (updatePhase == 8) {
            //Activate game timer
            performData = abi.encode(
                4,
                abi.encode(dataId, emptyBytes, emptyBytes, emptyBytes)
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

        if (updatePhase == 7) {
            //New game requested
            performData = abi.encode(updatePhase, "");
        } else if (updatePhase == 3) {
            //New game executed
            performData = abi.encode(
                updatePhase,
                ICoins100Store(gamesHub.helpers(keccak256("COINS100")))
                    .prepareNewGame16(
                        parseUint8Array(
                            IFunctionsConsumer(
                                gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                            ).updateData(dataId)
                        )
                    )
            );
        } else if (updatePhase == 4) {
            //Advance Rounds
            IAceTheBrackets16 aceTheBrackets16 = IAceTheBrackets16(
                gamesHub.games(keccak256("ACE16"))
            );
            uint256[16] memory prices = parseUint256Array(
                IFunctionsConsumer(
                    gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                ).updateData(dataId)
            );

            uint256[] memory gameIds = aceTheBrackets16.getActiveGames();

            performData = abi.encode(
                updatePhase,
                abi.encode(gameIds[0], prices)
            );
        } else if (updatePhase == 8) {
            //Activate game timer
            performData = abi.encode(
                4,
                abi.encode(dataId, emptyBytes, emptyBytes, emptyBytes)
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

        if (updatePhase == 7) {
            IAutomationTop100(gamesHub.helpers(keccak256("AUTOMATION_TOP100")))
                .sendRequestNewGame("N16", "16");
            emit NewGameRequested();
        } else if (updatePhase == 3) {
            IAceTheBrackets16(gamesHub.games(keccak256("ACE16_PROXY")))
                .performGames(_updateData, "", block.timestamp);
            emit NewGameExecuted();
        } else if (updatePhase == 4) {
            (uint256 gameId, uint256[16] memory prices) = abi.decode(
                _updateData,
                (uint256, uint256[16])
            );

            (
                uint256[16] memory pricesBegin,
                uint256[16] memory tokensIds
            ) = actualGameData(gameId);

            (
                uint256[16] memory winners,
                uint256[16] memory pricesWinners
            ) = determineWinners(tokensIds, pricesBegin, prices);

            uint256 timeStamp = (block.timestamp / 120) * 120;

            IAceTheBrackets16(gamesHub.games(keccak256("ACE16_PROXY")))
                .performGames(
                    "",
                    abi.encode(
                        [gameId, 0, 0, 0, 0],
                        [
                            abi.encode(prices),
                            emptyBytes,
                            emptyBytes,
                            emptyBytes,
                            emptyBytes
                        ],
                        [
                            abi.encode(pricesWinners),
                            emptyBytes,
                            emptyBytes,
                            emptyBytes,
                            emptyBytes
                        ],
                        [
                            abi.encode(winners),
                            emptyBytes,
                            emptyBytes,
                            emptyBytes,
                            emptyBytes
                        ]
                    ),
                    timeStamp
                );
            emit UpdateExecuted(gameId);
        }
    }

    /**
     * @dev Prepares the data for updating the game
     * @param gameId The index of the game
     * @return pricesBegin The starting prices
     * @return tokensIds The array of token IDs
     */
    function actualGameData(
        uint256 gameId
    ) public view returns (uint256[16] memory, uint256[16] memory) {
        IAceTheBrackets16 aceTheBrackets16 = IAceTheBrackets16(
            gamesHub.games(keccak256("ACE16"))
        );
        uint8 status = aceTheBrackets16.getGameStatus(gameId);

        (
            string[16] memory tokenSymbols,
            uint256[16] memory pricesBegin,
            ,
            ,

        ) = abi.decode(
                aceTheBrackets16.getRoundFullData(
                    gameId,
                    status == 0 ? 0 : status - 1
                ),
                (string[16], uint256[16], uint256[16], uint256, uint256)
            );
        return (
            pricesBegin,
            aceTheBrackets16.getTokensIds(abi.encode(tokenSymbols))
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
        uint256[16] memory tokensIds,
        uint256[16] memory pricesBegin,
        uint256[16] memory pricesEnd
    )
        public
        view
        returns (uint256[16] memory winners, uint256[16] memory pricesWinners)
    {
        for (uint256 i = 0; i < 8; i++) {
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
        for (uint256 i = 4; i < 16; i++) {
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
    ) public pure returns (uint256[16] memory pricesEnd) {
        uint256 startIndex = 0;
        uint256 endIndex;

        for (uint256 i = 0; i < 16; i++) {
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
            pricesEnd[i] = parseUint(stringArray, startIndex, endIndex);
            startIndex = endIndex + 1;
        }

        return pricesEnd;
    }

    /**
     * @notice Parse a string array and return an array of uint8
     * @param stringArray Bytes from string in the format "10,20,4,8,23,3,1,28"
     * @return values Array of 16 uint8 values
     */
    function parseUint8Array(
        bytes memory stringArray
    ) public pure returns (uint8[16] memory values) {
        uint256 startIndex = 0;
        uint256 endIndex;

        for (uint256 i = 0; i < 16; i++) {
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
            uint256 value = parseUint(stringArray, startIndex, endIndex);
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

    function arrayUint256ToStringBytes1(
        uint256[16] memory array
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    array[0].toString(),
                    ",",
                    array[1].toString(),
                    ",",
                    array[2].toString(),
                    ",",
                    array[3].toString(),
                    ",",
                    array[4].toString(),
                    ",",
                    array[5].toString(),
                    ",",
                    array[6].toString(),
                    ",",
                    array[7].toString()
                )
            );
    }

    function arrayUint256ToStringBytes2(
        uint256[16] memory array
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    array[8].toString(),
                    ",",
                    array[9].toString(),
                    ",",
                    array[10].toString(),
                    ",",
                    array[11].toString(),
                    ",",
                    array[12].toString(),
                    ",",
                    array[13].toString(),
                    ",",
                    array[14].toString(),
                    ",",
                    array[15].toString()
                )
            );
    }

    function arrayStringsToBytes1(
        string[16] memory array
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    array[0],
                    ",",
                    array[1],
                    ",",
                    array[2],
                    ",",
                    array[3],
                    ",",
                    array[4],
                    ",",
                    array[5],
                    ",",
                    array[6],
                    ",",
                    array[7]
                )
            );
    }

    function arrayStringsToBytes2(
        string[16] memory array
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    array[8],
                    ",",
                    array[9],
                    ",",
                    array[10],
                    ",",
                    array[11],
                    ",",
                    array[12],
                    ",",
                    array[13],
                    ",",
                    array[14],
                    ",",
                    array[15]
                )
            );
    }
}
