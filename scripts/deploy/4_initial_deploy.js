const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName];

  let gamesHub;

  if (networkData.GAMES_HUB === "") {
    console.log(`Deploying GamesHub...`);
    const GamesHub = await ethers.getContractFactory("GamesHub");
    gamesHub = await GamesHub.deploy();
    await gamesHub.deployed();

    console.log(`GamesHub deployed at ${gamesHub.address}`);
    networkData.GAMES_HUB = gamesHub.address;

    console.log(`Setting Admin Wallet address...`);
    await gamesHub.setGameContact(
      networkData.ADMIN_WALLET,
      ethers.utils.id("ADMIN_WALLET"),
      true
    );

    console.log(`Setting Treasury address...`);
    await gamesHub.setGameContact(
      networkData.TREASURY,
      ethers.utils.id("TREASURY"),
      true
    );
  } else {
    gamesHub = await ethers.getContractAt("GamesHub", networkData.GAMES_HUB);
    console.log(`GamesHub loaded at ${gamesHub.address}`);
  }

  if (networkData.TOKEN_ADDRESS === "") {
    console.log(`Deploying FakeUSDCToken...`);
    const FakeUSDCToken = await ethers.getContractFactory("FakeUSDCToken");
    const fakeToken = await FakeUSDCToken.deploy();
    await fakeToken.deployed();

    console.log(`FakeUSDCToken deployed at ${fakeToken.address}`);
    networkData.TOKEN_ADDRESS = fakeToken.address;

    console.log(`Setting token address to GamesHub...`);
    await gamesHub.setGameContact(
      fakeToken.address,
      ethers.utils.id("TOKEN"),
      true
    );
  } else {
    console.log(
      `FakeUSDCToken already deployed at ${networkData.TOKEN_ADDRESS}`
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
