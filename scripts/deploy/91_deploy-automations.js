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

  console.log(`Setting Functions8 contract address to GamesHub...`);
  await gamesHub.setGameContact(
    networkData.FUNCTIONS_ACE8,
    ethers.utils.id("FUNCTIONS_ACE8"),
    true
  );

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
  }

  fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

  if (networkData.ACE8ENTRY_LOGAUTOMATION === "") {
    console.log(`Deploying LogAutomationAce8Entry...`);
    const LogAutomationAce8Entry = await ethers.getContractFactory(
      "LogAutomationAce8Entry"
    );
    const logAutomationAce8Entry = await LogAutomationAce8Entry.deploy(
      networkData.GAMES_HUB
    );
    await logAutomationAce8Entry.deployed();

    console.log(
      `LogAutomationAce8Entry deployed at ${logAutomationAce8Entry.address}`
    );
    networkData.ACE8ENTRY_LOGAUTOMATION = logAutomationAce8Entry.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      logAutomationAce8Entry.address,
      ethers.utils.id("ACE8ENTRY_LOGAUTOMATION"),
      true
    );
  } else {
    console.log(
      `LogAutomationAce8Entry already deployed at ${networkData.ACE8ENTRY_LOGAUTOMATION}`
    );
  }

  fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

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

  //COINS100
  if (networkData.COINS100 === "") {
    console.log(`Deploying Coins100Store...`);
    const Coins100Store = await ethers.getContractFactory("Coins100Store");
    const coins100Store = await Coins100Store.deploy(networkData.GAMES_HUB);
    await coins100Store.deployed();

    console.log(`Coins100Store deployed at ${coins100Store.address}`);
    networkData.COINS100 = coins100Store.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      coins100Store.address,
      ethers.utils.id("COINS100"),
      true
    );
  } else {
    console.log(`Coins100Store already deployed at ${networkData.COINS100}`);
  }

  fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

  //AUTOMATION_TOP100 | AutomationTop100.sol
  if (networkData.AUTOMATION_TOP100 === "") {
    console.log(`Deploying AutomationTop100...`);
    const AutomationTop100 = await ethers.getContractFactory(
      "AutomationTop100"
    );
    const automationTop100 = await AutomationTop100.deploy(
      networkData.GAMES_HUB
    );
    await automationTop100.deployed();

    console.log(`AutomationTop100 deployed at ${automationTop100.address}`);
    networkData.AUTOMATION_TOP100 = automationTop100.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      automationTop100.address,
      ethers.utils.id("AUTOMATION_TOP100"),
      true
    );
  } else {
    console.log(
      `AutomationTop100 already deployed at ${networkData.AUTOMATION_TOP100}`
    );
  }

  fs.writeFileSync(variablesPath, JSON.stringify(data, null, 2));

  //AUTOMATIONLOG_TOP100 | AutomationLogTop100.sol
  if (networkData.AUTOMATIONLOG_TOP100 === "") {
    console.log(`Deploying AutomationLogTop100...`);
    const AutomationLogTop100 = await ethers.getContractFactory(
      "AutomationLogTop100"
    );
    const automationLogTop100 = await AutomationLogTop100.deploy(
      networkData.GAMES_HUB
    );
    await automationLogTop100.deployed();

    console.log(
      `AutomationLogTop100 deployed at ${automationLogTop100.address}`
    );
    networkData.AUTOMATIONLOG_TOP100 = automationLogTop100.address;

    console.log(`Setting contract address to GamesHub...`);
    await gamesHub.setGameContact(
      automationLogTop100.address,
      ethers.utils.id("AUTOMATIONLOG_TOP100"),
      true
    );
  } else {
    console.log(
      `AutomationLogTop100 already deployed at ${networkData.AUTOMATIONLOG_TOP100}`
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
