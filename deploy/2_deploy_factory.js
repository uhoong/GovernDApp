const hre = require("hardhat");

async function deployFactory() {
    const Factory = await hre.ethers.getContractFactory("VoteFactory");

    const factory = await Factory.deploy();

    await factory.waitForDeployment();

    console.log(
        `Factory deployed to ${await factory.getAddress()}`
    );

    return factory.getAddress();
}

module.exports = {
    deployFactory,
}