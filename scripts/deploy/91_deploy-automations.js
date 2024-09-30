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

  if (networkData.ACE8_LOGAUTOMATION === "") {
    console.log(`Deploying LogAutomationAce8...`);
    const LogAutomationAce8 = await ethers.getContractFactory(
      "LogAutomationAce8"
    );
    const logAutomationAce8 = await LogAutomationAce8.deploy(
      networkData.GAMES_HUB
    );
    await logAutomationAce8.deployed();

    console.log(`LogAutomationAce8 deployed at ${logAutomationAce8.address}`);
    networkData.ACE8_LOGAUTOMATION = logAutomationAce8.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      logAutomationAce8.address,
      ethers.utils.id("ACE8_LOGAUTOMATION"),
      true
    );
  } else {
    console.log(
      `LogAutomationAce8 already deployed at ${networkData.ACE8_LOGAUTOMATION}`
    );

    console.log(`Setting Functions8 contract address to GamesHub...`);
    await gamesHub.setGameContact(
      networkData.FUNCTIONS_ACE8,
      ethers.utils.id("FUNCTIONS_ACE8"),
      true
    );
  }

  // SOURCE_CODES_ACE // SourceCodesAce.sol
  if (networkData.SOURCE_CODES_ACE === "") {
    console.log(`Deploying SourceCodesAce...`);
    const SourceCodesAce = await ethers.getContractFactory("SourceCodesAce");
    const sourceCodesAce = await SourceCodesAce.deploy();
    await sourceCodesAce.deployed();

    console.log(`SourceCodesAce deployed at ${sourceCodesAce.address}`);
    networkData.SOURCE_CODES_ACE = sourceCodesAce.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      sourceCodesAce.address,
      ethers.utils.id("SOURCE_CODES_ACE"),
      true
    );
  } else {
    console.log(
      `SourceCodesAce already deployed at ${networkData.SOURCE_CODES_ACE}`
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
