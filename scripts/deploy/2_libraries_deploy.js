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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
