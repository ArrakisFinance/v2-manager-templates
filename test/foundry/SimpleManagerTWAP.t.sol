// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "../utils/TestWrapper.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "forge-std/StdStorage.sol";
import "contracts/SimpleManagerTWAP.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IArrakisV2Factory,
    InitializePayload
} from "@arrakisfi/v2-core/contracts/interfaces/IArrakisV2Factory.sol";
import {
    Rebalance,
    RangeWeight,
    Range
} from "@arrakisfi/v2-core/contracts/structs/SArrakisV2.sol";
import {
    IArrakisV2Resolver
} from "@arrakisfi/v2-core/contracts/interfaces/IArrakisV2Resolver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArrakisV2} from "@arrakisfi/v2-core/contracts/ArrakisV2.sol";

// #region constants.

// #region Tokens Wallets.

address constant binanceUSDCHotWallet = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
address constant aaveWETHPool = 0x28424507fefb6f7f8E9D3860F56504E4e5f5f390;

// #endregion Tokens Wallets.

// #region Tokens.

IERC20 constant usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
IERC20 constant weth = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

// #endregion Tokens.

address constant arrakisV2Factory = 0x055B6d3919042Be29C5F044A55529933e1273A88;
address constant arrakisV2Resolver = 0x4bc385b1dDf0121CC40A0715CfD3beFE52f905f5;
address constant uniFactory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
address constant swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
uint16 constant managerFeeBPS = 100;
Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

// #endregion constants.

// #region custom interfaces.

interface IArrakisV2SetManager {
    function setManager(address manager_) external;
}

// #endregion custom interfaces.

contract SimpleManagerTWAPTest is TestWrapper {
    using stdStorage for StdStorage;

    uint256 public constant AMOUNTOFUSDC = 100000e6;
    uint256 public constant AMOUNTOFWETH = 100e18;

    SimpleManagerTWAP public simpleManagerTWAP;
    IUniswapV3Factory public uniswapV3Factory;
    IArrakisV2Resolver public resolver;
    address public vault;
    int24 public lowerTick;
    int24 public upperTick;
    uint24 public feeTier;

    constructor() {
        simpleManagerTWAP = new SimpleManagerTWAP(
            IUniswapV3Factory(uniFactory),
            managerFeeBPS
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

    function testSingleRangeNoSwapRebalance() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);
        // make vault to be managed by SimpleManagerTwap.
        _rebalanceSetup();

        // get some usdc and weth tokens.
        _getTokens();

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, AMOUNTOFUSDC, AMOUNTOFWETH);

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

    // #region test withdrawAndCollectedFees.

    // solhint-disable-next-line ordering
    function testWithdrawAndCollectedFees() public {
        IArrakisV2 vaultV2 = IArrakisV2(vault);

        _withdrawAndCollectedFeesSetup();

        // get some usdc and weth tokens.
        _getTokens();

        //  mint some vault tokens.
        (uint256 amount0, uint256 amount1, uint256 mintAmount) = resolver
            .getMintAmounts(vaultV2, AMOUNTOFUSDC, AMOUNTOFWETH);

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

        simpleManagerTWAP.withdrawAndCollectedFees(vaults, address(this));

        assertEq(
            usdcBalanceBefore + managerBalance0,
            usdc.balanceOf(address(this))
        );
        assertEq(
            wethBalanceBefore + managerBalance1,
            weth.balanceOf(address(this))
        );
    }

    function _withdrawAndCollectedFeesSetup() internal {
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

    // #endregion test withdrawAndCollectedFees.

    // #region internal functions.

    function _getTokens() internal {
        // #region get tokens to create vault.

        // usdc
        vm.prank(binanceUSDCHotWallet, binanceUSDCHotWallet);
        usdc.transfer(msg.sender, AMOUNTOFUSDC);

        // weth
        vm.prank(aaveWETHPool, aaveWETHPool);
        weth.transfer(msg.sender, AMOUNTOFWETH);

        // #endregion get tokens to create vault.
    }

    function _getAmountsForLiquidity()
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        // #region get usdc/weth pool informations for vault creation.

        uniswapV3Factory = IUniswapV3Factory(uniFactory);
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapV3Factory.getPool(address(usdc), address(weth), 500)
        );
        (, int24 tick, , , , , ) = pool.slot0();
        int24 tickSpacing = pool.tickSpacing();

        lowerTick = tick - (tick % tickSpacing) - tickSpacing;
        upperTick = tick - (tick % tickSpacing) + 2 * tickSpacing;

        resolver = IArrakisV2Resolver(arrakisV2Resolver);

        (amount0, amount1) = resolver.getAmountsForLiquidity(
            tick,
            lowerTick,
            upperTick,
            1e18
        );

        // #endregion get usdc/weth pool informations for vault creation.
    }

    // #endregion internal functions.
}
