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

interface IAceTheBrackets8 {
    function getRoundFullData(
        uint256 gameIndex,
        uint8 round
    ) external view returns (bytes memory);

    function getTokensIds(
        bytes memory _symbols
    ) external view returns (uint256[8] memory);
}

interface IAce8Proxy {
    function performGames(
        bytes calldata _dataNewGame,
        bytes calldata _dataUpdate,
        uint256 _lastTimeStamp
    ) external;

    function getActiveGames() external view returns (uint256[] memory);

    function getGameStatus(
        uint256 gameIndex
    ) external view returns (uint8 status);
}

/**
 * @title Chainlink Functions example on-demand consumer contract example
 */
contract FunctionsConsumer is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    event CreateNewGame(
        bytes dataNewGame
    );
    event UpdateGame(
        bytes updateGame
    );

    bytes32 public donId; // DON ID for the Functions DON to which the requests are sent
    IGamesHub public gamesHub;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    bytes32 public s_executedRequestId;
    mapping(bytes32 => uint256) private gamesIds;

    bool private _setInitialData = true;

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
     * @param bytesArgs Bytes arguments passed into the source code and accessible via the global variable `bytesArgs` as hex strings
     * @param subscriptionId Subscription ID used to pay for request (FunctionsConsumer contract address must first be added to the subscription)
     * @param callbackGasLimit Maximum amount of gas used to call the inherited `handleOracleFulfillment` method
     */
    function sendRequest(
        string calldata source,
        FunctionsRequest.Location secretsLocation,
        bytes calldata encryptedSecretsReference,
        string[] calldata args,
        bytes[] calldata bytesArgs,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) external {
        require(
            msg.sender == gamesHub.helpers(keccak256("ACE8_AUTOMATION")) ||
                gamesHub.checkRole(keccak256("ADMIN"), msg.sender),
            "Sender not allowed to send request"
        );

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
            subscriptionId,
            callbackGasLimit,
            donId
        );

        gamesIds[s_lastRequestId] = bytesArgs.length > 0
            ? abi.decode(bytesArgs[0], (uint256))
            : 0;

        if (_setInitialData) {
            IAutomationAce(gamesHub.helpers(keccak256("ACE8_AUTOMATION")))
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
        s_lastError = err;
        s_executedRequestId = requestId;

        if (err.length == 0) {
            if(gamesIds[requestId] == 0) {
                (uint256[8] memory numericValues, string[8] memory coinSymbols) = parseMarketDataNew(
                    string(response)
                );
                emit CreateNewGame(abi.encode(numericValues, coinSymbols));
            }else{
                uint256 gameId = gamesIds[requestId];
                uint256[8] memory prices = abi.decode(response, (uint256[8]));

                emit UpdateGame(abi.encode(gameId, prices));
            }
        }
    }

    /**
     * @notice Parse market data string and return two arrays
     * @param _marketData String in the format "10603,IMX;20947,SUI;4948,CKB;8119,SFP;23254,CORE;3640,LPT;1518,MKR;28321,POL"
     * @return uint256[8] Array of numeric values
     * @return string[8] Array of coin symbols
     */
    function parseMarketDataNew(
        string memory _marketData
    ) public pure returns (uint256[8] memory, string[8] memory) {
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

        return (numericValues, coinSymbols);
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
