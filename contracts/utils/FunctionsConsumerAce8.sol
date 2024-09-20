// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

interface IAutomationAce {
  function initialize(
    bytes calldata _encryptedSecretsReference,
    uint64 _subscriptionId,
    uint32 _callbackGasLimit,
    FunctionsRequest.Location _secretsLocation
  ) external;
}

interface IGamesHub {
  function checkRole(bytes32 role, address account) external view returns (bool);

  function games(bytes32) external view returns (address);

  function helpers(bytes32) external view returns (address);
}

interface IAceTheBrackets8 {
  function getRoundFullData(uint256 gameIndex, uint8 round) external view returns (bytes memory);

  function getTokensIds(bytes memory _symbols) external view returns (uint256[8] memory);
}

interface IAce8Proxy {
  function performGames(bytes calldata _dataNewGame, bytes calldata _dataUpdate, uint256 _lastTimeStamp) external;

  function getActiveGames() external view returns (uint256[] memory);

  function getGameStatus(uint256 gameIndex) external view returns (uint8 status);
}

/**
 * @title Chainlink Functions example on-demand consumer contract example
 */
contract FunctionsConsumer is FunctionsClient, ConfirmedOwner {
  using FunctionsRequest for FunctionsRequest.Request;

  bytes32 public donId; // DON ID for the Functions DON to which the requests are sent
  IGamesHub public gamesHub;

  bytes32 public s_lastRequestId;
  bytes public s_lastResponse;
  bytes public s_lastError;
  bytes32 public s_executedRequestId;
  mapping(bytes32 => uint256) private gamesIds;

  bool private _setInitialData = true;

  constructor(address router, bytes32 _donId) FunctionsClient(router) ConfirmedOwner(msg.sender) {
    donId = _donId;
  }

  /** MODIFIERS **/
  modifier onlyAdministrator() {
    require(gamesHub.checkRole(keccak256("ADMIN"), msg.sender), "Restricted to administrators");
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
    require(address(gamesHub) == address(0), "GamesHub contract is already set");
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
      msg.sender == gamesHub.helpers(keccak256("ACE8_AUTOMATION")) || gamesHub.checkRole(keccak256("ADMIN"), msg.sender),
      "Sender not allowed to send request"
    );

    FunctionsRequest.Request memory req;
    req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, source);
    req.secretsLocation = secretsLocation;
    req.encryptedSecretsReference = encryptedSecretsReference;
    if (args.length > 0) {
      req.setArgs(args);
    }
    s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);

    gamesIds[s_lastRequestId] = bytesArgs.length > 0 ? abi.decode(bytesArgs[0], (uint256)) : 0;

    if (_setInitialData) {
      IAutomationAce(gamesHub.helpers(keccak256("ACE8_AUTOMATION"))).initialize(
        encryptedSecretsReference,
        subscriptionId,
        callbackGasLimit,
        secretsLocation
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
  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    s_lastError = err;
    s_executedRequestId = requestId;

    if (err.length == 0) {
      IAce8Proxy ace8Proxy = IAce8Proxy(gamesHub.games(keccak256("ACE8PROXY")));
      if (ace8Proxy.getActiveGames().length == 0) {
        (uint256[8] memory numericValues, string[8] memory coinSymbols) = parseMarketData(string(response));

        ace8Proxy.performGames(abi.encode(numericValues, coinSymbols), bytes(""), block.timestamp);
      } else {
        // encoded uint256[8] array
        bytes memory emptyBytesUint = abi.encode([0, 0, 0, 0, 0, 0, 0, 0]);
        string[8] memory teamNames;
        uint256[8] memory teamsIds;
        uint256[8] memory pricesStart;

        uint8 currentRound = ace8Proxy.getGameStatus(gamesIds[requestId]);

        if (currentRound == 0) {
          ace8Proxy.performGames(
            bytes(""),
            abi.encode(
              [gamesIds[requestId], 0, 0, 0],
              [
                //prices
                abi.encode(response, emptyBytesUint, emptyBytesUint, emptyBytesUint)
              ],
              [
                //prices winners
                abi.encode(emptyBytesUint, emptyBytesUint, emptyBytesUint, emptyBytesUint)
              ],
              [
                //winners
                abi.encode(emptyBytesUint, emptyBytesUint, emptyBytesUint, emptyBytesUint)
              ]
            ),
            block.timestamp
          );
        } else if (currentRound < 3) {
          (teamNames, pricesStart, , , ) = abi.decode(
            IAceTheBrackets8(gamesHub.games(keccak256("ACE8"))).getRoundFullData(gamesIds[requestId], 1),
            (string[8], uint256[8], uint256[8], uint256, uint256)
          );

          teamsIds = IAceTheBrackets8(gamesHub.games(keccak256("ACE8"))).getTokensIds(abi.encode(teamNames));

          uint256[8] memory pricesEnd = abi.decode(response, (uint256[8]));

          //update game
          ace8Proxy.performGames(
            bytes(""),
            buildUpdateGame(gamesIds[requestId], currentRound, pricesStart, pricesEnd),
            block.timestamp
          );
        }
      }
    }
  }

  /**
   * @notice Receive two uint256 values and measure the variation between them. It can return both a positive or negative value.
   * @param _newValue The new value
   * @param _oldValue The old value
   */
  function measureVariation(uint256 _newValue, uint256 _oldValue) public pure returns (int256) {
    return (int256(_newValue) - int256(_oldValue)) / int256(_oldValue);
  }

  /**
   * @notice Receive two variations and return the highest one. If both are equal, randomly return one of them.
   * @param _variation1 The first variation
   * @param _variation2 The second variation
   */
  function getWinner(int256 _variation1, int256 _variation2) public view returns (uint8) {
    if (_variation1 == _variation2) {
      uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp)));
      return random % 2 == 0 ? 1 : 2;
    }
    return _variation1 > _variation2 ? 1 : 2;
  }

  /**
   * @notice Receive pricesStart and pricesEnd and return the pricesWinners array as uint256[8], with the last 4 values as 0.
   * @param pricesStart The prices at the start of the round
   * @param pricesEnd The prices at the end of the round
   */
  function getPricesWinners(
    uint256[8] memory pricesStart,
    uint256[8] memory pricesEnd,
    uint8 round
  ) public view returns (uint256[8] memory) {
    return [
      getWinner(measureVariation(pricesEnd[0], pricesStart[0]), measureVariation(pricesEnd[1], pricesStart[1])) == 1
        ? pricesEnd[0]
        : pricesEnd[1],
      round == 0 || round == 1
        ? getWinner(measureVariation(pricesEnd[2], pricesStart[2]), measureVariation(pricesEnd[3], pricesStart[3])) == 1
          ? pricesEnd[2]
          : pricesEnd[3]
        : 0,
      round == 0
        ? getWinner(measureVariation(pricesEnd[4], pricesStart[4]), measureVariation(pricesEnd[5], pricesStart[5])) == 1
          ? pricesEnd[4]
          : pricesEnd[5]
        : 0,
      round == 0
        ? getWinner(measureVariation(pricesEnd[6], pricesStart[6]), measureVariation(pricesEnd[7], pricesStart[7])) == 1
          ? pricesEnd[6]
          : pricesEnd[7]
        : 0,
      0,
      0,
      0,
      0
    ];
  }

  /**
   * @notice Receive the needed data to build performGames data for updateGame
   * @param _gameIndex The game index
   * @param _round The round
   * @param _pricesStart The prices at the start of the round
   * @param _pricesEnd The prices at the end of the round
   */
  function buildUpdateGame(
    uint256 _gameIndex,
    uint8 _round,
    uint256[8] memory _pricesStart,
    uint256[8] memory _pricesEnd
  ) public view returns (bytes memory) {
    bytes memory emptyBytesUint = abi.encode([0, 0, 0, 0, 0, 0, 0, 0]);
    uint256[8] memory _pricesWinners = getPricesWinners(_pricesStart, _pricesEnd, _round);
    return
      abi.encode(
        [_gameIndex, 0, 0, 0],
        [
          //prices
          abi.encode(abi.encode(_pricesEnd), emptyBytesUint, emptyBytesUint, emptyBytesUint)
        ],
        [
          //prices winners
          abi.encode(abi.encode(_pricesWinners), emptyBytesUint, emptyBytesUint, emptyBytesUint, emptyBytesUint)
        ],
        [
          //winners
          abi.encode(
            [
              _pricesWinners[0] == _pricesEnd[0] ? 1 : 2,
              _pricesWinners[1] == _pricesEnd[2] ? 3 : 4,
              _pricesWinners[2] == _pricesEnd[4] ? 5 : 6,
              _pricesWinners[3] == _pricesEnd[6] ? 7 : 8,
              0,
              0,
              0,
              0
            ],
            emptyBytesUint,
            emptyBytesUint,
            emptyBytesUint
          )
        ]
      );
  }

  /**
   * @notice Parse market data string and return two arrays
   * @param _marketData String in the format "10603,IMX;20947,SUI;4948,CKB;8119,SFP;23254,CORE;3640,LPT;1518,MKR;28321,POL"
   * @return uint256[8] Array of numeric values
   * @return string[8] Array of coin symbols
   */
  function parseMarketData(string memory _marketData) public pure returns (uint256[8] memory, string[8] memory) {
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
        } else if (data[endIndex] == 0x3b || endIndex == data.length - 1) {
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
  function parseUint(bytes memory data, uint256 start, uint256 end) private pure returns (uint256) {
    uint256 result = 0;
    for (uint256 i = start; i < end; i++) {
      result = result * 10 + uint8(data[i]) - 48;
    }
    return result;
  }

  // Optimized helper function to extract a substring from bytes
  function substring(bytes memory data, uint256 start, uint256 end) private pure returns (string memory) {
    bytes memory result = new bytes(end - start);
    for (uint256 i = 0; i < end - start; i++) {
      result[i] = data[start + i];
    }
    return string(result);
  }
}
