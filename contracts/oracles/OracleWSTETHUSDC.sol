// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IWstETH} from "../interfaces/IWstETH.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/FullMath.sol";

// #region errors.

error AddressZero();
error OracleWrapperPrice0CallFailed();
error OracleWrapperPrice1CallFailed();
error GetStETHByWstETHCallFailed();
error GetWstETHByStETHCallFailed();

// #endregion errors.

contract OracleWSTETHUSDC is IOracleWrapper {
    IOracleWrapper public immutable stETHUSDCOracle;
    IWstETH public immutable wstETH;

    constructor(IOracleWrapper stETHUSDCOracle_, IWstETH wstETH_) {
        if (
            address(stETHUSDCOracle_) == address(0) ||
            address(wstETH_) == address(0)
        ) revert AddressZero();
        stETHUSDCOracle = stETHUSDCOracle_;
        wstETH = wstETH_;
    }

    function getPrice0() external view returns (uint256) {
        uint256 denominator = 1e18;
        try stETHUSDCOracle.getPrice0() returns (uint256 price0) {
            try wstETH.getStETHByWstETH(denominator) returns (
                uint256 stETHAmounts
            ) {
                return FullMath.mulDiv(price0, stETHAmounts, denominator);
            } catch {
                revert GetStETHByWstETHCallFailed();
            }
        } catch {
            revert OracleWrapperPrice0CallFailed();
        }
    }

    function getPrice1() external view returns (uint256) {
        uint256 denominator = 1e18;
        try stETHUSDCOracle.getPrice1() returns (uint256 price1) {
            try wstETH.getWstETHByStETH(denominator) returns (
                uint256 wstETHAmounts
            ) {
                return FullMath.mulDiv(price1, wstETHAmounts, denominator);
            } catch {
                revert GetWstETHByStETHCallFailed();
            }
        } catch {
            revert OracleWrapperPrice1CallFailed();
        }
    }
}
