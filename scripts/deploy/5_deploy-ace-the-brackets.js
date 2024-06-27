const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName];

  const GamesHub = await ethers.getContractAt(
    "GamesHub",
    networkData.GAMES_HUB
  );
  console.log(`GamesHub loaded at ${GamesHub.address}`);
  console.log(`Executor Address: ${networkData.Executor}`);


  if (networkData.BRACKETS === "") {
    console.log(`Deploying AceTheBrackets8...`);
    const AceTheBrackets8 = await ethers.getContractFactory("AceTheBrackets8");
    const aceTheBrackets = await AceTheBrackets8.deploy(
      networkData.GAMES_HUB,
      networkData.Executor,
      networkData.LAST_GAME
    );
    await aceTheBrackets.deployed();

    console.log(`AceTheBrackets8 deployed at ${aceTheBrackets.address}`);
    networkData.BRACKETS = aceTheBrackets.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting AceTheBrackets8 address to GamesHub...`);
    await GamesHub.setGameContact(
      aceTheBrackets.address,
      ethers.utils.id("BRACKETS"),
      false
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`AceTheBrackets8 already deployed at ${networkData.BRACKETS}`);
  }

  if (networkData.BRACKETS_PROXY === "") {
    console.log(`Deploying Ace8Proxy...`);
    const Ace8Proxy = await ethers.getContractFactory("Ace8Proxy");
    const aceProxy = await Ace8Proxy.deploy(
      networkData.GAMES_HUB,
      networkData.Executor,
      networkData.LAST_GAME
    );
    await aceProxy.deployed();

    console.log(`Ace8Proxy deployed at ${aceProxy.address}`);
    networkData.BRACKETS_PROXY = aceProxy.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting Ace8Proxy address to GamesHub...`);
    await GamesHub.setGameContact(
      aceProxy.address,
      ethers.utils.id("BRACKETS_PROXY"),
      false
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting Ace8Proxy last game...`);
    const aceProxyExec = await ethers.getContractAt(
      "Ace8Proxy",
      aceProxy.address
    );
    await aceProxyExec.setGameContract(
      networkData.LAST_GAME,
      networkData.PREVIOUS_BRACKETS
    );
  } else {
    console.log(`Ace8Proxy already deployed at ${networkData.BRACKETS_PROXY}`);
  }

  // networkData.PREVIOUS_BRACKETS = networkData.BRACKETS;
  // fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
