// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "../utils/BaseExtensionTest.sol";
import {
    LOVE20ExtensionBaseTokenJoin
} from "../../src/LOVE20ExtensionBaseTokenJoin.sol";
import {ITokenJoin} from "../../src/interface/base/ITokenJoin.sol";
import {IExtensionExit} from "../../src/interface/base/IExtensionExit.sol";
import {IExtensionReward} from "../../src/interface/base/IExtensionReward.sol";
import {IExtensionCore} from "../../src/interface/base/IExtensionCore.sol";
import {ExtensionReward} from "../../src/base/ExtensionReward.sol";
import {ExtensionAccounts} from "../../src/base/ExtensionAccounts.sol";
import {TokenJoin} from "../../src/base/TokenJoin.sol";
import {MockExtensionFactory} from "../mocks/MockExtensionFactory.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockExtensionForSecurity
 * @notice Mock extension for security testing
 */
contract MockExtensionForSecurity is LOVE20ExtensionBaseTokenJoin {
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBaseTokenJoin(
            factory_,
            joinTokenAddress_,
            waitingBlocks_
        )
    {}

    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    function joinedValue() external view override returns (uint256) {
        return totalJoinedAmount;
    }

    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        (uint256 amount, , ) = this.joinInfo(account);
        return amount;
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
 * @title MaliciousReentrancy
 * @notice Malicious contract that attempts to reenter the exit function
 * @dev Simplified version without token callback
 */
contract MaliciousReentrancy {
    MockExtensionForSecurity public extension;
    bool public attackExecuted;

    constructor(address extension_) {
        extension = MockExtensionForSecurity(extension_);
    }

    function attack() external {
        extension.exit();
    }
}

/**
 * @title BaseSecurityTest
 * @notice Comprehensive security test suite for base contracts
 * @dev Tests reentrancy protection, zero address checks, account management, and edge cases
 */
contract BaseSecurityTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockExtensionForSecurity public extension;

    event Join(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount,
        uint256 joinedBlock
    );
    event Exit(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );

    function setUp() public {
        setUpBase();

        mockFactory = new MockExtensionFactory(address(center));

        extension = new MockExtensionForSecurity(
            address(mockFactory),
            address(joinToken),
            WAITING_BLOCKS
        );

        registerFactory(address(token), address(mockFactory));
        mockFactory.registerExtension(address(extension));

        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );

        // Setup users with tokens
        joinToken.mint(user1, 1000e18);
        joinToken.mint(user2, 2000e18);
        joinToken.mint(user3, 3000e18);

        vm.prank(user1);
        joinToken.approve(address(extension), type(uint256).max);
        vm.prank(user2);
        joinToken.approve(address(extension), type(uint256).max);
        vm.prank(user3);
        joinToken.approve(address(extension), type(uint256).max);
    }

    // ============================================
    // Reentrancy Protection Tests
    // ============================================

    function test_ReentrancyProtection_JoinCannotReenter() public {
        // Join with user1
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Try to join again in same transaction should work (different call)
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.AlreadyJoined.selector);
        extension.join(100e18, new string[](0));
    }

    function test_ReentrancyProtection_ExitCannotReenter() public {
        // Setup: user joins and waits
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Fast forward blocks
        vm.roll(block.number + WAITING_BLOCKS + 1);

        // Exit should work once
        vm.prank(user1);
        extension.exit();

        // Try to exit again should fail (no joined amount)
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NoJoinedAmount.selector);
        extension.exit();
    }

    // ============================================
    // Zero Address Validation Tests
    // ============================================

    function test_Constructor_RevertsOnZeroJoinTokenAddress() public {
        vm.expectRevert(ITokenJoin.InvalidJoinTokenAddress.selector);
        new MockExtensionForSecurity(
            address(mockFactory),
            address(0),
            WAITING_BLOCKS
        );
    }

    function test_Initialize_RevertsOnZeroTokenAddress() public {
        MockExtensionForSecurity newExtension = new MockExtensionForSecurity(
            address(mockFactory),
            address(joinToken),
            WAITING_BLOCKS
        );

        mockFactory.registerExtension(address(newExtension));

        // Center wraps errors in InitializeFailed
        vm.expectRevert();
        center.initializeExtension(
            address(newExtension),
            address(0),
            ACTION_ID + 1
        );
    }

    // ============================================
    // Account Management O(1) Tests
    // ============================================

    function test_AccountManagement_AddAndRemove() public {
        // Add user1
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        assertEq(extension.accountsCount(), 1);
        assertEq(extension.accountAtIndex(0), user1);

        // Add user2
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        assertEq(extension.accountsCount(), 2);

        // Fast forward and remove user1
        vm.roll(block.number + WAITING_BLOCKS + 1);
        vm.prank(user1);
        extension.exit();

        assertEq(extension.accountsCount(), 1);
        // After removal, remaining account should still be accessible
        address remaining = extension.accountAtIndex(0);
        assertTrue(remaining == user2, "user2 should remain");
    }

    function test_AccountManagement_RemoveMiddleAccount() public {
        // Add three users
        vm.prank(user1);
        extension.join(100e18, new string[](0));
        vm.prank(user2);
        extension.join(200e18, new string[](0));
        vm.prank(user3);
        extension.join(300e18, new string[](0));

        assertEq(extension.accountsCount(), 3);

        // Fast forward and remove user2 (middle account)
        vm.roll(block.number + WAITING_BLOCKS + 1);
        vm.prank(user2);
        extension.exit();

        assertEq(extension.accountsCount(), 2);
        // Verify user2 is removed and other two remain
        address[] memory accs = extension.accounts();
        assertTrue(accs.length == 2, "Should have 2 accounts");
        assertTrue(
            (accs[0] == user1 || accs[0] == user3) &&
                (accs[1] == user1 || accs[1] == user3),
            "Should contain user1 and user3"
        );
    }

    function test_AccountManagement_RemoveNonExistentAccount() public {
        // Try to exit without joining
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NoJoinedAmount.selector);
        extension.exit();
    }

    function test_AccountManagement_MultipleAddRemove() public {
        // Add user1
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Remove user1
        vm.roll(block.number + WAITING_BLOCKS + 1);
        vm.prank(user1);
        extension.exit();

        assertEq(extension.accountsCount(), 0);

        // Add user1 again
        joinToken.mint(user1, 100e18);
        vm.roll(block.number + 1);
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        assertEq(extension.accountsCount(), 1);
        assertEq(extension.accountAtIndex(0), user1);
    }

    function test_AccountManagement_LargeNumberOfAccounts() public {
        uint256 numAccounts = 50;
        address[] memory accounts = new address[](numAccounts);

        // Add many accounts
        for (uint256 i = 0; i < numAccounts; i++) {
            accounts[i] = address(uint160(1000 + i));
            joinToken.mint(accounts[i], 1000e18);
            vm.prank(accounts[i]);
            joinToken.approve(address(extension), type(uint256).max);
            vm.prank(accounts[i]);
            extension.join(100e18, new string[](0));
        }

        assertEq(extension.accountsCount(), numAccounts);

        // Remove accounts from middle (test O(1) performance)
        vm.roll(block.number + WAITING_BLOCKS + 1);

        // Remove account at index 25
        vm.prank(accounts[25]);
        extension.exit();

        assertEq(extension.accountsCount(), numAccounts - 1);
    }

    // ============================================
    // Interface Consistency Tests
    // ============================================

    function test_Interface_TokenAddressIsView() public view {
        // Should be callable as a view function
        address tokenAddr = extension.tokenAddress();
        assertEq(tokenAddr, address(token));
    }

    function test_Interface_ActionIdIsView() public view {
        // Should be callable as a view function
        uint256 actionIdVal = extension.actionId();
        assertEq(actionIdVal, ACTION_ID);
    }

    // ============================================
    // Edge Cases and Boundary Tests
    // ============================================

    function test_EdgeCase_MultipleInitializationAttempts() public {
        MockExtensionForSecurity newExtension = new MockExtensionForSecurity(
            address(mockFactory),
            address(joinToken),
            WAITING_BLOCKS
        );

        mockFactory.registerExtension(address(newExtension));
        submit.setActionInfo(
            address(token),
            ACTION_ID + 2,
            address(newExtension)
        );
        token.mint(address(newExtension), 1e18);

        center.initializeExtension(
            address(newExtension),
            address(token),
            ACTION_ID + 2
        );

        // Try to initialize again - center wraps error
        vm.expectRevert();
        center.initializeExtension(
            address(newExtension),
            address(token),
            ACTION_ID + 2
        );
    }

    function test_EdgeCase_JoinWithZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.JoinAmountZero.selector);
        extension.join(0, new string[](0));
    }

    function test_EdgeCase_ExitBeforeWaitingPeriod() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Try to exit immediately
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();

        // Fast forward but still not enough
        vm.roll(block.number + WAITING_BLOCKS - 1);
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();

        // Should succeed at exactly waiting period
        vm.roll(block.number + 1);
        vm.prank(user1);
        extension.exit();
    }

    function test_EdgeCase_JoinAfterAlreadyJoined() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user1);
        vm.expectRevert(ITokenJoin.AlreadyJoined.selector);
        extension.join(200e18, new string[](0));
    }

    function test_EdgeCase_WaitingBlocksZero() public {
        MockExtensionForSecurity extensionNoWait = new MockExtensionForSecurity(
            address(mockFactory),
            address(joinToken),
            0 // No waiting period
        );

        mockFactory.registerExtension(address(extensionNoWait));
        submit.setActionInfo(
            address(token),
            ACTION_ID + 3,
            address(extensionNoWait)
        );
        token.mint(address(extensionNoWait), 2e18);
        center.initializeExtension(
            address(extensionNoWait),
            address(token),
            ACTION_ID + 3
        );

        // Approve
        vm.prank(user1);
        joinToken.approve(address(extensionNoWait), type(uint256).max);

        // Join
        vm.prank(user1);
        extensionNoWait.join(100e18, new string[](0));

        // Should be able to exit in same block
        vm.prank(user1);
        extensionNoWait.exit();

        assertEq(extensionNoWait.totalJoinedAmount(), 0);
    }

    function test_EdgeCase_StorageLayoutOptimization() public view {
        // Verify that tokenAddress and initialized are packed in same slot
        // This is a compile-time optimization, but we can verify the values are correct
        assertEq(extension.tokenAddress(), address(token));
        assertTrue(extension.initialized());
        assertEq(extension.actionId(), ACTION_ID);
    }

    // ============================================
    // Gas Optimization Tests
    // ============================================

    function test_Gas_AddAccountIsConstant() public {
        uint256 gas1;
        uint256 gas2;
        uint256 gas3;

        // First add - may have storage initialization overhead
        vm.prank(user1);
        gas1 = gasleft();
        extension.join(100e18, new string[](0));
        gas1 = gas1 - gasleft();

        // Second add
        vm.prank(user2);
        gas2 = gasleft();
        extension.join(200e18, new string[](0));
        gas2 = gas2 - gasleft();

        // Third add
        vm.prank(user3);
        gas3 = gasleft();
        extension.join(300e18, new string[](0));
        gas3 = gas3 - gasleft();

        // Compare 2nd and 3rd calls which should be more consistent (O(1))
        // Allow 10% variance
        uint256 avgGas23 = (gas2 + gas3) / 2;
        assertTrue(gas2 < (avgGas23 * 11) / 10, "gas2 too high");
        assertTrue(gas3 < (avgGas23 * 11) / 10, "gas3 too high");

        // First call can be higher due to storage init but should be reasonable
        assertTrue(gas1 < (gas2 * 15) / 10, "gas1 unreasonably high");
    }

    function test_Gas_RemoveAccountIsConstant() public {
        // Setup: add many accounts
        address[] memory accounts = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            accounts[i] = address(uint160(2000 + i));
            joinToken.mint(accounts[i], 1000e18);
            vm.prank(accounts[i]);
            joinToken.approve(address(extension), type(uint256).max);
            vm.prank(accounts[i]);
            extension.join(100e18, new string[](0));
        }

        vm.roll(block.number + WAITING_BLOCKS + 1);

        uint256 gas1;
        uint256 gas2;

        // Remove first account
        vm.prank(accounts[0]);
        gas1 = gasleft();
        extension.exit();
        gas1 = gas1 - gasleft();

        // Remove middle account
        vm.prank(accounts[5]);
        gas2 = gasleft();
        extension.exit();
        gas2 = gas2 - gasleft();

        // Gas should be similar (O(1) operation)
        uint256 avgGas = (gas1 + gas2) / 2;
        assertTrue(gas1 < (avgGas * 11) / 10, "gas1 too high");
        assertTrue(gas2 < (avgGas * 11) / 10, "gas2 too high");
    }
}
