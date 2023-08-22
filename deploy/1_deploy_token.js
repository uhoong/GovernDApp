const hre = require("hardhat");

async function deployCT(erc1155URI) {
    const CT = await hre.ethers.getContractFactory("ConditionalTokens");

    const ct = await CT.deploy(erc1155URI);

    await ct.waitForDeployment();

    console.log(
        `ConditionalTokens deployed to ${await ct.getAddress()}`
    );

    return ct.getAddress();
}

async function deployCTHelper() {
    const CTHelper = await hre.ethers.getContractFactory("CTHelpers");

    const ctHelper = await CTHelper.deploy();

    await ctHelper.waitForDeployment();

    console.log(
        `CTHelper deployed to ${await ctHelper.getAddress()}`
    );

    return ctHelper.getAddress();
}

async function deployGovernToken(account) {
    const GovernToken = await hre.ethers.getContractFactory("GovernToken");

    const governToken = await GovernToken.deploy(account);

    await governToken.waitForDeployment();

    console.log(
        `GovernToken deployed to ${await governToken.getAddress()}`
    );

    return governToken.getAddress();
}

async function deployTokenPowerStrategy(tokenAddr, lockTimeLimit) {
    const TokenPower = await hre.ethers.getContractFactory("TimeTokenPower");

    const tokenPower = await TokenPower.deploy(tokenAddr, lockTimeLimit);

    await tokenPower.waitForDeployment();

    console.log(
        `TokenPower deployed to ${await tokenPower.getAddress()}`
    );

    return tokenPower.getAddress();
}

module.exports = {
    deployCT,
    deployCTHelper,
    deployGovernToken,
    deployTokenPowerStrategy,
}