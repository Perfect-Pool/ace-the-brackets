// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTheBrackets8.sol";

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

interface ISourceCodesAce {
    function source8() external view returns (string memory);

    function sourceNew8() external view returns (string memory);
}

contract AutomationAce8 is AutomationCompatibleInterface {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    // Events
    event FunctionsConsumerSet(address indexed functionsConsumer);
    event PerformUpkeep(uint256 gameId, bool newGame);
    event Initialized(uint64 subscriptionId, uint32 callbackGasLimit);

    // State variables for Chainlink Automation
    uint256 public s_lastUpkeepTimeStamp;
    uint256 public s_upkeepCounter;

    bytes private encryptedSecretsReference;
    uint64 private subscriptionId;
    uint32 public callbackGasLimit;

    address public upkeepAddress;
    IGamesHub public gamesHub;
    address public forwarder;

    /**
     * @dev Constructor function, that sets the address of the games hub and the update interval of 10 min.
     * MUST be registered on Chainlink as Custom Logic automation.
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
    }

    /** MODIFIERS **/
    modifier onlyAdministrator() {
        require(
            gamesHub.checkRole(keccak256("ADMIN"), msg.sender),
            "Restricted to administrators"
        );
        _;
    }

    modifier onlyLogContract() {
        require(
            gamesHub.helpers(keccak256("ACE8_LOGAUTOMATION")) == msg.sender,
            "Restricted to log contract"
        );
        _;
    }

    modifier onlyForwarder() {
        require(
            forwarder == address(0) || msg.sender == forwarder,
            "Restricted to forwarder"
        );
        _;
    }

    /**
     * @notice Used by Automation to check if performUpkeep should be called.
     *
     * The function's argument is unused in this example, but there is an option to have Automation pass custom data
     * that can be used by the checkUpkeep function.
     *
     * Returns a tuple where the first element is a boolean which determines if upkeep is needed and the
     * second element contains custom bytes data which is passed to performUpkeep when it is called by Automation.
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
        IAceTheBrackets8 ace8 = IAceTheBrackets8(
            gamesHub.games(keccak256("ACE8_PROXY"))
        );

        uint256[] memory activeGames = ace8.getActiveGames();
        if (activeGames.length == 0) {
            return (true, "");
        }

        uint8 currentRound = ace8.getGameStatus(activeGames[0]);
        uint256 endTime;
        uint256 startTime;
        string[8] memory teamNames;
        bytes memory roundData;

        if (currentRound > 3) {
            return (false, "");
        } else if ((currentRound == 0) || (currentRound == 1)) {
            (roundData, , , , , , , , ) = abi.decode(
                ace8.getGameFullData(activeGames[0]),
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
            (teamNames, , , startTime, endTime) = abi.decode(
                roundData,
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );

            //subtracts 10 seconds from the start time to prevent block.timestamp delay
            startTime = startTime == 0 ? 0 : startTime - 10;
            if (startTime == 0 || block.timestamp < startTime) {
                return (false, "");
            }
        } else if (currentRound == 2) {
            (, roundData, , , , , , , ) = abi.decode(
                ace8.getGameFullData(activeGames[0]),
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
            (teamNames, , , , endTime) = abi.decode(
                roundData,
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );
            upkeepNeeded = true;
        } else if (currentRound == 3) {
            (, , roundData, , , , , , ) = abi.decode(
                ace8.getGameFullData(activeGames[0]),
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
            (teamNames, , , , endTime) = abi.decode(
                roundData,
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );
            upkeepNeeded = true;
        }

        endTime = endTime == 0 ? 0 : endTime - 10;
        if (endTime == 0 || block.timestamp < endTime) {
            return (false, "");
        }

        uint256[8] memory teamsIds = ace8.getTokensIds(abi.encode(teamNames));

        return (
            true,
            abi.encode(
                activeGames[0],
                abi.encodePacked(
                    teamsIds[0].toString(),
                    ",",
                    teamsIds[1].toString(),
                    ",",
                    teamsIds[2].toString(),
                    ",",
                    teamsIds[3].toString(),
                    ",",
                    teamsIds[4].toString(),
                    ",",
                    teamsIds[5].toString(),
                    ",",
                    teamsIds[6].toString(),
                    ",",
                    teamsIds[7].toString()
                )
            )
        );
    }

    /**
     * @notice Called by Automation to trigger a Functions request
     *
     * The function's argument is unused in this example, but there is an option to have Automation pass custom data
     * returned by checkUpkeep (See Chainlink Automation documentation)
     */
    function performUpkeep(
        bytes calldata performData
    ) external override onlyForwarder {
        // if (forwarder == address(0)) {
        //     forwarder = msg.sender;
        // }
        ISourceCodesAce sourceCodes = ISourceCodesAce(
            gamesHub.helpers(keccak256("SOURCE_CODES_ACE"))
        );

        s_lastUpkeepTimeStamp = block.timestamp;
        s_upkeepCounter = s_upkeepCounter + 1;

        if (performData.length == 0) {
            IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
                .sendRequest(
                    sourceCodes.sourceNew8(),
                    FunctionsRequest.Location.Remote,
                    encryptedSecretsReference,
                    new string[](0),
                    new bytes[](0),
                    subscriptionId,
                    callbackGasLimit
                );

            emit PerformUpkeep(0, true);
            return;
        }

        (uint256 gameId, bytes memory listIds) = abi.decode(
            performData,
            (uint256, bytes)
        );

        string[] memory args = new string[](1);
        bytes[] memory bytesArgs = new bytes[](1);

        args[0] = string(listIds);
        bytesArgs[0] = abi.encode(gameId);

        IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
            .sendRequest(
                sourceCodes.source8(),
                FunctionsRequest.Location.Remote,
                encryptedSecretsReference,
                args,
                bytesArgs,
                subscriptionId,
                callbackGasLimit
            );

        emit PerformUpkeep(gameId, false);
    }

    /**
     * @notice Initialize the contract with the necessary data
     * @param _encryptedSecretsReference Reference pointing to encrypted secrets
     * @param _subscriptionId Subscription ID used to pay for request
     * @param _callbackGasLimit Maximum amount of gas used to call the `fullfilRequest` method on the FunctionsConsumer contract
     */
    function initialize(
        bytes calldata _encryptedSecretsReference,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) public {
        require(
            address(
                IFunctionsConsumer(
                    gamesHub.helpers(keccak256("FUNCTIONS_ACE8"))
                )
            ) == msg.sender,
            "Only FunctionsConsumer can initialize"
        );
        encryptedSecretsReference = _encryptedSecretsReference;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;

        emit Initialized(_subscriptionId, _callbackGasLimit);
    }

    /**
     * @notice Function to send a sendRequest with source8New() to FunctionsConsumer.
     */
    function sendRequestNewGame() external onlyLogContract {
        IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
            .sendRequest(
                ISourceCodesAce(gamesHub.helpers(keccak256("SOURCE_CODES_ACE")))
                    .sourceNew8(),
                FunctionsRequest.Location.Remote,
                encryptedSecretsReference,
                new string[](0),
                new bytes[](0),
                subscriptionId,
                callbackGasLimit
            );
    }
}
