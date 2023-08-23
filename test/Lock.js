const {
    time,
    mineUpTo,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

const { deploy } = require("../deploy/deploy");
const { ethers } = require("hardhat");
const hre = require("hardhat");

describe("Governance",function () {
    // const {lockTimeLimit, delay, gracePeriod, minimumDelay, maximumDelay, propositionThreshold, stakingDelay, stakeThreshold, ctAddr, ctHelperAddr, tokenAddr, strategyAddr, factoryAddr, executorAddr, reviewAddr, governanceAddr} = deploy().then(value=>{
    const info = deploy().then(value=>{
        return value;
    });

    it("asdf",async function(){
        expect((await info).lockTimeLimit).to.equal(50n);
    })

    // async function deployFixture() {
    //     const ct = await ethers.getContractAt("ConditionalTokens",ctAddr);
    //     const ctHelper = await ethers.getContractAt("CTHelpers",ctHelperAddr);
    //     const token = await ethers.getContractAt("GovernToken",tokenAddr);
    //     const strategy = await ethers.getContractAt("TimeTokenPower",strategyAddr);
    //     const factory = await ethers.getContractAt("VoteFactory",factoryAddr);
    //     const executor = await ethers.getContractAt("Executor",executorAddr);
    //     const review = await ethers.getContractAt("Review",reviewAddr);
    //     const governance = await ethers.getContractAt("Governance",governanceAddr);
    //     return {lockTimeLimit, delay, gracePeriod, minimumDelay, maximumDelay, propositionThreshold, stakingDelay, stakeThreshold, ct, ctHelper, token, strategy, factory, executor, review, governance}
    // }

    // describe("Token",function(){
    //     it("Delegate",async function(){
    //         const [admin,singer1,signer2] = await ethers.getSigners();
    //         // const {token} = await deployFixture();
    //         const tx = await token.delegate(admin.address);
    //         const txReceipt = await tx.wait();
    //         expect((await token.checkpoints(admin.address,0))[1]).to.equal(10000000000000000000000000n);
    //     })

        // it("Token Power Check",async function(){
        //     const [admin,singer1,signer2] = await ethers.getSigners();
        //     const governance = await ethers.getContractAt("Governance",governanceAddr);
        //     const tx = await governance.create(0,await executor.getAddress(),["0x79E8AB29Ff79805025c9462a2f2F12e9A496f81d"],[0],["0x3454231243"],["0x3454231243"],[false],"0xc7cDb7A2E5dDa1B7A0E792Fe1ef08ED20A6F56D48ED20A6F56D48ED20A6F56D4");
        //     const txReceipt = await tx.wait();
        //     console.log(txReceipt);
        // })
    // })

    // describe("Create Proposal",function(){
        
    // })


})

// describe("Lock", function () {
//     // We define a fixture to reuse the same setup in every test.
//     // We use loadFixture to run this setup once, snapshot that state,
//     // and reset Hardhat Network to that snapshot in every test.
//     async function deployOneYearLockFixture() {
//         const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
//         const ONE_GWEI = 1_000_000_000;

//         const lockedAmount = ONE_GWEI;
//         const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

//         // Contracts are deployed using the first signer/account by default
//         const [owner, otherAccount] = await ethers.getSigners();

//         const Lock = await ethers.getContractFactory("Lock");
//         const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

//         return { lock, unlockTime, lockedAmount, owner, otherAccount };
//     }

//     describe("Deployment", function () {
//         it("Should set the right unlockTime", async function () {
//             const { lock, unlockTime } = await loadFixture(deployOneYearLockFixture);

//             expect(await lock.unlockTime()).to.equal(unlockTime);
//         });

//         it("Should set the right owner", async function () {
//             const { lock, owner } = await loadFixture(deployOneYearLockFixture);

//             expect(await lock.owner()).to.equal(owner.address);
//         });

//         it("Should receive and store the funds to lock", async function () {
//             const { lock, lockedAmount } = await loadFixture(
//                 deployOneYearLockFixture
//             );

//             expect(await ethers.provider.getBalance(lock.target)).to.equal(
//                 lockedAmount
//             );
//         });

//         it("Should fail if the unlockTime is not in the future", async function () {
//             // We don't use the fixture here because we want a different deployment
//             const latestTime = await time.latest();
//             const Lock = await ethers.getContractFactory("Lock");
//             await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
//                 "Unlock time should be in the future"
//             );
//         });
//     });

//     describe("Withdrawals", function () {
//         describe("Validations", function () {
//             it("Should revert with the right error if called too soon", async function () {
//                 const { lock } = await loadFixture(deployOneYearLockFixture);

//                 await expect(lock.withdraw()).to.be.revertedWith(
//                     "You can't withdraw yet"
//                 );
//             });

//             it("Should revert with the right error if called from another account", async function () {
//                 const { lock, unlockTime, otherAccount } = await loadFixture(
//                     deployOneYearLockFixture
//                 );

//                 // We can increase the time in Hardhat Network
//                 await time.increaseTo(unlockTime);

//                 // We use lock.connect() to send a transaction from another account
//                 await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
//                     "You aren't the owner"
//                 );
//             });

//             it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
//                 const { lock, unlockTime } = await loadFixture(
//                     deployOneYearLockFixture
//                 );

//                 // Transactions are sent using the first signer by default
//                 await time.increaseTo(unlockTime);

//                 await expect(lock.withdraw()).not.to.be.reverted;
//             });
//         });

//         describe("Events", function () {
//             it("Should emit an event on withdrawals", async function () {
//                 const { lock, unlockTime, lockedAmount } = await loadFixture(
//                     deployOneYearLockFixture
//                 );

//                 await time.increaseTo(unlockTime);

//                 await expect(lock.withdraw())
//                     .to.emit(lock, "Withdrawal")
//                     .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
//             });
//         });

//         describe("Transfers", function () {
//             it("Should transfer the funds to the owner", async function () {
//                 const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
//                     deployOneYearLockFixture
//                 );

//                 await time.increaseTo(unlockTime);

//                 await expect(lock.withdraw()).to.changeEtherBalances(
//                     [owner, lock],
//                     [lockedAmount, -lockedAmount]
//                 );
//             });
//         });
//     });
// });
