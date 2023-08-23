import '@nomicfoundation/hardhat-toolbox'
import '@typechain/hardhat'
import '@nomicfoundation/hardhat-ethers'
import "@nomiclabs/hardhat-ethers"
import '@nomicfoundation/hardhat-chai-matchers'

/** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
export default {
    solidity: {
        version: "0.8.19",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000,
            },
        },
    },
    networks: {
        localhost: {
            url: "http://127.0.0.1:8545/",
        }
    },
    typechain: {
        target: 'ethers-v6',
        alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
        externalArtifacts: ['externalArtifacts/*.json'], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
        dontOverrideCompile: false // defaults to false
    },
};
