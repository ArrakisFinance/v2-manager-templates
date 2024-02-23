// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../utils/TestWrapper.sol";
import "forge-std/Vm.sol";

import "../../contracts/oracles/WrappedFeedSTETH.sol";
import {IWstETH} from "../../contracts/interfaces/IWstETH.sol";
import {
    AggregatorV3Interface
} from "../../contracts/interfaces/AggregatorV3Interface.sol";
import "../mocks/WrappedFeedHelper.sol";

// import {
//     ChainLinkOraclePivot
// } from "../../contracts/oracles/ChainLinkOraclePivot.sol";

contract WrappedFeedTest is TestWrapper {
    WrappedFeedSTETH public oracle;
    IWstETH public wstETH;
    AggregatorV3Interface public priceFeed;

    function setUp() public {
        _reset(vm.envString("ETH_RPC_URL"), vm.envUint("ETH_BLOCK_NUMBER"));

        priceFeed = AggregatorV3Interface(
            0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8
        ); // STETH / USD
        wstETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    }

    function testOracleWSTETHUSDCCreationWithAddressZeroOracle() public {
        vm.expectRevert(abi.encodeWithSelector(AddressZero.selector));

        new WrappedFeedSTETH(AggregatorV3Interface(address(0)), wstETH, false);

        vm.expectRevert(abi.encodeWithSelector(AddressZero.selector));

        new WrappedFeedSTETH(priceFeed, IWstETH(address(0)), false);
    }

    function testOracleWSTETHUSDCWhenGetStETHByWstETHFailed() public {
        WstETHMock wstETHMock = new WstETHMock();

        oracle = new WrappedFeedSTETH(priceFeed, wstETHMock, false);

        vm.expectRevert(
            abi.encodeWithSelector(GetStETHByWstETHCallFailed.selector)
        );

        oracle.latestRoundData();
    }

    function testOracleWSTETHUSDCWhenGetWstETHByStETHFailed() public {
        WstETHMock wstETHMock = new WstETHMock();

        oracle = new WrappedFeedSTETH(priceFeed, wstETHMock, true);

        vm.expectRevert(
            abi.encodeWithSelector(GetWstETHByStETHCallFailed.selector)
        );

        oracle.latestRoundData();
    }

    /// @dev full setup in mainnet network.
    // function testPrice() public {
    //     oracle = new WrappedFeedSTETH(priceFeed, wstETH, false);

    //     (, int256 answer, , , ) = oracle.latestRoundData();

    //     (, int256 answerPriceFeed, , , ) = priceFeed.latestRoundData();
    //     console.logInt(answerPriceFeed);
    //     console.logInt(answer);

    //     /// @dev token0 is wstETH and token1 is USDC

    //     uint8 token0Decimals = 18;
    //     uint8 token1Decimals = 6;
    //     /// @dev mainnet address.
    //     address priceFeedA = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // USDC / USD
    //     address priceFeedB = address(oracle); // WSTETH / USD
    //     address sequencerUptimeFeed = address(0);
    //     uint256 outdatedA = 86400;
    //     uint256 outdatedB = 86400;
    //     bool ispriceFeedAInversed = false;
    //     bool ispriceFeedBInversed = true;

    //     ChainLinkOraclePivot oraclePivot = new ChainLinkOraclePivot(
    //         token0Decimals,
    //         token1Decimals,
    //         priceFeedA,
    //         priceFeedB,
    //         sequencerUptimeFeed,
    //         outdatedA,
    //         outdatedB,
    //         ispriceFeedAInversed,
    //         ispriceFeedBInversed
    //     );

    //     console.logUint(oraclePivot.getPrice0());
    //     console.logUint(oraclePivot.getPrice1());
    // }
}
