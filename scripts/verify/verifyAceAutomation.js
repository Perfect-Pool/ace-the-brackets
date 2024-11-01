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
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });