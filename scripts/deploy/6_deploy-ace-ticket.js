const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName];

  let tokenAddress;
  if (networkName.includes("-testnet")) {
    tokenAddress = networkData.TOKEN_ADDRESS;
  }else{
    tokenAddress = networkData.USDC;
  }

  // Carregar o contrato GamesHub
  const GamesHub = await ethers.getContractFactory("GamesHub");
  const gamesHub = await GamesHub.attach(networkData.GAMES_HUB);
  console.log(`GamesHub loaded at ${gamesHub.address}`);

  // Deploy do AceEntry8, se necessário
  const name = "NFT_ACE8";

  if (networkData.NFT_ACE8 === "") {
    const AceEntry8 = await ethers.getContractFactory("AceEntry8");
    const aceTicket8 = await AceEntry8.deploy(gamesHub.address, networkData.Executor, tokenAddress);
    await aceTicket8.deployed();
    console.log(`AceEntry8 deployed at ${aceTicket8.address}`);

    networkData.NFT_ACE8 = aceTicket8.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting AceEntry8 address to GamesHub...`);
    await gamesHub.setGameContact(
      aceTicket8.address,
      ethers.utils.id(name),
      true
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`AceEntry8 already deployed at ${networkData.NFT_ACE8}`);
  }

  
  // Deploy do AceEntry16, se necessário
  const name16 = "NFT_ACE16";

  if (networkData.NFT_ACE16 === "") {
    const AceEntry16 = await ethers.getContractFactory("AceEntry16");
    const aceTicket16 = await AceEntry16.deploy(gamesHub.address, networkData.Executor, tokenAddress);
    await aceTicket16.deployed();
    console.log(`AceEntry16 deployed at ${aceTicket16.address}`);

    networkData.NFT_ACE16 = aceTicket16.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting AceEntry16 address to GamesHub...`);
    await gamesHub.setGameContact(
      aceTicket16.address,
      ethers.utils.id(name16),
      true
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`AceEntry16 already deployed at ${networkData.NFT_ACE16}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
