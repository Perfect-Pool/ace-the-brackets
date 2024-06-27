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
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });