const hre = require("hardhat");

async function main() {
    const contracts = require("../../contracts.json");
    const networkName = hre.network.name;

    const address = contracts[networkName]["TOKEN_FAUCET"];
    if (!address) {
        console.error("TokenFaucet address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying TokenFaucet at address", address);

    await hre.run("verify:verify", {
        address: address,
        constructorArguments: [
            contracts[networkName].GAMES_HUB
        ],
        contract: "contracts/utils/TokenFaucet.sol:TokenFaucet"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });