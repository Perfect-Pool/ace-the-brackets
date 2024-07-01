import { ActionFn, Context, Event, WebhookEvent } from "@tenderly/actions";
import { ethers } from "ethers";

async function getGasPrice(provider: ethers.providers.Provider): Promise<ethers.BigNumber> {
    try {
        const gasPrice = await provider.getGasPrice();
        return gasPrice;
    } catch (error) {
        console.error("Erro ao obter o preço do GAS:", error);
        throw error;
    }
}

export const ethFaucet: ActionFn = async (
    context: Context,
    event: Event
) => {
    const privateKey = await context.secrets.get("project.addressPrivateKey");
    const rpcUrl = await context.secrets.get("baseSepolia.rpcUrl");
    const CONTRACT_ADDRESS = await context.secrets.get("baseSepolia.faucet.contract");
    const abiText = await context.secrets.get("faucet.abi");
    const abi = JSON.parse(abiText);
    const webhookEvent = event as WebhookEvent;

    console.log("Action:", webhookEvent.payload.action);
    console.log("Wallet:", webhookEvent.payload.address);

    console.log("Fetching wallet");
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log("Wallet:", wallet.address);

    console.log("Fetching Faucet contract");
    let contract;
    try {
        contract = new ethers.Contract(CONTRACT_ADDRESS, abi, wallet);
    } catch (error) {
        console.error("Failed to fetch contract:", error);
        return;
    }

    console.log("Sending ETH");
    let estimatedGas;
    let gasLimit;

    try {
        estimatedGas = await contract.estimateGas.requestEth(webhookEvent.payload.address);
        gasLimit = estimatedGas.mul(110).div(100);
    } catch (error) {
        console.error("Failed to estimate gas:", error);
        return;
    }

    const gasPrice = await getGasPrice(provider);

    console.log("Gas price:", gasPrice.toString());
    console.log("Gas limit:", gasLimit.toString());

    let transaction;
    try {
        transaction = await contract.requestEth(webhookEvent.payload.address, {
            gasPrice,
            gasLimit,
        });
    } catch (error) {
        console.error("Failed to send ETH:", error);
        return;
    }

    console.log("Transaction:", transaction.hash);
    console.log("Waiting for confirmation");

    try {
        await transaction.wait();
    } catch (error) {
        console.error("Failed to confirm transaction:", error);
        return;
    }

    console.log(`ETH sent to ${webhookEvent.payload.address}`);

};
