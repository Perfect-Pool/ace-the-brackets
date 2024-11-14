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

  if (networkData.ACE8 === "") {
    console.log(`Deploying AceTheBrackets8...`);
    const AceTheBrackets8 = await ethers.getContractFactory("AceTheBrackets8");
    const aceTheBrackets = await AceTheBrackets8.deploy(
      networkData.GAMES_HUB,
      networkData.Executor,
      networkData.LAST_GAME8
    );
    await aceTheBrackets.deployed();

    console.log(`AceTheBrackets8 deployed at ${aceTheBrackets.address}`);
    networkData.ACE8 = aceTheBrackets.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting AceTheBrackets8 address to GamesHub...`);
    await GamesHub.setGameContact(
      aceTheBrackets.address,
      ethers.utils.id("ACE8"),
      false
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`AceTheBrackets8 already deployed at ${networkData.ACE8}`);
  }

  if (networkData.ACE8_PROXY === "") {
    console.log(`Deploying Ace8Proxy...`);
    const Ace8Proxy = await ethers.getContractFactory("Ace8Proxy");
    const aceProxy = await Ace8Proxy.deploy(
      networkData.GAMES_HUB,
      networkData.Executor,
      networkData.LAST_GAME8
    );
    await aceProxy.deployed();

    console.log(`Ace8Proxy deployed at ${aceProxy.address}`);
    networkData.ACE8_PROXY = aceProxy.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting Ace8Proxy address to GamesHub...`);
    await GamesHub.setGameContact(
      aceProxy.address,
      ethers.utils.id("ACE8_PROXY"),
      false
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));

    if (networkData.PREVIOUS_ACE8 !== "") {
      console.log(`Setting Ace8Proxy last game...`);
      const aceProxyExec = await ethers.getContractAt(
        "Ace8Proxy",
        aceProxy.address
      );
      await aceProxyExec.setGameContract(
        networkData.LAST_GAME8,
        networkData.PREVIOUS_ACE8
      );
    }
  } else {
    console.log(`Ace8Proxy already deployed at ${networkData.ACE8_PROXY}`);
  }

  // networkData.PREVIOUS_ACE8 = networkData.ACE8;
  // fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

  if (networkData.ACE16 === "") {
    console.log(`Deploying AceTheBrackets16...`);
    const AceTheBrackets16 = await ethers.getContractFactory(
      "AceTheBrackets16"
    );
    const aceTheBrackets16 = await AceTheBrackets16.deploy(
      networkData.GAMES_HUB,
      networkData.Executor,
      networkData.LAST_GAME16
    );
    await aceTheBrackets16.deployed();

    console.log(`AceTheBrackets16 deployed at ${aceTheBrackets16.address}`);
    networkData.ACE16 = aceTheBrackets16.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting AceTheBrackets16 address to GamesHub...`);
    await GamesHub.setGameContact(
      aceTheBrackets16.address,
      ethers.utils.id("ACE16"),
      false
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`AceTheBrackets16 already deployed at ${networkData.ACE16}`);
    console.log(`Setting AceTheBrackets16 address to GamesHub...`);
    await GamesHub.setGameContact(
      networkData.ACE16,
      ethers.utils.id("ACE16"),
      false
    );

  }

  if (networkData.ACE16_PROXY === "") {
    console.log(`Deploying Ace16Proxy...`);
    const Ace16Proxy = await ethers.getContractFactory("Ace16Proxy");
    const aceProxy16 = await Ace16Proxy.deploy(
      networkData.GAMES_HUB,
      networkData.Executor,
      networkData.LAST_GAME16
    );
    await aceProxy16.deployed();

    console.log(`Ace16Proxy deployed at ${aceProxy16.address}`);
    networkData.ACE16_PROXY = aceProxy16.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting Ace16Proxy address to GamesHub...`);
    await GamesHub.setGameContact(
      aceProxy16.address,
      ethers.utils.id("ACE16_PROXY"),
      false
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));

    if (networkData.PREVIOUS_ACE16 !== "") {
      console.log(`Setting Ace16Proxy last game...`);
      const aceProxyExec = await ethers.getContractAt(
        "Ace16Proxy",
        aceProxy16.address
      );
      await aceProxyExec.setGameContract(
        networkData.LAST_GAME16,
        networkData.PREVIOUS_ACE16
      );
    }
  } else {
    console.log(`Ace16Proxy already deployed at ${networkData.ACE16_PROXY}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
