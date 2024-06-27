const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

const deployFolder = path.join(__dirname, '..', 'scripts/deploy');

// Pega o nome da rede dos argumentos do comando
const networkName = process.argv[2];

if (!networkName) {
  console.error('Please provide a network name.');
  process.exit(1);
}

const runDeployScript = async (file) => {
  const filePath = path.join(deployFolder, file);
  console.log(`Deploying ${file} on ${networkName}...`);

  try {
    const { stdout, stderr } = await execAsync(`npx hardhat run "${filePath}" --network ${networkName}`);
    console.log(stdout);
    if (stderr) {
      console.error(stderr);
    }
  } catch (error) {
    console.error(`Error deploying ${file}:`, error);
    process.exit(1);
  }
};

const main = async () => {
  try {
    const files = fs.readdirSync(deployFolder);
    for (const file of files) {
      await runDeployScript(file);
    }
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
};

main();
