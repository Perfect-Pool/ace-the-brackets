const hre = require("hardhat");

async function main() {
    const contracts = require("../../contracts.json");
    const networkName = hre.network.name;

    const address = contracts[networkName]["Libraries"]["ImageBetTexts"];
    if (!address) {
        console.error("ImageBetTexts address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying ImageBetTexts at address", address);

    await hre.run("verify:verify", {
        address: address,
        constructorArguments: [], // Adicionar os argumentos do construtor se necessário
        contract: "contracts/libraries/ImageBetTexts.sol:ImageBetTexts"
    });

    const address16 = contracts[networkName]["Libraries"]["ImageBetTexts16"];
    if (!address16) {
        console.error("ImageBetTexts16 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying ImageBetTexts16 at address", address16);

    await hre.run("verify:verify", {
        address: address16,
        constructorArguments: [], // Adicionar os argumentos do construtor se necessário
        contract: "contracts/libraries/ImageBetTexts16.sol:ImageBetTexts16"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });