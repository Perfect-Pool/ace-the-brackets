const [qty, cmcIds, geckoIdsString] = args;
if (secrets.cmcApiKey === "") {
  throw Error(`ACE${qty}: CMC API key not set`);
}

const quantity = parseInt(qty);
const PRECISION = 10 ** 8;
const EPSILON = 1e-10; // Small value to handle floating-point precision

// Filter out empty and zero IDs from CMC
const cmcIdArray = cmcIds.split(",").filter((id) => id !== "0" && id !== "");
const cmcIdsString = cmcIdArray.join(",");

// Get Gecko IDs (they are already strings like "bitcoin", "ethereum")
const geckoIdArray = geckoIdsString.split(",").filter((id) => id !== "");

try {
  // Try CoinMarketCap first
  const coinMarketCapRequest = Functions.makeHttpRequest({
    url: `https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest`,
    headers: { "X-CMC_PRO_API_KEY": secrets.cmcApiKey },
    params: {
      convert: "USD",
      id: cmcIdsString,
    },
  });

  const cmcResponse = await coinMarketCapRequest;
  if (!cmcResponse.error && cmcResponse.data && cmcResponse.data.data) {
    const data = cmcResponse.data.data;
    const idToSymbol = {};

    for (const key in data) {
      idToSymbol[data[key].id] = key;
    }

    let prices = cmcIdArray.map((id) => {
      const symbol = idToSymbol[id];
      if (data[symbol] && data[symbol].quote && data[symbol].quote.USD) {
        const price = data[symbol].quote.USD.price;
        const scaledPrice = Math.floor((price + EPSILON) * PRECISION);
        return scaledPrice > 0 ? scaledPrice : 1;
      }
      return 0;
    });

    while (prices.length < quantity) {
      prices.push(0);
    }

    return Functions.encodeString(prices.join(","));
  }

  // If CMC fails, try CoinGecko
  const geckoRequest = Functions.makeHttpRequest({
    url: `https://api.coingecko.com/api/v3/simple/price`,
    params: {
      ids: geckoIdArray.join(","),
      vs_currencies: "usd",
      ...(secrets.geckoApiKey
        ? { x_cg_demo_api_key: secrets.geckoApiKey }
        : {}),
    },
  });

  const geckoResponse = await geckoRequest;
  if (geckoResponse.data) {
    let prices = geckoIdArray.map((geckoId) => {
      if (geckoResponse.data[geckoId] && geckoResponse.data[geckoId].usd) {
        const price = geckoResponse.data[geckoId].usd;
        const scaledPrice = Math.floor((price + EPSILON) * PRECISION);
        return scaledPrice > 0 ? scaledPrice : 1;
      }
      return 0;
    });

    while (prices.length < quantity) {
      prices.push(0);
    }

    return Functions.encodeString(prices.join(","));
  }

  throw Error("Both CMC and CoinGecko requests failed");
} catch (error) {
  throw error;
}
