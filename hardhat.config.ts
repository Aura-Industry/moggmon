import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const tempoMainnetRpcUrl =
  process.env.TEMPO_MAINNET_RPC_URL || "https://rpc.presto.tempo.xyz";
const tempoModeratoRpcUrl =
  process.env.TEMPO_MODERATO_RPC_URL || "https://rpc.moderato.tempo.xyz";
const tempoAndantinoRpcUrl =
  process.env.TEMPO_ANDANTINO_RPC_URL || "https://rpc.testnet.tempo.xyz";
const tempoPrivateKey =
  process.env.TEMPO_PRIVATE_KEY || process.env.PRIVATE_KEY;
const ethereumMainnetRpcUrl =
  process.env.ETHEREUM_MAINNET_RPC_URL ||
  process.env.ETH_MAINNET_RPC_URL ||
  process.env.MAINNET_RPC_URL ||
  "https://ethereum-rpc.publicnode.com";
const ethereumSepoliaRpcUrl =
  process.env.ETHEREUM_SEPOLIA_RPC_URL ||
  process.env.ETH_SEPOLIA_RPC_URL ||
  process.env.SEPOLIA_RPC_URL ||
  "https://ethereum-sepolia-rpc.publicnode.com";
const ethereumPrivateKey =
  process.env.ETHEREUM_PRIVATE_KEY ||
  process.env.ETH_PRIVATE_KEY ||
  process.env.PRIVATE_KEY;
const etherscanApiKey =
  process.env.ETHERSCAN_API_KEY ||
  process.env.ETHERSCAN_V2_API_KEY ||
  process.env.ETHEREUM_ETHERSCAN_API_KEY ||
  "";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
      metadata: {
        bytecodeHash: "none",
      },
      evmVersion: "cancun",
      viaIR: true,
    },
  },
  paths: {
    sources: "./v1/contracts",
    tests: "./v1/test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    "tempo-mainnet": {
      url: tempoMainnetRpcUrl,
      chainId: 4217,
      accounts: tempoPrivateKey ? [tempoPrivateKey] : [],
      timeout: 100000,
    },
    "tempo-moderato": {
      url: tempoModeratoRpcUrl,
      chainId: 42431,
      accounts: tempoPrivateKey ? [tempoPrivateKey] : [],
      timeout: 100000,
    },
    "tempo-andantino": {
      url: tempoAndantinoRpcUrl,
      chainId: 42429,
      accounts: tempoPrivateKey ? [tempoPrivateKey] : [],
      timeout: 100000,
    },
    "ethereum-mainnet": {
      url: ethereumMainnetRpcUrl,
      chainId: 1,
      accounts: ethereumPrivateKey ? [ethereumPrivateKey] : [],
      timeout: 100000,
    },
    "ethereum-sepolia": {
      url: ethereumSepoliaRpcUrl,
      chainId: 11155111,
      accounts: ethereumPrivateKey ? [ethereumPrivateKey] : [],
      timeout: 100000,
    },
  },
  etherscan: {
    apiKey: etherscanApiKey,
  },
};

export default config;
