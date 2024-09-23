const hre = require("hardhat");

async function main() {
    const contracts = require("../../contracts.json");
    const networkName = hre.network.name;

    const address = contracts[networkName]["Libraries"]["ImageParts"];
    if (!address) {
        console.error("ImageParts address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying ImageParts at address", address);

    await hre.run("verify:verify", {
        address: address,
        constructorArguments: [], // Adicionar os argumentos do construtor se necessário
        contract: "contracts/libraries/ImageParts.sol:ImageParts"
    });

    const address16 = contracts[networkName]["Libraries"]["ImageParts16"];
    if (!address16) {
        console.error("ImageParts16 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying ImageParts16 at address", address16);

    await hre.run("verify:verify", {
        address: address16,
        constructorArguments: [], // Adicionar os argumentos do construtor se necessário
        contract: "contracts/libraries/ImageParts16.sol:ImageParts16"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });