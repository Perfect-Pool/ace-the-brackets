const fs = require("fs-extra");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const variablesPath = path.join(__dirname, "..", "..", "contracts.json");
  const data = JSON.parse(fs.readFileSync(variablesPath, "utf8"));
  const networkName = hre.network.name;
  const networkData = data[networkName];

  let gamesHub = await ethers.getContractAt("GamesHub", networkData.GAMES_HUB);
  console.log(`GamesHub loaded at ${gamesHub.address}`);

  if (networkData.ACE8_AUTOMATION === "") {
    console.log(`Deploying AutomationAce8...`);
    const AutomationAce8 = await ethers.getContractFactory("AutomationAce8");
    const automationAce8 = await AutomationAce8.deploy(networkData.GAMES_HUB);
    await automationAce8.deployed();

    console.log(`AutomationAce8 deployed at ${automationAce8.address}`);
    networkData.ACE8_AUTOMATION = automationAce8.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      automationAce8.address,
      ethers.utils.id("ACE8_AUTOMATION"),
      true
    );
  } else {
    console.log(
      `AutomationAce8 already deployed at ${networkData.ACE8_AUTOMATION}`
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
