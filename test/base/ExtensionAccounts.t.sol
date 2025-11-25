// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "../utils/BaseExtensionTest.sol";
import {LOVE20ExtensionBaseJoin} from "../../src/LOVE20ExtensionBaseJoin.sol";
import {
    IExtensionAccounts
} from "../../src/interface/base/IExtensionAccounts.sol";
import {IExtensionReward} from "../../src/interface/base/IExtensionReward.sol";
import {ExtensionReward} from "../../src/base/ExtensionReward.sol";
import {MockExtensionFactory} from "../mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockExtensionForAccounts
 * @notice Mock extension for testing ExtensionAccounts
 */
contract MockExtensionForAccounts is LOVE20ExtensionBaseJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address factory_) LOVE20ExtensionBaseJoin(factory_) {}

    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    function joinedValue() external view override returns (uint256) {
        return _accounts.length();
    }

    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        return _accounts.contains(account) ? 1 : 0;
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
 * @title ExtensionAccountsTest
 * @notice Test suite for ExtensionAccounts
 * @dev Tests account management with O(1) operations
 */
contract ExtensionAccountsTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockExtensionForAccounts public extension;

    function setUp() public {
        setUpBase();

        mockFactory = new MockExtensionFactory(address(center));
        extension = new MockExtensionForAccounts(address(mockFactory));

        registerFactory(address(token), address(mockFactory));
        mockFactory.registerExtension(address(extension));

        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );
    }

    // ============================================
    // Accounts View Tests
    // ============================================

    function test_Accounts_EmptyAtStart() public view {
        address[] memory accs = extension.accounts();
        assertEq(accs.length, 0, "Accounts should be empty initially");
    }

    function test_Accounts_AfterSingleJoin() public {
        vm.prank(user1);
        extension.join(new string[](0));

        address[] memory accs = extension.accounts();
        assertEq(accs.length, 1);
        assertEq(accs[0], user1);
    }

    function test_Accounts_AfterMultipleJoins() public {
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        address[] memory accs = extension.accounts();
        assertEq(accs.length, 3);
        assertEq(accs[0], user1);
        assertEq(accs[1], user2);
        assertEq(accs[2], user3);
    }

    // ============================================
    // AccountsCount Tests
    // ============================================

    function test_AccountsCount_Zero() public view {
        assertEq(extension.accountsCount(), 0);
    }

    function test_AccountsCount_One() public {
        vm.prank(user1);
        extension.join(new string[](0));
        assertEq(extension.accountsCount(), 1);
    }

    function test_AccountsCount_Multiple() public {
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        assertEq(extension.accountsCount(), 3);
    }

    function test_AccountsCount_AfterExit() public {
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));

        assertEq(extension.accountsCount(), 2);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.accountsCount(), 1);
    }

    // ============================================
    // AccountAtIndex Tests
    // ============================================

    function test_AccountAtIndex_SingleAccount() public {
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(extension.accountAtIndex(0), user1);
    }

    function test_AccountAtIndex_MultipleAccounts() public {
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        assertEq(extension.accountAtIndex(0), user1);
        assertEq(extension.accountAtIndex(1), user2);
        assertEq(extension.accountAtIndex(2), user3);
    }

    function test_AccountAtIndex_RevertsOutOfBounds() public {
        vm.prank(user1);
        extension.join(new string[](0));

        vm.expectRevert();
        extension.accountAtIndex(1);
    }

    // ============================================
    // Add/Remove Account Tests (via join/exit)
    // ============================================

    function test_AddAccount_AddsToSet() public {
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(extension.accountsCount(), 1);
        assertTrue(center.isAccountJoined(address(token), ACTION_ID, user1));
    }

    function test_AddAccount_UpdatesCenter() public {
        assertFalse(center.isAccountJoined(address(token), ACTION_ID, user1));

        vm.prank(user1);
        extension.join(new string[](0));

        assertTrue(center.isAccountJoined(address(token), ACTION_ID, user1));
    }

    function test_RemoveAccount_RemovesFromSet() public {
        vm.prank(user1);
        extension.join(new string[](0));

        vm.prank(user1);
        extension.exit();

        assertEq(extension.accountsCount(), 0);
    }

    function test_RemoveAccount_UpdatesCenter() public {
        vm.prank(user1);
        extension.join(new string[](0));
        assertTrue(center.isAccountJoined(address(token), ACTION_ID, user1));

        vm.prank(user1);
        extension.exit();

        assertFalse(center.isAccountJoined(address(token), ACTION_ID, user1));
    }

    function test_RemoveMiddleAccount_SwapsAndPops() public {
        // Add three accounts
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        assertEq(extension.accountsCount(), 3);

        // Remove middle account (user2)
        vm.prank(user2);
        extension.exit();

        assertEq(extension.accountsCount(), 2);

        // Verify remaining accounts
        address[] memory accs = extension.accounts();
        assertTrue(
            (accs[0] == user1 || accs[0] == user3) &&
                (accs[1] == user1 || accs[1] == user3),
            "Should contain user1 and user3"
        );
        assertTrue(accs[0] != accs[1], "Should be different accounts");
    }

    // ============================================
    // O(1) Gas Tests
    // ============================================

    function test_Gas_AddAccountIsConstant() public {
        uint256 gas1;
        uint256 gas2;
        uint256 gas3;

        vm.prank(user1);
        gas1 = gasleft();
        extension.join(new string[](0));
        gas1 = gas1 - gasleft();

        vm.prank(user2);
        gas2 = gasleft();
        extension.join(new string[](0));
        gas2 = gas2 - gasleft();

        vm.prank(user3);
        gas3 = gasleft();
        extension.join(new string[](0));
        gas3 = gas3 - gasleft();

        // Compare 2nd and 3rd calls which should be more consistent (O(1))
        uint256 avgGas23 = (gas2 + gas3) / 2;
        assertTrue(gas2 < (avgGas23 * 11) / 10, "gas2 too high");
        assertTrue(gas3 < (avgGas23 * 11) / 10, "gas3 too high");
    }

    function test_Gas_RemoveAccountIsConstant() public {
        // Add many accounts
        address[] memory accounts = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            accounts[i] = address(uint160(2000 + i));
            vm.prank(accounts[i]);
            extension.join(new string[](0));
        }

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

    // ============================================
    // Large Scale Tests
    // ============================================

    function test_LargeNumberOfAccounts() public {
        uint256 numAccounts = 50;
        address[] memory addrs = new address[](numAccounts);

        // Add many accounts
        for (uint256 i = 0; i < numAccounts; i++) {
            addrs[i] = address(uint160(1000 + i));
            vm.prank(addrs[i]);
            extension.join(new string[](0));
        }

        assertEq(extension.accountsCount(), numAccounts);

        // Verify all can be accessed
        for (uint256 i = 0; i < numAccounts; i++) {
            address acc = extension.accountAtIndex(i);
            assertEq(acc, addrs[i]);
        }
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_JoinExitRejoin() public {
        vm.prank(user1);
        extension.join(new string[](0));
        assertEq(extension.accountsCount(), 1);

        vm.prank(user1);
        extension.exit();
        assertEq(extension.accountsCount(), 0);

        vm.prank(user1);
        extension.join(new string[](0));
        assertEq(extension.accountsCount(), 1);
        assertEq(extension.accountAtIndex(0), user1);
    }

    function test_AllAccountsExit() public {
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        vm.prank(user1);
        extension.exit();
        vm.prank(user2);
        extension.exit();
        vm.prank(user3);
        extension.exit();

        assertEq(extension.accountsCount(), 0);
        address[] memory accs = extension.accounts();
        assertEq(accs.length, 0);
    }
}
