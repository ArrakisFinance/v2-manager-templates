import hre, { ethers, getNamedAccounts } from "hardhat";

const chainLinkOraclePivot = "0x1DDDEc1cE817bc771b6339E9DE97ae81B3bE0da4";

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

  await hre.run("verify:verify", {
    address: chainLinkOraclePivot,
    constructorArguments: [
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
    // other args
  });
}

main()
  .then(() => process.exit(0))
  .catch(async (error) => {
    console.error(error);
    process.exit(1);
  });
