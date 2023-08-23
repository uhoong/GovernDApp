const hre = require("hardhat");
const { deployCT, deployCTHelper, deployGovernToken, deployTokenPowerStrategy } = require("../deploy/1_deploy_token.js");
const { deployFactory } = require("../deploy/2_deploy_factory.js");
const { deployExecutor, deployGovernance, deployReview } = require("../deploy/3_deploy_governance.js");

async function deploy() {
    const lockTimeLimit = 50;

    const delay = 50;
    const gracePeriod = 50
    const minimumDelay = 50
    const maximumDelay = 50
    const propositionThreshold = 50

    const stakingDelay = 50;
    const stakeThreshold = 50;

    const accounts = await hre.ethers.getSigners();
    const admin = accounts[0];

    const ctAddr = await deployCT("Pangu");
    const ctHelperAddr = await deployCTHelper();
    const tokenAddr = await deployGovernToken(admin.address);
    const strategyAddr = await deployTokenPowerStrategy(tokenAddr, lockTimeLimit);

    const factoryAddr = await deployFactory();

    const executorAddr = await deployExecutor(delay, gracePeriod, minimumDelay, maximumDelay, tokenAddr, propositionThreshold);
    const reviewAddr = await deployReview(factoryAddr, ctAddr, admin);
    const governanceAddr = await deployGovernance(strategyAddr, reviewAddr, tokenAddr, stakingDelay, stakeThreshold, [executorAddr]);
    
    return { lockTimeLimit, delay, gracePeriod, minimumDelay, maximumDelay, propositionThreshold, stakingDelay, stakeThreshold, ctAddr, ctHelperAddr, tokenAddr, strategyAddr, factoryAddr, executorAddr, reviewAddr, governanceAddr }
}


module.exports = {
    deploy,
}