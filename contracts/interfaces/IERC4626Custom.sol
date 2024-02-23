// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

interface IERC4626Custom {
    function assetsPerShare() external view returns (uint256);
}
