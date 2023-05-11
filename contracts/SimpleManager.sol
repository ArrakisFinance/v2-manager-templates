// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IArrakisV2,
    Range,
    Rebalance
} from "@arrakisfi/v2-core/contracts/interfaces/IArrakisV2.sol";
import {FullMath} from "@arrakisfi/v3-lib-0.8/contracts/FullMath.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {IOracleWrapper} from "./interfaces/IOracleWrapper.sol";
import {IDecimals} from "./interfaces/IDecimals.sol";

import {hundred_percent, ten_percent} from "./constants/CSimpleManager.sol";

/// @title SimpleManager
/// @dev Most simple manager to manage public vault on Arrakis V2.
contract SimpleManager is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct VaultInfo {
        IOracleWrapper oracle;
        uint24 maxDeviation;
        uint24 maxSlippage;
    }

    struct SetupParams {
        address vault;
        IOracleWrapper oracle;
        uint24 maxDeviation;
        uint24 maxSlippage;
    }

    IUniswapV3Factory public immutable uniFactory;

    mapping(address => VaultInfo) public vaults;

    EnumerableSet.AddressSet internal _operators;

    event InitManagement(
        address vault,
        address oracle,
        uint24 maxDeviation,
        uint24 maxSlippage
    );
    event RebalanceVault(address vault, address caller);
    event AddOperators(address[] operators);
    event RemoveOperators(address[] operators);

    modifier onlyVaultOwner(address vault) {
        require(msg.sender == IOwnable(vault).owner(), "NO");
        _;
    }

    constructor(IUniswapV3Factory uniFactory_) {
        uniFactory = uniFactory_;
    }

    /// @notice Initialize management
    /// @dev onced initialize Arrakis will start to manage the initialize vault
    /// @param params SetupParams struct containing data for manager vault
    function initManagement(
        SetupParams calldata params
    ) external onlyVaultOwner(params.vault) {
        require(params.maxDeviation > 0, "DN");
        require(address(this) == IArrakisV2(params.vault).manager(), "NM");
        require(address(params.oracle) != address(0), "OZA");
        require(address(vaults[params.vault].oracle) == address(0), "AV");
        /// @dev 10% max slippage allowed by the manager.
        require(params.maxSlippage <= ten_percent, "MS");

        vaults[params.vault] = VaultInfo({
            oracle: params.oracle,
            maxDeviation: params.maxDeviation,
            maxSlippage: params.maxSlippage
        });

        emit InitManagement(
            params.vault,
            address(params.oracle),
            params.maxDeviation,
            params.maxSlippage
        );
    }

    /// @notice Rebalance vault
    /// @dev only an operator of the contract Arrakis Finance can call the contract
    /// @param vault_ address of the Arrakis V2 vault to rebalance
    /// @param ranges_ array of ranges where the rebalance action will
    /// deposit tokens
    /// @param rebalanceParams_ rebalance parameters.
    /// @param rangesToRemove_ array of ranges where rebalance will remove liquidity
    // solhint-disable-next-line function-max-lines, code-complexity
    function rebalance(
        address vault_,
        Range[] calldata ranges_,
        Rebalance calldata rebalanceParams_,
        Range[] calldata rangesToRemove_
    ) external {
        require(_operators.contains(msg.sender), "NO");
        VaultInfo memory vaultInfo = vaults[vault_];

        address token0;
        address token1;
        uint8 token0Decimals;
        uint8 token1Decimals;
        uint24[] memory checked;
        uint256 oraclePrice;
        uint256 increment;

        if (
            rebalanceParams_.deposits.length > 0 ||
            rebalanceParams_.swap.amountIn > 0
        ) {
            token0 = address(IArrakisV2(vault_).token0());
            token1 = address(IArrakisV2(vault_).token1());
            token0Decimals = IDecimals(token0).decimals();
            token1Decimals = IDecimals(token1).decimals();
        }

        if (rebalanceParams_.deposits.length > 0) {
            checked = new uint24[](rebalanceParams_.deposits.length);
            oraclePrice = vaultInfo.oracle.getPrice0();
        }

        for (uint256 i; i < rebalanceParams_.deposits.length; i++) {
            if (
                _includes(
                    rebalanceParams_.deposits[i].range.feeTier,
                    checked,
                    increment
                )
            ) continue;

            IUniswapV3Pool pool = IUniswapV3Pool(
                _getPool(
                    token0,
                    token1,
                    rebalanceParams_.deposits[i].range.feeTier
                )
            );

            uint256 sqrtPriceX96;

            (sqrtPriceX96, , , , , , ) = pool.slot0();

            uint256 poolPrice = FullMath.mulDiv(
                sqrtPriceX96 * sqrtPriceX96,
                10 ** token0Decimals,
                2 ** 192
            );

            _checkDeviation(
                poolPrice,
                oraclePrice,
                vaultInfo.maxDeviation,
                token1Decimals
            );

            checked[increment] = rebalanceParams_.deposits[i].range.feeTier;
            increment++;
        }

        // check expectedMinReturn on rebalance swap against oracle
        if (rebalanceParams_.swap.amountIn > 0) {
            _checkMinReturn(
                rebalanceParams_,
                vaultInfo.oracle,
                vaultInfo.maxSlippage,
                token0Decimals,
                token1Decimals
            );
        }

        IArrakisV2(vault_).rebalance(
            ranges_,
            rebalanceParams_,
            rangesToRemove_
        );

        emit RebalanceVault(vault_, msg.sender);
    }

    /// @notice Withdraw and Collect Fees generated by vaults on Uni v3
    /// @dev only the owner of the contract Arrakis Finance can call the contract
    /// @param vaults_ array of vaults where to collect fees
    /// @param target receiver of fees collection
    // solhint-disable-next-line code-complexity
    function withdrawAndCollectFees(
        IArrakisV2[] calldata vaults_,
        address target
    ) external onlyOwner {
        require(vaults_.length > 0, "ZV");
        require(target != address(0), "TZA");

        address[] memory tokens = new address[](2 * vaults_.length);
        uint256 increment;

        // #region withdraw from vaults.

        for (uint256 i; i < vaults_.length; i++) {
            require(vaults_[i].manager() == address(this), "NM");

            address token0 = address(vaults_[i].token0());
            address token1 = address(vaults_[i].token1());

            vaults_[i].withdrawManagerBalance();
            if (!_includesAddress(token0, tokens, increment)) {
                tokens[increment] = token0;
                increment++;
            }
            if (!_includesAddress(token1, tokens, increment)) {
                tokens[increment] = token1;
                increment++;
            }
        }

        // #endregion withdraw from vaults.

        // #region transfer token to target.

        for (uint256 i; i < increment; i++) {
            uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance > 0) IERC20(tokens[i]).safeTransfer(target, balance);
        }

        // #endregion transfer token to target.
    }

    /// @notice for adding operators
    /// @param operators_ list of operators to add
    /// @dev only callable by owner
    function addOperators(address[] calldata operators_) external onlyOwner {
        require(operators_.length > 0, "ZO");
        for (uint256 i; i < operators_.length; ++i) {
            require(
                operators_[i] != address(0) && _operators.add(operators_[i]),
                "O"
            );
        }

        emit AddOperators(operators_);
    }

    /// @notice for removing operators
    /// @param operators_ list of operators to remove
    /// @dev only callable by owner
    function removeOperators(address[] memory operators_) external onlyOwner {
        require(operators_.length > 0, "ZO");
        for (uint256 i; i < operators_.length; ++i) {
            require(_operators.remove(operators_[i]), "NO");
        }

        emit RemoveOperators(operators_);
    }

    /// @notice get list of operators
    /// @return operators array of address representing operators
    function getOperators() external view returns (address[] memory) {
        return _operators.values();
    }

    /// @notice check if it's operators
    /// @param operator_ address to check if it's an operator
    /// @return return true if inputed address is an operator
    /// otherwise return false
    function isOperator(address operator_) external view returns (bool) {
        require(operator_ != address(0), "AZ");
        return _operators.contains(operator_);
    }

    function _checkMinReturn(
        Rebalance memory rebalanceParams_,
        IOracleWrapper oracle_,
        uint24 maxSlippage,
        uint8 decimals0,
        uint8 decimals1
    ) internal view {
        if (rebalanceParams_.swap.zeroForOne) {
            require(
                FullMath.mulDiv(
                    rebalanceParams_.swap.expectedMinReturn,
                    10 ** decimals0,
                    rebalanceParams_.swap.amountIn
                ) >
                    FullMath.mulDiv(
                        oracle_.getPrice0(),
                        hundred_percent - maxSlippage,
                        hundred_percent
                    ),
                "S0"
            );
        } else {
            require(
                FullMath.mulDiv(
                    rebalanceParams_.swap.expectedMinReturn,
                    10 ** decimals1,
                    rebalanceParams_.swap.amountIn
                ) >
                    FullMath.mulDiv(
                        oracle_.getPrice1(),
                        hundred_percent - maxSlippage,
                        hundred_percent
                    ),
                "S1"
            );
        }
    }

    function _getPool(
        address token0,
        address token1,
        uint24 feeTier
    ) internal view returns (address pool) {
        pool = uniFactory.getPool(token0, token1, feeTier);

        require(pool != address(0), "NP");
    }

    function _checkDeviation(
        uint256 currentPrice_,
        uint256 oraclePrice_,
        uint24 maxDeviation_,
        uint8 priceDecimals_
    ) internal pure {
        uint256 deviation = FullMath.mulDiv(
            FullMath.mulDiv(
                currentPrice_ > oraclePrice_
                    ? currentPrice_ - oraclePrice_
                    : oraclePrice_ - currentPrice_,
                10 ** priceDecimals_,
                oraclePrice_
            ),
            hundred_percent,
            10 ** priceDecimals_
        );

        require(deviation <= maxDeviation_, "maxDeviation");
    }

    function _includes(
        uint24 target,
        uint24[] memory set,
        uint256 upperIndex
    ) internal pure returns (bool) {
        require(set.length >= upperIndex, "OOR");
        for (uint256 j; j < upperIndex; j++) {
            if (set[j] == target) {
                return true;
            }
        }

        return false;
    }

    function _includesAddress(
        address target,
        address[] memory set,
        uint256 upperIndex
    ) internal pure returns (bool) {
        require(set.length >= upperIndex, "OOR");
        for (uint256 j; j < upperIndex; j++) {
            if (set[j] == target) {
                return true;
            }
        }

        return false;
    }
}
