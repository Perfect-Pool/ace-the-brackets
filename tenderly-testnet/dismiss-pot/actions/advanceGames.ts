import { ActionFn, Context, Event } from "@tenderly/actions";

import { ethers } from "ethers";
import axios from 'axios';

interface Coin {
    id: number;
    symbol: string;
    tags: string[];
}

interface DecodedGame {
    game_id: number;
    game_round: number;
    coins: string[];
    prices: number[];
}

const getRandomUniqueElements = (arr: Coin[], n: number): Coin[] => {
    const uniqueById = Array.from(
        new Map(arr.map((item) => [item["id"], item])).values()
    );
    const filtered = uniqueById.filter(
        (item) => !item.tags.includes("stablecoin")
    );

    let result = new Array(n),
        len = filtered.length,
        taken = new Array(len);
    if (n > len)
        throw new RangeError(
            "getRandomUniqueElements: more elements taken than available"
        );
    while (n--) {
        const x = Math.floor(Math.random() * len);
        result[n] = filtered[x in taken ? taken[x] : x];
        taken[x] = --len in taken ? taken[len] : len;
    }
    return result;
};

const getCoinsTop = async (limit: number, maxCoins: number, context: Context): Promise<Coin[]> => {
    const apiKey = await context.secrets.get("project.cmcAPIKey");
    const url = `https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest`;

    try {
        const response = await axios.get(url, {
            params: {
                start: 1,
                limit: limit,
                sort: "market_cap",
            },
            headers: {
                "X-CMC_PRO_API_KEY": apiKey,
            },
            timeout: 5000,
        });

        const coinsData = response.data.data;
        const selectedCoins = getRandomUniqueElements(coinsData, maxCoins);

        const formattedCoins = selectedCoins.map((coin) => ({
            id: coin.id,
            symbol: coin.symbol,
            tags: coin.tags,
        }));

        return formattedCoins;
    } catch (error) {
        console.error("CoinMarketCap API call failed:", error);
        return [];
    }
}

const getPriceCMC = async (coin: string, context: Context): Promise<any> => {
    const apiKey = await context.secrets.get("project.cmcAPIKey");
    const url = `https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest`;

    try {
        const response = await axios.get(url, {
            params: {
                symbol: coin,
            },
            headers: {
                "X-CMC_PRO_API_KEY": apiKey,
            },
            timeout: 5000,
        });

        return response.data.data;
    } catch (error) {
        console.error("CoinMarketCap API call failed:", error);
        return [];
    }
}

// Function to decode the data returned by the getActiveGamesActualCoins() function
const decodeActiveGamesActualCoins = (encodedGames: string[]): DecodedGame[] => {
    const decodedGames: DecodedGame[] = encodedGames.reduce((acc: DecodedGame[], encodedGame: string) => {
        if (encodedGame === "0x") {
            return acc;
        }

        const decoded = ethers.utils.defaultAbiCoder.decode(
            ["uint256", "uint8", "string[8]", "uint256[8]"],
            encodedGame
        );

        acc.push({
            game_id: decoded[0].toNumber(),
            game_round: decoded[1],
            coins: decoded[2],
            prices: decoded[3].map((price: ethers.BigNumber) => price.toNumber()),
        });

        return acc;
    }, []);

    return decodedGames;
};

// Function to create the calldata for the createGame function
const createCalldataForNewGame = (newGameCoins: { id: number; symbol: string }[]) => {
    const cmcIds = newGameCoins.map((coin) => coin.id);
    const symbols = newGameCoins.map((coin) => coin.symbol);

    // Encode the data for the createGame function
    const calldata = ethers.utils.defaultAbiCoder.encode(
        ["uint256[8]", "string[8]"],
        [cmcIds, symbols]
    );

    return calldata;
};

const updateCoinsList = (coins: string, decodedGames: DecodedGame[]) => {
    let symbolsSet = new Set(coins.split(","));

    decodedGames.forEach((game) => {
        game.coins.forEach((coin) => {
            if (coin.trim() && !symbolsSet.has(coin)) {
                symbolsSet.add(coin);
            }
        });
    });

    return Array.from(symbolsSet).join(",");
};

const calculateGameResults = (decodedGames: DecodedGame[], prices: any) => {
    const resultGames = decodedGames.map((game) => {
        const variations = new Array(8).fill(0);
        const actualPrices = new Array(8).fill(0);
        const winners = new Array(8).fill(0);
        const pricesWinners = new Array(8).fill(0);

        let numCoins = 0;
        let numPrices = 0;
        let numWinners = 0;
        let numPricesWinners = 0;

        for (let index = 0; index < game.coins.length; index += 2) {
            if (!game.coins[index]) {
                continue;
            }
            const priceCurrent = Math.floor(
                prices[game.coins[index]].quote.USD.price * 10 ** 8
            );
            const priceNext = Math.floor(
                prices[game.coins[index + 1]].quote.USD.price * 10 ** 8
            );

            actualPrices[index] = priceCurrent;
            actualPrices[index + 1] = priceNext;
            numCoins += 2;
            numPrices += 2;

            if (game.prices[index] !== 0) {
                const variationCurrent =
                    (priceCurrent - game.prices[index]) / game.prices[index];
                const variationNext =
                    (priceNext - game.prices[index + 1]) / game.prices[index + 1];

                variations[index] = variationCurrent;
                variations[index + 1] = variationNext;

                if (variationCurrent === variationNext) {
                    const volumeChangeCurrent =
                        prices[game.coins[index]].quote.USD.volume_change_24h;
                    const volumeChangeNext =
                        prices[game.coins[index + 1]].quote.USD.volume_change_24h;

                    if (
                        volumeChangeCurrent !== undefined &&
                        volumeChangeNext !== undefined
                    ) {
                        if (volumeChangeCurrent > volumeChangeNext) {
                            winners[index / 2] = prices[game.coins[index]].id;
                            pricesWinners[index / 2] = priceCurrent;
                        } else {
                            winners[index / 2] = prices[game.coins[index + 1]].id;
                            pricesWinners[index / 2] = priceNext;
                        }
                    } else {
                        if (Math.random() > 0.5) {
                            winners[index / 2] = prices[game.coins[index]].id;
                            pricesWinners[index / 2] = priceCurrent;
                        } else {
                            winners[index / 2] = prices[game.coins[index + 1]].id;
                            pricesWinners[index / 2] = priceNext;
                        }
                    }
                } else if (variationCurrent > variationNext) {
                    winners[index / 2] = prices[game.coins[index]].id;
                    pricesWinners[index / 2] = priceCurrent;
                } else {
                    winners[index / 2] = prices[game.coins[index + 1]].id;
                    pricesWinners[index / 2] = priceNext;
                }
                numWinners++;
                numPricesWinners++;
            }
        }

        const retorno = {
            game_id: game.game_id,
            coins: game.coins,
            prices: actualPrices,
            variations: variations.map((v) => v || 0),
            winners,
            pricesWinners,
        };

        // console.log("Game results:", retorno);

        if (
            game.prices.every((price) => price === 0) &&
            game.game_round === 0 && numCoins !== 8 &&
            numPrices !== 8 &&
            numWinners !== 0 &&
            numPricesWinners !== 0) {
            return null;
        }

        if (
            game.prices.every((price) => price !== 0) &&
            game.game_round === 0 &&
            numCoins !== 8 &&
            numPrices !== 8 &&
            numWinners !== 4 &&
            numPricesWinners !== 4
        ) {
            return null;
        }

        if (
            game.game_round === 1 &&
            numCoins !== 4 &&
            numPrices !== 4 &&
            numWinners !== 2 &&
            numPricesWinners !== 2
        ) {
            return null;
        }

        if (
            game.game_round === 2 &&
            numCoins !== 2 &&
            numPrices !== 2 &&
            numWinners !== 1 &&
            numPricesWinners !== 1
        ) {
            return null;
        }


        return retorno;
    });

    return resultGames;
};

function createDataUpdate(resultGames: any[]) {
    let gameIds = new Array(4).fill(0);
    let prices = new Array(4).fill(
        ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [[0, 0, 0, 0, 0, 0, 0, 0]]
        )
    );
    let pricesWinners = new Array(4).fill(
        ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [[0, 0, 0, 0, 0, 0, 0, 0]]
        )
    );
    let winners = new Array(4).fill(
        ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [[0, 0, 0, 0, 0, 0, 0, 0]]
        )
    );

    resultGames.forEach((game, index) => {
        gameIds[index] = game.game_id;
        prices[index] = ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [game.prices]
        );
        pricesWinners[index] = ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [game.pricesWinners]
        );
        winners[index] = ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [game.winners]
        );
    });

    const dataUpdate = ethers.utils.defaultAbiCoder.encode(
        ["uint256[4]", "bytes[4]", "bytes[4]", "bytes[4]"],
        [gameIds, prices, pricesWinners, winners]
    );

    return dataUpdate;
}

