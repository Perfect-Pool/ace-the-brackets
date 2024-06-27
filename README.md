# ✅ Ace the Brackets

**Ace the Brackets** is a prediction game that employs a bracket-style system to determine the winner in a single-elimination competition between top coins and tokens, based on their price performance.

Unlike traditional price prediction games, Ace the Brackets introduces a unique twist by representing each user-submitted bracket as a dynamic NFT. These NFTs update at the end of each 10-minute round, reflecting the latest outcomes.

Users have 10 minutes to submit their brackets before the rounds start. The game operates on a smart contract, beginning with the random selection of 8 tokens, which are then placed into a bracket tournament. The prices of these tokens are fetched from the CoinMarketCap API price feeds. Game progression is automated using Tenderly, ensuring smooth and timely advancement of each round.

Ace the Brackets never stops; after each game concludes, a new bracket submission period begins, creating a continuous cycle of prediction and competition.

# Rules & Game Flow

1. **The Game**

Ace the Brackets is a tournament-style contest that takes place over three 10-minute rounds, with an initial 10-minute bracket submission phase.

2. **How it Works**

Starting tokens are randomly chosen from the top 100 CoinMarketCap cryptocurrencies list, excluding stablecoins. Winners are determined by the best price-performance (measured by greatest percentage gain or least percentage loss) during each round, according to data provided by CoinMarketCap.

3. **Entries and Scoring**

Each entry costs 5 USDC. Predict the winner of each matchup. Each correct prediction earns 1 point. There is a 10% service fee.

4. **Winning the Jackpot**

Predict each of the 7 matches correctly to win the jackpot. Each jackpot consists of 90% of the entry fees for the game, plus all previous jackpots since the last perfect score was achieved. If no one scores 7 points, the highest score gets 10% of the amount entered in that game (discounted the protocol's service fee), and the remainder rolls over to the next game.

5. **Prizes**

Jackpot amounts vary according to the number of entries and the jackpot rollover (if any) from previous games. Multiple winners divide all prizes equally. Once a perfect entry is achieved, the jackpot is awarded, and the new jackpot is reset to 0 USDC.