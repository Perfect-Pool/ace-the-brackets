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

contract AutomationAce8 is AutomationCompatibleInterface {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    // Events
    event FunctionsConsumerSet(address indexed functionsConsumer);
    event PerformUpkeep(uint256 gameId, bool newGame);
    event Initialized(
        bytes encryptedSecretsReference,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        FunctionsRequest.Location secretsLocation
    );

    // State variables for Chainlink Automation
    uint256 public s_updateInterval;
    uint256 public s_lastUpkeepTimeStamp;
    uint256 public s_upkeepCounter;
    uint256 public s_requestCounter;
    uint256 public s_responseCounter;

    bytes public encryptedSecretsReference;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit;
    FunctionsRequest.Location private secretsLocation;

    address public upkeepAddress;
    address public executionAddress;

    IFunctionsConsumer public functionsConsumer;
    IGamesHub public gamesHub;

    string public source =
        'const coinIds=args[0];if(secrets.apiKey===""){throw Error("Variable not set: apiKey")}const coinMarketCapRequest=Functions.makeHttpRequest({url:`https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?convert=USD&id=${coinIds}`,headers:{"X-CMC_PRO_API_KEY":secrets.apiKey}});const coinMarketCapResponse=await coinMarketCapRequest;if(coinMarketCapResponse.error){throw Error("CoinMarketCap API request failed")}const data=coinMarketCapResponse.data.data,idArray=coinIds.split(",");const idToSymbol={};for(const key in data){idToSymbol[data[key].id]=key}let prices=idArray.map(id=>{const symbol=idToSymbol[id];if(data[symbol]&&data[symbol].quote&&data[symbol].quote.USD){return Math.round(data[symbol].quote.USD.price*10**8)}return 0});while(prices.length<8){prices.push(0)}const buffer=new ArrayBuffer(prices.length*32),view=new DataView(buffer);prices.forEach((price,index)=>{const encodedPrice=Functions.encodeUint256(price);for(let i=0;i<32;i++){view.setUint8(index*32+i,encodedPrice[i])}});return buffer;';

    string public sourceNew =
        'if(secrets.apiKey===""){throw Error("Variable not set: apiKey")}const getRandomUniqueElements=(arr,n)=>{const uniqueById=Array.from(new Map(arr.map((item)=>[item["id"],item])).values());const filtered=uniqueById.filter((item)=>!item.tags.includes("stablecoin"));let result=new Array(n),len=filtered.length,taken=new Array(len);if(n>len){throw new RangeError("getRandomUniqueElements: more elements taken than available")}while(n--){const x=Math.floor(Math.random()*len);result[n]=filtered[x in taken?taken[x]:x];taken[x]=--len in taken?taken[len]:len}return result};const coinMarketCapRequest=Functions.makeHttpRequest({url:`https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest`,headers:{"X-CMC_PRO_API_KEY":secrets.apiKey},params:{start:1,limit:150,sort:"market_cap"}});const response=await coinMarketCapRequest;const coinsData=response.data.data;const selectedCoins=getRandomUniqueElements(coinsData,8);const newGameCoins=selectedCoins.map((coin)=>({id:coin.id,symbol:coin.symbol,tags:coin.tags}));const newGameString=newGameCoins.map((coin)=>`${coin.id},${coin.symbol}`).join(";");return Functions.encodeString(newGameString)';

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

    /**
     * @notice Used by Automation to check if performUpkeep should be called.
     *
     * The function's argument is unused in this example, but there is an option to have Automation pass custom data
     * that can be used by the checkUpkeep function.
     *
     * Returns a tuple where the first element is a boolean which determines if upkeep is needed and the
     * second element contains custom bytes data which is passed to performUpkeep when it is called by Automation.
     * @return upkeepNeeded Boolean indicating if upkeep is needed
     * @return updateData Custom data passed to performUpkeep
     */
    function checkUpkeep(
        bytes memory
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory updateData)
    {
        IAceTheBrackets8 ace8 = IAceTheBrackets8(
            gamesHub.games(keccak256("ACE8"))
        );
        uint256[] memory activeGames = ace8.getActiveGames();
        if (activeGames.length == 0) {
            return (true, abi.encode(0, new string[](0), true));
        }

        uint8 currentRound = ace8.getGameStatus(activeGames[0]);
        uint256 endTime;
        uint256 startTime;
        string[8] memory teamNames;
        uint256[8] memory teamsIds;

        if (currentRound > 3) {
            return (false, bytes(""));
        } else if ((currentRound == 0) || (currentRound == 1)) {
            (teamNames, , , startTime, endTime) = abi.decode(
                ace8.getRoundFullData(activeGames[0], 0),
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );

            if (block.timestamp < startTime) {
                return (false, bytes(""));
            }
        } else if (currentRound == 2) {
            (teamNames, , , , endTime) = abi.decode(
                ace8.getRoundFullData(activeGames[0], 1),
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );
        } else if (currentRound == 3) {
            (teamNames, , , , endTime) = abi.decode(
                ace8.getRoundFullData(activeGames[0], 2),
                (string[8], uint256[8], uint256[8], uint256, uint256)
            );
        }

        if (block.timestamp < endTime) {
            return (false, bytes(""));
        }

        teamsIds = ace8.getTokensIds(abi.encode(teamNames));
        return (
            true,
            abi.encode(
                activeGames[0],
                [
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
                    )
                ],
                false
            )
        );
    }

    /**
     * @notice Called by Automation to trigger a Functions request
     *
     * The function's argument is unused in this example, but there is an option to have Automation pass custom data
     * returned by checkUpkeep (See Chainlink Automation documentation)
     */
    function performUpkeep(bytes calldata) external override {
        (bool upkeepNeeded, bytes memory updateData) = checkUpkeep("");
        require(upkeepNeeded, "Conditions not met");

        s_lastUpkeepTimeStamp = block.timestamp;
        s_upkeepCounter = s_upkeepCounter + 1;

        (uint256 gameId, string[] memory args, bool newGame) = abi.decode(
            updateData,
            (uint256, string[], bool)
        );
        bytes[] memory bytesArgs = new bytes[](1);
        bytesArgs[0] = abi.encode(gameId);

        require(
            msg.sender == address(functionsConsumer),
            "Sender not allowed to set request"
        );
        functionsConsumer.sendRequest(
            newGame ? sourceNew : source,
            secretsLocation,
            encryptedSecretsReference,
            args,
            bytesArgs,
            subscriptionId,
            callbackGasLimit
        );

        emit PerformUpkeep(gameId, newGame);
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
     * @param _secretsLocation Location of secrets (only Location.Remote & Location.DONHosted are supported)
     */
    function initialize(
        bytes calldata _encryptedSecretsReference,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit,
        FunctionsRequest.Location _secretsLocation
    ) public {
        require(
            address(functionsConsumer) == msg.sender,
            "Only FunctionsConsumer can initialize"
        );
        encryptedSecretsReference = _encryptedSecretsReference;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        secretsLocation = _secretsLocation;

        emit Initialized(
            _encryptedSecretsReference,
            _subscriptionId,
            _callbackGasLimit,
            _secretsLocation
        );
    }
}
