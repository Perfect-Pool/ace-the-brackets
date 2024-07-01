import { ActionFn, Context, Event, TransactionEvent } from "@tenderly/actions";

import { ethers } from "ethers";

// Decoded data structure
interface DecodedData {
    gameId: number;
    iterateStart: number;
    iterateEnd: number;
}

// async function getGasPrice(provider: ethers.providers.Provider, context: Context)
//     : Promise<ethers.BigNumber> {
//     try {
//         const gasPrice = await provider.getGasPrice();
//         return gasPrice;
//     } catch (error) {
//         console.error("Error on getting gas price");
//         if (error instanceof Error) {
//             const errorString = error.toString();
//             await context.storage.putStr('errorConsolation', errorString);
//         } else {
//             await context.storage.putStr('errorConsolation', 'An unknown error occurred at getting gas price');
//         }
//         throw error;
//     }
// }

export const consolationPrize: ActionFn = async (context: Context, event: Event) => {
    const transactionEvent = event as TransactionEvent;

    const privateKey = await context.secrets.get("project.addressPrivateKey");
    const rpcUrl = await context.secrets.get("baseSepolia.rpcUrl");
    const CONTRACT_ADDRESS = await context.secrets.get("baseSepolia.aceTicket.contract");
    const abiText = await context.secrets.get("aceTicket.abi");
    const abi = JSON.parse(abiText);

    console.log("Fetching wallet");
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log("Wallet:", wallet.address);

    console.log("Fetching ACE contract");
    let aceTicketContract;
    try {
        aceTicketContract = new ethers.Contract(CONTRACT_ADDRESS, abi, wallet);
    } catch (error) {
        console.error("Failed to fetch contract.");
        if (error instanceof Error) {
            const errorString = error.toString();
            await context.storage.putStr('errorConsolation', errorString);
        } else {
            await context.storage.putStr('errorConsolation', 'An unknown error occurred at fetching contract');
        }
        return;
    }

    let estimatedGas;
    let gasLimit;

    console.log("Decoding event data");

    let decodedData: DecodedData = {
        gameId: 0,
        iterateStart: 0,
        iterateEnd: 0,
    };

    const logs = transactionEvent.logs;
    logs.forEach((log, index) => {
        if (log.topics[0] !== "0xae71d4ebf2d066790f15124a158f211d7b88d29cac736ade8f968f106e63e028") {
            console.log("Log is not the correct event:", log.topics[0]);
            return;
        }
        console.log("Event Found:", log.topics[0]);
        try {
            const abiDecodedData = ethers.utils.defaultAbiCoder.decode(["uint256", "uint256", "uint256"], log.data);
            decodedData = {
                gameId: abiDecodedData[0].toNumber(),
                iterateStart: abiDecodedData[1].toNumber(),
                iterateEnd: abiDecodedData[2].toNumber(),
            };
        } catch (error) {
            console.error(`Failed to decode data for log ${index}`);
            console.log("Trying next log");
        }
    }, decodedData);

    if (decodedData.gameId === 0) {
        console.error("Failed to decode data for all logs");
        await context.storage.putStr('errorConsolation', 'Failed to decode data for all logs');
        return;
    }

    console.log("Game ID:", decodedData.gameId);
    console.log("Iterate Start:", decodedData.iterateStart);
    console.log("Iterate End:", decodedData.iterateEnd);

    const gameIdToBigInt = ethers.BigNumber.from(decodedData.gameId);
    const iterateStartToBigInt = ethers.BigNumber.from(decodedData.iterateStart);
    const iterateEndToBigInt = ethers.BigNumber.from(decodedData.iterateEnd);

    try {
        estimatedGas = await aceTicketContract.estimateGas.iterateGameTokenIds(
            gameIdToBigInt,
            iterateStartToBigInt,
            iterateEndToBigInt
        );
        gasLimit = estimatedGas.mul(120).div(100);
    } catch (error) {
        console.error("Failed to estimate gas.");
        if (error instanceof Error) {
            const errorString = error.toString();
            await context.storage.putStr('errorConsolation', errorString);
        } else {
            await context.storage.putStr('errorConsolation', 'An unknown error occurred at estimating gas');
        }
        return;
    }

    // const gasPrice = await getGasPrice(provider, context);

    console.log(
        `Estimated gas: ${estimatedGas.toString()}, adjusted gas limit: ${gasLimit.toString()}`
    );

    try {
        const tx = await aceTicketContract.iterateGameTokenIds(
            gameIdToBigInt,
            iterateStartToBigInt,
            iterateEndToBigInt,
            {
                gasLimit: gasLimit,
                // gasPrice: gasPrice,
            }
        );

        await tx.wait();
        console.log(`Games successfully iterated. TX: ${tx.hash}`);
    } catch (error) {
        console.error("Failed to perform iteration.");
        if (error instanceof Error) {
            const errorString = error.toString();
            await context.storage.putStr('errorConsolation', errorString);
        } else {
            await context.storage.putStr('errorConsolation', 'An unknown error occurred at sending transaction');
        }
    }
};