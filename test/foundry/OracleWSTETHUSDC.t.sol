// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../utils/TestWrapper.sol";
import "forge-std/Vm.sol";

import "../../contracts/oracles/OracleWSTETHUSDC.sol";
import {
    ChainLinkOraclePivot
} from "../../contracts/oracles/ChainLinkOraclePivot.sol";
import {IWstETH} from "../../contracts/interfaces/IWstETH.sol";
import "../mocks/OracleWSTETHUSDCHelper.sol";

contract OracleWSTETHUSDCTest is TestWrapper {
    // OracleWSTETHUSDC public oracle;
    ChainLinkOraclePivot public stethUSDCOracle;
    IWstETH public wstETH;

    function setUp() public {
        _reset(vm.envString("ETH_RPC_URL"), vm.envUint("ETH_BLOCK_NUMBER"));

        /// @dev token0 is USDC and token1 is stETH
        uint8 token0Decimals = 6;
        uint8 token1Decimals = 18;
        /// @dev mainnet address.
        address priceFeedA = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8; // STETH / USD
        address priceFeedB = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // USDC / USD
        address sequencerUptimeFeed = address(0);
        uint256 outdatedA = 3600;
        uint256 outdatedB = 86400;
        bool ispriceFeedAInversed = false;
        bool ispriceFeedBInversed = true;

        stethUSDCOracle = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeedA,
            priceFeedB,
            sequencerUptimeFeed,
            outdatedA,
            outdatedB,
            ispriceFeedAInversed,
            ispriceFeedBInversed
        );
        wstETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

        // oracle = new OracleWSTETHUSDC(stethUSDCOracle, wstETH);
    }

    function testOracleWSTETHUSDCCreationWithAddressZeroOracle() public {
        vm.expectRevert(abi.encodeWithSelector(AddressZero.selector));

        new OracleWSTETHUSDC(ChainLinkOraclePivot(address(0)), wstETH);

        vm.expectRevert(abi.encodeWithSelector(AddressZero.selector));

        new OracleWSTETHUSDC(stethUSDCOracle, IWstETH(address(0)));
    }

    function testOracleWSTETHUSDCWhenGetPrice0Failed() public {
        ChainLinkOraclePivotMock chainlinkOracleMock = new ChainLinkOraclePivotMock();

        OracleWSTETHUSDC oracle = new OracleWSTETHUSDC(
            chainlinkOracleMock,
            wstETH
        );

        vm.expectRevert(
            abi.encodeWithSelector(OracleWrapperPrice0CallFailed.selector)
        );

        oracle.getPrice0();
    }

    function testOracleWSTETHUSDCWhenGetPrice1Failed() public {
        ChainLinkOraclePivotMock chainlinkOracleMock = new ChainLinkOraclePivotMock();

        OracleWSTETHUSDC oracle = new OracleWSTETHUSDC(
            chainlinkOracleMock,
            wstETH
        );

        vm.expectRevert(
            abi.encodeWithSelector(OracleWrapperPrice1CallFailed.selector)
        );

        oracle.getPrice1();
    }

    function testOracleWSTETHUSDCWhenGetStETHByWstETHFailed() public {
        WstETHMock wstETHMock = new WstETHMock();

        OracleWSTETHUSDC oracle = new OracleWSTETHUSDC(
            stethUSDCOracle,
            wstETHMock
        );

        vm.expectRevert(
            abi.encodeWithSelector(GetStETHByWstETHCallFailed.selector)
        );

        oracle.getPrice0();
    }

    function testOracleWSTETHUSDCWhenGetWstETHByStETHFailed() public {
        WstETHMock wstETHMock = new WstETHMock();

        OracleWSTETHUSDC oracle = new OracleWSTETHUSDC(
            stethUSDCOracle,
            wstETHMock
        );

        vm.expectRevert(
            abi.encodeWithSelector(GetWstETHByStETHCallFailed.selector)
        );

        oracle.getPrice1();
    }

    // function testPrice0() public {
    //     console.logUint(stethUSDCOracle.getPrice0());
    //     console.logUint(oracle.getPrice0());
    // }

    // function testPrice1() public {
    //     console.logUint(stethUSDCOracle.getPrice1());
    //     console.logUint(oracle.getPrice1());
    // }
}
