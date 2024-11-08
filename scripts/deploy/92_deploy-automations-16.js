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

  if (networkData.ACE16_AUTOMATION === "") {
    console.log(`Deploying AutomationAce16...`);
    const AutomationAce16 = await ethers.getContractFactory("AutomationAce16");
    const automationAce16 = await AutomationAce16.deploy(networkData.GAMES_HUB);
    await automationAce16.deployed();

    console.log(`AutomationAce16 deployed at ${automationAce16.address}`);
    networkData.ACE16_AUTOMATION = automationAce16.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      automationAce16.address,
      ethers.utils.id("ACE16_AUTOMATION"),
      true
    );
  } else {
    console.log(
      `AutomationAce16 already deployed at ${networkData.ACE16_AUTOMATION}`
    );
  }

  fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

  if (networkData.ACE16_LOGAUTOMATION === "") {
    console.log(`Deploying LogAutomationAce16...`);
    const LogAutomationAce16 = await ethers.getContractFactory(
      "LogAutomationAce16"
    );
    const logAutomationAce16 = await LogAutomationAce16.deploy(
      networkData.GAMES_HUB
    );
    await logAutomationAce16.deployed();

    console.log(`LogAutomationAce16 deployed at ${logAutomationAce16.address}`);
    networkData.ACE16_LOGAUTOMATION = logAutomationAce16.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      logAutomationAce16.address,
      ethers.utils.id("ACE16_LOGAUTOMATION"),
      true
    );
  } else {
    console.log(
      `LogAutomationAce16 already deployed at ${networkData.ACE16_LOGAUTOMATION}`
    );
  }

  fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

  if (networkData.ACE16ENTRY_LOGAUTOMATION === "") {
    console.log(`Deploying LogAutomationAce16Entry...`);
    const LogAutomationAce16Entry = await ethers.getContractFactory(
      "LogAutomationAce16Entry"
    );
    const logAutomationAce16Entry = await LogAutomationAce16Entry.deploy(
      networkData.GAMES_HUB
    );
    await logAutomationAce16Entry.deployed();

    console.log(
      `LogAutomationAce16Entry deployed at ${logAutomationAce16Entry.address}`
    );
    networkData.ACE16ENTRY_LOGAUTOMATION = logAutomationAce16Entry.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      logAutomationAce16Entry.address,
      ethers.utils.id("ACE16ENTRY_LOGAUTOMATION"),
      true
    );
  } else {
    console.log(
      `LogAutomationAce16Entry already deployed at ${networkData.ACE16ENTRY_LOGAUTOMATION}`
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
