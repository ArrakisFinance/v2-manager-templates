// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/FullMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title ChainLink Oracle wrapper
contract ChainLinkOracle is IOracleWrapper {
    // #region immutable variable.

    uint8 public immutable token0Decimals;
    uint8 public immutable token1Decimals;
    AggregatorV3Interface public immutable priceFeed;
    bool internal immutable _isPriceFeedInversed;

    // #endregion immutable variable.

    constructor(
        uint8 token0Decimals_,
        uint8 token1Decimals_,
        address priceFeed_,
        bool isPriceFeedInversed_
    ) {
        token0Decimals = token0Decimals_;
        token1Decimals = token1Decimals_;
        priceFeed = AggregatorV3Interface(priceFeed_);
        _isPriceFeedInversed = isPriceFeedInversed_;
    }

    /// @notice get Price of token 1 over token 0
    /// @return price0
    function getPrice0() external view override returns (uint256 price0) {
        (, int price, , , ) = priceFeed.latestRoundData();
        uint8 priceFeedDecimals = priceFeed.decimals();
        if (_isPriceFeedInversed) {
            return
                FullMath.mulDiv(
                    FullMath.mulDiv(
                        10 ** priceFeedDecimals,
                        10 ** priceFeedDecimals,
                        SafeCast.toUint256(price)
                    ),
                    10 ** token1Decimals,
                    10 ** priceFeedDecimals
                );
        }
        return
            FullMath.mulDiv(
                SafeCast.toUint256(price),
                10 ** token1Decimals,
                10 ** priceFeedDecimals
            );
    }

    /// @notice get Price of token 0 over token 1
    /// @return price1
    function getPrice1() external view override returns (uint256 price1) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint8 priceFeedDecimals = priceFeed.decimals();
        if (!_isPriceFeedInversed) {
            return
                FullMath.mulDiv(
                    FullMath.mulDiv(
                        10 ** priceFeedDecimals,
                        10 ** priceFeedDecimals,
                        SafeCast.toUint256(price)
                    ),
                    10 ** token0Decimals,
                    10 ** priceFeedDecimals
                );
        }
        return
            FullMath.mulDiv(
                SafeCast.toUint256(price),
                10 ** token0Decimals,
                10 ** priceFeedDecimals
            );
    }
}
