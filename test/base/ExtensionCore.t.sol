// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "../utils/BaseExtensionTest.sol";
import {LOVE20ExtensionBaseJoin} from "../../src/LOVE20ExtensionBaseJoin.sol";
import {IExtensionCore} from "../../src/interface/base/IExtensionCore.sol";
import {IExtensionReward} from "../../src/interface/base/IExtensionReward.sol";
import {ExtensionReward} from "../../src/base/ExtensionReward.sol";
import {MockExtensionFactory} from "../mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockExtensionForCore
 * @notice Mock extension for testing ExtensionCore
 */
contract MockExtensionForCore is LOVE20ExtensionBaseJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(
        address factory_,
        address tokenAddress_
    ) LOVE20ExtensionBaseJoin(factory_, tokenAddress_) {}

    function isJoinedValueCalculated() external pure override returns (bool) {
        return false;
    }

    function joinedValue() external pure override returns (uint256) {
        return 0;
    }

    function joinedValueByAccount(
        address
    ) external pure override returns (uint256) {
        return 0;
    }

    function rewardByAccount(
        uint256,
        address
    )
        public
        pure
        override(IExtensionReward, ExtensionReward)
        returns (uint256 reward, bool isMinted)
    {
        return (0, false);
    }

    function _calculateReward(
        uint256,
        address
    ) internal pure override returns (uint256) {
        return 0;
    }
}

/**
 * @title ExtensionCoreTest
 * @notice Test suite for ExtensionCore
 * @dev Tests constructor, initialization, and view functions
 */
contract ExtensionCoreTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockExtensionForCore public extension;

    function setUp() public {
        setUpBase();

        mockFactory = new MockExtensionFactory(address(center));
        extension = new MockExtensionForCore(
            address(mockFactory),
            address(token)
        );

        registerFactory(address(token), address(mockFactory));
        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension), address(token));
    }

    // ============================================
    // Constructor Tests
    // ============================================

    function test_Constructor_StoresFactory() public view {
        assertEq(
            extension.factory(),
            address(mockFactory),
            "Factory should be stored"
        );
    }

    function test_Constructor_RetrievesCenter() public view {
        assertEq(
            extension.center(),
            address(center),
            "Center should be retrieved from factory"
        );
    }

    function test_Constructor_NotInitialized() public view {
        assertFalse(
            extension.initialized(),
            "Should not be initialized at construction"
        );
    }

    function test_Constructor_TokenAddressSet() public view {
        assertEq(
            extension.tokenAddress(),
            address(token),
            "Token address should be set at construction"
        );
    }

    function test_Constructor_ActionIdZero() public view {
        assertEq(
            extension.actionId(),
            0,
            "Action ID should be zero before init"
        );
    }

    // ============================================
    // Initialize Tests
    // ============================================

    function test_Initialize_Success() public {
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(new string[](0));

        assertTrue(extension.initialized(), "Should be initialized");
        assertEq(
            extension.tokenAddress(),
            address(token),
            "Token address should be set"
        );
        assertEq(extension.actionId(), ACTION_ID, "Action ID should be set");
    }

    // ============================================
    // View Functions Tests
    // ============================================

    function test_Center_ReturnsCorrectAddress() public view {
        assertEq(extension.center(), address(center));
    }

    function test_Factory_ReturnsCorrectAddress() public view {
        assertEq(extension.factory(), address(mockFactory));
    }

    function test_TokenAddress_SetAtConstruction() public view {
        // tokenAddress is now set at construction, not at initialization
        assertEq(extension.tokenAddress(), address(token));
    }

    function test_TokenAddress_AfterInit() public {
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(extension.tokenAddress(), address(token));
    }

    function test_ActionId_BeforeInit() public view {
        assertEq(extension.actionId(), 0);
    }

    function test_ActionId_AfterInit() public {
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(extension.actionId(), ACTION_ID);
    }

    function test_Initialized_BeforeInit() public view {
        assertFalse(extension.initialized());
    }

    function test_Initialized_AfterInit() public {
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(new string[](0));

        assertTrue(extension.initialized());
    }

    // ============================================
    // Multiple Extensions Tests
    // ============================================

    function test_MultipleExtensions_IndependentInit() public {
        MockExtensionForCore extension2 = new MockExtensionForCore(
            address(mockFactory),
            address(token)
        );
        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension2), address(token));

        // Setup first extension
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Setup second extension with different action ID
        submit.setActionInfo(
            address(token),
            ACTION_ID + 1,
            address(extension2)
        );
        token.mint(address(extension2), 1e18);
        vote.setVotedActionIds(
            address(token),
            join.currentRound(),
            ACTION_ID + 1
        );

        // First extension auto-initializes when user joins
        vm.prank(user1);
        extension.join(new string[](0));

        // Second extension auto-initializes when user joins
        vm.prank(user1);
        extension2.join(new string[](0));

        // Verify both are independently initialized
        assertTrue(extension.initialized());
        assertTrue(extension2.initialized());
        assertEq(extension.actionId(), ACTION_ID);
        assertEq(extension2.actionId(), ACTION_ID + 1);
    }
}
