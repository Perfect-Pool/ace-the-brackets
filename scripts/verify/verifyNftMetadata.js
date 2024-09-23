const hre = require("hardhat");

async function main() {
    const contracts = require("../../contracts.json");
    const networkName = hre.network.name;

    const address = contracts[networkName]["NFT_METADATA_ACE8"];
    if (!address) {
        console.error("NftMetadata address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying NftMetadata at address", address);

    await hre.run("verify:verify", {
        address: address,
        constructorArguments: [contracts[networkName].GAMES_HUB],
        contract: "contracts/utils/NftMetadata.sol:NftMetadata"
    });

    const address16 = contracts[networkName]["NFT_METADATA_ACE16"];
    if (!address16) {
        console.error("NftMetadata16 address not found in contracts.json");
        process.exit(1);
    }

    console.log("Verifying NftMetadata16 at address", address16);

    await hre.run("verify:verify", {
        address: address16,
        constructorArguments: [contracts[networkName].GAMES_HUB],
        contract: "contracts/utils/NftMetadata16.sol:NftMetadata16"
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });