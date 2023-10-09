// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {ChainLinkOraclePivot} from "./ChainLinkOraclePivot.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract ChainLinkOraclePivotFeed {
    ChainLinkOraclePivot public immutable oraclePivot;

    constructor(
        uint8 token0Decimals_,
        uint8 token1Decimals_,
        address priceFeedA_,
        address priceFeedB_,
        address sequencerUptimeFeed_,
        uint256 outdatedA_,
        uint256 outdatedB_,
        bool ispriceFeedAInversed_,
        bool ispriceFeedBInversed_
    ) {
        oraclePivot = new ChainLinkOraclePivot(
            token0Decimals_,
            token1Decimals_,
            priceFeedA_,
            priceFeedB_,
            sequencerUptimeFeed_,
            outdatedA_,
            outdatedB_,
            ispriceFeedAInversed_,
            ispriceFeedBInversed_
        );
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        uint256 outdatedA = oraclePivot.outdatedA();
        uint256 outdatedB = oraclePivot.outdatedB();

        updatedAt =
            block.timestamp - // solhint-disable-line not-rely-on-time
            (outdatedA > outdatedB ? outdatedB - 1 : outdatedA - 1);

        answer = SafeCast.toInt256(oraclePivot.getPrice0());
    }

    function decimals() external view returns (uint8) {
        return oraclePivot.token1Decimals();
    }
}
