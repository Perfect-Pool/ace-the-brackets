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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
