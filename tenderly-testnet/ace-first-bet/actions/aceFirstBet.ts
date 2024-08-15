import { ActionFn, Context, Event, TransactionEvent } from "@tenderly/actions";

import { ethers } from "ethers";
import axios from "axios";

interface BetPlacedEvent {
    player: string;
    gameId: number;
    tokenId: number;
    betCode: string;
}

interface DecodedGame {
    game_id: number;
    game_round: number;
    game_start: number;
}

interface UpdateData {
    gameIds: ethers.BigNumber[];
    prices: string[]; //bytes encoded uint256[]
    pricesWinners: string[]; //bytes encoded uint256[]
    winners: string[]; //bytes encoded uint256[]
};

interface GameData {
    gameId: number;
    prices: number[];
    pricesWinners: number[];
    winners: number[];
};


interface LogPayload {
    message: string;
    level: 'debug' | 'info' | 'warning' | 'error' | 'fatal';
}

async function sendErrorLog(message: string, context: Context): Promise<void> {
    const url = await context.secrets.get("sentry.test.url");
    const apikey = await context.secrets.get("sentry.test.key");

    const headers = {
        'Content-Type': 'application/json',
        'X-API-Key': apikey
    };

    const payload: LogPayload = {
        message,
        level: 'error'
    };

    try {
        await axios.post(url, payload, { headers });
        console.log('Error log sent successfully');
    } catch (error) {
        console.error('Failed to send error log:', error);
    }
}


// Function to decode the data returned by the getActiveGamesActualCoins() function
const decodeGame = (encodedGame: string, gameId: number): DecodedGame => {
    if (encodedGame === "0x") {
        return {
            game_id: gameId,
            game_round: 0,
            game_start: 0
        };
    }

    const decoded = ethers.utils.defaultAbiCoder.decode(
        ["bytes", "bytes", "bytes", "string", "uint256", "uint8", "uint256", "uint256", "bool"],
        encodedGame
    );

    return {
        game_id: gameId,
        game_round: decoded[5],
        game_start: decoded[6].toNumber(),
    };
};

const encodeUpdateData = (game_id: number): string => {
    const gameData: GameData = {
        gameId: game_id,
        prices: Array(8).fill(ethers.BigNumber.from(0)),
        pricesWinners: Array(8).fill(ethers.BigNumber.from(0)),
        winners: Array(8).fill(ethers.BigNumber.from(0)),
    };

    const gameIdsArray = [game_id, 0, 0, 0];

    const updateData: UpdateData = {
        gameIds: gameIdsArray.map((id) => ethers.BigNumber.from(id)),
        prices: Array(4).fill(ethers.utils.defaultAbiCoder.encode(["uint256[]"], [gameData.prices])),
        pricesWinners: Array(4).fill(ethers.utils.defaultAbiCoder.encode(["uint256[]"], [gameData.pricesWinners])),
        winners: Array(4).fill(ethers.utils.defaultAbiCoder.encode(["uint256[]"], [gameData.winners])),
    };

    return ethers.utils.defaultAbiCoder.encode(
        ["uint256[]", "bytes[]", "bytes[]", "bytes[]"],
        [updateData.gameIds, updateData.prices, updateData.pricesWinners, updateData.winners]
    );
};

export const aceFirstBet: ActionFn = async (context: Context, event: Event) => {
    const transactionEvent = event as TransactionEvent;

    const privateKey = await context.secrets.get("project.addressPrivateKey");
    const rpcUrl = await context.secrets.get("baseSepolia.rpcUrl");
    const ACE_CONTRACT_ADDRESS = await context.secrets.get("baseSepolia.aceTheBrackets.contract");
    const aceAbiText = await context.secrets.get("aceTheBrackets.abi");
    const aceAbi = JSON.parse(aceAbiText);

    console.log("Fetching wallet");
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log("Wallet:", wallet.address);

    console.log("Fetching ACE contract");
    let aceContract;
    try {
        aceContract = new ethers.Contract(ACE_CONTRACT_ADDRESS, aceAbi, wallet);
    } catch (error) {
        console.error("Failed to fetch contract (s).");
        await sendErrorLog('Failed to fetch contract on ACE first bet automation.', context);
        return;
    }

    let estimatedGas;
    let gasLimit;

    console.log("Decoding event data");

    let decodedData: BetPlacedEvent = {
        player: "",
        gameId: 0,
        tokenId: 0,
        betCode: "",
    };

    const logs = transactionEvent.logs;
    logs.forEach((log, index) => {
        if (log.topics[0] !== "0x1793ba998e9a843da8d17fbc98fc43bc4121583acf9b7509005bdeaba03891a7") {
            console.log("Log is not the correct event:", log.topics[0]);
            return;
        }
        console.log("Event Found:", log.topics[0]);
        try {
            const abiDecodedData = ethers.utils.defaultAbiCoder.decode(["address", "uint256", "uint256", "string"], log.data);
            decodedData = {
                player: abiDecodedData[0],
                gameId: abiDecodedData[1].toNumber(),
                tokenId: abiDecodedData[2].toNumber(),
                betCode: abiDecodedData[3],
            };
        } catch (error) {
            console.error(`Failed to decode data for log ${index}`);
            console.log("Trying next log");
        }
    }, decodedData);

    if (decodedData.gameId === 0) {
        console.error("Failed to decode data for all logs");
        await sendErrorLog('Failed to decode data for all logs on ACE first bet automation.', context);
        return;
    }

    let gameData;
    try {
        gameData = await aceContract.getGameFullData(decodedData.gameId);
    } catch (error) {
        console.error("Failed to fetch active games:", error);
        return;
    }

    const gameDecoded = decodeGame(gameData, decodedData.gameId);
    const lastTimeStamp = Math.floor(Date.now() / 1000 / 60) * 60;

    const updateGamesCalldata = encodeUpdateData(decodedData.gameId);

    console.log("Game ID:", decodedData.gameId);
    console.log("Iterate Start:", gameDecoded.game_start);try {
        estimatedGas = await aceContract.estimateGas.performGames(
            '0x',
            updateGamesCalldata,
            lastTimeStamp
        );
        gasLimit = estimatedGas.mul(110).div(100);
    } catch (error:any) {
        console.error("Failed to perform games:", error);
        await sendErrorLog(`Failed to perform games on ACE: ${error?.message?.split(' [')[0]}`, context);
        return;
    }

    console.log("Gas limit:", gasLimit.toString());

    console.log(
        `Estimated gas: ${estimatedGas.toString()}, adjusted gas limit: ${gasLimit.toString()}`
    );

    try {
        const tx = await aceContract.performGames(
            '0x',
            updateGamesCalldata,
            lastTimeStamp,
            {
                gasLimit: gasLimit
            }
        );

        await tx.wait();
        console.log(`Games successfully updated. TX: ${tx.hash}`);
        await context.storage.putNumber('executed', lastTimeStamp);
    } catch (error:any) {
        console.error("Failed to perform games:", error);
        await sendErrorLog(`Failed to perform games on ACE: ${error?.message?.split(' [')[0]}`, context);
    }
};