if (secrets.cmcApiKey === "" || secrets.geckoApiKey === "") {
  throw Error("API keys not set");
}
let lastIndex = parseInt(args[1]) || 0;
let itLasts = parseInt(args[2]) || 0;
if (itLasts === 0) {
  return Functions.encodeUint256(0);
}
try {
  const [cmcResponse, geckoResponse1, geckoResponse2] = await Promise.all([
    Functions.makeHttpRequest({
      url: `https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest`,
      headers: { "X-CMC_PRO_API_KEY": secrets.cmcApiKey },
      params: { start: 1, limit: 200, sort: "market_cap" },
    }),
    Functions.makeHttpRequest({
      url: `https://api.coingecko.com/api/v3/coins/markets`,
      params: {
        vs_currency: "usd",
        order: "market_cap_desc",
        page: 1,
        ...(secrets.geckoApiKey
          ? { x_cg_demo_api_key: secrets.geckoApiKey }
          : {}),
      },
    }),
    Functions.makeHttpRequest({
      url: `https://api.coingecko.com/api/v3/coins/markets`,
      params: {
        vs_currency: "usd",
        order: "market_cap_desc",
        page: 2,
        ...(secrets.geckoApiKey
          ? { x_cg_demo_api_key: secrets.geckoApiKey }
          : {}),
      },
    }),
  ]);
  if (!cmcResponse || !cmcResponse.data || !cmcResponse.data.data) {
    throw Error("Invalid CMC response");
  }
  if (!geckoResponse1 || !geckoResponse1.data) {
    throw Error("Invalid Gecko response");
  }
  const geckoResponse = geckoResponse1.data.concat(geckoResponse2.data);
  const geckoCoins = new Map();
  geckoResponse.forEach((coin) => {
    geckoCoins.set(coin.symbol.toLowerCase(), {
      id: coin.id,
      name: coin.name.toLowerCase(),
    });
  });
  const finalCoins = [];
  const cmcCoins = cmcResponse.data.data;
  for (
    let i = lastIndex;
    i < cmcCoins.length && finalCoins.length < 7 && itLasts > 0;
    i += 1
  ) {
    const cmcCoin = cmcCoins[i];
    if ((cmcCoin.tags && cmcCoin.tags.includes("stablecoin")) || cmcCoin.symbol==="FTM") {
      lastIndex += 1;
      continue;
    }
    const geckoCoin = geckoCoins.get(cmcCoin.symbol.toLowerCase());
    if (geckoCoin && geckoCoin.name === cmcCoin.name.toLowerCase()) {
      finalCoins.push({
        cmc_id: cmcCoin.id,
        gecko_id: geckoCoin.id,
        symbol: cmcCoin.symbol,
      });
      itLasts -= 1;
    }
    lastIndex += 1;
  }
  const returnString =
    finalCoins.length > 0
      ? `${lastIndex};${finalCoins
          .map((coin) => `${coin.cmc_id},${coin.gecko_id},${coin.symbol}`)
          .join(";")}`
      : "";
  return Functions.encodeString(returnString);
} catch (error) {
  throw error;
}
