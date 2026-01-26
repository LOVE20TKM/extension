// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {TokenLib} from "../../src/lib/TokenLib.sol";
import {MockUniswapV2Factory} from "../mocks/MockUniswapV2Factory.sol";
import {MockUniswapV2Pair} from "../mocks/MockUniswapV2Pair.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/**
 * @title MockTokenLibConsumer
 * @notice Mock contract to test TokenLib library functions
 */
contract MockTokenLibConsumer {
    function isLpTokenFromFactory(
        address lpToken,
        address factoryAddress
    ) external view returns (bool) {
        return TokenLib.isLpTokenFromFactory(lpToken, factoryAddress);
    }

    function isLpTokenContainsToken(
        address lpToken,
        address token
    ) external view returns (bool) {
        return TokenLib.isLpTokenContainsToken(lpToken, token);
    }
}

/**
 * @title TokenLibTest
 * @notice Test suite for TokenLib library
 */
contract TokenLibTest is Test {
    MockTokenLibConsumer public consumer;
    MockUniswapV2Factory public factory;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public tokenC;
    MockUniswapV2Pair public pairAB;
    MockUniswapV2Pair public pairAC;
    MockUniswapV2Pair public pairBC;

    function setUp() public {
        consumer = new MockTokenLibConsumer();
        factory = new MockUniswapV2Factory();

        tokenA = new MockERC20();
        tokenB = new MockERC20();
        tokenC = new MockERC20();

        pairAB = MockUniswapV2Pair(
            factory.createPair(address(tokenA), address(tokenB))
        );
        pairAC = MockUniswapV2Pair(
            factory.createPair(address(tokenA), address(tokenC))
        );
        pairBC = MockUniswapV2Pair(
            factory.createPair(address(tokenB), address(tokenC))
        );
    }

    // ============================================
    // isLpTokenFromFactory Tests
    // ============================================

    function test_isLpTokenFromFactory_ValidPair() public view {
        bool result = consumer.isLpTokenFromFactory(
            address(pairAB),
            address(factory)
        );
        assertTrue(result, "Valid pair should return true");
    }

    function test_isLpTokenFromFactory_InvalidFactory() public view {
        address invalidFactory = address(0x123);
        bool result = consumer.isLpTokenFromFactory(
            address(pairAB),
            invalidFactory
        );
        assertFalse(result, "Invalid factory should return false");
    }

    function test_isLpTokenFromFactory_EOAAddress() public view {
        address eoa = address(0x456);
        bool result = consumer.isLpTokenFromFactory(eoa, address(factory));
        assertFalse(result, "EOA address should return false");
    }

    function test_isLpTokenFromFactory_ZeroAddress() public view {
        bool result = consumer.isLpTokenFromFactory(
            address(0),
            address(factory)
        );
        assertFalse(result, "Zero address should return false");
    }

    function test_isLpTokenFromFactory_NonPairContract() public {
        MockERC20 nonPair = new MockERC20();
        bool result = consumer.isLpTokenFromFactory(
            address(nonPair),
            address(factory)
        );
        assertFalse(result, "Non-pair contract should return false");
    }

    function test_isLpTokenFromFactory_WrongFactory() public {
        MockUniswapV2Factory otherFactory = new MockUniswapV2Factory();
        bool result = consumer.isLpTokenFromFactory(
            address(pairAB),
            address(otherFactory)
        );
        assertFalse(result, "Pair from different factory should return false");
    }

    function test_isLpTokenFromFactory_AllPairs() public view {
        assertTrue(
            consumer.isLpTokenFromFactory(address(pairAB), address(factory)),
            "pairAB should be valid"
        );
        assertTrue(
            consumer.isLpTokenFromFactory(address(pairAC), address(factory)),
            "pairAC should be valid"
        );
        assertTrue(
            consumer.isLpTokenFromFactory(address(pairBC), address(factory)),
            "pairBC should be valid"
        );
    }

    function test_isLpTokenFromFactory_EOAFactory() public view {
        address eoaFactory = address(0x789);
        bool result = consumer.isLpTokenFromFactory(
            address(pairAB),
            eoaFactory
        );
        assertFalse(result, "EOA factory should return false");
    }

    // ============================================
    // isLpTokenContainsToken Tests
    // ============================================

    function test_isLpTokenContainsToken_ContainsToken0() public view {
        bool result = consumer.isLpTokenContainsToken(
            address(pairAB),
            address(tokenA)
        );
        assertTrue(
            result,
            "Pair containing tokenA as token0 should return true"
        );
    }

    function test_isLpTokenContainsToken_ContainsToken1() public view {
        bool result = consumer.isLpTokenContainsToken(
            address(pairAB),
            address(tokenB)
        );
        assertTrue(
            result,
            "Pair containing tokenB as token1 should return true"
        );
    }

    function test_isLpTokenContainsToken_DoesNotContain() public view {
        bool result = consumer.isLpTokenContainsToken(
            address(pairAB),
            address(tokenC)
        );
        assertFalse(result, "Pair not containing tokenC should return false");
    }

    function test_isLpTokenContainsToken_EOAAddress() public view {
        address eoa = address(0x999);
        bool result = consumer.isLpTokenContainsToken(eoa, address(tokenA));
        assertFalse(result, "EOA address should return false");
    }

    function test_isLpTokenContainsToken_ZeroAddress() public view {
        bool result = consumer.isLpTokenContainsToken(
            address(0),
            address(tokenA)
        );
        assertFalse(result, "Zero address should return false");
    }

    function test_isLpTokenContainsToken_NonPairContract() public {
        MockERC20 nonPair = new MockERC20();
        bool result = consumer.isLpTokenContainsToken(
            address(nonPair),
            address(tokenA)
        );
        assertFalse(result, "Non-pair contract should return false");
    }

    function test_isLpTokenContainsToken_AllPairs() public view {
        assertTrue(
            consumer.isLpTokenContainsToken(address(pairAB), address(tokenA)),
            "pairAB should contain tokenA"
        );
        assertTrue(
            consumer.isLpTokenContainsToken(address(pairAB), address(tokenB)),
            "pairAB should contain tokenB"
        );
        assertTrue(
            consumer.isLpTokenContainsToken(address(pairAC), address(tokenA)),
            "pairAC should contain tokenA"
        );
        assertTrue(
            consumer.isLpTokenContainsToken(address(pairAC), address(tokenC)),
            "pairAC should contain tokenC"
        );
        assertFalse(
            consumer.isLpTokenContainsToken(address(pairAB), address(tokenC)),
            "pairAB should not contain tokenC"
        );
    }

    function test_isLpTokenContainsToken_ZeroToken() public view {
        bool result = consumer.isLpTokenContainsToken(
            address(pairAB),
            address(0)
        );
        assertFalse(result, "Zero token address should return false");
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_isLpTokenFromFactory_PairWithZeroToken0() public {
        MockUniswapV2Pair badPair = new MockUniswapV2Pair(
            address(0),
            address(tokenA)
        );
        bool result = consumer.isLpTokenFromFactory(
            address(badPair),
            address(factory)
        );
        assertFalse(result, "Pair with zero token0 should return false");
    }

    function test_isLpTokenFromFactory_PairWithZeroToken1() public {
        MockUniswapV2Pair badPair = new MockUniswapV2Pair(
            address(tokenA),
            address(0)
        );
        bool result = consumer.isLpTokenFromFactory(
            address(badPair),
            address(factory)
        );
        assertFalse(result, "Pair with zero token1 should return false");
    }

    function test_isLpTokenFromFactory_PairWithSameTokens() public {
        MockUniswapV2Pair badPair = new MockUniswapV2Pair(
            address(tokenA),
            address(tokenA)
        );
        bool result = consumer.isLpTokenFromFactory(
            address(badPair),
            address(factory)
        );
        assertFalse(result, "Pair with same tokens should return false");
    }

    function test_isLpTokenContainsToken_PairWithZeroToken0_ContainsTarget()
        public
    {
        // If pair has zero token0 but token1 is the target, it should return true
        // because the function only checks if pair contains the target token
        MockUniswapV2Pair badPair = new MockUniswapV2Pair(
            address(0),
            address(tokenA)
        );
        bool result = consumer.isLpTokenContainsToken(
            address(badPair),
            address(tokenA)
        );
        assertTrue(
            result,
            "Pair with zero token0 but token1 is target should return true"
        );
    }

    function test_isLpTokenContainsToken_PairWithZeroToken1_ContainsTarget()
        public
    {
        // If pair has zero token1 but token0 is the target, it should return true
        MockUniswapV2Pair badPair = new MockUniswapV2Pair(
            address(tokenA),
            address(0)
        );
        bool result = consumer.isLpTokenContainsToken(
            address(badPair),
            address(tokenA)
        );
        assertTrue(
            result,
            "Pair with zero token1 but token0 is target should return true"
        );
    }

    function test_isLpTokenContainsToken_PairWithZeroToken0_DoesNotContainTarget()
        public
    {
        // If pair has zero token0 and token1 is not the target, it should return false
        MockUniswapV2Pair badPair = new MockUniswapV2Pair(
            address(0),
            address(tokenB)
        );
        bool result = consumer.isLpTokenContainsToken(
            address(badPair),
            address(tokenA)
        );
        assertFalse(
            result,
            "Pair with zero token0 and token1 is not target should return false"
        );
    }
}
