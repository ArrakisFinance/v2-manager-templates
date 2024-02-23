import hre, { deployments, getNamedAccounts } from "hardhat";

const priceFeed = "0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8";
const wstETH = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
const isPriceFeedInversed = false;

async function main() {
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const deployResult = await deploy("WrappedFeedSTETH", {
    from: deployer,
    args: [priceFeed, wstETH, isPriceFeedInversed],
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
