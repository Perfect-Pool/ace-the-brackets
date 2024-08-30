const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName]["Libraries"];

  let imageBetTextsAddress = networkData.ImageBetTexts;
  if (!imageBetTextsAddress) {
    throw new Error("ImageBetTexts library is not deployed. Deploy it first.");
  }

  console.log(`Using ImageBetTexts at address: ${imageBetTextsAddress}`);

  if (networkData.ImageParts === "") {
    console.log(`Deploying ImageParts...`);

    const ImageParts = await ethers.getContractFactory("ImageParts", {
      libraries: {
        ImageBetTexts: imageBetTextsAddress,
      },
    });

    const imageParts = await ImageParts.deploy();
    await imageParts.deployed();
    console.log(`ImageParts deployed at ${imageParts.address}`);

    networkData.ImageParts = imageParts.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

  } else {
    console.log(`ImageParts already deployed at ${networkData.ImageParts}`);
  }

  

  let imageBetTextsAddress16 = networkData.ImageBetTexts16;
  if (!imageBetTextsAddress16) {
    throw new Error("ImageBetTexts16 library is not deployed. Deploy it first.");
  }

  console.log(`Using ImageBetTexts16 at address: ${imageBetTextsAddress16}`);

  if (networkData.ImageParts16 === "") {
    console.log(`Deploying ImageParts16...`);

    const ImageParts16 = await ethers.getContractFactory("ImageParts16", {
      libraries: {
        ImageBetTexts16: imageBetTextsAddress16,
      },
    });

    const imageParts16 = await ImageParts16.deploy();
    await imageParts16.deployed();
    console.log(`ImageParts16 deployed at ${imageParts16.address}`);

    networkData.ImageParts16 = imageParts16.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

  } else {
    console.log(`ImageParts16 already deployed at ${networkData.ImageParts16}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
