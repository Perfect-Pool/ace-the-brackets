const hre = require("hardhat");

async function main() {
    const contracts = require("../../contracts.json");
    const networkName = hre.network.name;

    const address = contracts[networkName]["ACE8_AUTOMATION"];
    if (!address) {
        console.error("AutomationAce8 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying AutomationAce8 at address", address);

    await hre.run("verify:verify", {
        address: address,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/AutomationAce8.sol:AutomationAce8"
    });

    const addressLog = contracts[networkName]["ACE8_LOGAUTOMATION"];
    if (!addressLog) {
        console.error("LogAutomationAce8 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying LogAutomationAce8 at address", addressLog);

    await hre.run("verify:verify", {
        address: addressLog,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/LogAutomationAce8.sol:LogAutomationAce8"
    });

    const addressLogEntry = contracts[networkName]["ACE8ENTRY_LOGAUTOMATION"];
    if (!addressLogEntry) {
        console.error("LogAutomationAce8Entry address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying LogAutomationAce8Entry at address", addressLogEntry);

    await hre.run("verify:verify", {
        address: addressLogEntry,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/LogAutomationAce8Entry.sol:LogAutomationAce8Entry"
    });

    const addressCodes =  contracts[networkName]["SOURCE_CODES_ACE"];
    if (!addressCodes) {
        console.error("SourceCodesAce address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying SourceCodesAce at address", addressCodes);

    await hre.run("verify:verify", {
        address: addressCodes,
        contract: "contracts/automations/SourceCodesAce.sol:SourceCodesAce"
    });

    //AutomationTop100
    const addressTop100 =  contracts[networkName]["AUTOMATION_TOP100"];
    if (!addressTop100) {
        console.error("AutomationTop100 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying AutomationTop100 at address", addressTop100);

    await hre.run("verify:verify", {
        address: addressTop100,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/AutomationTop100.sol:AutomationTop100"
    });

    //AUTOMATIONLOG_TOP100 | AutomationLogTop100
    const addressLogTop100 =  contracts[networkName]["AUTOMATIONLOG_TOP100"];
    if (!addressLogTop100) {
        console.error("AutomationLogTop100 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying AutomationLogTop100 at address", addressLogTop100);

    await hre.run("verify:verify", {
        address: addressLogTop100,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/AutomationLogTop100.sol:AutomationLogTop100"
    });

    //COINS100 | Coins100Store
    const addressCoins100 =  contracts[networkName]["COINS100"];
    if (!addressCoins100) {
        console.error("Coins100 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying Coins100 at address", addressCoins100);

    await hre.run("verify:verify", {
        address: addressCoins100,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/Coins100Store.sol:Coins100Store"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });