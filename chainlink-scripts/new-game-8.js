if (secrets.apiKey === "") {
  throw Error("Variable not set: apiKey");
}

const getRandomUniqueElements = (arr, n) => {
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

const coinMarketCapRequest = Functions.makeHttpRequest({
  url: `https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest`,
  headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },
  params: { start: 1, limit: 150, sort: "market_cap" },
});

const response = await coinMarketCapRequest;
const coinsData = response.data.data;
const selectedCoins = getRandomUniqueElements(coinsData, 8);
const newGameCoins = selectedCoins.map((coin) => ({
  id: coin.id,
  symbol: coin.symbol,
  tags: coin.tags,
}));

const newGameString = newGameCoins
  .map((coin) => `${coin.id},${coin.symbol}`)
  .join(";");
  
return Functions.encodeString(newGameString);
