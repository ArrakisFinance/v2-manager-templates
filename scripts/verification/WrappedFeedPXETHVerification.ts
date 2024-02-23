import hre from "hardhat";

// to set onced the wrappedFeedPXETH deployed.
const wrappedFeedPXETH = "";

const priceFeed = "0x19219BC90F48DeE4d5cF202E09c438FAacFd8Bea";
const token = "0x9Ba021B0a9b958B5E75cE9f6dff97C7eE52cb3E6";
const isPriceFeedInversed = false;

async function main() {
  await hre.run("verify:verify", {
    address: wrappedFeedPXETH,
    constructorArguments: [priceFeed, token, isPriceFeedInversed],
    // other args
  });
}

main()
  .then(() => process.exit(0))
  .catch(async (error) => {
    console.error(error);
    process.exit(1);
  });
