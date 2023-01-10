// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../utils/TestWrapper.sol";
import "forge-std/Vm.sol";
import "contracts/SimpleManagerTWAP.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    IArrakisV2Factory,
    InitializePayload
} from "@arrakisfi/v2-core/contracts/interfaces/IArrakisV2Factory.sol";
import {
    ISwapRouter
} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {
    Rebalance,
    RangeWeight,
    Range,
    SwapPayload
} from "@arrakisfi/v2-core/contracts/structs/SArrakisV2.sol";
import {Twap} from "contracts/libraries/Twap.sol";
import {
    IArrakisV2Resolver
} from "@arrakisfi/v2-core/contracts/interfaces/IArrakisV2Resolver.sol";
import {IArrakisV2SetManager} from "../interfaces/IArrakisV2SetManager.sol";
import {IArrakisV2SetInits} from "../interfaces/IArrakisV2SetInits.sol";
import {
    IArrakisV2GetRestrictedMint
} from "../interfaces/IArrakisV2GetRestrictedMint.sol";
import {IArrakisV2GetOwner} from "../interfaces/IArrakisV2GetOwner.sol";
import {binanceUSDCHotWallet, aaveWETHPool} from "../constants/Wallets.sol";
import {usdc, weth} from "../constants/Tokens.sol";
import {
    arrakisV2Factory,
    arrakisV2Resolver,
    uniFactory,
    swapRouter,
    vm
} from "../constants/ContractsInstances.sol";
import {hundred_percent} from "contracts/constants/CSimpleManagerTWAP.sol";

