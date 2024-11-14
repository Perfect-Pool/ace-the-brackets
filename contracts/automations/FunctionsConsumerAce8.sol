// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

interface IAutomationAce {
    function initialize(
        bytes calldata _encryptedSecretsReference,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) external;
}

interface IGamesHub {
    function checkRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    function games(bytes32) external view returns (address);

    function helpers(bytes32) external view returns (address);
}

/**
 * @title Chainlink Functions example on-demand consumer contract example
 */
contract FunctionsConsumer is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    event UpdateGame(uint8 indexed updatePhase, uint256 indexed gameDataIndex);

    bytes32 public donId; // DON ID for the Functions DON to which the requests are sent
    IGamesHub public gamesHub;

    bytes32 public s_lastRequestId;
    bytes public s_lastError;
    bytes32 public s_executedRequestId;
    mapping(bytes32 => uint8) private updatePhase;

    mapping(uint256 => bytes) public updateData;
    uint256 public updateDataIndex;

    bool private _setInitialData = true;
    uint64 public constant SUBSCRIPTION_ID = 176;

    constructor(
        address router,
        bytes32 _donId
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        donId = _donId;
    }

    /** MODIFIERS **/
    modifier onlyAdministrator() {
        require(
            gamesHub.checkRole(keccak256("ADMIN"), msg.sender),
            "Restricted to administrators"
        );
        _;
    }

    modifier onlyProject() {
        require(
            msg.sender == gamesHub.helpers(keccak256("ACE8_LOGAUTOMATION")) ||
                msg.sender == gamesHub.games(keccak256("ACE8")) ||
                msg.sender == gamesHub.helpers(keccak256("ACE8_AUTOMATION")) ||
                msg.sender == gamesHub.helpers(keccak256("AUTOMATION_TOP100")),
            "Restricted to Project contracts"
        );
        _;
    }

    /**
     * @notice Set the DON ID
     * @param newDonId New DON ID
     */
    function setDonId(bytes32 newDonId) external onlyAdministrator {
        donId = newDonId;
    }

    /**
     * @notice Set the GamesHub contract address, if the contract is not set. Do not allow to change the address after this is set.
     * @param _gamesHub Address of the GamesHub contract
     */
    function setGamesHub(address _gamesHub) external onlyOwner {
        require(
            address(gamesHub) == address(0),
            "GamesHub contract is already set"
        );
        gamesHub = IGamesHub(_gamesHub);
    }

    /**
     * @notice Triggers an on-demand Functions request using remote encrypted secrets
     * @param source JavaScript source code
     * @param secretsLocation Location of secrets (only Location.Remote & Location.DONHosted are supported)
     * @param encryptedSecretsReference Reference pointing to encrypted secrets
     * @param args String arguments passed into the source code and accessible via the global variable `args`
     * @param subscriptionId Subscription ID used to pay for request (FunctionsConsumer contract address must first be added to the subscription)
     * @param callbackGasLimit Maximum amount of gas used to call the inherited `handleOracleFulfillment` method
     */
    function sendRequest(
        string calldata source,
        FunctionsRequest.Location secretsLocation,
        bytes calldata encryptedSecretsReference,
        string[] calldata args,
        bytes[] calldata,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) external {
        require(
            msg.sender == gamesHub.helpers(keccak256("AUTOMATION_TOP100")) ||
                gamesHub.checkRole(keccak256("ADMIN"), msg.sender),
            "Sender not allowed to send request"
        );

        uint8 updatePhaseIndex;
        if (args.length > 0) {
            if (
                keccak256(abi.encodePacked(args[0])) ==
                keccak256(abi.encodePacked("N8"))
            ) {
                updatePhaseIndex = 1;
            } else if (
                keccak256(abi.encodePacked(args[0])) ==
                keccak256(abi.encodePacked("8"))
            ) {
                updatePhaseIndex = 2;
            } else if (
                keccak256(abi.encodePacked(args[0])) ==
                keccak256(abi.encodePacked("T"))
            ) {
                updatePhaseIndex = 5;
            } else {
                revert("Invalid phase");
            }
        }

        FunctionsRequest.Request memory req;
        req.initializeRequest(
            FunctionsRequest.Location.Inline,
            FunctionsRequest.CodeLanguage.JavaScript,
            source
        );
        req.secretsLocation = secretsLocation;
        req.encryptedSecretsReference = encryptedSecretsReference;
        if (args.length > 0) {
            req.setArgs(args);
        }
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            SUBSCRIPTION_ID,
            callbackGasLimit,
            donId
        );

        updatePhase[s_lastRequestId] = updatePhaseIndex;

        if (_setInitialData) {
            IAutomationAce(gamesHub.helpers(keccak256("AUTOMATION_TOP100")))
                .initialize(
                    encryptedSecretsReference,
                    subscriptionId,
                    callbackGasLimit
                );
            _setInitialData = false;
        }
    }

    function unset() external onlyAdministrator {
        _setInitialData = true;
    }

    /**
     * @notice Store latest result/error
     * @param requestId The request ID, returned by sendRequest()
     * @param response Aggregated response from the user code
     * @param err Aggregated error from the user code or from the execution pipeline
     * Either response or error parameter will be set, but never both
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        s_executedRequestId = requestId;
        uint8 updatePhaseIndex = updatePhase[requestId];

        if (err.length == 0 && response.length != 0) {
            emit UpdateGame(updatePhaseIndex, storeUpdateData(response));
        }

        s_lastError = err;
    }

    /**
     * @dev Store the updated data, returning the index
     * @param data The data to store
     * @return The index of the stored data
     */
    function storeUpdateData(bytes memory data) internal returns (uint256) {
        updateData[updateDataIndex] = data;
        uint256 returnIndex = updateDataIndex;
        updateDataIndex++;
        return returnIndex;
    }

    /**
     * @notice Emit a UpdateGame event receiving a uint8 and uint256
     * @param _updatePhase uint8
     * @param gameDataIndex uint256
     */
    function emitUpdateGame(
        uint8 _updatePhase,
        uint256 gameDataIndex
    ) external onlyProject {
        emit UpdateGame(_updatePhase, gameDataIndex);
    }
}
