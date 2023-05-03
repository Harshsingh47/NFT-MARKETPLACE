const { ethers } = require("hardhat");

async function main() {
    const NFTFACTORY = await ethers.getContractFactory("NFTFactory");
    
    // Start deployment, returning a promise that resolves to a contract object
    const NFT_Contract = await NFTFACTORY.deploy();   
    console.log("NFTFACTORY contract deployed to address:", NFT_Contract.address);

    const NFTMarketplace = await ethers.getContractFactory("NFTMarketplace")
    const Marketplace_Contract = await NFTMarketplace.deploy();   
    // const receipt = await Marketplace_Contract.wait()
    // console.log(Marketplace_Contract.log)
    console.log("NFTMarketplace Contract deployed to address:", Marketplace_Contract.address);
 }
 
 main()
   .then(() => process.exit(0))
   .catch(error => {
     console.error(error);
     process.exit(1);
   });