const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName];

  const GamesHub = await ethers.getContractAt(
    "GamesHub",
    networkData.GAMES_HUB
  );
  console.log(`GamesHub loaded at ${GamesHub.address}`);
  console.log(`Executor Address: ${networkData.Executor}`);

  if (networkData.BRACKETS !== "") {
    console.log(`Setting AceTheBrackets8 address to GamesHub...`);
    await GamesHub.setGameContact(
      networkData.BRACKETS,
      ethers.utils.id("BRACKETS"),
      false
    );
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  if (networkData.NFT_BRACKETS !== "") {
    console.log(`Setting AceTicket8 address to GamesHub...`);
    await GamesHub.setGameContact(
      networkData.NFT_BRACKETS,
      ethers.utils.id("ACE_TICKET"),
      true
    );
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  if (networkData.NFT_IMAGE !== "") {
    console.log("Setting NftImage address to GamesHub...");
    await GamesHub.setGameContact(
      networkData.NFT_IMAGE,
      ethers.utils.id("NFT_IMAGE"),
      true
    );
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  if (networkData.NFT_METADATA !== "") {
    console.log(`Setting NftMetadata address to GamesHub...`);
    await GamesHub.setGameContact(
      networkData.NFT_METADATA,
      ethers.utils.id("METADATA"),
      true
    );
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
