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
    IGamesHub public gamesHub;

    /**
     * @dev Constructor function
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
    }

    function checkLog(
        Log calldata log,
        bytes memory checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;

        if (checkData.length == 0) {
            // new game
            performData = abi.encode(true, log.data);
        } else {
            // update game
            (
                uint256 gameId,
                uint256[8] memory pricesBegin,
                uint256[8] memory prices,
                uint256[8] memory tokensIds
            ) = logDataToGameUpdate(log.data);

            performData = abi.encode(
                false,
                abi.encode(
                    gameId,
                    pricesBegin,
                    prices,
                    tokensIds
                )
            );
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        (bool isNewGame, bytes memory data) = abi.decode(
            performData,
            (bool, bytes)
        );

        IAceTheBrackets8 aceTheBrackets8 = IAceTheBrackets8(
            gamesHub.games(keccak256("ACE8_TEST"))
        );

        if (isNewGame) {
            aceTheBrackets8.createGame(data);
        } else {
            (
                uint256 gameId,
                uint256[8] memory pricesBegin,
                uint256[8] memory prices,
                uint256[8] memory tokensIds
            ) = abi.decode(data, (uint256, uint256[8], uint256[8], uint256[8]));

            (
                uint256[8] memory winners,
                uint256[8] memory pricesWinners
            ) = determineWinners(tokensIds, pricesBegin, prices);

            aceTheBrackets8.advanceGame(
                gameId,
                block.timestamp,
                abi.encode(prices),
                abi.encode(pricesWinners),
                abi.encode(winners)
            );
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
}
