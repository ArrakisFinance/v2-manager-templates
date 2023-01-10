// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    IArrakisV2,
    Range,
    Rebalance
} from "@arrakisfi/v2-core/contracts/interfaces/IArrakisV2.sol";
import {FullMath, IDecimals, IUniswapV3Pool, Twap} from "./libraries/Twap.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";

import {hundred_percent, ten_percent} from "./constants/CSimpleManagerTWAP.sol";


contract SimpleManagerTWAP is Ownable {
    using SafeERC20 for IERC20;

    struct VaultInfo {
        IUniswapV3Pool twapOracle;
        int24 twapDeviation;
        uint24 twapDuration;
        uint24 maxSlippage;
    }

    struct SetupParams {
        address vault;
        uint24 twapFeeTier;
        int24 twapDeviation;
        uint24 twapDuration;
        uint24 maxSlippage;
    }

    IUniswapV3Factory public immutable uniFactory;
    uint16 public immutable managerFeeBPS;

    mapping(address => VaultInfo) public vaults;

    event RebalanceVault(address vault, address caller);

    modifier onlyVaultOwner(address vault) {
        require(msg.sender == IOwnable(vault).owner(), "NO");
        _;
    }

    constructor(IUniswapV3Factory uniFactory_, uint16 managerFeeBPS_) {
        uniFactory = uniFactory_;
        managerFeeBPS = managerFeeBPS_;
    }

    function initManagement(
        SetupParams calldata params
    ) external onlyVaultOwner(params.vault) {
        require(params.twapDeviation > 0, "DN");
        require(address(this) == IArrakisV2(params.vault).manager(), "NM");
        require(address(vaults[params.vault].twapOracle) == address(0), "AV");
        /// @dev 10% max slippage allowed by the manager.
        require(params.maxSlippage <= ten_percent, "MS");

        IUniswapV3Pool pool = IUniswapV3Pool(
            _getPool(
                address(IArrakisV2(params.vault).token0()),
                address(IArrakisV2(params.vault).token1()),
                params.twapFeeTier
            )
        );

        vaults[params.vault] = VaultInfo({
            twapOracle: pool,
            twapDeviation: params.twapDeviation,
            twapDuration: params.twapDuration,
            maxSlippage: params.maxSlippage
        });
    }

    // solhint-disable-next-line function-max-lines
    function rebalance(
        address vault_,
        Range[] calldata ranges_,
        Rebalance calldata rebalanceParams_,
        Range[] calldata rangesToRemove_
    ) external onlyOwner {
        VaultInfo memory vaultInfo = vaults[vault_];

        address token0 = address(IArrakisV2(vault_).token0());
        address token1 = address(IArrakisV2(vault_).token1());

        // check twap deviation for all fee tiers with deposits
        uint24[] memory checked = new uint24[](
            rebalanceParams_.deposits.length
        );
        uint256 increment;
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

            Twap.checkDeviation(
                pool,
                vaultInfo.twapDuration,
                vaultInfo.twapDeviation
            );
            checked[increment] = rebalanceParams_.deposits[i].range.feeTier;
            increment++;
        }

        // check expectedMinReturn on rebalance swap against twap
        if (rebalanceParams_.swap.amountIn > 0) {
            _checkMinReturn(
                rebalanceParams_,
                vaultInfo.twapOracle,
                vaultInfo.twapDuration,
                vaultInfo.maxSlippage,
                IDecimals(token0).decimals(),
                IDecimals(token1).decimals()
            );
        }

        IArrakisV2(vault_).rebalance(
            ranges_,
            rebalanceParams_,
            rangesToRemove_
        );

        emit RebalanceVault(vault_, msg.sender);
    }

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

    function _checkMinReturn(
        Rebalance memory rebalanceParams_,
        IUniswapV3Pool twapOracle,
        uint24 twapDuration,
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
                        Twap.getPrice0(twapOracle, twapDuration),
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
                        Twap.getPrice1(twapOracle, twapDuration),
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
