const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName]["Libraries"];

  if (!networkData.ImageParts || networkData.ImageParts === "") {
    throw new Error(
      "ImageParts library address not found in contracts.json. Please deploy ImageParts first."
    );
  }
  const imagePartsAddress = networkData.ImageParts;

  if (networkData.BuildImageAce === "") {
    console.log(
      `Deploying BuildImageAce with ImageParts at ${imagePartsAddress}...`
    );

    const BuildImageAce = await ethers.getContractFactory("BuildImageAce", {
      libraries: {
        ImageParts: imagePartsAddress,
      },
    });

    const buildImageAce = await BuildImageAce.deploy();
    await buildImageAce.deployed();
    console.log(`BuildImageAce deployed at ${buildImageAce.address}`);

    networkData.BuildImageAce = buildImageAce.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(
      `BuildImageAce already deployed at ${networkData.BuildImageAce}`
    );
  }

  if (!networkData.ImageParts16 || networkData.ImageParts16 === "") {
    throw new Error(
      "ImageParts16 library address not found in contracts.json. Please deploy ImageParts first."
    );
  }
  const imagePartsAddress16 = networkData.ImageParts16;

  if (networkData.BuildImageAce16 === "") {
    console.log(
      `Deploying BuildImageAce16 with ImageParts16 at ${imagePartsAddress16}...`
    );

    const BuildImageAce16 = await ethers.getContractFactory("BuildImageAce16", {
      libraries: {
        ImageParts16: imagePartsAddress16,
      },
    });

    const buildImageAce16 = await BuildImageAce16.deploy();
    await buildImageAce16.deployed();
    console.log(`BuildImageAce16 deployed at ${buildImageAce16.address}`);

    networkData.BuildImageAce16 = buildImageAce16.address;
    fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

    await new Promise((resolve) => setTimeout(resolve, 5000));
  } else {
    console.log(
      `BuildImageAce16 already deployed at ${networkData.BuildImageAce16}`
    );
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
