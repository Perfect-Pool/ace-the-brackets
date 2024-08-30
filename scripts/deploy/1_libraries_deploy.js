const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const ImageBetTexts = await ethers.getContractFactory("ImageBetTexts");
  const ImageBetTexts16 = await ethers.getContractFactory("ImageBetTexts16");

  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName]["Libraries"];

  if (networkData.ImageBetTexts === "") {
    console.log(`Deploying ImageBetTexts...`);
    const imageBetTexts = await ImageBetTexts.deploy();
    await imageBetTexts.deployed();
    console.log(`ImageBetTexts deployed at ${imageBetTexts.address}`);

    networkData.ImageBetTexts = imageBetTexts.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`ImageBetTexts already deployed at ${networkData.ImageBetTexts}`);
  }

  if (networkData.ImageBetTexts16 === "") {
    console.log(`Deploying ImageBetTexts16...`);
    const imageBetTexts16 = await ImageBetTexts16.deploy();
    await imageBetTexts16.deployed();
    console.log(`ImageBetTexts16 deployed at ${imageBetTexts16.address}`);

    networkData.ImageBetTexts16 = imageBetTexts16.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(`ImageBetTexts16 already deployed at ${networkData.ImageBetTexts16}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
