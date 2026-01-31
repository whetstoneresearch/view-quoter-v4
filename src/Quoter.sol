// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IQuoter} from "./interfaces/IQuoter.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {QuoterMath} from "./libraries/QuoterMath.sol";

contract Quoter is IQuoter {
    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    function quoteSingle(PoolKey memory poolKey, SwapParams memory swapParams)
        public
        view
        override
        returns (int256, int256, uint160, uint32)
    {
        return QuoterMath.quote(poolManager, poolKey, swapParams);
    }
}
