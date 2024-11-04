// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IGamesHub.sol";

interface ICoins100Store {
    function lastStoredIndex() external view returns (uint8);
}

interface ISourceCodesAce {
    function sourceTop100() external view returns (string memory);

    function newGame() external view returns (string memory);
}

interface IFunctionsConsumer {
    function sendRequest(
        string calldata source,
        FunctionsRequest.Location secretsLocation,
        bytes calldata encryptedSecretsReference,
        string[] calldata args,
        bytes[] calldata bytesArgs,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) external;
}

contract AutomationTop100 is AutomationCompatibleInterface {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    // Events
    event FunctionsConsumerSet(address indexed functionsConsumer);
    event PerformUpkeep(uint256 gameId, bool newGame);
    event Initialized(uint64 subscriptionId, uint32 callbackGasLimit);

    // State variables for Chainlink Automation
    uint256 public s_lastUpkeepTimeStamp;
    uint256 public s_upkeepInterval = 604800; // 1 semana em segundos
    uint256 public s_upkeepCounter;

    bytes private encryptedSecretsReference;
    uint64 private subscriptionId;
    uint32 public callbackGasLimit;

    IGamesHub public gamesHub;
    address public forwarder;

    /**
     * @dev Constructor function, that sets the address of the games hub and the update interval of 1 week.
     * MUST be registered on Chainlink as Custom Logic automation.
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
        s_lastUpkeepTimeStamp = block.timestamp - s_upkeepInterval;
    }

    modifier onlyForwarder() {
        require(
            forwarder == address(0) || msg.sender == forwarder,
            "Restricted to forwarder"
        );
        _;
    }

    modifier onlyLogContract() {
        require(
            msg.sender == gamesHub.helpers(keccak256("AUTOMATIONLOG_TOP100")) ||
            msg.sender == gamesHub.helpers(keccak256("ACE8_LOGAUTOMATION")),
            "Restricted to log contracts"
        );
        _;
    }

    /**
     * @notice Initialize the contract with the required parameters from FunctionsConsumer
     * @param _encryptedSecretsReference Encrypted secrets reference
     * @param _subscriptionId Subscription ID
     * @param _callbackGasLimit Callback gas limit
     */
    function initialize(
        bytes calldata _encryptedSecretsReference,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) external {
        require(
            msg.sender == gamesHub.helpers(keccak256("FUNCTIONS_ACE8")),
            "Only FunctionsConsumer can initialize"
        );
        encryptedSecretsReference = _encryptedSecretsReference;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        emit Initialized(_subscriptionId, _callbackGasLimit);
    }

    /**
     * @notice Used by Automation to check if performUpkeep should be called.
     * @return upkeepNeeded Boolean indicating if upkeep is needed
     * @return performData Custom data passed to performUpkeep
     */
    function checkUpkeep(
        bytes memory
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded =
            (block.timestamp - s_lastUpkeepTimeStamp) > s_upkeepInterval;
        performData = new bytes(0);
    }

    /**
     * @notice Called by Automation to trigger a Functions request
     */
    function performUpkeep(bytes calldata) external override onlyForwarder {
        if (forwarder == address(0)) {
            forwarder = msg.sender;
        }

        require(
            (block.timestamp - s_lastUpkeepTimeStamp) > s_upkeepInterval,
            "Upkeep interval not reached"
        );

        s_lastUpkeepTimeStamp = block.timestamp;
        s_upkeepCounter++;
        ICoins100Store coins100Store = ICoins100Store(
            gamesHub.helpers(keccak256("COINS100"))
        );

        uint8 lastIndex = coins100Store.lastStoredIndex();
        uint256 itLasts = lastIndex == 0 ? 100 : 99 - lastIndex;

        callFunctionsConsumer(lastIndex, itLasts);
    }

    /**
     * @notice Called by this contract or LogAutomation contract to call FunctionsConsumer
     * @param lastIndex Last index called
     * @param itLasts Number of iterations until 99
     */
    function callFunctionsConsumer(uint256 lastIndex, uint256 itLasts) public {
        require(
            msg.sender == address(this) ||
                msg.sender ==
                gamesHub.helpers(keccak256("AUTOMATIONLOG_TOP100")),
            "Only this contract or LogAutomation can call"
        );

        ISourceCodesAce sourceCodesAce = ISourceCodesAce(
            gamesHub.helpers(keccak256("SOURCE_CODES_ACE"))
        );
        IFunctionsConsumer functionsConsumer = IFunctionsConsumer(
            gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
        );

        string[] memory args = new string[](3);
        args[0] = "T";
        args[1] = lastIndex.toString();
        args[2] = itLasts.toString();

        functionsConsumer.sendRequest(
            sourceCodesAce.sourceTop100(),
            FunctionsRequest.Location.Remote,
            encryptedSecretsReference,
            args,
            new bytes[](0),
            subscriptionId,
            callbackGasLimit
        );
    }

    /**
     * @notice Generic function to send a request to FunctionsConsumer
     * @param source Source code to be executed
     * @param args Arguments to be passed to the source code
     */
    function sendRequest(
        string calldata source,
        string[] calldata args
    ) external onlyLogContract {
        IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
            .sendRequest(
                source,
                FunctionsRequest.Location.Remote,
                encryptedSecretsReference,
                args,
                new bytes[](0),
                subscriptionId,
                callbackGasLimit
            );
    }

    /**
     * @notice Function to send a sendRequest with newGame() to FunctionsConsumer.
     */
    function sendRequestNewGame() external onlyLogContract {
        string[] memory args = new string[](2);
        args[0] = "N8";
        args[1] = "8";

        IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
            .sendRequest(
                ISourceCodesAce(gamesHub.helpers(keccak256("SOURCE_CODES_ACE")))
                    .newGame(),
                FunctionsRequest.Location.Remote,
                encryptedSecretsReference,
                args,
                new bytes[](0),
                subscriptionId,
                callbackGasLimit
            );
    }
}
