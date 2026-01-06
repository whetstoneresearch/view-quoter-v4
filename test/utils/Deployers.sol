// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {TestERC20} from "@uniswap/v4-core/src/test/TestERC20.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {V4PoolManagerDeployer} from "./hookmate/artifacts/V4PoolManager.sol";

/// @notice Minimal Deployers contract compatible with Solidity ^0.8.26
/// Uses hookmate for PoolManager deployment to avoid pragma version conflicts
contract Deployers is Test {
    using LPFeeLibrary for uint24;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // Constants
    bytes internal constant ZERO_BYTES = new bytes(0);
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint160 internal constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 internal constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    // Global variables
    Currency internal currency0;
    Currency internal currency1;
    IPoolManager internal manager;
    PoolModifyLiquidityTest internal modifyLiquidityRouter;
    PoolSwapTest internal swapRouter;
    PoolKey internal key;

    function deployFreshManagerAndRouters() internal {
        // Deploy PoolManager using hookmate
        manager = IPoolManager(V4PoolManagerDeployer.deploy(address(this)));

        swapRouter = new PoolSwapTest(manager);
        modifyLiquidityRouter = new PoolModifyLiquidityTest(manager);
    }

    function deployMintAndApprove2Currencies() internal returns (Currency, Currency) {
        TestERC20[] memory tokens = new TestERC20[](2);

        for (uint256 i = 0; i < 2; i++) {
            tokens[i] = new TestERC20(2 ** 128);
            // Mint a large amount but avoid overflow with the initial supply
            tokens[i].mint(address(this), type(uint128).max);

            address[3] memory toApprove = [
                address(swapRouter),
                address(modifyLiquidityRouter),
                address(manager)
            ];

            for (uint256 j = 0; j < toApprove.length; j++) {
                tokens[i].approve(toApprove[j], type(uint256).max);
            }
        }

        // Sort tokens
        if (address(tokens[0]) > address(tokens[1])) {
            (tokens[0], tokens[1]) = (tokens[1], tokens[0]);
        }

        currency0 = Currency.wrap(address(tokens[0]));
        currency1 = Currency.wrap(address(tokens[1]));

        return (currency0, currency1);
    }

    function initPoolAndAddLiquidity(
        Currency _currency0,
        Currency _currency1,
        IHooks hooks,
        uint24 fee,
        uint160 sqrtPriceX96,
        bytes memory /* initData */
    ) internal returns (PoolKey memory _key, PoolId id) {
        int24 tickSpacing = fee.isDynamicFee() ? int24(60) : int24(fee / 50);
        _key = PoolKey(_currency0, _currency1, fee, tickSpacing, hooks);
        id = _key.toId();

        manager.initialize(_key, sqrtPriceX96);

        // Add single liquidity position to match v4-core behavior
        modifyLiquidityRouter.modifyLiquidity(
            _key,
            ModifyLiquidityParams({tickLower: -120, tickUpper: 120, liquidityDelta: 1e18, salt: 0}),
            ZERO_BYTES
        );

        return (_key, id);
    }

    function swap(PoolKey memory _key, bool zeroForOne, int256 amountSpecified, bytes memory hookData)
        internal
        returns (BalanceDelta)
    {
        return swapRouter.swap(
            _key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            hookData
        );
    }
}
