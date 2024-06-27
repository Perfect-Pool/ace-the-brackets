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
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });