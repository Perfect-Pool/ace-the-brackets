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
    } catch (error: any) {
        console.error('Failed to send error log:', error);
    }
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
    if (n > len) {
        throw new RangeError(
            "getRandomUniqueElements: more elements taken than available"
        );
    }
    while (n--) {
        const x = Math.floor(Math.random() * len);
        result[n] = filtered[x in taken ? taken[x] : x];
        taken[x] = --len in taken ? taken[len] : len;
    }
    return result;
};

const getCoinsTop = async (limit: number, maxCoins: number, context: Context, timestampExec: number): Promise<Coin[]> => {
    const apiKey = await context.secrets.get("project.cmcAPIKeyTest");
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
        await sendErrorLog("CoinMarketCap API call failed on ACE", context);
        return [];
    }
}

const getPriceCMC = async (coin: string, context: Context, timestampExec: number): Promise<any> => {
    const apiKey = await context.secrets.get("project.cmcAPIKeyTest");
    const url = `https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest`;

    const timestamptoIso8601 = new Date(timestampExec * 1000).toISOString();
    console.log("Timestamp to ISO8601: ", timestamptoIso8601);

    try {
        const response = await axios.get(url, {
            params: {
                symbol: coin
            },
            headers: {
                "X-CMC_PRO_API_KEY": apiKey,
            },
        });

        return response.data.data;
    } catch (error) {
        console.error("CoinMarketCap API call failed:", error);
        await sendErrorLog("CoinMarketCap API call failed on ACE", context);
        return [];
    }
}

// Function to decode the data returned by the getActiveGamesActualCoins() function
const decodeActiveGamesActualCoins = async (encodedGames: string[], aceContract: ethers.Contract, lastTimeStamp: number): Promise<DecodedGame[]> => {
    const decodedGames: DecodedGame[] = [];

    for (const encodedGame of encodedGames) {
        if (encodedGame === "0x") {
            continue;
        }

        const decoded = ethers.utils.defaultAbiCoder.decode(
            ["uint256", "uint8", "string[8]", "uint256[8]"],
            encodedGame
        );

        const gameId = decoded[0].toNumber();
        if (gameId === 0) {
            continue;
        }
        const actualRound = decoded[1];
        console.log("Decoding Game ID: ", gameId);
        const fullGameData = await aceContract.getGameFullData(decoded[0]);

        console.log("Decoding Full Game Data");
        const decodedFulldata = ethers.utils.defaultAbiCoder.decode(
            ["bytes", "bytes", "bytes", "string", "uint256", "uint8", "uint256", "uint256", "bool"],
            fullGameData
        );

        // const fullRoundData = ethers.utils.defaultAbiCoder.decode(
        //     ["string[]", "uint256[]", "uint256[]", "uint256", "uint256"],
        //     decodedFulldata[actualRound]
        // );

        const gameStart = decodedFulldata[6].toNumber();
        if (gameStart === 0) {
            console.log("This game has no timer yet.");
            continue;
        }

        if (actualRound === 0 && gameStart > lastTimeStamp) {
            console.log("This game has not started yet.");
            continue;
        }
        // const roundEnd = fullRoundData[4].toNumber();

        // if (roundEnd > lastTimeStamp) {
        //     console.log("This round has not ended yet.");
        //     continue;
        // }

        decodedGames.push({
            game_id: gameId,
            game_round: actualRound,
            coins: decoded[2],
            prices: decoded[3].map((price: ethers.BigNumber) => price.toNumber()),
        });
    }

    return decodedGames;
};

// Function to create the calldata for the createGame function
const createCalldataForNewGame = async (newGameCoins: { id: number; symbol: string }[]) => {
    const cmcIds = newGameCoins.map((coin) => coin.id);
    const symbols = newGameCoins.map((coin) => coin.symbol);

    const calldata = ethers.utils.defaultAbiCoder.encode(
        ["uint256[8]", "string[8]"],
        [cmcIds, symbols]
    );

    return calldata;
};

const updateCoinsList = (coins: string, decodedGames: DecodedGame[]) => {
    let symbolsSet = coins === "" ? new Set() :
        new Set(coins.split(","));

    decodedGames.forEach((game) => {
        if (!game || game === null || game.game_id === 0) return;
        game.coins.forEach((coin) => {
            if (coin.trim() && !symbolsSet.has(coin)) {
                symbolsSet.add(coin);
            }
        });
    });

    return Array.from(symbolsSet).join(",");
};

const calculateGameResults = async (decodedGames: DecodedGame[], prices: any) => {
    let resultGames: any[] = [];

    decodedGames.forEach(async (game) => {
        const variations: any[] = []
        const actualPrices: any[] = []
        const winners: any[] = []
        const pricesWinners: any[] = []

        for (let index = 0; index < game.coins.length; index += 2) {
            if (!game.coins[index]) {
                continue;
            }

            const moeda = prices[game.coins[index]];
            const moedaNext = prices[game.coins[index + 1]];

            if (!moeda || !moedaNext || !moeda?.quote?.USD || !moedaNext?.quote?.USD) {
                console.error("Prices not found for coin: ", game.coins[index]);
                console.error("Price: ", prices[game.coins[index]]);
                continue;
            }

            const priceCurrent = Math.floor(
                moeda.quote.USD.price * 10 ** 8
            );
            const priceNext = Math.floor(
                moedaNext.quote.USD.price * 10 ** 8
            );
            console.log("Price current ", game.coins[index], ": ", priceCurrent);
            console.log("Price next ", game.coins[index + 1], ": ", priceNext);

            actualPrices[index] = priceCurrent;
            actualPrices[index + 1] = priceNext;

            if (game.prices[index] !== 0) {
                const variationCurrent =
                    (priceCurrent - game.prices[index]) / game.prices[index];
                const variationNext =
                    (priceNext - game.prices[index + 1]) / game.prices[index + 1];

                variations[index] = variationCurrent;
                variations[index + 1] = variationNext;

                if (variationCurrent === variationNext) {
                    const volumeChangeCurrent =
                        moeda.quote.USD.volume_change_24h;
                    const volumeChangeNext =
                        moedaNext.quote.USD.volume_change_24h;

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
            }
        }

        let retorno = {
            game_id: game.game_id,
            coins: game.coins.filter((coin) => coin !== ""),
            prices: actualPrices,
            variations: variations.map((v) => v || 0),
            winners,
            pricesWinners,
        };

        let permitirPush = true;

        //iterar coins e ver se existem valores zerados. Acrescentar valores zerados até fechar 8 posições
        permitirPush = !retorno.coins.some((coin) => coin === "");
        if (!(game.game_round === 0 && game.prices[0] === 0)) {
            permitirPush = permitirPush && !retorno.prices.some((price) => price === 0);
            permitirPush = permitirPush && !retorno.winners.some((winner) => winner === 0);
            permitirPush = permitirPush && !retorno.pricesWinners.some((price) => price === 0);
        } else console.log("Falhou na verificação de valores zerados do primeiro round.");

        const expectedLength = game.game_round === 0 ? 8 : game.game_round === 1 ? 4 : 2;
        console.log("Retorno: ", retorno);

        if (permitirPush &&
            retorno.coins.length === expectedLength
        ) {
            if (!(game.game_round === 0 && game.prices[0] === 0) &&
                !(retorno.variations.length === expectedLength &&
                    retorno.prices.length === expectedLength &&
                    retorno.winners.length === expectedLength / 2 &&
                    retorno.pricesWinners.length === expectedLength / 2)
            ) return;
            while (retorno.coins.length < 8) retorno.coins.push("");
            while (retorno.variations.length < 8) retorno.variations.push(0);
            while (retorno.prices.length < 8) retorno.prices.push(0);
            while (retorno.winners.length < 8) retorno.winners.push(0);
            while (retorno.pricesWinners.length < 8) retorno.pricesWinners.push(0);
            resultGames.push(retorno);
            return;
        } else console.log("Falhou na verificação de expectativa de tamanho do retorno.");

        console.error("Erro ao calcular o retorno do jogo: ", retorno.game_id, " Round: ", game.game_round);
    });

    console.log("Result games Final: ", resultGames);
    return resultGames;
};

function createDataUpdate(resultGames: any[]) {
    const gameIds: number[] = [];
    const prices: string[] = [];
    const pricesWinners: string[] = [];
    const winners: string[] = [];

    resultGames.forEach((game) => {
        gameIds.push(game.game_id);
        prices.push(
            ethers.utils.defaultAbiCoder.encode(
                ["uint256[8]"],
                [game.prices]
            )
        );
        pricesWinners.push(
            ethers.utils.defaultAbiCoder.encode(
                ["uint256[8]"],
                [game.pricesWinners]
            )
        );
        winners.push(
            ethers.utils.defaultAbiCoder.encode(
                ["uint256[8]"],
                [game.winners]
            )
        );
    });

    const paddedGameIds = gameIds.concat(new Array(4 - gameIds.length).fill(0));
    const paddedPrices = prices.concat(new Array(4 - prices.length).fill(
        ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [[0, 0, 0, 0, 0, 0, 0, 0]]
        )
    ));
    const paddedPricesWinners = pricesWinners.concat(new Array(4 - pricesWinners.length).fill(
        ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [[0, 0, 0, 0, 0, 0, 0, 0]]
        )
    ));
    const paddedWinners = winners.concat(new Array(4 - winners.length).fill(
        ethers.utils.defaultAbiCoder.encode(
            ["uint256[8]"],
            [[0, 0, 0, 0, 0, 0, 0, 0]]
        )
    ));

    const dataUpdate = ethers.utils.defaultAbiCoder.encode(
        ["uint256[4]", "bytes[4]", "bytes[4]", "bytes[4]"],
        [paddedGameIds, paddedPrices, paddedPricesWinners, paddedWinners]
    );

    return dataUpdate;
}

