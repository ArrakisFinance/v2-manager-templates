// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../utils/TestWrapper.sol";
import "forge-std/Vm.sol";
import {
    AggregatorV3Interface
} from "../../contracts/interfaces/AggregatorV3Interface.sol";
import {IERC4626Custom} from "../../contracts/interfaces/IERC4626Custom.sol";
import {WrappedFeedPXETH} from "../../contracts/oracles/WrappedFeedPXETH.sol";

contract WrappedFeedPXETHTest is TestWrapper {
    AggregatorV3Interface public constant apxETH_ETH =
        AggregatorV3Interface(0x19219BC90F48DeE4d5cF202E09c438FAacFd8Bea);
    address public constant apxETH = 0x9Ba021B0a9b958B5E75cE9f6dff97C7eE52cb3E6;
    bool public constant ispriceFeedInversed = false;

    WrappedFeedPXETH public oracleAdapter;

    function setUp() public {
        _reset(vm.envString("ETH_RPC_URL"), vm.envUint("ETH_BLOCK_NUMBER"));

        oracleAdapter = new WrappedFeedPXETH(
            apxETH_ETH,
            apxETH,
            ispriceFeedInversed
        );
    }

    // #region test latestRoundData.

    function testLatestRoundData() public {
        (, int256 answer, , , ) = oracleAdapter.latestRoundData();

        console.logString("pxETH/ETH price : ");
        console.logInt(answer);

        (, answer, , , ) = apxETH_ETH.latestRoundData();

        console.logString("apxETH/ETH price : ");
        console.logInt(answer);

        console.logString("pxETH/apxETH price : ");
        console.logUint(IERC4626Custom(apxETH).assetsPerShare());
    }

    // #endregion test latestRoundData.

    // #region test decimals.

    function testDecimals() public {
        console.logUint(apxETH_ETH.decimals());
        console.logUint(oracleAdapter.decimals());
    }

    // #endregion test decimals.
}
