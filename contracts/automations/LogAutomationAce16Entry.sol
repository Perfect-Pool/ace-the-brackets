// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../interfaces/IGamesHub.sol";

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

interface IAceTicket16 {
    function iterateGameTokenIds(
        uint256 _gameId,
        uint256 _iterateStart,
        uint256 _iterateEnd
    ) external;
}

contract LogAutomationAce16Entry is ILogAutomation {
    event GameTimeStartRequested(uint256 gameId);
    event IterateExecuted(
        uint256 gameId,
        uint256 iterateStart,
        uint256 iterateEnd
    );

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
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        performData = log.data;
        upkeepNeeded = true;
    }

    function performUpkeep(
        bytes calldata performData
    ) external override onlyForwarder {
        if (forwarder == address(0)) {
            forwarder = msg.sender;
        }
        (uint256 gameId, uint256 iterateStart, uint256 iterateEnd) = abi.decode(
            performData,
            (uint256, uint256, uint256)
        );

        IAceTicket16(gamesHub.helpers(keccak256("NFT_ACE16")))
            .iterateGameTokenIds(gameId, iterateStart, iterateEnd);
        emit IterateExecuted(gameId, iterateStart, iterateEnd);
    }
}
