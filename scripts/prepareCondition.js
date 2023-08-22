const hre = require("hardhat");

const ctAddr = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

async function prepareCondition(){
    const ct = await hre.ethers.getContractAt("ConditionalTokens","0x5FbDB2315678afecb367f032d93F642f64180aa3");
    const temp = await ct.prepareCondition.populateTransaction("0x5FbDB2315678afecb367f032d93F642f64180aa3","0x5FbDB2315678afecb367f032d93F642f64180aa3642f64180aa3642f64180aa3",3);
    console.log(temp)
}

prepareCondition()