import hre, { ethers, deployments, getNamedAccounts } from "hardhat";

const token0 = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
const token1 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const priceFeed = "0x30496218Ad394c677092dAbf9Ab1CF8406C588aB";
const sequencerUpTimeFeed = "0x0000000000000000000000000000000000000000";
const outdated = 86400;
const isPriceFeedInversed = false;

async function main() {
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const token0Decimals = await (
    await ethers.getContractAt(
      ["function decimals() external view returns (uint8)"],
      token0,
      deployer
    )
  ).decimals();
  const token1Decimals = await (
    await ethers.getContractAt(
      ["function decimals() external view returns (uint8)"],
      token1,
      deployer
    )
  ).decimals();

  const deployResult = await deploy("ChainLinkOracle", {
    from: deployer,
    args: [
      token0Decimals,
      token1Decimals,
      priceFeed,
      sequencerUpTimeFeed,
      outdated,
      isPriceFeedInversed,
    ],
    log: hre.network.name !== "hardhat" ? true : false,
    gasPrice: "16000000000",
  });

  console.log(`contract address ${deployResult.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
