const hre = require("hardhat");

async function main() {
    const contracts = require("../../contracts.json");
    const networkName = hre.network.name;

    const address = contracts[networkName]["TOKEN_ADDRESS"];
    if (!address) {
        console.error("FakeUSDCToken address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying FakeUSDCToken at address", address);

    await hre.run("verify:verify", {
        address: address,
        constructorArguments: [], 
        contract: "contracts/utils/FakeUSDCToken.sol:FakeUSDCToken"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });