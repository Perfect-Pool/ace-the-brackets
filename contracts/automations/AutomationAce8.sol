// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IGamesHub.sol";
import "../interfaces/IAceTheBrackets8.sol";

interface ICoins100Store {
    function coinGeckoIDs8(
        string[8] memory _symbols
    ) external view returns (string[8] memory);
}

interface IFunctionsConsumer {
    function emitUpdateGame(uint8 updatePhase, uint256 gameDataIndex) external;
}

interface IAce8Entry {
    function getGamePlayers(
        uint256 gameId
    ) external view returns (uint256[] memory);
}

interface ISourceCodesAce {
    function updateGame() external view returns (string memory);

    function newGame() external view returns (string memory);
}

interface IAutomationTop100 {
    function sendRequest(
        string calldata source,
        string[] calldata args,
        bytes32 contractSymbol
    ) external;
}

contract AutomationAce8 is AutomationCompatibleInterface {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    // Events
    event FunctionsConsumerSet(address indexed functionsConsumer);
    event PerformUpkeep(uint256 gameId, bool newGame);

    // State variables for Chainlink Automation
    uint256 public s_lastUpkeepTimeStamp;
    uint256 public s_upkeepInterval = 500;
    uint256 public s_upkeepCounter;

    IGamesHub public gamesHub;
    address public forwarder;

    /**
     * @dev Constructor function, that sets the address of the games hub and the update interval of 10 min.
     * MUST be registered on Chainlink as Custom Logic automation.
     * @param _gamesHubAddress Address of the games hub
     */
    constructor(address _gamesHubAddress) {
        gamesHub = IGamesHub(_gamesHubAddress);
        s_lastUpkeepTimeStamp = block.timestamp - s_upkeepInterval;
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
            if (block.timestamp < (s_lastUpkeepTimeStamp + s_upkeepInterval)) {
                return (false, abi.encodePacked("TIME"));
            }
            return (true, "");
        }

        uint8 currentRound = ace8.getGameStatus(activeGames[0]);
        uint256 endTime;
        uint256 startTime;
        string[8] memory teamNames;
        bytes memory roundData;
        bool active = true;

        if (currentRound > 3) {
            return (false, "");
        } else if ((currentRound == 0) || (currentRound == 1)) {
            (roundData, , , , , , , , active) = abi.decode(
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
            if (startTime == 0) {
                if (
                    IAce8Entry(gamesHub.helpers(keccak256("NFT_ACE8")))
                        .getGamePlayers(activeGames[0])
                        .length > 0
                ) {
                    return (true, abi.encode(activeGames[0], "", ""));
                }
                return (false, abi.encodePacked("0"));
            } else if (block.timestamp < startTime) {
                return (false, abi.encodePacked("S"));
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

        if (active) {
            endTime = endTime == 0 ? 0 : endTime - 10;
            if (endTime == 0 || block.timestamp < endTime) {
                return (false, abi.encodePacked("ED"));
            }
        }

        if (block.timestamp < (s_lastUpkeepTimeStamp + s_upkeepInterval)) {
            return (false, abi.encodePacked("TIME"));
        }
        bytes memory _teamNamesBytes = abi.encode(teamNames);
        uint256[8] memory teamsIds = ace8.getTokensIds(_teamNamesBytes);
        string[8] memory teamsIdsCG = ICoins100Store(
            gamesHub.helpers(keccak256("COINS100"))
        ).coinGeckoIDs8(teamNames);

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
                ),
                abi.encodePacked(
                    teamsIdsCG[0],
                    ",",
                    teamsIdsCG[1],
                    ",",
                    teamsIdsCG[2],
                    ",",
                    teamsIdsCG[3],
                    ",",
                    teamsIdsCG[4],
                    ",",
                    teamsIdsCG[5],
                    ",",
                    teamsIdsCG[6],
                    ",",
                    teamsIdsCG[7]
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
        if (forwarder == address(0)) {
            forwarder = msg.sender;
        }
        ISourceCodesAce sourceCodes = ISourceCodesAce(
            gamesHub.helpers(keccak256("SOURCE_CODES_ACE"))
        );

        s_lastUpkeepTimeStamp = block.timestamp;
        s_upkeepCounter = s_upkeepCounter + 1;

        string[] memory args = new string[](3);

        if (performData.length == 0) {
            IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
                .emitUpdateGame(0, 0);
            emit PerformUpkeep(0, true);
            return;
        }

        (uint256 gameId, bytes memory listIds, bytes memory geckoIds) = abi
            .decode(performData, (uint256, bytes, bytes));

        if (listIds.length == 0) {
            IFunctionsConsumer(gamesHub.helpers(keccak256("FUNCTIONS_ACE8")))
                .emitUpdateGame(6, gameId);
            emit PerformUpkeep(gameId, false);
            return;
        }

        args[0] = "8";
        args[1] = string(listIds);
        args[2] = string(geckoIds);

        IAutomationTop100(gamesHub.helpers(keccak256("AUTOMATION_TOP100")))
            .sendRequest(
                sourceCodes.updateGame(),
                args,
                keccak256("FUNCTIONS_ACE8")
            );

        emit PerformUpkeep(gameId, false);
    }
}
