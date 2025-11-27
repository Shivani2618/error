const { ethers } = require("hardhat");

async function main() {
  const MetaMintStudio = await ethers.getContractFactory("MetaMintStudio");
  const metaMintStudio = await MetaMintStudio.deploy();

  await metaMintStudio.deployed();

  console.log("MetaMintStudio contract deployed to:", metaMintStudio.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
