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

  const name = "NFT_METADATA_ACE8";
  if (networkData.NFT_METADATA_ACE8 === "") {
    console.log(`Deploying NftMetadata...`);
    const NftMetadata = await ethers.getContractFactory("NftMetadata");
    const nftMetadata = await NftMetadata.deploy(gamesHubAddress);
    await nftMetadata.deployed();
    console.log(`NftMetadata deployed at ${nftMetadata.address}`);

    networkData.NFT_METADATA_ACE8 = nftMetadata.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting NftMetadata address to GamesHub...`);
    await GamesHub.setGameContact(
      nftMetadata.address,
      ethers.utils.id(name),
      true
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`NftMetadata already deployed at ${networkData.NFT_METADATA_ACE8}`);
  }

  const name16 = "NFT_METADATA_ACE16";
  if (networkData.NFT_METADATA_ACE16 === "") {
    console.log(`Deploying NftMetadata16...`);
    const NftMetadata16 = await ethers.getContractFactory("NftMetadata16");
    const nftMetadata16 = await NftMetadata16.deploy(gamesHubAddress);
    await nftMetadata16.deployed();
    console.log(`NftMetadata16 deployed at ${nftMetadata16.address}`);

    networkData.NFT_METADATA_ACE16 = nftMetadata16.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log(`Setting NftMetadata16 address to GamesHub...`);
    await GamesHub.setGameContact(
      nftMetadata16.address,
      ethers.utils.id(name16),
      true
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`NftMetadata16 already deployed at ${networkData.NFT_METADATA_ACE16}`);
  }
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
