if (secrets.cmcApiKey === "" || secrets.geckoApiKey === "") {
  throw Error("API keys not set");
}

// Validate and get arguments
let lastIndex = parseInt(args[0]) || 0;
let itLasts = parseInt(args[1]) || 0;

if (itLasts === 0) {
  return Functions.encodeString("");
}

try {
  // Request top 260 from both APIs in parallel
  const [cmcResponse, geckoResponse] = await Promise.all([
    Functions.makeHttpRequest({
      url: `https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest`,
      headers: { "X-CMC_PRO_API_KEY": secrets.cmcApiKey },
      params: { start: 1, limit: 260, sort: "market_cap" },
    }),
    Functions.makeHttpRequest({
      url: `https://pro-api.coingecko.com/api/v3/coins/markets`,
      headers: { "x-cg-pro-api-key": secrets.geckoApiKey },
      params: {
        vs_currency: 'usd',
        order: 'market_cap_desc',
        per_page: 260,
        page: 1,
        sparkline: false
      }
    })
  ]);

  if (!cmcResponse || !cmcResponse.data || !cmcResponse.data.data) {
    console.log("Invalid CMC response");
    return Functions.encodeString("");
  }

  if (!geckoResponse || !geckoResponse.data) {
    console.log("Invalid Gecko response");
    return Functions.encodeString("");
  }

  // Create map of gecko coins by symbol for faster lookup
  const geckoCoins = new Map();
  geckoResponse.data.forEach(coin => {
    geckoCoins.set(coin.symbol.toLowerCase(), {
      id: coin.id,
      name: coin.name.toLowerCase()
    });
  });

  const finalCoins = [];
  const cmcCoins = cmcResponse.data.data;

  // Process coins starting from lastIndex
  for (let i = lastIndex; i < cmcCoins.length && finalCoins.length < 10 && itLasts > 0; i++) {
    const cmcCoin = cmcCoins[i];
    
    // Skip stablecoins
    if (cmcCoin.tags && cmcCoin.tags.includes("stablecoin")) {
      lastIndex++;
      continue;
    }

    // Check if coin exists in gecko and names match
    const geckoCoin = geckoCoins.get(cmcCoin.symbol.toLowerCase());
    if (geckoCoin && geckoCoin.name === cmcCoin.name.toLowerCase()) {
      finalCoins.push({
        cmc_id: cmcCoin.id,
        gecko_id: geckoCoin.id,
        symbol: cmcCoin.symbol
      });
      itLasts--;
    }
    
    lastIndex++;
  }

  // Format return string
  const returnString = finalCoins.length > 0
    ? `${lastIndex};${finalCoins.map(coin => 
        `${coin.cmc_id},${coin.gecko_id},${coin.symbol}`
      ).join(';')}`
    : "";

  return Functions.encodeString(returnString);

} catch (error) {
  console.log("Error details:", error);
  return Functions.encodeString("");
}
