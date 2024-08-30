const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName];

  const gamesHubAddress = networkData.GAMES_HUB;
  console.log(`GamesHub loaded at ${gamesHubAddress}`);
  const GamesHub = await ethers.getContractAt("GamesHub", gamesHubAddress);

  // Ensure the BuildImageAce library is deployed
  if (!networkData["Libraries"].BuildImageAce || networkData["Libraries"].BuildImageAce === "") {
    throw new Error(
      "BuildImageAce library address not found. Please deploy BuildImageAce first."
    );
  }

  const name = "NFT_IMAGE_ACE8";

  if (networkData.NFT_IMAGE_ACE8 === "") {
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

    networkData.NFT_IMAGE_ACE8 = nftImage.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    console.log("Setting NftImage address to GamesHub...");
    await GamesHub.setGameContact(
      nftImage.address,
      ethers.utils.id(name),
      true
    );
  } else {
    console.log(`NftImage already deployed at ${networkData.NFT_IMAGE_ACE8}`);
  }

  
  // Ensure the BuildImageAce16 library is deployed
  if (!networkData["Libraries"].BuildImageAce16 || networkData["Libraries"].BuildImageAce16 === "") {
    throw new Error(
      "BuildImageAce16 library address not found. Please deploy BuildImageAce16 first."
    );
  }

  const name16 = "NFT_IMAGE_ACE16";

  if (networkData.NFT_IMAGE_ACE16 === "") {
    console.log("Deploying NftImage16...");
    // Linking BuildImageAce16 library
    const NftImage16 = await ethers.getContractFactory("NftImage16", {
      libraries: {
        BuildImageAce16: networkData["Libraries"].BuildImageAce16,
      },
    });
    const nftImage16 = await NftImage16.deploy(gamesHubAddress);
    await nftImage16.deployed();
    console.log(`NftImage16 deployed at ${nftImage16.address}`);

    networkData.NFT_IMAGE_ACE16 = nftImage16.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    console.log("Setting NftImage16 address to GamesHub...");
    await GamesHub.setGameContact(
      nftImage16.address,
      ethers.utils.id(name16),
      true
    );
  } else {
    console.log(`NftImage16 already deployed at ${networkData.NFT_IMAGE_ACE16}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
