// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IWstETH} from "../interfaces/IWstETH.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/FullMath.sol";

contract OracleWSTETHUSDC is IOracleWrapper {
    IOracleWrapper public immutable stETHUSDCOracle;
    IWstETH public immutable wstETH;

    constructor(IOracleWrapper stETHUSDCOracle_, IWstETH wstETH_) {
        stETHUSDCOracle = stETHUSDCOracle_;
        wstETH = wstETH_;
    }

    function getPrice0() external view returns (uint256 price0) {
        uint256 denominator = 1e18;
        return
            FullMath.mulDiv(
                stETHUSDCOracle.getPrice0(),
                wstETH.getStETHByWstETH(denominator),
                denominator
            );
    }

    function getPrice1() external view returns (uint256 price1) {
        uint256 denominator = 1e18;
        return
            FullMath.mulDiv(
                stETHUSDCOracle.getPrice1(),
                wstETH.getWstETHByStETH(denominator),
                denominator
            );
    }
}
