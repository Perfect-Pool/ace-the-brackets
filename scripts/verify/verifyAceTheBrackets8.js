const hre = require("hardhat");

async function main() {
  const contracts = require("../../contracts.json");
  const networkName = hre.network.name;

  const address = contracts[networkName]["ACE8"];
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
      contracts[networkName].LAST_GAME8
    ],
    contract: "contracts/games/AceTheBrackets8.sol:AceTheBrackets8",
  });

  console.log("Verifying AceTheBrackets8 testing at address", contracts[networkName]["ACE8_TEST"]);

  await hre.run("verify:verify", {
    address: contracts[networkName]["ACE8_TEST"],
    constructorArguments: [
      contracts[networkName].GAMES_HUB,
      contracts[networkName].Executor,
      contracts[networkName].LAST_GAME8
    ],
    contract: "contracts/games/AceTheBrackets8.sol:AceTheBrackets8",
  });

  const addressProxy = contracts[networkName]["ACE8_PROXY"];
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
      contracts[networkName].LAST_GAME8
    ],
    contract: "contracts/games/Ace8Proxy.sol:Ace8Proxy",
  });

  const address16 = contracts[networkName]["ACE16"];
  if (!address16) {
    console.error("AceTheBrackets16 address not found in contracts.json");
    process.exit(1);
  }

  console.log("Verifying AceTheBrackets16 at address", address16);

  await hre.run("verify:verify", {
    address: address16,
    constructorArguments: [
      contracts[networkName].GAMES_HUB,
      contracts[networkName].Executor,
      contracts[networkName].LAST_GAME16
    ],
    contract: "contracts/games/AceTheBrackets16.sol:AceTheBrackets16",
  });

  const addressProxy16 = contracts[networkName]["ACE16_PROXY"];
  if (!addressProxy16) {
    console.error("Ace16Proxy address not found in contracts.json");
    process.exit(1);
  }

  console.log("Verifying Ace16Proxy at address", addressProxy16);

  await hre.run("verify:verify", {
    address: addressProxy16,
    constructorArguments: [
      contracts[networkName].GAMES_HUB,
      contracts[networkName].Executor,
      contracts[networkName].LAST_GAME16
    ],
    contract: "contracts/games/Ace16Proxy.sol:Ace16Proxy",
  });

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