export const advanceGames: ActionFn = async (context: Context, event: Event) => {
    const lastTimeStamp = Math.floor(Date.now() / 1000 / 60) * 60;

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
        await sendErrorLog("Failed to fetch contract on ACE", context);
        return;
    }

    console.log("Fetching active games");
    let gamesData;
    try {
        gamesData = await aceContract.getActiveGamesActualCoins();
    } catch (error) {
        console.error("Failed to fetch active games:", error);
        await sendErrorLog("Failed to fetch active games on ACE ", context);
        return;
    }

    console.log("Decoding active games data");
    const decodedGames = await decodeActiveGamesActualCoins(gamesData, aceContract, lastTimeStamp);

    let coins = "";
    let newGameCoins;
    let newGameCalldata = "0x";

    console.log("Checking if there is a new game to be created");
    if (decodedGames.some((game) => game.game_round === 2)) {
        newGameCoins = await getCoinsTop(150, 8, context, lastTimeStamp);
        newGameCalldata = await createCalldataForNewGame(newGameCoins);
        coins = newGameCoins.map((coin) => coin.symbol).join(",");

        console.log("New game coins:", newGameCoins);
    }

    coins = updateCoinsList(coins, decodedGames);
    if(coins === "") {
        console.error("No coins found to update games");
        return;
    }
    console.log("Coins for all games:", coins);

    console.log("Fetching prices");
    const prices = await getPriceCMC(coins, context, lastTimeStamp);

    if (!prices || Object.keys(prices).length === 0) {
        console.error("Failed to fetch prices");
        await sendErrorLog("Failed to fetch prices on ACE", context);
        return;
    }

    console.log("Calculating game results");
    const resultGames = await calculateGameResults(decodedGames, prices);

    console.log("Decoded games:", decodedGames);

    if (resultGames === null || resultGames.length !== decodedGames.length) {
        console.error("Failed to calculate game results");
        await sendErrorLog("Failed to calculate game results on ACE", context);
        return;
    }

    let updateGamesCalldata;
    try {
        updateGamesCalldata =
            resultGames.length === 0 ? "0x" : createDataUpdate(resultGames);
    } catch (error) {
        console.error("Failed to create update games calldata:", error);
        await sendErrorLog("Failed to create update games calldata on ACE", context);
        return;
    }

    console.log("Preparing transaction to perform games");

    console.log("Last timestamp:", lastTimeStamp);
    console.log("New game calldata:", newGameCalldata);
    console.log("Update games calldata:", updateGamesCalldata);

    console.log("Sending Transaction");
    let estimatedGas;
    let gasLimit;

    try {
        estimatedGas = await aceContract.estimateGas.performGames(
            newGameCalldata,
            updateGamesCalldata,
            lastTimeStamp
        );
        gasLimit = estimatedGas.mul(110).div(100);
    } catch (error) {
        console.error("Failed to estimate gas:", error);
        await sendErrorLog("Failed to estimate gas on ACE", context);
        return;
    }

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
                gasLimit: gasLimit
            }
        );

        await tx.wait();
        console.log(`Games successfully updated. TX: ${tx.hash}`);
        await context.storage.putNumber('executed', lastTimeStamp);
    } catch (error: any) {
        console.error("Failed to perform games:", error);
        await sendErrorLog(`Failed to perform games on ACE: ${error?.message?.split(' [')[0]}`, context);
    }

};