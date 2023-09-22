import { ethers } from "hardhat";

import { deploy } from "../deploy/deploy";

const conditionalTokensAddr = "0x6Bc8a795EAD1A713cDF69B78cdd7aFa810e66212";
const ctHelperAddr = "0x68Bf42Ee4c703c4B285e701F1d18d488fc384419";
const governTokenAddr = "0x483EaEb6614E534f4dC4B89081b32E74111a637a";
const tokenPowerAddr = "0xA391C1CDf022B934359601b22Da181109bB10D37";
const factoryAddr = "0x0818af0234209C87d3aB822C6D3c946fedE09c0B";
const reviewAddr = "0x6A9886E69922B2CcC8b9f2BfCcF953C12a9a0e74";
const governanceAddr = "0x86EaDE0E297f83568A44056A87e8FB2e75e51df2";
const executorAddr = "0x2c74158B46b891c57A24e190CA0ccBDeDA1a87C7";
const TargetAddr = "0x11FDA58E1d06c2D2F9C243738FF6B0a3b25fD35A";

const userAddr = "0x643AC6aFeFdC7E9E66648262C67247e1166946f9";
const userWallet = new ethers.Wallet("6d11059e1d517f6880f8c8bbdc7ba81ba407226708cd21507b9b854a4ce5b18d", ethers.provider)

const ipfsHash = "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B11C251C2007B11C251C2007B1";

async function deployAllContract() {
    const lockTimeLimit = 50000;

    const delay = 50;
    const gracePeriod = 50
    const minimumDelay = 50
    const maximumDelay = 50
    const propositionThreshold = 5  //投票需要掌握5000e18的代币

    const stakingDelay = 50;       //提案创建后，有50个区块的时间用于质押和准备市场
    const stakeThreshold = 50;


    const [admin, signer1, signer2, signer3, signer4, signer5, signer6] = await ethers.getSigners();

    console.log("部署合约");
    const info = await deploy(lockTimeLimit, delay, gracePeriod, minimumDelay, maximumDelay, propositionThreshold, stakingDelay, stakeThreshold);
    const target = await ethers.deployContract("Target");
    console.log(`Target deployed to ${await target.getAddress()}`);
    console.log("部署完成");
}

async function getContract() {
    const conditionalTokens = await ethers.getContractAt("ConditionalTokens", conditionalTokensAddr);
    // const ctHelper = await ethers.getContractAt("")
    const governToken = await ethers.getContractAt("GovernToken", governTokenAddr)
    const tokenPower = await ethers.getContractAt("TimeTokenPower", tokenPowerAddr)
    const factory = await ethers.getContractAt("VoteFactory", factoryAddr)
    const review = await ethers.getContractAt("Review", reviewAddr)
    const governance = await ethers.getContractAt("Governance", governanceAddr)
    const executor = await ethers.getContractAt("Executor", executorAddr)
    const target = await ethers.getContractAt("Target", TargetAddr);
    return { conditionalTokens, governToken, tokenPower, factory, review, governance, executor, target }
}

async function authorizeExecutors() {
    let tx;
    const { governance } = await getContract();
    tx = await governance.authorizeExecutors([executorAddr]);
    await tx.wait();
}

async function suite() {
    const {conditionalTokens, governToken, tokenPower, factory, review, governance, executor, target} = await getContract();
    await authorizeExecutors();
    await transfer();
    await tokenDelegate();
    await createProposal();
    await createProposal();
    await createProposal();
    await stakeAndLockForPower();
}


async function balance() {
    const { governToken } = await getContract();
    const [admin, signer1] = await ethers.getSigners();
    console.log(ethers.formatEther(await governToken.balanceOf(userAddr)))
}

async function transfer() {
    const amount = ethers.parseEther("9000");
    const { governToken } = await getContract();
    const [admin, signer1] = await ethers.getSigners();
    const tx = await governToken.transfer(userAddr, amount);
    const receipt = await tx.wait();
}

async function tokenDelegate() {
    let tx;
    const { governToken } = await getContract();
    const tempToken = governToken.connect(userWallet);
    tx = await tempToken.delegate(userWallet.address);
    await tx.wait();
}

async function approve() {
    const { governToken } = await getContract();
    const tempToken = governToken.connect(userWallet);
    const tx = await tempToken.approve(tokenPowerAddr, ethers.parseEther("300"));
    const receipt = await tx.wait();
}

async function stake() {
    const { tokenPower } = await getContract();
    const tempTokenPower = tokenPower.connect(userWallet);
    const tx = await tempTokenPower.stake(ethers.parseEther("300"));
    const receipt = await tx.wait();
}

async function stakeAndLockForPower() {
    let tx;
    let amount = ethers.parseEther("400");
    let lockTime = 5000n;
    const { governToken, tokenPower } = await getContract();
    let tempPower = await tokenPower.connect(userWallet);
    let tempToken = await governToken.connect(userWallet);
    tx = await tempToken.approve(tempPower.target, amount);
    await tx.wait();
    tx = await tempPower.stake(amount);
    await tx.wait();
    let tokenId = await tempPower.tokenIds(userWallet.address);
    tx = await tempPower.lock(tokenId - 1n, lockTime, userWallet.address);
    await tx.wait();
}

async function createProposal() {
    let tx;
    const { governance,target } = await getContract();
    const tempGovernance = governance.connect(userWallet);
    let txData = await target.setTargetWithValue.populateTransaction(20);
    tx = await tempGovernance.create(0, executorAddr, [TargetAddr], [0], [""], [txData.data], [false], ipfsHash);
}

async function getProposalById() {
    let tx;
    const { governance,target } = await getContract();
    const tempGovernance = governance.connect(userWallet);
    console.log(await tempGovernance.getProposalById(1));
}

async function getImplementationAddr() {
    let tx;
    const { factory } = await getContract();
    const implementationAddr = await factory.timeTokenVoteImplementation();
    console.log(implementationAddr);
}

async function mineUpTo(height:number) {
    const { governToken } = await getContract();
    let i = await ethers.provider.getBlockNumber();
    while(i<height){
        await governToken.approve(userAddr,1);
        i++;
    }
}

async function chainControl() {
    console.log(await ethers.provider.getBlockNumber());
    await mineUpTo(1821634);
    console.log(await ethers.provider.getBlockNumber());
}

async function test() {
    const { governance,tokenPower,target } = await getContract();
    let proposalState = (await tokenPower.getCurrentVotingPower.populateTransaction(userAddr)).data;
    console.log(proposalState);
}

chainControl();