const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName];

  // Ensure the BuildImageAce library is deployed
  if (!networkData["Libraries"].BuildImageAce || networkData["Libraries"].BuildImageAce === "") {
    throw new Error(
      "BuildImageAce library address not found. Please deploy BuildImageAce first."
    );
  }

  const gamesHubAddress = networkData.GAMES_HUB;
  console.log(`GamesHub loaded at ${gamesHubAddress}`);
  const GamesHub = await ethers.getContractAt("GamesHub", gamesHubAddress);

  const name = "NFT_IMAGE";

  if (networkData.NFT_IMAGE === "") {
    console.log("Deploying NftImage...");
    // Linking BuildImageAce library
    const NftImage = await ethers.getContractFactory("NftImage", {
      libraries: {
        BuildImageAce: networkData["Libraries"].BuildImageAce,
      },
    });
    const nftImage = await NftImage.deploy(gamesHubAddress);
    await nftImage.deployed();
    console.log(`NftImage deployed at ${nftImage.address}`);

    networkData.NFT_IMAGE = nftImage.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    console.log("Setting NftImage address to GamesHub...");
    await GamesHub.setGameContact(
      nftImage.address,
      ethers.utils.id(name),
      true
    );
  } else {
    console.log(`NftImage already deployed at ${networkData.NFT_IMAGE}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
