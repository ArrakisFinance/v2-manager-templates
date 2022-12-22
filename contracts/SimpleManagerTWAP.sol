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
import {
    FullMath,
    IDecimals,
    IUniswapV3Pool,
    Twap
} from "./libraries/Twap.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";

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

    IUniswapV3Factory immutable public uniFactory;
    uint16 immutable public managerFeeBPS;

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

    function initManagement(SetupParams calldata params) external onlyVaultOwner(params.vault) {
        require(params.twapDeviation > 0, "DN");
        require(address(this) == IArrakisV2(params.vault).manager(), "NM");
        require(address(vaults[params.vault].twapOracle) == address(0), "AV");
        address pool = uniFactory.getPool(
            address(IArrakisV2(params.vault).token0()),
            address(IArrakisV2(params.vault).token1()),
            params.twapFeeTier
        );
        require(pool != address(0), "NP");

        vaults[params.vault] = VaultInfo({
            twapOracle: IUniswapV3Pool(pool),
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
        require(address(vaultInfo.twapOracle) != address(0), "NV");

        address token0 = address(IArrakisV2(vault_).token0());
        address token1 = address(IArrakisV2(vault_).token1());

        // check twap deviation for all fee tiers with deposits
        uint24[] memory checked = new uint24[](0);
        for (uint256 i; i < rebalanceParams_.deposits.length; i++) {
            if (!_includes(rebalanceParams_.deposits[i].range.feeTier, checked)) {
                IUniswapV3Pool pool = IUniswapV3Pool(uniFactory.getPool(
                    token0,
                    token1,
                    rebalanceParams_.deposits[i].range.feeTier
                ));

                Twap.checkDeviation(pool, vaultInfo.twapDuration, vaultInfo.twapDeviation);
                checked[checked.length] = rebalanceParams_.deposits[i].range.feeTier;
            }
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

    function withdrawCollectedFees(IERC20[] calldata tokens, address target_) external onlyOwner {
        for (uint256 i; i < tokens.length; i++) {
            tokens[i].safeTransfer(target_, tokens[i].balanceOf(address(this)));
        }
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
                    10**decimals0,
                    rebalanceParams_.swap.amountIn
                ) >
                    FullMath.mulDiv(
                        Twap.getPrice0(twapOracle, twapDuration),
                        maxSlippage,
                        10000
                    ),
                "S0"
            );
        } else {
            require(
                FullMath.mulDiv(
                    rebalanceParams_.swap.expectedMinReturn,
                    10**decimals1,
                    rebalanceParams_.swap.amountIn
                ) >
                    FullMath.mulDiv(
                        Twap.getPrice0(twapOracle, twapDuration),
                        maxSlippage,
                        10000
                    ),
                "S1"
            );
        }
    }

    function _includes(uint24 target, uint24[] memory set) internal pure returns (bool) {
        for (uint256 j; j < set.length; j++) {
            if (set[j] == target) {
                return true;
            }
        }

        return false;
    }
}
