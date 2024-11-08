const hre = require("hardhat");

async function main() {
    const contracts = require("../../contracts.json");
    const networkName = hre.network.name;

    const address = contracts[networkName]["ACE16_AUTOMATION"];
    if (!address) {
        console.error("AutomationAce16 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying AutomationAce16 at address", address);

    await hre.run("verify:verify", {
        address: address,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/AutomationAce16.sol:AutomationAce16"
    });

    const addressLog = contracts[networkName]["ACE16_LOGAUTOMATION"];
    if (!addressLog) {
        console.error("LogAutomationAce16 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying LogAutomationAce16 at address", addressLog);

    await hre.run("verify:verify", {
        address: addressLog,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/LogAutomationAce16.sol:LogAutomationAce16"
    });

    const addressLogEntry = contracts[networkName]["ACE16ENTRY_LOGAUTOMATION"];
    if (!addressLogEntry) {
        console.error("LogAutomationAce16Entry address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying LogAutomationAce16Entry at address", addressLogEntry);

    await hre.run("verify:verify", {
        address: addressLogEntry,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/automations/LogAutomationAce16Entry.sol:LogAutomationAce16Entry"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });