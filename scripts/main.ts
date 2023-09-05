import { ethers } from "hardhat";

import { deploy } from "../deploy/deploy";

import { mineUpTo } from "@nomicfoundation/hardhat-network-helpers";

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

    let tx;
    let txReceipt;
    let tokenId;

    // 合约部署
    console.log("部署合约");
    const info = await deploy(lockTimeLimit, delay, gracePeriod, minimumDelay, maximumDelay, propositionThreshold, stakingDelay, stakeThreshold);
    const target = await ethers.deployContract("Target");
    console.log(`Target deployed to ${await target.getAddress()}`);
    console.log("部署完成");

    let token = await ethers.getContractAt("GovernToken", info.tokenAddr, admin);
    let governance = await ethers.getContractAt("Governance", info.governanceAddr);
    let factory = await ethers.getContractAt("VoteFactory",info.factoryAddr);
    let strategy = await ethers.getContractAt("TimeTokenPower",info.strategyAddr);
    tx = await governance.authorizeExecutors([info.executorAddr]);
    await tx.wait();

    // 创建提案
    // // signer1 获得 4000e18 代币，signer2 获得 2000e18 代币
    console.log("委托票权")
    token.transfer(signer1.address, ethers.parseEther("9000"));
    token.transfer(signer2.address, ethers.parseEther("9000"));
    // // 质押产生投票权
    console.log("质押产生投票权");
    let tempStrategy = await strategy.connect(signer1);
    let tempToken = await token.connect(signer1);
    tx = await tempToken.approve(strategy.target,ethers.parseEther("2000"));
    await tx.wait();
    tx = await tempStrategy.stake(ethers.parseEther("2000"));
    await tx.wait();
    tokenId = await strategy.tokenIds(signer1.address);
    tx = await tempStrategy.lock(tokenId-1n,5000,signer1.address);
    await tx.wait();
    console.log(`signer1 的币权为：${await strategy.getCurrentVotingPower(signer1.address)}`);

    tempStrategy = await strategy.connect(signer2);
    tempToken = await token.connect(signer2);
    tx = await tempToken.approve(strategy.target,ethers.parseEther("1000"));
    await tx.wait();
    tx = await tempStrategy.stake(ethers.parseEther("1000"));
    await tx.wait();
    tokenId = await strategy.tokenIds(signer2.address);
    tx = await tempStrategy.lock(tokenId-1n,1000,signer2.address);
    await tx.wait();
    console.log(`signer1 的币权为：${await strategy.getCurrentVotingPower(signer2.address)}`);
    // // signer1 委托给自己，signer2 委托和 signer1
    tempToken = await token.connect(signer1);
    tx = await tempToken.delegate(signer1.address);
    await tx.wait();
    tempToken = await token.connect(signer2);
    tx = await tempToken.delegate(signer1.address);
    await tx.wait();
    console.log(`signer1 的提议权为：${await token.getCurrentVotingPower(signer1.address)}`);
    // // signer1 调用函数创建提案，提案的目标是改变 Target 合约中的值
    let txData = await target.setTargetWithValue.populateTransaction(20);
    let tempGovernance = governance.connect(signer1);
    tx = await tempGovernance.create(0,info.executorAddr,[await target.getAddress()],[0],[""],[txData.data],[false],ipfsHash);
    txReceipt = await tx.wait();

    let event = await tempGovernance.queryFilter(tempGovernance.getEvent("ProposalCreated"),await ethers.provider.getBlockNumber()-5,await ethers.provider.getBlockNumber());
    let newProposalId = event[event.length-1].args[0];
    let newProposalInfo = await tempGovernance.getProposalById(newProposalId);
    console.log("提案创建完毕，信息如下");
    console.log(`提案信息：${newProposalInfo}`);
    console.log(`当前区块高度：${await ethers.provider.getBlockNumber()}`);
    
    // 创建投票合约
    // // 挖矿至指定高度
    await mineUpTo(newProposalInfo.startBlock);
    console.log(`挖矿至高度为：${await ethers.provider.getBlockNumber()}`);
    tx = await tempGovernance.createReview(newProposalId);
    await tx.wait();
    let voteAddr = await factory.getContractAddress(governance.target,newProposalId);
    console.log(`投票创建完成，合约地址为：${voteAddr}`);
    let vote = await ethers.getContractAt("TimeTokenVote",voteAddr);

    // 投票
    let tempVote =  vote.connect(signer1);
    tx = await tempVote.castVote(true);
    await tx.wait();
    tempVote =  vote.connect(signer2);
    tx = await tempVote.castVote(false);
    await tx.wait();

    // 快进到投票结束
    await mineUpTo(newProposalInfo.endBlock);

    // 提案入队
    tx = await governance.queue(newProposalId);
    await tx.wait();
    newProposalInfo = await governance.getProposalById(newProposalId);
    console.log(`提案信息：${newProposalInfo}`);

    // 提案执行
    await mineUpTo(newProposalInfo.executionBlock);
    tx = await governance.execute(newProposalId);
    await tx.wait();

    newProposalInfo = await governance.getProposalById(newProposalId);
    console.log(`提案信息：${newProposalInfo}`);

    // 
    console.log(await target.value())
}

main()
