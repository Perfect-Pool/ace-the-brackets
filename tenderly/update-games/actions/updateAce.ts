import { ActionFn, Context, Event, WebhookEvent } from "@tenderly/actions";
import { ethers } from "ethers";
import axios, { AxiosRequestConfig } from 'axios';

interface PostData {
    newGame: string;
    updateGame: string;
    lastTimeStamp: number;
}

async function callAPI(context: Context, newGame: string, updateGame: string, lastTimeStamp: number): Promise<void> {
    try {
        const accessToken = await context.secrets.get('project.accessToken');

        const postData: PostData = {
            newGame: newGame,
            updateGame: updateGame,
            lastTimeStamp: lastTimeStamp,
        };

        const config: AxiosRequestConfig = {
            method: 'POST',
            url: 'https://api.tenderly.co/api/v1/actions/357e81b6-4dae-4823-a2d4-105e9e3d8158/webhook',
            headers: {
                'x-access-key': accessToken,
                'Content-Type': 'application/json',
            },
            data: postData,
        };

        const response = await axios(config);
        console.log("API chamada com sucesso: ", response.data);
    } catch (error) {
        console.error('Error calling API:', error);
    }
}

async function getGasPrice(provider: ethers.providers.Provider): Promise<ethers.BigNumber> {
    try {
        const gasPrice = await provider.getGasPrice();
        return gasPrice;
    } catch (error) {
        console.error("Erro ao obter o preço do GAS:", error);
        throw error;
    }
}

export const updateAce: ActionFn = async (
    context: Context,
    event: Event
) => {
    const privateKey = await context.secrets.get("project.addressPrivateKey");
    const rpcUrl = await context.secrets.get("baseSepolia.rpcUrl");
    const CONTRACT_ADDRESS = await context.secrets.get("baseSepolia.aceTheBrackets.contract");
    const abiText = await context.secrets.get("aceTheBrackets.abi");

    const abi = JSON.parse(abiText);
    const webhookEvent = event as WebhookEvent;

    const newGameCalldata = webhookEvent.payload.newGame;
    const updateGamesCalldata = webhookEvent.payload.updateGame;
    const lastTimeStamp = webhookEvent.payload.lastTimeStamp;

    console.log("NewGameData:", newGameCalldata);
    console.log("updateGameData:", updateGamesCalldata);

    console.log("Fetching wallet");
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log("Wallet:", wallet.address);

    console.log("Fetching ACE contract");
    let aceContract;
    try {
        aceContract = new ethers.Contract(CONTRACT_ADDRESS, abi, wallet);
    } catch (error) {
        console.error("Failed to fetch contract:", error);
        return;
    }

    console.log("Sending Transaction");
    let estimatedGas;
    let gasLimit;

    const gasPrice = await getGasPrice(provider);

    try {
        estimatedGas = await aceContract.estimateGas.performGames(
            newGameCalldata,
            updateGamesCalldata,
            lastTimeStamp
        );
        gasLimit = estimatedGas.mul(110).div(100);
    } catch (error) {
        console.error("Failed to estimate gas:", error);
        await new Promise((resolve) => setTimeout(resolve, 5000));
        await callAPI(context, newGameCalldata, updateGamesCalldata, lastTimeStamp);
        return;
    }

    console.log("Gas price:", gasPrice.toString());
    console.log("Gas limit:", gasLimit.toString());

    console.log(
        `Estimated gas: ${estimatedGas.toString()}, adjusted gas limit: ${gasLimit.toString()}`
    );

    try {
        const tx = await aceContract.performGames(
            newGameCalldata,
            updateGamesCalldata,
            lastTimeStamp,
            {
                gasLimit: gasLimit,
                gasPrice: gasPrice,
            }
        );

        await tx.wait();
        console.log(`Games successfully updated. TX: ${tx.hash}`);
    } catch (error) {
        console.error("Failed to perform games:", error);
        await new Promise((resolve) => setTimeout(resolve, 5000));
        await callAPI(context, newGameCalldata, updateGamesCalldata, lastTimeStamp);
    }

};
