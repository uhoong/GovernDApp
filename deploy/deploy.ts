// const hre = require("hardhat");
// const { deployCT, deployCTHelper, deployGovernToken, deployTokenPowerStrategy } = require("../deploy/1_deploy_token.js");
// const { deployFactory } = require("../deploy/2_deploy_factory.js");
// const { deployExecutor, deployGovernance, deployReview } = require("../deploy/3_deploy_governance.js");

import hre from "hardhat";
import { deployCT, deployCTHelper, deployGovernToken, deployTokenPowerStrategy } from "../deploy/1_deploy_token"
import { deployFactory } from "../deploy/2_deploy_factory"
import { deployExecutor, deployGovernance, deployReview } from "../deploy/3_deploy_governance"

export async function deploy(lockTimeLimit, delay, gracePeriod, minimumDelay, maximumDelay, propositionThreshold, stakingDelay, stakeThreshold) {
    const accounts = await hre.ethers.getSigners();
    const admin = accounts[0];

    const ctAddr = await deployCT("Pangu");
    const ctHelperAddr = await deployCTHelper();
    const tokenAddr = await deployGovernToken(admin.address);
    const strategyAddr = await deployTokenPowerStrategy(tokenAddr, lockTimeLimit);

    const factoryAddr = await deployFactory();

    const reviewAddr = await deployReview(factoryAddr, ctAddr, admin);
    const governanceAddr = await deployGovernance(strategyAddr, reviewAddr, tokenAddr, stakingDelay, stakeThreshold, []);
    const executorAddr = await deployExecutor(governanceAddr,delay, gracePeriod, minimumDelay, maximumDelay, tokenAddr, propositionThreshold);
    
    
    return { ctAddr, ctHelperAddr, tokenAddr, strategyAddr, factoryAddr, executorAddr, reviewAddr, governanceAddr }
}

// module.exports = {
//     deploy,
// }