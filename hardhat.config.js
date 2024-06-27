require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

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
    mumbai: {
      url: process.env.MUMBAI_RPC_URL,
      accounts: [privateKey],
      chainId: parseInt(process.env.MUMBAI_CHAIN_ID),
    },
    base: {
      url: process.env.BASE_RPC_URL,
      accounts: [privateKey],
      chainId: parseInt(process.env.BASE_CHAIN_ID),
      gasPrice: 2000,
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL,
      accounts: [privateKey],
      chainId: parseInt(process.env.POLYGON_CHAIN_ID),
      gasPrice: 150000000000,
    },
  },
  etherscan: {
    apiKey: {
      polygon: process.env.POLYGON_BLOCK_EXPLORER_API_KEY,
      polygonMumbai: process.env.MUMBAI_BLOCK_EXPLORER_API_KEY,
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
