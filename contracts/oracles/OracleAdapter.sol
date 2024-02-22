// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {IERC4626Custom} from "../interfaces/IERC4626Custom.sol";
import {IDecimals} from "../interfaces/IDecimals.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/FullMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// #region errors.

error AddressZero();
error GetAssetsPerShareFailed();

// #endregion errors.

contract OracleAdapter {
    AggregatorV3Interface public immutable priceFeed;
    address public immutable token;
    bool public immutable ispriceFeedInversed;

    constructor(
        AggregatorV3Interface priceFeed_,
        address token_,
        bool ispriceFeedInversed_
    ) {
        if (address(priceFeed_) == address(0) || token_ == address(0))
            revert AddressZero();
        priceFeed = priceFeed_;
        token = token_;
        ispriceFeedInversed = ispriceFeedInversed_;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed
            .latestRoundData();
        uint256 denominator = 10 ** IDecimals(token).decimals();
        uint256 price = SafeCast.toUint256(answer);

        try IERC4626Custom(token).assetsPerShare() returns (
            uint256 assetsPerShare
        ) {
            if (ispriceFeedInversed) {
                price = FullMath.mulDiv(price, denominator, assetsPerShare);
            } else {
                price = FullMath.mulDiv(price, assetsPerShare, denominator);
            }
        } catch {
            revert GetAssetsPerShareFailed();
        }

        answer = SafeCast.toInt256(price);
    }

    function decimals() external view returns (uint8) {
        return priceFeed.decimals();
    }
}
