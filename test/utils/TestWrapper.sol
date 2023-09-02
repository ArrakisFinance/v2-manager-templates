// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

contract TestWrapper is Test {
    constructor() {
        vm.createSelectFork(
            vm.envString("POL_RPC_URL"),
            vm.envUint("POL_BLOCK_NUMBER")
        );
    }

    function _reset(string memory url_, uint256 blockNumber) internal {
        vm.createSelectFork(url_, blockNumber);
    }
}
