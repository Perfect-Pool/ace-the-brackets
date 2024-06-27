const hre = require("hardhat");

async function main() {
  const contracts = require("../../contracts.json");
  const networkName = hre.network.name;

  const address = contracts[networkName]["BRACKETS"];
  if (!address) {
    console.error("AceTheBrackets8 address not found in contracts.json");
    process.exit(1);
  }

  console.log("Verifying AceTheBrackets8 at address", address);

  await hre.run("verify:verify", {
    address: address,
    constructorArguments: [
      contracts[networkName].GAMES_HUB,
      contracts[networkName].Executor,
      contracts[networkName].LAST_GAME
    ],
    contract: "contracts/games/AceTheBrackets8.sol:AceTheBrackets8",
  });

  const addressProxy = contracts[networkName]["BRACKETS_PROXY"];
  if (!addressProxy) {
    console.error("Ace8Proxy address not found in contracts.json");
    process.exit(1);
  }

  console.log("Verifying Ace8Proxy at address", addressProxy);

  await hre.run("verify:verify", {
    address: addressProxy,
    constructorArguments: [
      contracts[networkName].GAMES_HUB,
      contracts[networkName].Executor,
      contracts[networkName].LAST_GAME
    ],
    contract: "contracts/games/Ace8Proxy.sol:Ace8Proxy",
  });


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
