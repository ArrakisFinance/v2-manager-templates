import hre from "hardhat";

const wrappedFeed = "0x99997Ffe9ac2223921D8C6D06724cDD87093d662";

const priceFeed = "0x41878779a388585509657CE5Fb95a80050502186";
const wstETH = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
const isPriceFeedInversed = false;

async function main() {
  await hre.run("verify:verify", {
    address: wrappedFeed,
    constructorArguments: [priceFeed, wstETH, isPriceFeedInversed],
    // other args
  });
}

main()
  .then(() => process.exit(0))
  .catch(async (error) => {
    console.error(error);
    process.exit(1);
  });
