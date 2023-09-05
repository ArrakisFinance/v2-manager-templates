import hre, { ethers, getNamedAccounts } from "hardhat";

const chainLinkOracle = "0x654B32A1230A78cE2FeB4CC42952dC89C5f482C1";

const token0 = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
const token1 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const priceFeed = "0x30496218Ad394c677092dAbf9Ab1CF8406C588aB";
const sequencerUpTimeFeed = "0x0000000000000000000000000000000000000000";
const outdated = 86400;
const isPriceFeedInversed = false;

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
    address: chainLinkOracle,
    constructorArguments: [
      token0Decimals,
      token1Decimals,
      priceFeed,
      sequencerUpTimeFeed,
      outdated,
      isPriceFeedInversed,
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
