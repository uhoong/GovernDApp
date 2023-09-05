import { ethers } from "hardhat";

import { deploy } from "../deploy/deploy";

async function main() {
    const lockTimeLimit = 50000;

    const delay = 50;
    const gracePeriod = 50
    const minimumDelay = 50
    const maximumDelay = 50
    const propositionThreshold = 5  //投票需要掌握5000e18的代币

    const stakingDelay = 50;       //提案创建后，有50个区块的时间用于质押和准备市场
    const stakeThreshold = 50;

    const ipfsHash = "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B11C251C2007B11C251C2007B1";

    const [admin, signer1, signer2, signer3, signer4, signer5, signer6] = await ethers.getSigners();

    console.log("部署合约");
    const info = await deploy(lockTimeLimit, delay, gracePeriod, minimumDelay, maximumDelay, propositionThreshold, stakingDelay, stakeThreshold);
    const target = await ethers.deployContract("Target");
    console.log(`Target deployed to ${await target.getAddress()}`);
    console.log("部署完成");
}

main()