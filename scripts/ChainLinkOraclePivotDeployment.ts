import hre, { ethers, deployments, getNamedAccounts } from "hardhat";

const token0 = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
const token1 = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const priceFeedA = "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6";
const priceFeedB = "0x99997Ffe9ac2223921D8C6D06724cDD87093d662";
const sequencerUpTimeFeed = "0x0000000000000000000000000000000000000000";
const outdatedA = 86400;
const outdatedB = 3600;
const isPriceFeedAInversed = false;
const isPriceFeedBInversed = true;

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

  const deployResult = await deploy("ChainLinkOraclePivot", {
    from: deployer,
    args: [
      token0Decimals,
      token1Decimals,
      priceFeedA,
      priceFeedB,
      sequencerUpTimeFeed,
      outdatedA,
      outdatedB,
      isPriceFeedAInversed,
      isPriceFeedBInversed,
    ],
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
