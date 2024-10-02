// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../interfaces/IGamesHub.sol";

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

interface IAce8Proxy {
    function performGames(
        bytes calldata _dataNewGame,
        bytes calldata _dataUpdate,
        uint256 _lastTimeStamp
    ) external;

    function getGameFullData(
        uint256 _gameId
    ) external view returns (bytes memory);
}

interface IAceTicket8 {
    function iterateGameTokenIds(
        uint256 _gameId,
        uint256 _iterateStart,
        uint256 _iterateEnd
    ) external;
}

contract LogAutomationAce8Entry is ILogAutomation {
    event GameTimeStarted(uint256 timeStamp);
    event IterateExecuted(
        uint256 gameId,
        uint256 iterateStart,
        uint256 iterateEnd
    );

    bytes32 public constant ISBET_EVENT =
        0x1793ba998e9a843da8d17fbc98fc43bc4121583acf9b7509005bdeaba03891a7;
    bytes32 public constant ISPRIZE_EVENT =
        0xae71d4ebf2d066790f15124a158f211d7b88d29cac736ade8f968f106e63e028;

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
        bytes32 eventType = log.topics[0];
        uint8 updatePhase;
        bytes memory _updateData;

        if (eventType == ISBET_EVENT) {
            updatePhase = 0;
            uint256 gameId = bytes32ToUint256(log.topics[1]);
            IAce8Proxy ace8Proxy = IAce8Proxy(
                gamesHub.helpers(keccak256("ACE8_PROXY"))
            );

            (, , , , , , uint256 gameStart, , ) = abi.decode(
                ace8Proxy.getGameFullData(gameId),
                (
                    bytes,
                    bytes,
                    bytes,
                    string,
                    uint256,
                    uint8,
                    uint256,
                    uint256,
                    bool
                )
            );
            if (gameStart == 0) {
                return (false, emptyBytes);
            }
            _updateData = abi.encode(
                [gameId, 0, 0, 0],
                [emptyBytes, emptyBytes, emptyBytes, emptyBytes],
                [emptyBytes, emptyBytes, emptyBytes, emptyBytes],
                [emptyBytes, emptyBytes, emptyBytes, emptyBytes]
            );
        } else if (eventType == ISPRIZE_EVENT) {
            updatePhase = 1;
            _updateData = log.data;
        }

        performData = abi.encode(updatePhase, _updateData);
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
            uint256 timeStamp = (block.timestamp / 120) * 120;
            IAce8Proxy(gamesHub.games(keccak256("ACE8_PROXY"))).performGames(
                "",
                _updateData,
                timeStamp
            );
            emit GameTimeStarted(timeStamp);
        } else {
            (uint256 gameId, uint256 iterateStart, uint256 iterateEnd) = abi
                .decode(_updateData, (uint256, uint256, uint256));

            IAceTicket8(gamesHub.helpers(keccak256("NFT_ACE8")))
                .iterateGameTokenIds(gameId, iterateStart, iterateEnd);
            emit IterateExecuted(gameId, iterateStart, iterateEnd);
        }
    }

    function bytes32ToUint256(bytes32 b) private pure returns (uint256) {
        return uint256(b);
    }
}
