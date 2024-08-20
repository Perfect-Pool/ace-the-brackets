import { ActionFn, Context, Event, TransactionEvent } from "@tenderly/actions";

import { ethers } from "ethers";
import axios from "axios";

interface UpdateData {
    gameIds: number[];
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

const encodeUpdateData = (game_id: number): string => {
    const gameData: GameData = {
        gameId: game_id,
        prices: Array(8).fill(0),
        pricesWinners: Array(8).fill(0),
        winners: Array(8).fill(0),
    };

    const gameIdsArray = [game_id, 0, 0, 0];

    const updateData: UpdateData = {
        gameIds: gameIdsArray,
        prices: Array(4).fill(ethers.utils.defaultAbiCoder.encode(["uint256[8]"], [gameData.prices])),
        pricesWinners: Array(4).fill(ethers.utils.defaultAbiCoder.encode(["uint256[8]"], [gameData.pricesWinners])),
        winners: Array(4).fill(ethers.utils.defaultAbiCoder.encode(["uint256[8]"], [gameData.winners])),
    };

    return ethers.utils.defaultAbiCoder.encode(
        ["uint256[4]", "bytes[4]", "bytes[4]", "bytes[4]"],
        [updateData.gameIds, updateData.prices, updateData.pricesWinners, updateData.winners]
    );
};

export const aceFirstBet: ActionFn = async (context: Context, event: Event) => {
    const transactionEvent = event as TransactionEvent;

    const privateKey = await context.secrets.get("project.addressPrivateKey");
    const rpcUrl = await context.secrets.get("baseSepolia.rpcUrl");
    const ACE_CONTRACT_ADDRESS = await context.secrets.get("baseSepolia.aceTheBrackets.contract");
    const TICKET_CONTRACT = await context.secrets.get("baseSepolia.aceTicket.contract");
    const aceAbiText = await context.secrets.get("aceTheBrackets.abi");
    const aceAbi = JSON.parse(aceAbiText);

    const ticketABI = [
        {
            "inputs": [
                {
                    "internalType": "uint256",
                    "name": "gameId",
                    "type": "uint256"
                }
            ],
            "name": "getGamePlayers",
            "outputs": [
                {
                    "internalType": "uint256[]",
                    "name": "",
                    "type": "uint256[]"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        },
    ];

    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);

    let aceContract;
    let ticketContract;
    try {
        aceContract = new ethers.Contract(ACE_CONTRACT_ADDRESS, aceAbi, wallet);
        ticketContract = new ethers.Contract(TICKET_CONTRACT, ticketABI, wallet);
    } catch (error) {
        console.error("Failed to fetch contract (s).");
        await sendErrorLog('Failed to fetch contract on ACE first bet automation.', context);
        return;
    }

    let estimatedGas;
    let gasLimit;

    let gameId = 0;

    const logs = transactionEvent.logs;
    logs.forEach((log, index) => {
        if (log.topics[0] !== "0x1793ba998e9a843da8d17fbc98fc43bc4121583acf9b7509005bdeaba03891a7") {
            return;
        }
        try {
            const abiDecodedData = ethers.utils.defaultAbiCoder.decode(["uint256"], log.topics[2]);
            gameId = abiDecodedData[0].toNumber();
        } catch (error) {
            console.error(`Failed to decode data for log ${index}`);
        }
    }, gameId);

    if (gameId === 0) {
        console.error("Failed to decode data for all logs");
        await sendErrorLog('Failed to decode data for all logs on ACE first bet automation.', context);
        return;
    }

    //if getGamePlayers already has a player, then return with a message saying that the game already has a player
    const players = await ticketContract.getGamePlayers(gameId);
    if (players.length > 0) {
        console.log("Game timer is already ongoing.");
        return;
    }

    const lastTimeStamp = Math.floor(Date.now() / 1000 / 60) * 60;
    const updateGamesCalldata = encodeUpdateData(gameId);

    console.log("Game ID:", gameId);

    try {
        estimatedGas = await aceContract.estimateGas.performGames(
            '0x',
            updateGamesCalldata,
            lastTimeStamp
        );
        gasLimit = estimatedGas.mul(110).div(100);
    } catch (error: any) {
        console.error("Failed to perform games.");
        await sendErrorLog(`Failed to perform games on ACE: ${error?.message?.split(' [')[0]}`, context);
        return;
    }

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
    } catch (error: any) {
        console.error("Failed to perform games");
        await sendErrorLog(`Failed to perform games on ACE: ${error?.message?.split(' [')[0]}`, context);
    }
};