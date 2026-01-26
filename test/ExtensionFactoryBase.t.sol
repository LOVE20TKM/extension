// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {ExtensionFactoryBase} from "../src/ExtensionFactoryBase.sol";
import {
    IExtensionFactory,
    DEFAULT_JOIN_AMOUNT
} from "../src/interface/IExtensionFactory.sol";
import {ExtensionCenter} from "../src/ExtensionCenter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockExtension} from "./mocks/MockExtension.sol";
import {MockStake} from "./mocks/MockStake.sol";
import {MockJoin} from "./mocks/MockJoin.sol";
import {MockVerify} from "./mocks/MockVerify.sol";
import {MockMint} from "./mocks/MockMint.sol";
import {MockSubmit} from "./mocks/MockSubmit.sol";
import {MockLaunch} from "./mocks/MockLaunch.sol";
import {MockVote} from "./mocks/MockVote.sol";
import {MockRandom} from "./mocks/MockRandom.sol";
import {MockUniswapV2Factory} from "./mocks/MockUniswapV2Factory.sol";

/**
 * @title MockExtensionFactory
 * @notice Concrete implementation of ExtensionFactoryBase for testing
 */
contract MockExtensionFactoryForBaseTest is ExtensionFactoryBase {
    constructor(address center_) ExtensionFactoryBase(center_) {}

    function createExtension(address tokenAddress) external returns (address) {
        MockExtension extension = new MockExtension(
            address(this),
            tokenAddress
        );
        _registerExtension(address(extension), tokenAddress);
        return address(extension);
    }
}

/**
 * @title ExtensionFactoryBaseTest
 * @notice Test suite for ExtensionFactoryBase
 */
