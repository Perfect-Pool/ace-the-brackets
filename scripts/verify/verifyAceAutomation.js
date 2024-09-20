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
        contract: "contracts/utils/AutomationAce8.sol:AutomationAce8"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });