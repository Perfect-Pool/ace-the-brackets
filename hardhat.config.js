require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

const { ethers } = require("ethers");

const privateKey = process.env.PRIVATE_KEY;

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    "base-testnet": {
      url: process.env.BASE_TESTNET_RPC_URL,
      accounts: [privateKey],
      chainId: parseInt(process.env.BASE_TESTNET_CHAIN_ID),
    },
    base: {
      url: process.env.BASE_RPC_URL,
      accounts: [privateKey],
      chainId: parseInt(process.env.BASE_CHAIN_ID),
      gasPrice: ethers.utils.parseUnits('0.06', 'gwei').toNumber(),
    }
  },
  etherscan: {
    apiKey: {
      base: process.env.BASE_BLOCK_EXPLORER_API_KEY,
      "base-testnet": process.env.BASE_TESTNET_BLOCK_EXPLORER_API_KEY,
    },
    customChains: [
      {
        network: "base-testnet",
        chainId: parseInt(process.env.BASE_TESTNET_CHAIN_ID),
        urls: {
          apiURL: process.env.BASE_TESTNET_BLOCK_EXPLORER_API_URL,
          browserURL: process.env.BASE_TESTNET_BLOCK_EXPLORER_URL,
        },
      },
      {
        network: "base",
        chainId: parseInt(process.env.BASE_CHAIN_ID),
        urls: {
          apiURL: process.env.BASE_BLOCK_EXPLORER_API_URL,
          browserURL: process.env.BASE_BLOCK_EXPLORER_URL,
        },
      },
    ],
  },
};
