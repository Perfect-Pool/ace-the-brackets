// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTheBrackets8.sol";

interface IFunctionsConsumer {
    function sendRequest(
        string calldata source,
        bytes32 secretsLocation,
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
    using Strings for uint256;

    // Events
    event FunctionsConsumerSet(address indexed functionsConsumer);
    event PerformUpkeep(uint256 gameId, bool newGame);
    event Initialized(
        bytes encryptedSecretsReference,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    );

    // State variables for Chainlink Automation
    uint256 public s_updateInterval;
    uint256 public s_lastUpkeepTimeStamp;
    uint256 public s_upkeepCounter;
    uint256 public s_requestCounter;
    uint256 public s_responseCounter;

    bytes private encryptedSecretsReference;
    uint64 private subscriptionId;
    uint32 public callbackGasLimit;

    address public upkeepAddress;
    address public executionAddress;

    IFunctionsConsumer public functionsConsumer;
    IGamesHub public gamesHub;

    /**
     * @dev Constructor function
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
    }

    /** MODIFIERS **/
    modifier onlyAdministrator() {
        require(gamesHub.checkRole(keccak256("ADMIN"), msg.sender), "ACEP-01");
        _;
    }

    modifier onlyGameContract() {
        require(
            gamesHub.games(keccak256("ACE8_TEST")) == msg.sender,
            "ACEP-02"
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
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        IAceTheBrackets8 ace8 = IAceTheBrackets8(
            gamesHub.games(keccak256("ACE8_TEST"))
        );

        uint256[] memory activeGames = ace8.getActiveGames();
        if (activeGames.length == 0) {
            return (true, "");
        }

        uint8 currentRound = ace8.getGameStatus(activeGames[0]);
        uint256 endTime;
        uint256 startTime;
        string[8] memory teamNames;
        uint256[8] memory teamsIds;

        if (currentRound > 3) {
            return (false, "");
        } else if ((currentRound == 0) || (currentRound == 1)) {
            (teamNames, , , startTime, endTime) = abi.decode(
                ace8.getRoundFullData(activeGames[0], 0),
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );

            //subtracts 10 seconds from the start time to prevent block.timestamp delay
            startTime = startTime - 10;
            if (block.timestamp < startTime) {
                return (false, "");
            }
        } else {
            (teamNames, , , , endTime) = abi.decode(
                ace8.getRoundFullData(activeGames[0], (currentRound - 1)),
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );
        }

        endTime = endTime - 10;
        if (block.timestamp < endTime) {
            return (false, "");
        }

        teamsIds = ace8.getTokensIds(abi.encode(teamNames));

        return (
            true,
            abi.encode(
                string(
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
                ),
                activeGames[0]
            )
        );
    }

    /**
     * @notice Called by Automation to trigger a Functions request
     *
     * The function's argument is unused in this example, but there is an option to have Automation pass custom data
     * returned by checkUpkeep (See Chainlink Automation documentation)
     */
    function performUpkeep(bytes calldata performData) external override {
        ISourceCodesAce sourceCodes = ISourceCodesAce(
            gamesHub.helpers(keccak256("SOURCE_CODES_ACE"))
        );

        s_lastUpkeepTimeStamp = block.timestamp;
        s_upkeepCounter = s_upkeepCounter + 1;

        if (performData.length == 0) {
            functionsConsumer.sendRequest(
                sourceCodes.sourceNew8(),
                bytes32(""),
                encryptedSecretsReference,
                new string[](0),
                new bytes[](0),
                subscriptionId,
                callbackGasLimit
            );

            emit PerformUpkeep(0, true);
            return;
        }

        (string memory listIds, uint256 gameId) = abi.decode(
            performData,
            (string, uint256)
        );

        string[] memory args = new string[](1);
        bytes[] memory bytesArgs = new bytes[](1);

        args[0] = listIds;
        bytesArgs[0] = abi.encode(gameId);

        functionsConsumer.sendRequest(
            sourceCodes.source8(),
            bytes32(""),
            encryptedSecretsReference,
            args,
            bytesArgs,
            subscriptionId,
            callbackGasLimit
        );

        emit PerformUpkeep(gameId, false);
    }

    /**
     * @notice Set the address of the FunctionsConsumer contract
     * @param _functionsConsumer Address of the FunctionsConsumer contract
     * @dev Only the administrator can call this function
     */
    function setFunctionsConsumer(
        address _functionsConsumer
    ) external onlyAdministrator {
        functionsConsumer = IFunctionsConsumer(_functionsConsumer);
        emit FunctionsConsumerSet(_functionsConsumer);
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
            address(functionsConsumer) == msg.sender,
            "Only FunctionsConsumer can initialize"
        );
        encryptedSecretsReference = _encryptedSecretsReference;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;

        emit Initialized(
            _encryptedSecretsReference,
            _subscriptionId,
            _callbackGasLimit
        );
    }

    /**
     * @notice Function to send a sendRequest with source8New() to FunctionsConsumer.
     */
    function sendRequestNewGame() external onlyGameContract {
        functionsConsumer.sendRequest(
            ISourceCodesAce(gamesHub.helpers(keccak256("SOURCE_CODES_ACE")))
                .sourceNew8(),
            bytes32(""),
            encryptedSecretsReference,
            new string[](0),
            new bytes[](0),
            subscriptionId,
            callbackGasLimit
        );
    }
}
