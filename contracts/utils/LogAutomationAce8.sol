// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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

interface IFunctionsConsumer {
    function emitUpdateGame(uint8 updatePhase, uint256 gameDataIndex) external;
}

interface ILogAutomation {
    function checkLog(
        Log calldata log,
        bytes memory checkData
    ) external returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}

interface IGamesHub {
    function checkRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    function games(bytes32) external view returns (address);

    function helpers(bytes32) external view returns (address);
}

interface IAceTheBrackets8 {
    function getRoundFullData(
        uint256 gameIndex,
        uint8 round
    ) external view returns (bytes memory);

    function getTokensIds(
        bytes memory _symbols
    ) external view returns (uint256[8] memory);

    function getGameStatus(
        uint256 gameIndex
    ) external view returns (uint8 status);

    // _dataNewGame: [uint256[8] numericValues, string[8] coinSymbols]
    function createGame(bytes calldata _dataNewGame) external;

    function advanceGame(
        uint256 gameIndex,
        uint256 _lastTimeStamp,
        bytes memory _prices,
        bytes memory _pricesWinners,
        bytes memory _winners
    ) external;
}

contract LogAutomationAce8 is ILogAutomation {
    event UpdateDataStored(uint256 indexed index);
    event UpdateExecuted(uint256 indexed gameId);

    IGamesHub public gamesHub;

    mapping(uint256 => bytes) public updateData;
    uint256 public updateDataIndex;

    /**
     * @dev Constructor function
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
    }

    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        performData = abi.encode(
            bytes32ToUint8(log.topics[1]),
            bytes32ToUint256(log.topics[2])
        );
    }

    function performUpkeep(bytes calldata performData) external override {
        (uint8 updatePhase, uint256 gameDataIndex) = abi.decode(
            performData,
            (uint8, uint256)
        );

        IAceTheBrackets8 aceTheBrackets8 = IAceTheBrackets8(
            gamesHub.games(keccak256("ACE8_TEST"))
        );

        if (updatePhase == 0) {
            updateData[updateDataIndex] = parseMarketDataNew(
                string(updateData[gameDataIndex])
            );
            emit UpdateDataStored(updateDataIndex);

            IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
                .emitUpdateGame(1, updateDataIndex);
            updateDataIndex++;
        } else if (updatePhase == 1) {
            aceTheBrackets8.createGame(updateData[gameDataIndex]);
        } else if (updatePhase == 2) {
            (
                uint256 gameId,
                uint256[8] memory pricesBegin,
                uint256[8] memory prices,
                uint256[8] memory tokensIds
            ) = logDataToGameUpdate(updateData[gameDataIndex]);

            (
                uint256[8] memory winners,
                uint256[8] memory pricesWinners
            ) = determineWinners(tokensIds, pricesBegin, prices);

            updateData[updateDataIndex] = abi.encode(
                gameId,
                abi.encode(prices),
                abi.encode(pricesWinners),
                abi.encode(winners)
            );
            emit UpdateDataStored(updateDataIndex);

            IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
                .emitUpdateGame(3, updateDataIndex);
            updateDataIndex++;
        } else {
            (
                uint256 gameId,
                bytes memory prices,
                bytes memory pricesWinners,
                bytes memory winners
            ) = abi.decode(
                    updateData[gameDataIndex],
                    (uint256, bytes, bytes, bytes)
                );

            aceTheBrackets8.advanceGame(
                gameId,
                block.timestamp,
                prices,
                pricesWinners,
                winners
            );
            emit UpdateExecuted(gameId);
        }
    }

    /**
     * @dev Prepares the data for updating the game
     * @param logData The log data
     * @return gameId The ID of the game
     * @return pricesBegin The previous prices to compare
     * @return prices The new prices to compare
     * @return tokensIds The IDs of the tokens
     */

    function logDataToGameUpdate(
        bytes memory logData
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
        (uint256 gameId, uint256[8] memory prices) = abi.decode(
            logData,
            (uint256, uint256[8])
        );

        IAceTheBrackets8 aceTheBrackets8 = IAceTheBrackets8(
            gamesHub.games(keccak256("ACE8_TEST"))
        );

        bytes memory roundFullData = aceTheBrackets8.getRoundFullData(
            gameId,
            aceTheBrackets8.getGameStatus(gameId) //round number
        );

        (
            string[8] memory tokenSymbols,
            uint256[8] memory pricesBegin,
            ,
            ,

        ) = abi.decode(
                roundFullData,
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );

        return (
            gameId,
            pricesBegin,
            prices,
            aceTheBrackets8.getTokensIds(abi.encode(tokenSymbols))
        );
    }

    /**
     * @dev Store the updated data, returning the index
     * @param data The data to store
     * @return The index of the stored data
     */
    function storeUpdateData(bytes memory data) external returns (uint256) {
        updateData[updateDataIndex] = data;
        emit UpdateDataStored(updateDataIndex);
        return updateDataIndex++;
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
        int256 variation = int256(priceEnd) - int256(priceBegin);
        return (variation * 1e18) / int256(priceBegin);
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
                    uint256(keccak256(abi.encodePacked(block.timestamp, i))) %
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
     * @notice Parse market data string and return two arrays
     * @param _marketData String in the format "10603,IMX;20947,SUI;4948,CKB;8119,SFP;23254,CORE;3640,LPT;1518,MKR;28321,POL"
     * @return bytes Encoded Array of numeric values and Array of coin symbols
     */
    function parseMarketDataNew(
        string memory _marketData
    ) public pure returns (bytes memory) {
        bytes memory data = bytes(_marketData);
        uint256[8] memory numericValues;
        string[8] memory coinSymbols;

        uint256 startIndex = 0;
        uint256 endIndex;
        uint256 commaIndex;

        for (uint256 i = 0; i < 8; i++) {
            for (endIndex = startIndex; endIndex < data.length; endIndex++) {
                if (data[endIndex] == 0x2c) {
                    // ',' character
                    commaIndex = endIndex;
                } else if (
                    data[endIndex] == 0x3b || endIndex == data.length - 1
                ) {
                    // ';' character or end of string
                    break;
                }
            }
            numericValues[i] = parseUint(data, startIndex, commaIndex);
            coinSymbols[i] = substring(data, commaIndex + 1, endIndex);
            startIndex = endIndex + 1;
        }

        return abi.encode(numericValues, coinSymbols);
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
