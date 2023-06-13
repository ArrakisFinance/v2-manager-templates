// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../utils/TestWrapper.sol";
import "forge-std/Vm.sol";
import {ChainLinkOracle} from "contracts/oracles/ChainLinkOracle.sol";
import {
    ChainLinkOraclePivot,
    FullMath
} from "contracts/oracles/ChainLinkOraclePivot.sol";
import {hundred_percent} from "contracts/constants/CSimpleManager.sol";

contract PriceFeedMock {
    function latestRoundData()
        external
        returns (uint80, int256 price, uint256, uint256 updatedAt, uint80)
    {
        revert("revert");
    }
}

// solhint-disable-next-line max-states-count
contract ChainLinkOraclePivotWrapperTest is TestWrapper {
    using stdStorage for StdStorage;

    // solhint-disable-next-line no-empty-blocks
    function setUp() public {}

    // #region test getPrice0 wrong price feed.

    function testGetPrice0ShouldRevertWithWrongPriceFeedA() public {
        /* solhint-enable reentrancy */

        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;
        address priceFeed0 = address(new PriceFeedMock());
        address priceFeed1 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;
        uint256 outdated = 86400;

        // #region create Oracle.

        ChainLinkOraclePivot o = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        // #endregion create Oracle.

        vm.expectRevert(bytes("ChainLinkOracle: price feed A call failed."));
        o.getPrice0();
    }

    function testGetPrice0ShouldRevertWithWrongPriceFeedB() public {
        /* solhint-enable reentrancy */

        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;
        address priceFeed0 = 0x327e23A4855b6F663a28c5161541d69Af8973302;
        address priceFeed1 = address(new PriceFeedMock());
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;
        uint256 outdated = 86400;

        // #region create Oracle.

        ChainLinkOraclePivot o = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        // #endregion create Oracle.

        vm.expectRevert(bytes("ChainLinkOracle: price feed B call failed."));
        o.getPrice0();
    }

    // #endregion test getPrice0.

    // #region test getPrice1 wrong price feed.

    function testGetPrice1ShouldRevertWithWrongPriceFeedA() public {
        /* solhint-enable reentrancy */

        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;
        address priceFeed0 = address(new PriceFeedMock());
        address priceFeed1 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;
        uint256 outdated = 86400;

        // #region create Oracle.

        ChainLinkOraclePivot o = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        // #endregion create Oracle.

        vm.expectRevert(bytes("ChainLinkOracle: price feed A call failed."));
        o.getPrice1();
    }

    function testGetPrice1ShouldRevertWithWrongPriceFeedB() public {
        /* solhint-enable reentrancy */

        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;
        address priceFeed0 = 0x327e23A4855b6F663a28c5161541d69Af8973302;
        address priceFeed1 = address(new PriceFeedMock());
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;
        uint256 outdated = 86400;

        // #region create Oracle.

        ChainLinkOraclePivot o = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        // #endregion create Oracle.

        vm.expectRevert(bytes("ChainLinkOracle: price feed B call failed."));
        o.getPrice1();
    }

    // #endregion test getPrice1.

    // #region test set outdated.

    function testSetOutDatedShouldRevertOnlyOwner() public {
        /* solhint-enable reentrancy */

        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;
        address priceFeed0 = 0x327e23A4855b6F663a28c5161541d69Af8973302;
        address priceFeed1 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;
        uint256 outdated = 86400;

        // #region create Oracle.

        ChainLinkOraclePivot o = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        vm.prank(msg.sender);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        o.setOutdated(100_000);
    }

    function testSetOutDated() public {
        /* solhint-enable reentrancy */

        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;
        address priceFeed0 = 0x327e23A4855b6F663a28c5161541d69Af8973302;
        address priceFeed1 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;
        uint256 outdated = 86400;

        // #region create Oracle.

        ChainLinkOraclePivot o = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        // #endregion create Oracle.

        assertEq(o.outdated(), 86400);

        o.setOutdated(100_000);

        assertEq(o.outdated(), 100000);
    }

    // #endregion test set outdated.

    // #region test outdated.

    function testGetPrice0WithOutdatedData() public {
        /* solhint-enable reentrancy */

        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;
        address priceFeed0 = 0x327e23A4855b6F663a28c5161541d69Af8973302;
        address priceFeed1 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;
        uint256 outdated = 86400;

        // #region create Oracle.

        ChainLinkOraclePivot o = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        // #endregion create Oracle.

        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 100_000);

        vm.expectRevert(bytes("ChainLinkOracle: priceFeedA outdated."));
        o.getPrice0();
    }

    function testGetPrice1WithOutdatedData() public {
        /* solhint-enable reentrancy */

        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;
        address priceFeed0 = 0x327e23A4855b6F663a28c5161541d69Af8973302;
        address priceFeed1 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;
        uint256 outdated = 86400;

        // #region create Oracle.

        ChainLinkOraclePivot o = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        // #endregion create Oracle.

        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 100_000);

        vm.expectRevert(bytes("ChainLinkOracle: priceFeedA outdated."));
        o.getPrice1();
    }

    // #endregion test outdated.

    // #region 1st case .

    // solhint-disable-next-line function-max-lines
    function testFirstCase() public {
        // #region expected oracle.

        address expectedPriceFeed = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;
        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;

        uint256 outdated = 100_000;
        bool isPriceFeedInversed = false;

        ChainLinkOracle expectedOracle = new ChainLinkOracle(
            token0Decimals,
            token1Decimals,
            expectedPriceFeed,
            address(0),
            outdated,
            isPriceFeedInversed
        );

        uint256 expectedPrice0 = expectedOracle.getPrice0();
        uint256 expectedPrice1 = expectedOracle.getPrice1();

        // #endregion expected oracle.

        // #region pivot oracle.

        address priceFeed0 = 0x327e23A4855b6F663a28c5161541d69Af8973302;
        address priceFeed1 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = false;

        ChainLinkOraclePivot oraclePivot = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        uint256 actualPrice0 = oraclePivot.getPrice0();
        uint256 actualPrice1 = oraclePivot.getPrice1();

        // #endregion pivot oracle.

        assertLe(
            FullMath.mulDiv(
                expectedPrice0 > actualPrice0
                    ? expectedPrice0 - actualPrice0
                    : actualPrice0 - expectedPrice0,
                hundred_percent,
                expectedPrice0
            ),
            100
        );
        assertLe(
            FullMath.mulDiv(
                expectedPrice1 > actualPrice1
                    ? expectedPrice1 - actualPrice1
                    : actualPrice1 - expectedPrice1,
                hundred_percent,
                expectedPrice1
            ),
            100
        );
    }

    // #endregion 1st case.

    // #region 4th case .

    // solhint-disable-next-line function-max-lines
    function testFourthCase() public {
        // #region expected oracle.

        address expectedPriceFeed = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;
        uint8 token0Decimals = 8;
        uint8 token1Decimals = 18;

        uint256 outdated = 100_000;
        bool isPriceFeedInversed = true;

        ChainLinkOracle expectedOracle = new ChainLinkOracle(
            token0Decimals,
            token1Decimals,
            expectedPriceFeed,
            address(0),
            outdated,
            isPriceFeedInversed
        );

        uint256 expectedPrice0 = expectedOracle.getPrice0();
        uint256 expectedPrice1 = expectedOracle.getPrice1();

        // #endregion expected oracle.

        // #region pivot oracle.

        address priceFeed0 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        address priceFeed1 = 0x327e23A4855b6F663a28c5161541d69Af8973302;
        bool isPriceFeed0Inversed = true;
        bool isPriceFeed1Inversed = true;

        ChainLinkOraclePivot oraclePivot = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        uint256 actualPrice0 = oraclePivot.getPrice0();
        uint256 actualPrice1 = oraclePivot.getPrice1();

        // #endregion pivot oracle.

        assertLe(
            FullMath.mulDiv(
                expectedPrice0 > actualPrice0
                    ? expectedPrice0 - actualPrice0
                    : actualPrice0 - expectedPrice0,
                hundred_percent,
                expectedPrice0
            ),
            100
        );
        assertLe(
            FullMath.mulDiv(
                expectedPrice1 > actualPrice1
                    ? expectedPrice1 - actualPrice1
                    : actualPrice1 - expectedPrice1,
                hundred_percent,
                expectedPrice1
            ),
            100
        );
    }

    // #endregion 4th case.

    // #region 2nd case .

    // solhint-disable-next-line function-max-lines
    function testSecondCase() public {
        // #region expected oracle.

        address expectedPriceFeed = 0xefb7e6be8356cCc6827799B6A7348eE674A80EaE;
        uint8 token0Decimals = 18;
        uint8 token1Decimals = 8;

        uint256 outdated = 100_000;
        bool isPriceFeedInversed = true;

        ChainLinkOracle expectedOracle = new ChainLinkOracle(
            token0Decimals,
            token1Decimals,
            expectedPriceFeed,
            address(0),
            outdated,
            isPriceFeedInversed
        );

        uint256 expectedPrice0 = expectedOracle.getPrice0();
        uint256 expectedPrice1 = expectedOracle.getPrice1();

        // #endregion expected oracle.

        // #region pivot oracle.

        address priceFeed0 = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        address priceFeed1 = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
        bool isPriceFeed0Inversed = false;
        bool isPriceFeed1Inversed = true;

        ChainLinkOraclePivot oraclePivot = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        uint256 actualPrice0 = oraclePivot.getPrice0();
        uint256 actualPrice1 = oraclePivot.getPrice1();

        // #endregion pivot oracle.

        assertLe(
            FullMath.mulDiv(
                expectedPrice0 > actualPrice0
                    ? expectedPrice0 - actualPrice0
                    : actualPrice0 - expectedPrice0,
                hundred_percent,
                expectedPrice0
            ),
            100
        );
        assertLe(
            FullMath.mulDiv(
                expectedPrice1 > actualPrice1
                    ? expectedPrice1 - actualPrice1
                    : actualPrice1 - expectedPrice1,
                hundred_percent,
                expectedPrice1
            ),
            100
        );
    }

    // #endregion 2nd case.

    // #region 3rd case .

    // solhint-disable-next-line function-max-lines
    function testThirdCase() public {
        // #region expected oracle.

        address expectedPriceFeed = 0xF9680D99D6C9589e2a93a78A04A279e509205945;
        uint8 token0Decimals = 8;
        uint8 token1Decimals = 18;

        uint256 outdated = 100_000;
        bool isPriceFeedInversed = true;

        ChainLinkOracle expectedOracle = new ChainLinkOracle(
            token0Decimals,
            token1Decimals,
            expectedPriceFeed,
            address(0),
            outdated,
            isPriceFeedInversed
        );

        uint256 expectedPrice0 = expectedOracle.getPrice0();
        uint256 expectedPrice1 = expectedOracle.getPrice1();

        // #endregion expected oracle.

        // #region pivot oracle.

        address priceFeed0 = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
        address priceFeed1 = 0xefb7e6be8356cCc6827799B6A7348eE674A80EaE;
        bool isPriceFeed0Inversed = true;
        bool isPriceFeed1Inversed = false;

        ChainLinkOraclePivot oraclePivot = new ChainLinkOraclePivot(
            token0Decimals,
            token1Decimals,
            priceFeed0,
            priceFeed1,
            address(0),
            outdated,
            isPriceFeed0Inversed,
            isPriceFeed1Inversed
        );

        uint256 actualPrice0 = oraclePivot.getPrice0();
        uint256 actualPrice1 = oraclePivot.getPrice1();

        // #endregion pivot oracle.

        assertLe(
            FullMath.mulDiv(
                expectedPrice0 > actualPrice0
                    ? expectedPrice0 - actualPrice0
                    : actualPrice0 - expectedPrice0,
                hundred_percent,
                expectedPrice0
            ),
            100
        );
        assertLe(
            FullMath.mulDiv(
                expectedPrice1 > actualPrice1
                    ? expectedPrice1 - actualPrice1
                    : actualPrice1 - expectedPrice1,
                hundred_percent,
                expectedPrice1
            ),
            100
        );
    }

    // #endregion 3rd case.
}
