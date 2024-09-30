const coinIdsInput = args[0];
if (secrets.apiKey === "") {
  throw Error("Variable not set: apiKey");
}

const idArrayFilter = coinIdsInput.split(",");
const coinIds = idArrayFilter.filter((id) => id !== "0" && id !== "").join(",");

const coinMarketCapRequest = Functions.makeHttpRequest({
  url: `https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest?convert=USD&id=${coinIds}`,
  headers: { "X-CMC_PRO_API_KEY": secrets.apiKey },
});

const coinMarketCapResponse = await coinMarketCapRequest;
if (coinMarketCapResponse.error) {
  throw Error("CoinMarketCap API request failed");
}

const data = coinMarketCapResponse.data.data;
const idArray = coinIds.split(",");

const idToSymbol = {};

for (const key in data) {
  idToSymbol[data[key].id] = key;
}

let prices = idArray.map((id) => {
  const symbol = idToSymbol[id];
  if (data[symbol] && data[symbol].quote && data[symbol].quote.USD) {
    return Math.round(data[symbol].quote.USD.price * 10 ** 8) === 0
      ? 1
      : Math.round(data[symbol].quote.USD.price * 10 ** 8);
  }
  return 0;
});

while (prices.length < 8) {
  prices.push(0);
}

const buffer = new ArrayBuffer(prices.length * 32),
  view = new DataView(buffer);

prices.forEach((price, index) => {
  const encodedPrice = Functions.encodeUint256(price);
  for (let i = 0; i < 32; i++) {
    view.setUint8(index * 32 + i, encodedPrice[i]);
  }
});

return buffer;
