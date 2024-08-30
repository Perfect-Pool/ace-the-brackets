const hre = require("hardhat");

async function main() {
  const contracts = require("../../contracts.json");
  const networkName = hre.network.name;

  let tokenAddress;
  if (networkName.includes("-testnet")) {
    tokenAddress = contracts[networkName].TOKEN_ADDRESS;
  } else {
    tokenAddress = contracts[networkName].USDC;
  }

  const address = contracts[networkName]["NFT_ACE8"];
  if (!address) {
    console.error("AceEntry8 address not found in contracts.json");
    process.exit(1);
  }

  console.log("Verifying AceEntry8 at address", address);

  await hre.run("verify:verify", {
    address: address,
    constructorArguments: [
      contracts[networkName].GAMES_HUB,
      contracts[networkName].Executor,
      tokenAddress,
    ],
    contract: "contracts/utils/AceEntry8.sol:AceEntry8",
  });


  const address16 = contracts[networkName]["NFT_ACE16"];
  if (!address16) {
    console.error("AceEntry16 address not found in contracts.json");
    process.exit(1);
  }

  console.log("Verifying AceEntry16 at address", address16);

  await hre.run("verify:verify", {
    address: address16,
    constructorArguments: [
      contracts[networkName].GAMES_HUB,
      contracts[networkName].Executor,
      tokenAddress,
    ],
    contract: "contracts/utils/AceEntry16.sol:AceEntry16",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
