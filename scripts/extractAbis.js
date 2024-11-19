const fs = require("fs");
const path = require("path");

// Caminho para os artefatos do Hardhat
const artifactsDir = path.join(__dirname, "..", "artifacts", "contracts");

// Contratos para extrair ABIs
const contracts = [
  { name: "AceTheBrackets8", path: "games/AceTheBrackets8.sol" },
  { name: "Ace8Proxy", path: "games/Ace8Proxy.sol" },
  { name: "AceEntry8", path: "utils/AceEntry8.sol" },
  { name: "AceTheBrackets16", path: "games/AceTheBrackets16.sol" },
  { name: "Ace16Proxy", path: "games/Ace16Proxy.sol" },
  { name: "AceEntry16", path: "utils/AceEntry16.sol" },
  { name: "TokenFaucet", path: "utils/TokenFaucet.sol" },
  { name: "AutomationAce8", path: "automations/AutomationAce8.sol" },
  { name: "AutomationAce16", path: "automations/AutomationAce16.sol" },
  { name: "AutomationTop100", path: "automations/AutomationTop100.sol" },
  { name: "AutomationLogTop100", path: "automations/AutomationLogTop100.sol" },
  { name: "FunctionsConsumerAce", path: "automations/FunctionsConsumerAce8.sol" },
];

// Função para extrair e salvar ABI
async function extractAndSaveAbi(contractName, contractPath) {
  const artifactPath = path.join(
    artifactsDir,
    contractPath,
    `${contractName}.json`
  );

  // Lê o arquivo do artefato do contrato
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  // Extrai o ABI
  const abi = artifact.abi;

  // Define o caminho do arquivo ABI de saída
  const outputDir = path.join(__dirname, "..", "abi");
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir);
  }
  const outputPath = path.join(outputDir, `${contractName}.abi.json`);

  // Salva o ABI em um arquivo
  fs.writeFileSync(outputPath, JSON.stringify(abi, null, 2));
  console.log(`ABI for ${contractName} saved to ${outputPath}`);
}

// Executa a extração para cada contrato
contracts.forEach((contract) =>
  extractAndSaveAbi(contract.name, contract.path)
);
