import { AddressLike } from "ethers";
import hre from "hardhat";

export async function deployExecutor(adminAddr, delay, gracePeriod, minimumDelay, maximumDelay, tokenAddr, propositionThreshold) {
    const Executor = await hre.ethers.getContractFactory("Executor");

    const executor = await Executor.deploy(adminAddr, delay, gracePeriod, minimumDelay, maximumDelay, tokenAddr, propositionThreshold);

    await executor.waitForDeployment();

    console.log(
        `Executor deployed to ${await executor.getAddress()}`
    );

    return executor.getAddress();
}

export async function deployReview(factoryAddr, ctAddr, oracleAddr) {
    const accounts = await hre.ethers.getSigners()
    const admin = accounts[0];

    const Review = await hre.ethers.getContractFactory("Review");

    const review = await Review.deploy(factoryAddr, ctAddr, oracleAddr);

    await review.waitForDeployment();

    console.log(
        `Review deployed to ${await review.getAddress()}`
    );

    return review.getAddress();
}

export async function deployGovernance(strategyAddr, reviewAddr, tokenAddr, stakingDelay, stakeThreshold, executors) {
    const Governance = await hre.ethers.getContractFactory("Governance");

    const governance = await Governance.deploy(strategyAddr, reviewAddr, tokenAddr, stakingDelay, stakeThreshold, executors);

    await governance.waitForDeployment();

    console.log(
        `Governance deployed to ${await governance.getAddress()}`
    );

    return governance.getAddress();
}

// module.exports = {
//     deployExecutor,
//     deployReview,
//     deployGovernance,
// }