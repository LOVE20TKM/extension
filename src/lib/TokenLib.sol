// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    IUniswapV2Pair
} from "@core/uniswap-v2-core/interfaces/IUniswapV2Pair.sol";
import {
    IUniswapV2Factory
} from "@core/uniswap-v2-core/interfaces/IUniswapV2Factory.sol";

library TokenLib {
    function isLpTokenFromFactory(
        address lpToken,
        address factoryAddress
    ) internal view returns (bool) {
        if (lpToken.code.length == 0) return false;
        if (factoryAddress.code.length == 0) return false;

        address token0;
        address token1;
        try IUniswapV2Pair(lpToken).token0() returns (address t0) {
            try IUniswapV2Pair(lpToken).token1() returns (address t1) {
                if (t0 == address(0) || t1 == address(0) || t0 == t1)
                    return false;

                token0 = t0;
                token1 = t1;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
        try IUniswapV2Factory(factoryAddress).getPair(token0, token1) returns (
            address expectedPair
        ) {
            return expectedPair == lpToken;
        } catch {
            return false;
        }
    }

    function isLpTokenContainsToken(
        address lpToken,
        address token
    ) internal view returns (bool) {
        if (lpToken.code.length == 0) return false;

        try IUniswapV2Pair(lpToken).token0() returns (address t0) {
            try IUniswapV2Pair(lpToken).token1() returns (address t1) {
                return t0 == token || t1 == token;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }
}
