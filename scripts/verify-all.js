const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');

// Promisify exec for use with async/await
const execAsync = util.promisify(exec);

const scriptsVerifyPath = path.join(__dirname, '..', 'scripts', 'verify');
const networkName = process.argv[2];

if (!networkName) {
  console.error('Please provide a network name.');
  process.exit(1);
}

async function verifyContracts() {
  try {
    const files = await fs.promises.readdir(scriptsVerifyPath);

    for (const file of files) {
      if (file.endsWith('.js')) {
        const filePath = path.join(scriptsVerifyPath, file);
        console.log(`Verifying contract with ${file} on ${networkName}...`);

        const { stdout, stderr } = await execAsync(`npx hardhat run ${filePath} --network ${networkName}`);

        console.log(`Output for ${file}: ${stdout}`);
        if (stderr) console.error(`Error for ${file}: ${stderr}`);
      }
    }
  } catch (error) {
    console.error(`Verification process failed: ${error}`);
    process.exit(1);
  }
}

verifyContracts();
