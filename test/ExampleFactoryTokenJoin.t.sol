// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {
    ExampleFactoryTokenJoin
} from "../src/examples/ExampleFactoryTokenJoin.sol";
import {ExampleTokenJoin} from "../src/examples/ExampleTokenJoin.sol";
import {ExtensionCenter} from "../src/ExtensionCenter.sol";
import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/**
 * @title ExampleFactoryTokenJoinTest
 * @notice Test suite for ExampleFactoryTokenJoin
 */
contract ExampleFactoryTokenJoinTest is BaseExtensionTest {
    ExampleFactoryTokenJoin public factory;

    function setUp() public {
        setUpBase();

        factory = new ExampleFactoryTokenJoin(address(center));

        prepareFactoryRegistration(address(factory), address(token));
    }

    // ============================================
    // Constructor Tests
    // ============================================

    function test_Constructor() public view {
        assertEq(factory.CENTER_ADDRESS(), address(center));
    }

    // ============================================
    // CreateExtension Tests
    // ============================================

    function test_CreateExtension() public {
        address extension = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );

        assertTrue(extension != address(0));
        assertTrue(factory.exists(extension));
        assertEq(factory.extensionsCount(), 1);
        assertEq(factory.extensions()[0], extension);
    }

    function test_CreateExtension_RegistersInFactory() public {
        // Mint enough tokens for two extensions
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        address extension1 = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );
        address extension2 = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );

        assertEq(factory.extensionsCount(), 2);
        assertEq(factory.extensions()[0], extension1);
        assertEq(factory.extensions()[1], extension2);
        assertTrue(factory.exists(extension1));
        assertTrue(factory.exists(extension2));
    }

    function test_CreateExtension_TransfersTokens() public {
        uint256 balanceBefore = token.balanceOf(address(this));

        address extension = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );

        // Check that tokens were transferred to extension
        assertEq(token.balanceOf(extension), 1e18);
        assertEq(token.balanceOf(address(this)), balanceBefore - 1e18);
    }

    function test_CreateExtension_ReturnsExampleTokenJoin() public {
        address extension = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );

        ExampleTokenJoin exampleExtension = ExampleTokenJoin(extension);
        assertEq(exampleExtension.TOKEN_ADDRESS(), address(token));
        assertEq(exampleExtension.JOIN_TOKEN_ADDRESS(), address(joinToken));
        assertEq(exampleExtension.WAITING_BLOCKS(), WAITING_BLOCKS);
        assertEq(exampleExtension.FACTORY_ADDRESS(), address(factory));
    }

    function test_CreateExtension_MultipleExtensions() public {
        token.mint(address(this), 10e18);
        token.approve(address(factory), type(uint256).max);

        address extension1 = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );
        address extension2 = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS + 50
        );
        address extension3 = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS + 100
        );

        assertEq(factory.extensionsCount(), 3);

        ExampleTokenJoin ext1 = ExampleTokenJoin(extension1);
        ExampleTokenJoin ext2 = ExampleTokenJoin(extension2);
        ExampleTokenJoin ext3 = ExampleTokenJoin(extension3);

        assertEq(ext1.WAITING_BLOCKS(), WAITING_BLOCKS);
        assertEq(ext2.WAITING_BLOCKS(), WAITING_BLOCKS + 50);
        assertEq(ext3.WAITING_BLOCKS(), WAITING_BLOCKS + 100);
    }

    // ============================================
    // ExtensionParams Tests
    // ============================================

    function test_ExtensionParams_ReturnsCorrectValues() public {
        address extension = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );

        (
            address tokenAddress,
            address joinTokenAddress,
            uint256 waitingBlocks
        ) = factory.extensionParams(extension);

        assertEq(tokenAddress, address(token));
        assertEq(joinTokenAddress, address(joinToken));
        assertEq(waitingBlocks, WAITING_BLOCKS);
    }

    function test_ExtensionParams_MultipleExtensions() public {
        token.mint(address(this), 10e18);
        token.approve(address(factory), type(uint256).max);

        address extension1 = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );
        address extension2 = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS + 50
        );

        (
            address tokenAddr1,
            address joinTokenAddr1,
            uint256 waitingBlocks1
        ) = factory.extensionParams(extension1);

        (
            address tokenAddr2,
            address joinTokenAddr2,
            uint256 waitingBlocks2
        ) = factory.extensionParams(extension2);

        assertEq(tokenAddr1, address(token));
        assertEq(joinTokenAddr1, address(joinToken));
        assertEq(waitingBlocks1, WAITING_BLOCKS);

        assertEq(tokenAddr2, address(token));
        assertEq(joinTokenAddr2, address(joinToken));
        assertEq(waitingBlocks2, WAITING_BLOCKS + 50);
    }

    function test_ExtensionParams_NonExistentExtension() public view {
        (
            address tokenAddress,
            address joinTokenAddress,
            uint256 waitingBlocks
        ) = factory.extensionParams(address(0x9999));

        assertEq(tokenAddress, address(0));
        assertEq(joinTokenAddress, address(0));
        assertEq(waitingBlocks, 0);
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_Integration_CreateAndUseExtension() public {
        address extension = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );

        ExampleTokenJoin exampleExtension = ExampleTokenJoin(extension);

        // Verify extension is properly initialized
        assertEq(exampleExtension.TOKEN_ADDRESS(), address(token));
        assertEq(exampleExtension.JOIN_TOKEN_ADDRESS(), address(joinToken));
        assertEq(exampleExtension.WAITING_BLOCKS(), WAITING_BLOCKS);
        assertEq(exampleExtension.FACTORY_ADDRESS(), address(factory));

        // Verify factory can retrieve params
        (
            address tokenAddress,
            address joinTokenAddress,
            uint256 waitingBlocks
        ) = factory.extensionParams(extension);

        assertEq(tokenAddress, address(token));
        assertEq(joinTokenAddress, address(joinToken));
        assertEq(waitingBlocks, WAITING_BLOCKS);
    }

    function test_Integration_DifferentTokens() public {
        MockERC20 token2 = new MockERC20();
        MockERC20 joinToken2 = new MockERC20();

        // Mark tokens as LOVE20Token for ExtensionBase validation
        launch.setLOVE20Token(address(token2), true);
        launch.setLOVE20Token(address(joinToken2), true);

        token2.mint(address(this), 1e18);
        token2.approve(address(factory), type(uint256).max);

        address extension1 = factory.createExtension(
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );
        address extension2 = factory.createExtension(
            address(token2),
            address(joinToken2),
            WAITING_BLOCKS + 50
        );

        (
            address tokenAddr1,
            address joinTokenAddr1,
            uint256 waitingBlocks1
        ) = factory.extensionParams(extension1);

        (
            address tokenAddr2,
            address joinTokenAddr2,
            uint256 waitingBlocks2
        ) = factory.extensionParams(extension2);

        assertEq(tokenAddr1, address(token));
        assertEq(joinTokenAddr1, address(joinToken));
        assertEq(waitingBlocks1, WAITING_BLOCKS);

        assertEq(tokenAddr2, address(token2));
        assertEq(joinTokenAddr2, address(joinToken2));
        assertEq(waitingBlocks2, WAITING_BLOCKS + 50);
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_CreateExtension_ZeroWaitingBlocks() public {
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        address extension = factory.createExtension(
            address(token),
            address(joinToken),
            0
        );

        ExampleTokenJoin exampleExtension = ExampleTokenJoin(extension);
        assertEq(exampleExtension.WAITING_BLOCKS(), 0);
    }

    function test_CreateExtension_LargeWaitingBlocks() public {
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        uint256 largeWaitingBlocks = type(uint256).max;
        address extension = factory.createExtension(
            address(token),
            address(joinToken),
            largeWaitingBlocks
        );

        ExampleTokenJoin exampleExtension = ExampleTokenJoin(extension);
        assertEq(exampleExtension.WAITING_BLOCKS(), largeWaitingBlocks);
    }
}
