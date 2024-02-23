import hre, { deployments, getNamedAccounts } from "hardhat";

const priceFeed = "0x19219BC90F48DeE4d5cF202E09c438FAacFd8Bea";
const token = "0x9Ba021B0a9b958B5E75cE9f6dff97C7eE52cb3E6";
const isPriceFeedInversed = false;

async function main() {
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const deployResult = await deploy("WrappedFeedPXETH", {
    from: deployer,
    args: [priceFeed, token, isPriceFeedInversed],
    log: hre.network.name !== "hardhat" ? true : false,
    gasPrice: "12000000000",
  });

  console.log(`contract address ${deployResult.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
