const { ethers } = require("hardhat");
const chainlinkConfig = require("../chainlink.json");
const Table = require("cli-table3");
const axios = require("axios");
require("dotenv").config();

async function sendSentryLog(message, level) {
  try {
    const url = hre.network.name.includes("testnet") ? process.env.SENTRY_TESTNET : process.env.SENTRY_MAINNET;
    await axios.post(url, 
      { message, level },
      { 
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': process.env.SENTRY_API
        }
      }
    );
  } catch (error) {
    console.error("Error sending Sentry log:", error.message);
    await callWebhook();
  }
}

async function callWebhook() {
  try {
    await axios.post('http://3.139.107.23:5678/webhook/ace-the-brackets/fund-chainlink');
    console.log('Successfully called fund-chainlink webhook');
  } catch (error) {
    console.error('Error calling fund-chainlink webhook:', error.message);
  }
}

async function main() {
  const network = hre.network.name;
  const config = chainlinkConfig[network];
  
  if (!config) {
    console.error(`No configuration found for network: ${network}`);
    return;
  }

  // Connect to the Automation Registry contract
  const registry = await ethers.getContractAt(
    "IAutomationRegistryConsumer",
    config.AUTOMATIONS_REGISTRY
  );

  // Connect to the Functions Router contract
  const functionsRouter = await ethers.getContractAt(
    "IFunctionsSubscriptions",
    config.FUNCTIONS_ROUTER
  );

  const results = [];
  let totalToDeposit = ethers.BigNumber.from(0);
  let needsAttention = false;
  let criticalContracts = [];

  // Process automations
  for (const automation of config.automations) {
    const automationId = ethers.BigNumber.from(automation.id);
    const currentBalance = await registry.getBalance(automationId);
    const minBalance = await registry.getMinBalance(automationId);
    
    const currentBalanceLink = parseFloat(ethers.utils.formatEther(currentBalance));
    const minBalanceLink = parseFloat(ethers.utils.formatEther(minBalance));
    const percentageAboveMin = ((currentBalanceLink - minBalanceLink) / minBalanceLink) * 100;

    // Determine status and send Sentry logs if needed
    let status;
    if (percentageAboveMin >= 20) {
      status = `\x1b[32mOK (${percentageAboveMin.toFixed(0)}%)\x1b[0m`;
    } else if (percentageAboveMin >= 15) {
      status = `\x1b[33mMedium (${percentageAboveMin.toFixed(0)}%)\x1b[0m`;
    } else if (percentageAboveMin >= 10) {
      status = `\x1b[35mLow (${percentageAboveMin.toFixed(0)}%)\x1b[0m`;
      needsAttention = true;
      criticalContracts.push({
        name: automation.name,
        type: 'Automation',
        percentage: percentageAboveMin
      });
    } else {
      status = `\x1b[31mCritical (${percentageAboveMin.toFixed(0)}%)\x1b[0m`;
      needsAttention = true;
      criticalContracts.push({
        name: automation.name,
        type: 'Automation',
        percentage: percentageAboveMin
      });
    }

    const targetBalance = minBalanceLink * 1.2;
    const toDeposit = Math.max(0, targetBalance - currentBalanceLink);

    if (toDeposit > 0) {
      totalToDeposit = totalToDeposit.add(
        ethers.utils.parseEther(toDeposit.toFixed(18))
      );
    }

    results.push({
      name: automation.name,
      currentBalance: currentBalanceLink,
      minBalance: minBalanceLink,
      status,
      toDeposit,
      percentageAboveMin,
      type: 'automation'
    });
  }

  // Process Functions subscriptions
  for (const func of config.functions) {
    const subscription = await functionsRouter.getSubscription(func.id);
    const currentBalanceLink = parseFloat(ethers.utils.formatEther(subscription.balance));
    const minBalanceLink = 0.4; // Fixed minimum balance for Functions
    const percentageAboveMin = ((currentBalanceLink - minBalanceLink) / minBalanceLink) * 100;

    // Determine status for Functions and send Sentry logs if needed
    let status;
    if (percentageAboveMin >= 20) {
      status = `\x1b[32mOK (${percentageAboveMin.toFixed(0)}%)\x1b[0m`;
    } else if (percentageAboveMin >= 15) {
      status = `\x1b[33mMedium (${percentageAboveMin.toFixed(0)}%)\x1b[0m`;
    } else if (percentageAboveMin >= 10) {
      status = `\x1b[35mLow (${percentageAboveMin.toFixed(0)}%)\x1b[0m`;
      needsAttention = true;
      criticalContracts.push({
        name: func.name,
        type: 'Functions',
        percentage: percentageAboveMin
      });
    } else {
      status = `\x1b[31mCritical (${percentageAboveMin.toFixed(0)}%)\x1b[0m`;
      needsAttention = true;
      criticalContracts.push({
        name: func.name,
        type: 'Functions',
        percentage: percentageAboveMin
      });
    }

    const toDeposit = currentBalanceLink >= 1 ? 0 : 1 - currentBalanceLink;

    if (toDeposit > 0) {
      totalToDeposit = totalToDeposit.add(
        ethers.utils.parseEther(toDeposit.toFixed(18))
      );
    }

    results.push({
      name: func.name,
      currentBalance: currentBalanceLink,
      minBalance: minBalanceLink,
      status,
      toDeposit,
      percentageAboveMin,
      type: 'function'
    });
  }

  // Sort results by percentageAboveMin (ascending)
  results.sort((a, b) => a.percentageAboveMin - b.percentageAboveMin);

  // Create a table for the report
  const table = new Table({
    head: ["Contract Name", "Current Balance", "Minimum Balance", "Status", "To Deposit"],
    style: {
      head: ["cyan"],
    },
  });

  // Add sorted results to table
  for (const result of results) {
    table.push([
      result.name,
      result.currentBalance.toFixed(4),
      result.minBalance.toFixed(4),
      result.status,
      result.toDeposit.toFixed(4)
    ]);
  }

  // Print the report
  console.log("\nChainlink Balance Report");
  console.log("=======================\n");
  console.log(table.toString());
  console.log("\nTotal LINK needed for deposit:", 
    parseFloat(ethers.utils.formatEther(totalToDeposit)).toFixed(4));

  // Send a single Sentry message if there are any contracts needing attention
  if (needsAttention) {
    const totalWithBuffer = parseFloat(ethers.utils.formatEther(totalToDeposit)) * 1.25;
    let message = `LINK Balance Alert:\n`;
    criticalContracts.forEach(contract => {
      message += `- ${contract.type} ${contract.name}: ${contract.percentage.toFixed(2)}% above minimum\n`;
    });
    message += `\nTotal LINK needed (with 25% buffer): ${totalWithBuffer.toFixed(4)}`;
    
    await sendSentryLog(message, criticalContracts.some(c => c.percentage < 15) ? 'error' : 'warning');
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