contract ExtensionFactoryBaseTest is Test {
    MockExtensionFactoryForBaseTest public factory;
    ExtensionCenter public center;
    MockERC20 public token;
    MockStake public stake;
    MockJoin public join;
    MockVerify public verify;
    MockMint public mint;
    MockSubmit public submit;
    MockLaunch public launch;
    MockVote public vote;
    MockRandom public random;
    MockUniswapV2Factory public uniswapFactory;

    function setUp() public {
        // Deploy mock contracts
        stake = new MockStake();
        join = new MockJoin();
        verify = new MockVerify();
        mint = new MockMint();
        submit = new MockSubmit();
        launch = new MockLaunch();
        vote = new MockVote();
        random = new MockRandom();
        uniswapFactory = new MockUniswapV2Factory();

        // Deploy ExtensionCenter
        center = new ExtensionCenter(
            address(uniswapFactory),
            address(launch),
            address(stake),
            address(submit),
            address(vote),
            address(join),
            address(verify),
            address(mint),
            address(random)
        );

        // Initialize current round
        verify.setCurrentRound(0);

        factory = new MockExtensionFactoryForBaseTest(address(center));
        token = new MockERC20();
        
        // Mark token as LOVE20Token for ExtensionBase validation
        launch.setLOVE20Token(address(token), true);
    }

    // ============================================
    // Constructor Tests
    // ============================================

    function test_Constructor() public view {
        assertEq(factory.CENTER_ADDRESS(), address(center));
    }

    // ============================================
    // Extensions List Tests
    // ============================================

    function test_Extensions_Empty() public view {
        address[] memory extensions = factory.extensions();
        assertEq(extensions.length, 0);
        assertEq(factory.extensionsCount(), 0);
    }

    function test_Extensions_SingleExtension() public {
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        address extension = factory.createExtension(address(token));

        address[] memory extensions = factory.extensions();
        assertEq(extensions.length, 1);
        assertEq(extensions[0], extension);
        assertEq(factory.extensionsCount(), 1);
    }

    function test_Extensions_MultipleExtensions() public {
        token.mint(address(this), 10e18);
        token.approve(address(factory), type(uint256).max);

        address extension1 = factory.createExtension(address(token));
        address extension2 = factory.createExtension(address(token));
        address extension3 = factory.createExtension(address(token));

        address[] memory extensions = factory.extensions();
        assertEq(extensions.length, 3);
        assertEq(extensions[0], extension1);
        assertEq(extensions[1], extension2);
        assertEq(extensions[2], extension3);
        assertEq(factory.extensionsCount(), 3);
    }

    // ============================================
    // ExtensionsAtIndex Tests
    // ============================================

    function test_ExtensionsAtIndex_SingleExtension() public {
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        address extension = factory.createExtension(address(token));

        assertEq(factory.extensionsAtIndex(0), extension);
    }

    function test_ExtensionsAtIndex_MultipleExtensions() public {
        token.mint(address(this), 10e18);
        token.approve(address(factory), type(uint256).max);

        address extension1 = factory.createExtension(address(token));
        address extension2 = factory.createExtension(address(token));
        address extension3 = factory.createExtension(address(token));

        assertEq(factory.extensionsAtIndex(0), extension1);
        assertEq(factory.extensionsAtIndex(1), extension2);
        assertEq(factory.extensionsAtIndex(2), extension3);
    }

    function test_ExtensionsAtIndex_RevertIfOutOfBounds() public {
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        factory.createExtension(address(token));

        vm.expectRevert();
        factory.extensionsAtIndex(1);
    }

    // ============================================
    // Exists Tests
    // ============================================

    function test_Exists_NonExistentExtension() public view {
        assertFalse(factory.exists(address(0x9999)));
    }

    function test_Exists_RegisteredExtension() public {
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        address extension = factory.createExtension(address(token));

        assertTrue(factory.exists(extension));
    }

    function test_Exists_MultipleExtensions() public {
        token.mint(address(this), 10e18);
        token.approve(address(factory), type(uint256).max);

        address extension1 = factory.createExtension(address(token));
        address extension2 = factory.createExtension(address(token));
        address extension3 = factory.createExtension(address(token));

        assertTrue(factory.exists(extension1));
        assertTrue(factory.exists(extension2));
        assertTrue(factory.exists(extension3));
        assertFalse(factory.exists(address(0x9999)));
    }

    // ============================================
    // RegisterExtension Tests
    // ============================================

    function test_RegisterExtension_TransfersTokens() public {
        uint256 amount = 1e18;
        token.mint(address(this), amount);
        token.approve(address(factory), type(uint256).max);

        address extension = factory.createExtension(address(token));

        // Check that tokens were transferred to extension
        assertEq(token.balanceOf(extension), DEFAULT_JOIN_AMOUNT);
        assertEq(token.balanceOf(address(this)), amount - DEFAULT_JOIN_AMOUNT);
    }

    function test_RegisterExtension_RegistersExtension() public {
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        address extension = factory.createExtension(address(token));

        assertTrue(factory.exists(extension));
        assertEq(factory.extensionsCount(), 1);
        assertEq(factory.extensions()[0], extension);
    }

    function test_RegisterExtension_MultipleRegistrations() public {
        token.mint(address(this), 10e18);
        token.approve(address(factory), type(uint256).max);

        address extension1 = factory.createExtension(address(token));
        address extension2 = factory.createExtension(address(token));
        address extension3 = factory.createExtension(address(token));

        assertEq(factory.extensionsCount(), 3);
        assertTrue(factory.exists(extension1));
        assertTrue(factory.exists(extension2));
        assertTrue(factory.exists(extension3));
    }

    function test_RegisterExtension_RevertIfInsufficientBalance() public {
        token.mint(address(this), DEFAULT_JOIN_AMOUNT - 1);
        token.approve(address(factory), type(uint256).max);

        vm.expectRevert();
        factory.createExtension(address(token));
    }

    function test_RegisterExtension_RevertIfInsufficientAllowance() public {
        token.mint(address(this), 1e18);
        token.approve(address(factory), DEFAULT_JOIN_AMOUNT - 1);

        vm.expectRevert();
        factory.createExtension(address(token));
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_Extensions_AfterManyRegistrations() public {
        token.mint(address(this), 100e18);
        token.approve(address(factory), type(uint256).max);

        address[] memory createdExtensions = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            createdExtensions[i] = factory.createExtension(address(token));
        }

        address[] memory extensions = factory.extensions();
        assertEq(extensions.length, 10);

        for (uint256 i = 0; i < 10; i++) {
            assertEq(extensions[i], createdExtensions[i]);
            assertTrue(factory.exists(createdExtensions[i]));
            assertEq(factory.extensionsAtIndex(i), createdExtensions[i]);
        }
    }
}
