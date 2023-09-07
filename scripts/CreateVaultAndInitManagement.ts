import hre, { ethers, getNamedAccounts } from "hardhat";
import { SimpleManager } from "../typechain";
import { getAddresses } from "../src/addresses";

const addresses = getAddresses(hre.network.name);
// #region vault creation
const feeTiers = [500];
const token0 = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
const token1 = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const owner = "";
const init0 = ethers.utils.parseUnits("1", 18);
const init1 = ethers.utils.parseUnits("2000", 6);
const routers: string[] = [];
// #endregion vault creation
// #region init management

const oracle = "0x1DDDEc1cE817bc771b6339E9DE97ae81B3bE0da4";
const maxDeviation = 100;
const maxSlippage = 100;
const managerFeeBPS = 200;
const coolDownPeriod = 60;

// #endregion init management
// Create the chainlink wrapped oracle before calling this script.

async function main() {
  const simpleManager: SimpleManager = (await hre.ethers.getContract(
    "SimpleManager"
  )) as SimpleManager;
  const { deployer } = await getNamedAccounts();

  const arrakisV2Factory = await ethers.getContractAt(
    "function deployVault((uint24[],address,address,address,uint256,uint256,address,address[]),bool) returns(address vault)",
    addresses.ArrakisV2Factory,
    deployer
  );

  /// @dev create a beacon proxy
  const receipt = await (
    await arrakisV2Factory.deployVault(
      {
        feeTiers,
        token0,
        token1,
        owner,
        init0,
        init1,
        manager: simpleManager.address,
        routers,
      },
      true,
      {
        gasPrice: "12000000000",
      }
    )
  ).wait();

  const event = receipt?.events?.find(
    (event: { event: string }) => event.event === "VaultCreated"
  );
  // eslint-disable-next-line no-unsafe-optional-chaining
  const result = event?.args;

  console.log(`vault address ${result?.vault}`);

  await simpleManager.initManagement(
    {
      vault: result?.vault,
      oracle,
      maxDeviation,
      maxSlippage,
      managerFeeBPS,
      coolDownPeriod,
    },
    {
      gasPrice: "12000000000",
    }
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
