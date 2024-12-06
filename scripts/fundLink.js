const { ethers } = require("hardhat");
const chainlinkConfig = require("../chainlink.json");

async function main() {
  const contractName = "FUNCTIONS_ACE8";
  const amountLink = "0.1";
  const network = hre.network.name;
  const config = chainlinkConfig[network];

  if (!contractName || !amountLink) {
    console.error(
      "Usage: npx hardhat run scripts/fundLink.js --network <network>"
    );
    process.exit(1);
  }

  if (!config) {
    console.error(`No configuration found for network: ${network}`);
    return;
  }

  const [signer] = await ethers.getSigners();

  // Initialize LINK token contract with our custom interface
  const linkTokenAbi = [
    "function balanceOf(address owner) view returns (uint256)",
    "function approve(address spender, uint256 value) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function transferAndCall(address to, uint256 value, bytes calldata data) returns (bool)"
  ];
  const linkToken = new ethers.Contract(config.LINK_TOKEN, linkTokenAbi, signer);

  // Convert amount to wei
  const fundAmount = ethers.utils.parseEther(amountLink);

  // Check if we have enough balance
  const walletBalance = await linkToken.balanceOf(signer.address);
  if (walletBalance.lt(fundAmount)) {
    console.error(
      `Insufficient LINK balance. Have: ${ethers.utils.formatEther(
        walletBalance
      )}, Need: ${amountLink}`
    );
    process.exit(1);
  }

  // Find the contract in config
  const automationContract = config.automations.find(
    (a) => a.name === contractName
  );
  const functionsContract = config.functions.find(
    (f) => f.name === contractName
  );

  if (automationContract) {
    try {
      console.log(
        `Funding Automation contract ${contractName} with ${amountLink} LINK...`
      );
      
      // Initialize registry contract
      const registry = await ethers.getContractAt(
        "IAutomationRegistryConsumer",
        config.AUTOMATIONS_REGISTRY
      );

      // Check and set allowance if needed
      const allowance = await linkToken.allowance(signer.address, config.AUTOMATIONS_REGISTRY);
      if (allowance.lt(fundAmount)) {
        console.log("Approving LINK token spending...");
        const approveTx = await linkToken.approve(config.AUTOMATIONS_REGISTRY, ethers.constants.MaxUint256);
        await approveTx.wait();
      }

      // Fund using addFunds
      const tx = await registry.addFunds(automationContract.id, fundAmount);
      await tx.wait();

      console.log("✅ Funding successful!");
    } catch (error) {
      console.error("Error funding automation contract:", error.message);
      process.exit(1);
    }
  } else if (functionsContract) {
    try {
      console.log(
        `Funding Functions subscription ${contractName} with ${amountLink} LINK...`
      );
      // Direct transferAndCall for functions
      const tx = await linkToken.transferAndCall(
        config.FUNCTIONS_ROUTER,
        fundAmount,
        ethers.utils.defaultAbiCoder.encode(["uint64"], [functionsContract.id])
      );
      await tx.wait();

      console.log("✅ Funding successful!");
    } catch (error) {
      console.error("Error funding Functions subscription:", error.message);
      process.exit(1);
    }
  } else {
    console.error(`Contract ${contractName} not found in configuration`);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
