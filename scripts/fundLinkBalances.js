const { ethers } = require("hardhat");
const chainlinkConfig = require("../chainlink.json");
const Table = require("cli-table3");

async function main() {
  const network = hre.network.name;
  const config = chainlinkConfig[network];
  
  if (!config) {
    console.error(`No configuration found for network: ${network}`);
    return;
  }

  const [signer] = await ethers.getSigners();

  const MIN_PERCENTAGE = 15;

  // Initialize LINK token contract with our custom interface
  const linkTokenAbi = [
    "function balanceOf(address owner) view returns (uint256)",
    "function approve(address spender, uint256 value) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function transferAndCall(address to, uint256 value, bytes calldata data) returns (bool)"
  ];
  const linkToken = new ethers.Contract(config.LINK_TOKEN, linkTokenAbi, signer);

  // Initialize contracts for balance checking
  const registry = await ethers.getContractAt(
    "IAutomationRegistryConsumer",
    config.AUTOMATIONS_REGISTRY
  );

  const functionsRouter = await ethers.getContractAt(
    "IFunctionsSubscriptions",
    config.FUNCTIONS_ROUTER
  );

  // Get current LINK balance
  const walletBalance = await linkToken.balanceOf(signer.address);
  let remainingBalance = walletBalance;
  const walletBalanceLink = parseFloat(ethers.utils.formatEther(walletBalance));

  console.log("\nChainlink Funding Report");
  console.log("=======================");
  console.log(`\nWallet LINK Balance: ${walletBalanceLink.toFixed(4)}`);

  // Process automations and functions
  const automationResults = [];
  const functionResults = [];
  let totalNeeded = ethers.BigNumber.from(0);
  let totalFunded = ethers.BigNumber.from(0);

  // Process automations
  console.log(`\nProcessing automations below ${MIN_PERCENTAGE}%...`);
  for (const automation of config.automations) {
    const currentBalance = await registry.getBalance(automation.id);
    const minBalance = await registry.getMinBalance(automation.id);
    
    const currentBalanceLink = parseFloat(ethers.utils.formatEther(currentBalance));
    const minBalanceLink = parseFloat(ethers.utils.formatEther(minBalance));
    const percentageAboveMin = ((currentBalanceLink - minBalanceLink) / minBalanceLink) * 100;

    // Only consider automations below MIN_PERCENTAGE%
    if (percentageAboveMin < MIN_PERCENTAGE) {
      const targetBalance = minBalanceLink * 1.25; // Target is min + 25%
      const toFund = Math.max(0, targetBalance - currentBalanceLink);

      if (toFund > 0) {
        automationResults.push({
          name: automation.name,
          id: automation.id,
          currentBalance: currentBalanceLink,
          targetBalance: targetBalance,
          toFund: toFund,
          percentageAboveMin: percentageAboveMin
        });

        totalNeeded = totalNeeded.add(
          ethers.utils.parseEther(toFund.toFixed(18))
        );
      }
    }
  }

  // Process Functions subscriptions
  console.log(`\nProcessing Functions subscriptions below ${MIN_PERCENTAGE}%...`);
  for (const func of config.functions) {
    const subscription = await functionsRouter.getSubscription(func.id);
    const currentBalanceLink = parseFloat(ethers.utils.formatEther(subscription.balance));
    const minBalanceLink = 0.5; // Fixed minimum balance for Functions
    const percentageAboveMin = ((currentBalanceLink - minBalanceLink) / minBalanceLink) * 100;

    // Only consider functions below MIN_PERCENTAGE%
    if (percentageAboveMin < MIN_PERCENTAGE) {
      const targetBalance = minBalanceLink * 1.25; // Target is min + 25%
      const toFund = Math.max(0, targetBalance - currentBalanceLink);

      if (toFund > 0) {
        functionResults.push({
          name: func.name,
          id: func.id,
          currentBalance: currentBalanceLink,
          targetBalance: targetBalance,
          toFund: toFund,
          percentageAboveMin: percentageAboveMin
        });

        totalNeeded = totalNeeded.add(
          ethers.utils.parseEther(toFund.toFixed(18))
        );
      }
    }
  }

  // Sort results by percentage above minimum
  const allResults = [...automationResults, ...functionResults].sort(
    (a, b) => a.percentageAboveMin - b.percentageAboveMin
  );

  // Create and display the funding table
  const table = new Table({
    head: ["Contract Name", "Current Balance", "Target Balance", "To Fund", "Status"],
    style: { head: [], border: [] }
  });

  // Process funding for each contract that needs it
  for (const result of allResults) {
    const fundAmount = ethers.utils.parseEther(result.toFund.toFixed(18));
    
    // Check if we have enough balance to fund this contract
    if (remainingBalance.lt(fundAmount)) {
      table.push([
        result.name,
        result.currentBalance.toFixed(4),
        result.targetBalance.toFixed(4),
        result.toFund.toFixed(4),
        "❌ Insufficient LINK"
      ]);
      continue;
    }

    try {
      // Check if it's an automation or function contract
      const isAutomation = config.automations.some(a => a.name === result.name);

      if (isAutomation) {
        const allowance = await linkToken.allowance(signer.address, config.AUTOMATIONS_REGISTRY);
        if (allowance.lt(fundAmount)) {
          const approveTx = await linkToken.approve(config.AUTOMATIONS_REGISTRY, ethers.constants.MaxUint256);
          await approveTx.wait();
        }
        
        // Fund automation using addFunds
        const tx = await registry.addFunds(result.id, fundAmount);
        await tx.wait();
      } else {
        // Fund Functions subscription using transferAndCall
        const tx = await linkToken.transferAndCall(
          config.FUNCTIONS_ROUTER,
          fundAmount,
          ethers.utils.defaultAbiCoder.encode(["uint64"], [result.id])
        );
        await tx.wait();
      }

      remainingBalance = remainingBalance.sub(fundAmount);
      totalFunded = totalFunded.add(fundAmount);

      table.push([
        result.name,
        result.currentBalance.toFixed(4),
        result.targetBalance.toFixed(4),
        result.toFund.toFixed(4),
        "✅ Funded"
      ]);
    } catch (error) {
      console.error(`Error funding ${result.name}:`, error.message);
      table.push([
        result.name,
        result.currentBalance.toFixed(4),
        result.targetBalance.toFixed(4),
        result.toFund.toFixed(4),
        "❌ Error"
      ]);
    }
  }

  console.log(table.toString());
  console.log(`\nTotal LINK needed: ${ethers.utils.formatEther(totalNeeded)}`);
  console.log(`Total LINK funded: ${ethers.utils.formatEther(totalFunded)}`);

  if (totalFunded.gt(0)) {
    console.log("\n✅ All funding completed successfully!");
  } else if (allResults.length > 0) {
    console.log("\n⚠️ No contracts were funded due to errors or insufficient balance");
  } else {
    console.log("\n✅ No contracts need funding at this time");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