// solhint-disable-next-line max-states-count
contract SimpleManagerTWAPTest is TestWrapper {
    using stdStorage for StdStorage;

    uint256 public constant AMOUNT_OF_USDC = 100000e6;
    uint256 public constant AMOUNT_OF_WETH = 100e18;

    uint16 public constant MANAGER_FEE_BPS = 100;

    SimpleManagerTWAP public simpleManagerTWAP;
    IUniswapV3Factory public uniswapV3Factory;
    IArrakisV2Resolver public resolver;
    address public vault;
    int24 public lowerTick;
    int24 public upperTick;
    int24 public tickSpacing;
    uint24 public feeTier;

    constructor() {
        simpleManagerTWAP = new SimpleManagerTWAP(
            IUniswapV3Factory(uniFactory),
            MANAGER_FEE_BPS
        );
    }

    function setUp() public {
        // #region create Vault

        feeTier = 500;
        /* solhint-disable reentrancy */
        (uint256 amount0, uint256 amount1) = _getAmountsForLiquidity();

        uint24[] memory feeTiers = new uint24[](1);
        feeTiers[0] = feeTier;

        address[] memory routers = new address[](1);
        routers[0] = swapRouter;

        vault = IArrakisV2Factory(arrakisV2Factory).deployVault(
            InitializePayload({
                feeTiers: feeTiers,
                token0: address(usdc),
                token1: address(weth),
                owner: msg.sender,
                init0: amount0,
                init1: amount1,
                manager: address(simpleManagerTWAP),
                routers: routers,
                burnBuffer: 1000
            }),
            true
        );

        // #endregion create Vault

        /* solhint-enable reentrancy */
    }

    // #region test initManagement.

    function testInitManagementCallerNotOwner() public {
        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: feeTier,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 100
            });
        vm.expectRevert(bytes("NO"));

        simpleManagerTWAP.initManagement(params);
    }

    function testInitManagementTwapDeviationZero() public {
        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: feeTier,
                twapDeviation: 0,
                twapDuration: 100,
                maxSlippage: 100
            });
        vm.prank(msg.sender);
        vm.expectRevert(bytes("DN"));

        simpleManagerTWAP.initManagement(params);
    }

    function testInitManagementNotManagedBySimpleManagerTWAP() public {
        vm.prank(msg.sender);
        IArrakisV2SetManager(vault).setManager(msg.sender);

        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: feeTier,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 100
            });
        vm.prank(msg.sender);
        vm.expectRevert(bytes("NM"));

        simpleManagerTWAP.initManagement(params);
    }

    function testInitManagementAlreadyAdded() public {
        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: feeTier,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 100
            });

        vm.prank(msg.sender);

        simpleManagerTWAP.initManagement(params);

        vm.prank(msg.sender);
        vm.expectRevert(bytes("AV"));

        simpleManagerTWAP.initManagement(params);
    }

    function testInitManagementSlippageTooHigh() public {
        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: feeTier,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 1001
            });

        vm.prank(msg.sender);
        vm.expectRevert(bytes("MS"));

        simpleManagerTWAP.initManagement(params);
    }

    function testInitManagementWrongFeeTier() public {
        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: 5,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 100
            });

        vm.prank(msg.sender);
        vm.expectRevert(bytes("NP"));

        simpleManagerTWAP.initManagement(params);
    }

    function testInitManagement() public {
        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: feeTier,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 100
            });

        vm.prank(msg.sender);

        simpleManagerTWAP.initManagement(params);

        // #region asserts.

        IArrakisV2 vaultV2 = IArrakisV2(vault);

        address pool = uniswapV3Factory.getPool(
            address(vaultV2.token0()),
            address(vaultV2.token1()),
            params.twapFeeTier
        );

        (
            IUniswapV3Pool twapOracle,
            int24 twapDeviation,
            uint24 twapDuration,
            uint24 maxSlippage
        ) = simpleManagerTWAP.vaults(vault);

        assertEq(address(twapOracle), pool);
        assertEq(twapDeviation, params.twapDeviation);
        assertEq(twapDuration, params.twapDuration);
        assertEq(maxSlippage, params.maxSlippage);

        // #endregion asserts.
    }

    // #endregion test initManagement.

    // #region test rebalance.

    function testSingleRangeNoSwapRebalanceNotCalledByOwner() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);
        // make vault to be managed by SimpleManagerTwap.
        _rebalanceSetup();

        // get some usdc and weth tokens.
        _getTokens();

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, AMOUNT_OF_USDC, AMOUNT_OF_WETH);

        vm.prank(msg.sender);
        usdc.approve(vault, amount0);

        vm.prank(msg.sender);
        weth.approve(vault, amount1);

        vm.prank(msg.sender);
        vaultV2.mint(mintAmount, msg.sender);

        // get rebalance payload.
        Range memory range = Range({
            lowerTick: lowerTick,
            upperTick: upperTick,
            feeTier: feeTier
        });
        RangeWeight[] memory rangeWeights = new RangeWeight[](1);
        rangeWeights[0] = RangeWeight({weight: 10000, range: range});

        Rebalance memory rebalancePayload = resolver.standardRebalance(
            rangeWeights,
            vaultV2
        );

        Range[] memory ranges = new Range[](1);
        ranges[0] = range;
        Range[] memory rangesToRemove = new Range[](0);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(msg.sender);
        simpleManagerTWAP.rebalance(
            vault,
            ranges,
            rebalancePayload,
            rangesToRemove
        );
    }

    // solhint-disable-next-line function-max-lines
    function testSingleRangeNoSwapRebalance() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);
        // make vault to be managed by SimpleManagerTwap.
        _rebalanceSetup();

        // get some usdc and weth tokens.
        _getTokens();

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, AMOUNT_OF_USDC, AMOUNT_OF_WETH);

        vm.prank(msg.sender);
        usdc.approve(vault, amount0);

        vm.prank(msg.sender);
        weth.approve(vault, amount1);

        vm.prank(msg.sender);
        vaultV2.mint(mintAmount, msg.sender);

        // get rebalance payload.
        Range memory range = Range({
            lowerTick: lowerTick,
            upperTick: upperTick,
            feeTier: feeTier
        });
        RangeWeight[] memory rangeWeights = new RangeWeight[](1);
        rangeWeights[0] = RangeWeight({weight: 10000, range: range});

        Rebalance memory rebalancePayload = resolver.standardRebalance(
            rangeWeights,
            vaultV2
        );

        Range[] memory ranges = new Range[](1);
        ranges[0] = range;
        Range[] memory rangesToRemove = new Range[](0);

        simpleManagerTWAP.rebalance(
            vault,
            ranges,
            rebalancePayload,
            rangesToRemove
        );
    }

    // solhint-disable-next-line function-max-lines
    function testMultipleRangeNoSwapRebalance() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);
        // make vault to be managed by SimpleManagerTwap.
        _rebalanceSetup();

        // get some usdc and weth tokens.
        _getTokens();

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, AMOUNT_OF_USDC, AMOUNT_OF_WETH);

        vm.prank(msg.sender);
        usdc.approve(vault, amount0);

        vm.prank(msg.sender);
        weth.approve(vault, amount1);

        vm.prank(msg.sender);
        vaultV2.mint(mintAmount, msg.sender);

        // get rebalance payload.
        Range memory range0 = Range({
            lowerTick: lowerTick,
            upperTick: upperTick,
            feeTier: feeTier
        });
        Range memory range1 = Range({
            lowerTick: lowerTick - tickSpacing,
            upperTick: lowerTick,
            feeTier: feeTier
        });
        RangeWeight[] memory rangeWeights = new RangeWeight[](2);
        rangeWeights[0] = RangeWeight({weight: 5000, range: range0});
        rangeWeights[1] = RangeWeight({weight: 5000, range: range1});

        Rebalance memory rebalancePayload = resolver.standardRebalance(
            rangeWeights,
            vaultV2
        );

        Range[] memory ranges = new Range[](2);
        ranges[0] = range0;
        ranges[1] = range1;
        Range[] memory rangesToRemove = new Range[](0);

        simpleManagerTWAP.rebalance(
            vault,
            ranges,
            rebalancePayload,
            rangesToRemove
        );
    }

    // solhint-disable-next-line function-max-lines
    function testSingleRangeSwapRebalanceShouldRevertWithS0() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);
        // make vault to be managed by SimpleManagerTwap.
        _rebalanceSetup();

        // get some usdc tokens.
        _getUSDCTokens();

        uint256 slot = stdstore.target(vault).sig("init1()").find();

        uint256 init1 = 0;
        vm.store(vault, bytes32(slot), bytes32(init1));

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, AMOUNT_OF_USDC * 2, 0);

        vm.prank(msg.sender);
        usdc.approve(vault, amount0);

        vm.prank(msg.sender);
        weth.approve(vault, amount1);

        vm.prank(msg.sender);
        vaultV2.mint(mintAmount, msg.sender);

        Range memory range = Range({
            lowerTick: lowerTick,
            upperTick: upperTick,
            feeTier: feeTier
        });
        RangeWeight[] memory rangeWeights = new RangeWeight[](1);
        rangeWeights[0] = RangeWeight({weight: 10000, range: range});

        Rebalance memory rebalancePayload = resolver.standardRebalance(
            rangeWeights,
            vaultV2
        );

        (
            IUniswapV3Pool twapOracle,
            ,
            uint24 twapDuration,
            uint24 maxSlippage
        ) = simpleManagerTWAP.vaults(vault);

        uint256 expectedMinReturn = FullMath.mulDiv(
            FullMath.mulDiv(
                Twap.getPrice0(twapOracle, twapDuration),
                hundred_percent - maxSlippage,
                hundred_percent
            ),
            AMOUNT_OF_USDC,
            10 ** ERC20(address(usdc)).decimals()
        );

        rebalancePayload.swap = SwapPayload({
            router: swapRouter,
            amountIn: AMOUNT_OF_USDC,
            expectedMinReturn: expectedMinReturn,
            zeroForOne: true,
            payload: abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(usdc),
                    tokenOut: address(weth),
                    fee: feeTier,
                    recipient: vault,
                    deadline: type(uint256).max,
                    amountIn: AMOUNT_OF_USDC,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        rebalancePayload.deposits[0].liquidity = 1000;

        Range[] memory ranges = new Range[](1);
        ranges[0] = range;
        Range[] memory rangesToRemove = new Range[](0);

        vm.expectRevert(bytes("S0"));

        simpleManagerTWAP.rebalance(
            vault,
            ranges,
            rebalancePayload,
            rangesToRemove
        );
    }

    // solhint-disable-next-line function-max-lines
    function testSingleRangeSwapRebalance() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);
        // make vault to be managed by SimpleManagerTwap.
        _rebalanceSetup();

        // get some usdc tokens.
        _getUSDCTokens();

        uint256 slot = stdstore.target(vault).sig("init1()").find();

        uint256 init1 = 0;
        vm.store(vault, bytes32(slot), bytes32(init1));

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, AMOUNT_OF_USDC * 2, 0);

        vm.prank(msg.sender);
        usdc.approve(vault, amount0);

        vm.prank(msg.sender);
        weth.approve(vault, amount1);

        vm.prank(msg.sender);
        vaultV2.mint(mintAmount, msg.sender);

        Range memory range = Range({
            lowerTick: lowerTick,
            upperTick: upperTick,
            feeTier: feeTier
        });
        RangeWeight[] memory rangeWeights = new RangeWeight[](1);
        rangeWeights[0] = RangeWeight({weight: 10000, range: range});

        Rebalance memory rebalancePayload = resolver.standardRebalance(
            rangeWeights,
            vaultV2
        );

        (
            IUniswapV3Pool twapOracle,
            ,
            uint24 twapDuration,
            uint24 maxSlippage
        ) = simpleManagerTWAP.vaults(vault);

        uint256 expectedMinReturn = FullMath.mulDiv(
            FullMath.mulDiv(
                Twap.getPrice0(twapOracle, twapDuration),
                hundred_percent - maxSlippage,
                hundred_percent
            ),
            AMOUNT_OF_USDC,
            10 ** ERC20(address(usdc)).decimals()
        ) + 10 ** ERC20(address(usdc)).decimals();

        rebalancePayload.swap = SwapPayload({
            router: swapRouter,
            amountIn: AMOUNT_OF_USDC,
            expectedMinReturn: expectedMinReturn,
            zeroForOne: true,
            payload: abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(usdc),
                    tokenOut: address(weth),
                    fee: feeTier,
                    recipient: vault,
                    deadline: type(uint256).max,
                    amountIn: AMOUNT_OF_USDC,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        rebalancePayload.deposits[0].liquidity = 1000;

        Range[] memory ranges = new Range[](1);
        ranges[0] = range;
        Range[] memory rangesToRemove = new Range[](0);

        simpleManagerTWAP.rebalance(
            vault,
            ranges,
            rebalancePayload,
            rangesToRemove
        );
    }

    // solhint-disable-next-line function-max-lines
    function testSingleRangeSwapRebalanceWETH() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);
        // make vault to be managed by SimpleManagerTwap.
        _rebalanceSetup();

        // get some usdc tokens.
        _getWETHTokens();

        uint256 slot = stdstore.target(vault).sig("init0()").find();

        uint256 init0 = 0;
        vm.store(vault, bytes32(slot), bytes32(init0));

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, 0, AMOUNT_OF_WETH * 2);

        vm.prank(msg.sender);
        usdc.approve(vault, amount0);

        vm.prank(msg.sender);
        weth.approve(vault, amount1);

        vm.prank(msg.sender);
        vaultV2.mint(mintAmount, msg.sender);

        Range memory range = Range({
            lowerTick: lowerTick,
            upperTick: upperTick,
            feeTier: feeTier
        });
        RangeWeight[] memory rangeWeights = new RangeWeight[](1);
        rangeWeights[0] = RangeWeight({weight: 10000, range: range});

        Rebalance memory rebalancePayload = resolver.standardRebalance(
            rangeWeights,
            vaultV2
        );

        (
            IUniswapV3Pool twapOracle,
            ,
            uint24 twapDuration,
            uint24 maxSlippage
        ) = simpleManagerTWAP.vaults(vault);

        uint256 expectedMinReturn = (FullMath.mulDiv(
            FullMath.mulDiv(
                Twap.getPrice1(twapOracle, twapDuration),
                hundred_percent - maxSlippage,
                hundred_percent
            ),
            AMOUNT_OF_WETH,
            10 ** ERC20(address(weth)).decimals()
        ) * 10050) / 10000;

        rebalancePayload.swap = SwapPayload({
            router: swapRouter,
            amountIn: AMOUNT_OF_WETH,
            expectedMinReturn: expectedMinReturn,
            zeroForOne: false,
            payload: abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(weth),
                    tokenOut: address(usdc),
                    fee: feeTier,
                    recipient: vault,
                    deadline: type(uint256).max,
                    amountIn: AMOUNT_OF_WETH,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        rebalancePayload.deposits[0].liquidity = 1000;

        Range[] memory ranges = new Range[](1);
        ranges[0] = range;
        Range[] memory rangesToRemove = new Range[](0);

        simpleManagerTWAP.rebalance(
            vault,
            ranges,
            rebalancePayload,
            rangesToRemove
        );
    }

    function _rebalanceSetup() internal {
        // do init management.

        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: 500,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 100
            });

        vm.prank(msg.sender);

        simpleManagerTWAP.initManagement(params);
    }

    // #endregion test rebalance.

    // #region test withdrawAndCollectFees.

    // solhint-disable-next-line ordering, function-max-lines
    function testWithdrawAndCollectFees() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);

        _withdrawAndCollectFeesSetup();

        // get some usdc and weth tokens.
        _getTokens();

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, AMOUNT_OF_USDC, AMOUNT_OF_WETH);

        vm.prank(msg.sender);
        usdc.approve(vault, amount0);

        vm.prank(msg.sender);
        weth.approve(vault, amount1);

        vm.prank(msg.sender);
        vaultV2.mint(mintAmount, msg.sender);

        // #region change managerBalance0 and managerBalance1.

        uint256 slot = stdstore.target(vault).sig("managerBalance0()").find();

        uint256 managerBalance0 = 100;
        vm.store(vault, bytes32(slot), bytes32(managerBalance0));

        slot = stdstore.target(address(vault)).sig("managerBalance1()").find();

        uint256 managerBalance1 = 1000;
        vm.store(vault, bytes32(slot), bytes32(managerBalance1));

        // #endregion change managerBalance0 and managerBalance1.

        uint256 usdcBalanceBefore = usdc.balanceOf(address(this));
        uint256 wethBalanceBefore = weth.balanceOf(address(this));

        IArrakisV2[] memory vaults = new IArrakisV2[](1);
        vaults[0] = vaultV2;

        simpleManagerTWAP.withdrawAndCollectFees(vaults, address(this));

        assertEq(
            usdcBalanceBefore + managerBalance0,
            usdc.balanceOf(address(this))
        );
        assertEq(
            wethBalanceBefore + managerBalance1,
            weth.balanceOf(address(this))
        );
    }

    function testWithdrawAndCollectFeesMultipleVault() public {
        // #region create second vault.

        /* solhint-disable reentrancy */
        (uint256 amount0, uint256 amount1) = _getAmountsForLiquidity();

        uint24[] memory feeTiers = new uint24[](1);
        feeTiers[0] = feeTier;

        address[] memory routers = new address[](1);
        routers[0] = swapRouter;

        address secondVault = IArrakisV2Factory(arrakisV2Factory).deployVault(
            InitializePayload({
                feeTiers: feeTiers,
                token0: address(usdc),
                token1: address(weth),
                owner: msg.sender,
                init0: amount0,
                init1: amount1,
                manager: address(simpleManagerTWAP),
                routers: routers,
                burnBuffer: 1000
            }),
            true
        );

        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: secondVault,
                twapFeeTier: 500,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 100
            });

        vm.prank(msg.sender);
        simpleManagerTWAP.initManagement(params);

        // #endregion create second vault.

        IArrakisV2 vaultV2 = IArrakisV2(vault);
        IArrakisV2 secondVaultV2 = IArrakisV2(secondVault);

        _withdrawAndCollectFeesSetup();

        // get some usdc and weth tokens.
        _getTokens();

        //  mint some vault tokens.
        uint256 mintAmount;
        (amount0, amount1, mintAmount) = resolver.getMintAmounts(
            vaultV2,
            AMOUNT_OF_USDC,
            AMOUNT_OF_WETH
        );

        vm.prank(msg.sender);
        usdc.approve(vault, amount0);

        vm.prank(msg.sender);
        weth.approve(vault, amount1);

        vm.prank(msg.sender);
        vaultV2.mint(mintAmount, msg.sender);

        _getTokens();

        vm.prank(msg.sender);
        usdc.approve(secondVault, amount0);

        vm.prank(msg.sender);
        weth.approve(secondVault, amount1);

        vm.prank(msg.sender);
        secondVaultV2.mint(mintAmount, msg.sender);

        // #region change managerBalance0 and managerBalance1.

        uint256 slot = stdstore.target(vault).sig("managerBalance0()").find();

        uint256 managerBalance0 = 100;
        vm.store(vault, bytes32(slot), bytes32(managerBalance0));
        vm.store(secondVault, bytes32(slot), bytes32(managerBalance0));

        slot = stdstore.target(address(vault)).sig("managerBalance1()").find();

        uint256 managerBalance1 = 1000;
        vm.store(vault, bytes32(slot), bytes32(managerBalance1));
        vm.store(secondVault, bytes32(slot), bytes32(managerBalance1));

        // #endregion change managerBalance0 and managerBalance1.

        uint256 usdcBalanceBefore = usdc.balanceOf(address(this));
        uint256 wethBalanceBefore = weth.balanceOf(address(this));

        IArrakisV2[] memory vaults = new IArrakisV2[](2);
        vaults[0] = vaultV2;
        vaults[1] = secondVaultV2;

        simpleManagerTWAP.withdrawAndCollectFees(vaults, address(this));

        assertEq(
            usdcBalanceBefore + (managerBalance0 * 2),
            usdc.balanceOf(address(this))
        );
        assertEq(
            wethBalanceBefore + (managerBalance1 * 2),
            weth.balanceOf(address(this))
        );
    }

    function _withdrawAndCollectFeesSetup() internal {
        // do init management.

        SimpleManagerTWAP.SetupParams memory params = SimpleManagerTWAP
            .SetupParams({
                vault: vault,
                twapFeeTier: 500,
                twapDeviation: 100,
                twapDuration: 100,
                maxSlippage: 100
            });

        vm.prank(msg.sender);

        simpleManagerTWAP.initManagement(params);
    }

    // #endregion test withdrawAndCollectFees.

    // #region internal functions.

    function _getTokens() internal {
        // usdc
        vm.prank(binanceUSDCHotWallet, binanceUSDCHotWallet);
        usdc.transfer(msg.sender, AMOUNT_OF_USDC);

        // weth
        vm.prank(aaveWETHPool, aaveWETHPool);
        weth.transfer(msg.sender, AMOUNT_OF_WETH);
    }

    function _getUSDCTokens() internal {
        vm.prank(binanceUSDCHotWallet, binanceUSDCHotWallet);
        usdc.transfer(msg.sender, AMOUNT_OF_USDC * 2);
    }

    function _getWETHTokens() internal {
        vm.prank(aaveWETHPool, aaveWETHPool);
        weth.transfer(msg.sender, AMOUNT_OF_WETH * 2);
    }

    function _getAmountsForLiquidity()
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        uniswapV3Factory = IUniswapV3Factory(uniFactory);
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapV3Factory.getPool(address(usdc), address(weth), 500)
        );
        (, int24 tick, , , , , ) = pool.slot0();
        tickSpacing = pool.tickSpacing();

        lowerTick = tick - (tick % tickSpacing) - tickSpacing;
        upperTick = tick - (tick % tickSpacing) + 2 * tickSpacing;

        resolver = IArrakisV2Resolver(arrakisV2Resolver);

        (amount0, amount1) = resolver.getAmountsForLiquidity(
            tick,
            lowerTick,
            upperTick,
            1e18
        );
    }

    // #endregion internal functions.
}
