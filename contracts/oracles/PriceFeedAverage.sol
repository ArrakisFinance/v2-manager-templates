// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error NotSameDecimals();
error PriceFeedAOutdated(uint256 lastUpdate);
error PriceFeedBOutdated(uint256 lastUpdate);
error LatestRoundDataAFailed();
error LatestRoundDataBFailed();

contract PriceFeedAverage is Ownable {
    AggregatorV3Interface public immutable priceFeedA;
    AggregatorV3Interface public immutable priceFeedB;

    uint256 public outdatedA;
    uint256 public outdatedB;

    // #region events.

    event LogSetOutdatedA(
        address oracle,
        uint256 oldOutdated,
        uint256 newOutdated
    );

    event LogSetOutdatedB(
        address oracle,
        uint256 oldOutdated,
        uint256 newOutdated
    );

    // #endregion events.

    constructor(
        address priceFeedA_,
        address priceFeedB_,
        uint256 outdatedA_,
        uint256 outdatedB_
    ) {
        priceFeedA = AggregatorV3Interface(priceFeedA_);
        priceFeedB = AggregatorV3Interface(priceFeedB_);

        if (priceFeedA.decimals() != priceFeedB.decimals())
            revert NotSameDecimals();

        outdatedA = outdatedA_;
        outdatedB = outdatedB_;
    }

    /// @notice set outdated value for Token A
    /// @param outdatedA_ new outdated value
    function setOutdatedA(uint256 outdatedA_) external onlyOwner {
        uint256 oldOutdatedA = outdatedA;
        outdatedA = outdatedA_;
        emit LogSetOutdatedA(address(this), oldOutdatedA, outdatedA_);
    }

    /// @notice set outdated value for Token B
    /// @param outdatedB_ new outdated value
    function setOutdatedB(uint256 outdatedB_) external onlyOwner {
        uint256 oldOutdatedB = outdatedB;
        outdatedB = outdatedB_;
        emit LogSetOutdatedB(address(this), oldOutdatedB, outdatedB_);
    }

    // solhint-disable-next-line function-max-lines
    function latestRoundData()
        external
        view
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        int256 priceA;
        int256 priceB;

        try priceFeedA.latestRoundData() returns (
            uint80,
            int256 price,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            // solhint-disable-next-line not-rely-on-time
            if (block.timestamp - updatedAt > outdatedA)
                revert PriceFeedAOutdated(updatedAt);

            priceA = price;
        } catch {
            revert LatestRoundDataAFailed();
        }

        try priceFeedB.latestRoundData() returns (
            uint80,
            int256 price,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            // solhint-disable-next-line not-rely-on-time
            if (block.timestamp - updatedAt > outdatedB)
                revert PriceFeedBOutdated(updatedAt);

            priceB = price;
        } catch {
            revert LatestRoundDataBFailed();
        }

        answer = (priceA + priceB) / 2;
        updatedAt =
            block.timestamp - // solhint-disable-line not-rely-on-time
            (outdatedA > outdatedB ? outdatedB - 1 : outdatedA - 1);
    }

    function decimals() external view returns (uint8) {
        return priceFeedA.decimals();
    }
}
