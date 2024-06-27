const hre = require("hardhat");

async function main() {
    const contracts = require("../../contracts.json");
    const networkName = hre.network.name;

    const address = contracts[networkName]["GAMES_HUB"];
    if (!address) {
        console.error("GamesHub address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying GamesHub at address", address);

    await hre.run("verify:verify", {
        address: address,
        constructorArguments: [], // Adicionar os argumentos do construtor se necessário
        contract: "contracts/GamesHub.sol:GamesHub"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });