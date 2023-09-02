// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {IOracleWrapper} from "../../contracts/interfaces/IOracleWrapper.sol";
import {IWstETH} from "../../contracts/interfaces/IWstETH.sol";

contract ChainLinkOraclePivotMock is IOracleWrapper {
    function getPrice0() external pure returns (uint256) {
        revert();
    }

    function getPrice1() external pure returns (uint256) {
        revert();
    }
}

contract WstETHMock is IWstETH {
    function getStETHByWstETH(uint256) external pure returns (uint256) {
        revert();
    }

    function getWstETHByStETH(uint256) external pure returns (uint256) {
        revert();
    }
}
