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

contract OracleWSTETH is IOracleWrapper {
    /// @dev oracle should be stETH/Something
    IOracleWrapper public immutable oracle;
    IWstETH public immutable wstETH;
    bool internal immutable _isInversed;

    constructor(IOracleWrapper oracle_, IWstETH wstETH_, bool isInversed_) {
        if (address(oracle_) == address(0) || address(wstETH_) == address(0))
            revert AddressZero();
        oracle = oracle_;
        wstETH = wstETH_;
        _isInversed = isInversed_;
    }

    function getPrice0() external view returns (uint256) {
        if (_isInversed) return _getPrice1();
        return _getPrice0();
    }

    function getPrice1() external view returns (uint256) {
        if (_isInversed) return _getPrice0();
        return _getPrice1();
    }

    function _getPrice0() internal view returns (uint256) {
        uint256 denominator = 1e18;
        try oracle.getPrice0() returns (uint256 price0) {
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

    function _getPrice1() internal view returns (uint256) {
        uint256 denominator = 1e18;
        try oracle.getPrice1() returns (uint256 price1) {
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
