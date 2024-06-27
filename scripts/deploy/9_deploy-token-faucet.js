const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName];

  let gamesHub = await ethers.getContractAt("GamesHub", networkData.GAMES_HUB);
  console.log(`GamesHub loaded at ${gamesHub.address}`);

  if (networkData.TOKEN_FAUCET === "") {
    console.log(`Deploying TokenFaucet...`);
    const TokenFaucet = await ethers.getContractFactory("TokenFaucet");
    const tokenFaucet = await TokenFaucet.deploy(networkData.GAMES_HUB);
    await tokenFaucet.deployed();

    console.log(`TokenFaucet deployed at ${tokenFaucet.address}`);
    networkData.TOKEN_FAUCET = tokenFaucet.address;

    console.log(`Setting token address to GamesHub...`);
    await gamesHub.setGameContact(
      tokenFaucet.address,
      ethers.utils.id("TOKEN_FAUCET"),
      true
    );
  } else {
    console.log(
      `TokenFaucet already deployed at ${networkData.TOKEN_FAUCET}`
    );
  }

  fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
