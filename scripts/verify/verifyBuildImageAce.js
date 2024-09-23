const hre = require("hardhat");

async function main() {
  const contracts = require("../../contracts.json");
  const networkName = hre.network.name;

  // Carregando o endereço do contrato de contracts.json
  const address = contracts[networkName]["Libraries"]["BuildImageAce"];
  if (!address) {
    console.error("BuildImageAce address not found in contracts.json");
    process.exit(1);
  }

  console.log("Verifying BuildImageAce at address", address);

  await hre.run("verify:verify", {
    address: address,
    constructorArguments: [],
    contract: "contracts/libraries/BuildImageAce.sol:BuildImageAce",
  });

  const address16 = contracts[networkName]["Libraries"]["BuildImageAce16"];
  if (!address16) {
    console.error("BuildImageAce16 address not found in contracts.json");
    process.exit(1);
  }

  console.log("Verifying BuildImageAce16 at address", address16);

  await hre.run("verify:verify", {
    address: address16,
    constructorArguments: [],
    contract: "contracts/libraries/BuildImageAce16.sol:BuildImageAce16",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
