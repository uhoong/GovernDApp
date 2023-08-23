import {ethers} from "hardhat";

import {deploy} from "../deploy/deploy";


async function main() {
    const lockTimeLimit = 50;

    const delay = 50;
    const gracePeriod = 50
    const minimumDelay = 50
    const maximumDelay = 50
    const propositionThreshold = 5  //投票需要掌握5000e18的代币

    const stakingDelay = 50;       //提案创建后，有50个区块的时间用于质押和准备市场
    const stakeThreshold = 50;

    const [admin,signer1,signer2,signer3,signer4,signer5,signer6] = await ethers.getSigners();

    const info = await deploy(lockTimeLimit, delay, gracePeriod, minimumDelay, maximumDelay, propositionThreshold, stakingDelay, stakeThreshold);


}