// const getGasPrice = async (polygonScanUrl: string, polygonScanKey: string): Promise<ethers.BigNumber> => {
//     try {
//         const response = await axios.get(
//             `${polygonScanUrl}?module=proxy&action=eth_gasPrice&apikey=${polygonScanKey}`
//         );
//         const proposedGasPriceHex = response.data.result;
//         const gasPriceGwei = ethers.BigNumber.from(proposedGasPriceHex);

//         // Increase the gas price by 10%
//         const increasedGasPrice = gasPriceGwei.mul(110).div(100);
//         return increasedGasPrice;
//     } catch (error) {
//         console.log("Failed to fetch gas price:", error);
//         return ethers.utils.parseUnits("10", "gwei");
//     }
// };

async function getGasPrice(provider: ethers.providers.Provider): Promise<ethers.BigNumber> {
    try {
        const gasPrice = await provider.getGasPrice();
        return gasPrice;
    } catch (error) {
        console.error("Erro ao obter o preço do GAS:", error);
        throw error;
    }
}

// function obterMinutosDaHoraAtual(): number {
//     const agora: Date = new Date();
//     const minutos: number = agora.getMinutes();
//     return minutos;
// }

export const advanceGames: ActionFn = async (context: Context, event: Event) => {
    // // executar apenas a cada 20 minutos
    // const minutos = obterMinutosDaHoraAtual();
    // if (minutos % 20 > 10) return;

    const privateKey = await context.secrets.get("project.addressPrivateKey");
    const rpcUrl = await context.secrets.get("baseSepolia.rpcUrl");
    const CONTRACT_ADDRESS = await context.secrets.get("baseSepolia.aceTheBrackets.contract");
    const abiText = await context.secrets.get("aceTheBrackets.abi");
    const abi = JSON.parse(abiText);

    console.log("Ace Contract:", CONTRACT_ADDRESS);

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

    console.log("Fetching coins for a new game");
    const newGameCoins = await getCoinsTop(150, 8, context);
    const newGameCalldata = createCalldataForNewGame(newGameCoins);
    let coins = newGameCoins.map((coin) => coin.symbol).join(",");

    console.log("Coins for a new game:", coins);

    console.log("Fetching active games");
    let gamesData;
    try {
        gamesData = await aceContract.getActiveGamesActualCoins();
    } catch (error) {
        console.error("Failed to fetch active games:", error);
        return;
    }

    console.log("Decoding active games data");
    const decodedGames = decodeActiveGamesActualCoins(gamesData);

    coins = updateCoinsList(coins, decodedGames);
    console.log("Coins for all games:", coins);

    console.log("Fetching prices");
    const prices = await getPriceCMC(coins, context);

    if (!prices || Object.keys(prices).length === 0) {
        console.error("Failed to fetch prices");
        return;
    }

    console.log("Calculating game results");
    const resultGames = calculateGameResults(decodedGames, prices);

    if (resultGames === null) {
        console.error("Failed to calculate game results");
        return;
    }

    const updateGamesCalldata =
        resultGames.length === 0 ? "0x" : createDataUpdate(resultGames);

    console.log("Preparing transaction to perform games");
    let estimatedGas;
    let gasLimit;
    let lastTimeStamp = Math.floor(Date.now() / 1000);

    console.log("Last timestamp:", lastTimeStamp);
    console.log("New game calldata:", newGameCalldata);
    console.log("Update games calldata:", updateGamesCalldata);

    try {
        estimatedGas = await aceContract.estimateGas.performGames(
            newGameCalldata,
            updateGamesCalldata,
            lastTimeStamp
        );
        gasLimit = estimatedGas.mul(120).div(100);
    } catch (error) {
        console.error("Failed to estimate gas:", error);
        return;
    }
    const gasPrice = await getGasPrice(provider);

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
    }
};