// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {RoundHistoryAddressSet} from "../../src/lib/RoundHistoryAddressSet.sol";

using RoundHistoryAddressSet for RoundHistoryAddressSet.Storage;

/**
 * @title MockRoundHistoryAddressSetConsumer
 * @notice Mock contract to test RoundHistoryAddressSet library
 */
contract MockRoundHistoryAddressSetConsumer {
    mapping(address => mapping(uint256 => RoundHistoryAddressSet.Storage))
        internal _storage;

    function add(
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 currentRound
    ) external {
        _storage[tokenAddress][actionId].add(currentRound, account);
    }

    function remove(
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 currentRound
    ) external {
        _storage[tokenAddress][actionId].remove(currentRound, account);
    }

    function values(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address[] memory) {
        return _storage[tokenAddress][actionId].values();
    }

    function count(
        address tokenAddress,
        uint256 actionId
    ) external view returns (uint256) {
        return _storage[tokenAddress][actionId].count();
    }

    function atIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index
    ) external view returns (address) {
        return _storage[tokenAddress][actionId].atIndex(index);
    }

    function valuesByRound(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view returns (address[] memory) {
        return _storage[tokenAddress][actionId].valuesByRound(round);
    }

    function countByRound(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view returns (uint256) {
        return _storage[tokenAddress][actionId].countByRound(round);
    }

    function atIndexByRound(
        address tokenAddress,
        uint256 actionId,
        uint256 index,
        uint256 round
    ) external view returns (address) {
        return _storage[tokenAddress][actionId].atIndexByRound(index, round);
    }

    function contains(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (bool) {
        return _storage[tokenAddress][actionId].contains(account);
    }

    function containsByRound(
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 round
    ) external view returns (bool) {
        return _storage[tokenAddress][actionId].containsByRound(account, round);
    }
}

/**
 * @title RoundHistoryAddressSetTest
 * @notice Test suite for RoundHistoryAddressSet library
 */
contract RoundHistoryAddressSetTest is Test {
    MockRoundHistoryAddressSetConsumer public consumer;

    address public tokenAddress = address(0x2001);
    uint256 public actionId = 1;

    address public account1 = address(0x1001);
    address public account2 = address(0x1002);
    address public account3 = address(0x1003);
    address public account4 = address(0x1004);
    address public account5 = address(0x1005);

    function setUp() public {
        consumer = new MockRoundHistoryAddressSetConsumer();
    }

    // ============================================
    // AddAccount Tests
    // ============================================

    function test_AddAccount_SingleAccount() public {
        consumer.add(tokenAddress, actionId, account1, 1);

        assertEq(consumer.count(tokenAddress, actionId), 1);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 1);
        assertEq(accounts[0], account1);
        assertEq(consumer.atIndex(tokenAddress, actionId, 0), account1);
    }

    function test_AddAccount_MultipleAccounts() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        assertEq(consumer.count(tokenAddress, actionId), 3);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 3);
        assertEq(accounts[0], account1);
        assertEq(accounts[1], account2);
        assertEq(accounts[2], account3);
    }

    function test_AddAccount_DifferentRounds() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 2);
        consumer.add(tokenAddress, actionId, account3, 3);

        assertEq(consumer.count(tokenAddress, actionId), 3);

        // Check round 1
        assertEq(consumer.countByRound(tokenAddress, actionId, 1), 1);
        address[] memory round1Accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(round1Accounts.length, 1);
        assertEq(round1Accounts[0], account1);

        // Check round 2
        assertEq(consumer.countByRound(tokenAddress, actionId, 2), 2);
        address[] memory round2Accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            2
        );
        assertEq(round2Accounts.length, 2);
        assertEq(round2Accounts[0], account1);
        assertEq(round2Accounts[1], account2);

        // Check round 3
        assertEq(consumer.countByRound(tokenAddress, actionId, 3), 3);
    }

    function test_AddAccount_EmptyList() public view {
        assertEq(consumer.count(tokenAddress, actionId), 0);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 0);
    }

    // ============================================
    // RemoveAccount Tests
    // ============================================

    function test_RemoveAccount_SingleAccount() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.remove(tokenAddress, actionId, account1, 2);

        assertEq(consumer.count(tokenAddress, actionId), 0);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 0);
    }

    function test_RemoveAccount_LastAccount() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        consumer.remove(tokenAddress, actionId, account3, 2);

        assertEq(consumer.count(tokenAddress, actionId), 2);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 2);
        assertEq(accounts[0], account1);
        assertEq(accounts[1], account2);
    }

    function test_RemoveAccount_MiddleAccount() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        consumer.remove(tokenAddress, actionId, account2, 2);

        assertEq(consumer.count(tokenAddress, actionId), 2);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 2);
        assertEq(accounts[0], account1);
        assertEq(accounts[1], account3);
    }

    function test_RemoveAccount_FirstAccount() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        consumer.remove(tokenAddress, actionId, account1, 2);

        assertEq(consumer.count(tokenAddress, actionId), 2);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 2);
        assertEq(accounts[0], account3); // account3 swapped to index 0
        assertEq(accounts[1], account2);
    }

    function test_RemoveAccount_MultipleRemovals() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);
        consumer.add(tokenAddress, actionId, account4, 1);
        consumer.add(tokenAddress, actionId, account5, 1);

        consumer.remove(tokenAddress, actionId, account2, 2);
        consumer.remove(tokenAddress, actionId, account4, 3);

        assertEq(consumer.count(tokenAddress, actionId), 3);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 3);
        assertEq(accounts[0], account1);
        assertEq(accounts[1], account5); // swapped from index 4
        assertEq(accounts[2], account3);
    }

    function test_RemoveAccount_HistoryPreserved() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        // Remove in round 2
        consumer.remove(tokenAddress, actionId, account2, 2);

        // Round 1 should still have 3 accounts
        assertEq(consumer.countByRound(tokenAddress, actionId, 1), 3);
        address[] memory round1Accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(round1Accounts.length, 3);
        assertEq(round1Accounts[0], account1);
        assertEq(round1Accounts[1], account2);
        assertEq(round1Accounts[2], account3);

        // Round 2 should have 2 accounts
        assertEq(consumer.countByRound(tokenAddress, actionId, 2), 2);
        address[] memory round2Accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            2
        );
        assertEq(round2Accounts.length, 2);
        assertEq(round2Accounts[0], account1);
        assertEq(round2Accounts[1], account3);
    }

    // ============================================
    // Query Tests
    // ============================================

    function test_AccountsCount_Empty() public view {
        assertEq(consumer.count(tokenAddress, actionId), 0);
    }

    function test_Accounts_Empty() public view {
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 0);
    }

    function test_AccountsAtIndex_OutOfBounds() public {
        consumer.add(tokenAddress, actionId, account1, 1);

        // Should return address(0) for out of bounds
        assertEq(consumer.atIndex(tokenAddress, actionId, 1), address(0));
    }

    function test_AccountsByRound_Empty() public view {
        address[] memory accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(accounts.length, 0);
        assertEq(consumer.countByRound(tokenAddress, actionId, 1), 0);
    }

    function test_AccountsByRound_ExactRound() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 2);

        address[] memory round1Accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(round1Accounts.length, 2);
        assertEq(round1Accounts[0], account1);
        assertEq(round1Accounts[1], account2);

        address[] memory round2Accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            2
        );
        assertEq(round2Accounts.length, 3);
        assertEq(round2Accounts[0], account1);
        assertEq(round2Accounts[1], account2);
        assertEq(round2Accounts[2], account3);
    }

    function test_AccountsByRound_BetweenRounds() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 5);
        consumer.add(tokenAddress, actionId, account3, 10);

        // Query round 3 (between 1 and 5) should return round 1 state
        address[] memory round3Accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            3
        );
        assertEq(round3Accounts.length, 1);
        assertEq(round3Accounts[0], account1);

        // Query round 7 (between 5 and 10) should return round 5 state
        address[] memory round7Accounts = consumer.valuesByRound(
            tokenAddress,
            actionId,
            7
        );
        assertEq(round7Accounts.length, 2);
        assertEq(round7Accounts[0], account1);
        assertEq(round7Accounts[1], account2);
    }

    function test_AccountsByRoundAtIndex() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 2);

        assertEq(
            consumer.atIndexByRound(tokenAddress, actionId, 0, 1),
            account1
        );
        assertEq(
            consumer.atIndexByRound(tokenAddress, actionId, 1, 1),
            account2
        );
        assertEq(
            consumer.atIndexByRound(tokenAddress, actionId, 0, 2),
            account1
        );
        assertEq(
            consumer.atIndexByRound(tokenAddress, actionId, 2, 2),
            account3
        );
    }

    // ============================================
    // Multiple TokenAddress/ActionId Tests
    // ============================================

    function test_MultipleTokenAddresses() public {
        address tokenAddress2 = address(0x2002);

        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress2, actionId, account2, 1);

        assertEq(consumer.count(tokenAddress, actionId), 1);
        assertEq(consumer.count(tokenAddress2, actionId), 1);

        address[] memory accounts1 = consumer.values(tokenAddress, actionId);
        address[] memory accounts2 = consumer.values(tokenAddress2, actionId);

        assertEq(accounts1.length, 1);
        assertEq(accounts1[0], account1);
        assertEq(accounts2.length, 1);
        assertEq(accounts2[0], account2);
    }

    function test_MultipleActionIds() public {
        uint256 actionId2 = 2;

        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId2, account2, 1);

        assertEq(consumer.count(tokenAddress, actionId), 1);
        assertEq(consumer.count(tokenAddress, actionId2), 1);

        address[] memory accounts1 = consumer.values(tokenAddress, actionId);
        address[] memory accounts2 = consumer.values(tokenAddress, actionId2);

        assertEq(accounts1.length, 1);
        assertEq(accounts1[0], account1);
        assertEq(accounts2.length, 1);
        assertEq(accounts2[0], account2);
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_AddRemoveAdd_SameAccount() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.remove(tokenAddress, actionId, account1, 2);
        consumer.add(tokenAddress, actionId, account1, 3);

        assertEq(consumer.count(tokenAddress, actionId), 1);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 1);
        assertEq(accounts[0], account1);
    }

    function test_RemoveAllAccounts() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        consumer.remove(tokenAddress, actionId, account1, 2);
        consumer.remove(tokenAddress, actionId, account3, 3);
        consumer.remove(tokenAddress, actionId, account2, 4);

        assertEq(consumer.count(tokenAddress, actionId), 0);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, 0);
    }

    function test_LargeNumberOfAccounts() public {
        uint256 count = 50;
        address[] memory testAccounts = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            testAccounts[i] = address(uint160(0x3000 + i));
            consumer.add(tokenAddress, actionId, testAccounts[i], 1);
        }

        assertEq(consumer.count(tokenAddress, actionId), count);
        address[] memory accounts = consumer.values(tokenAddress, actionId);
        assertEq(accounts.length, count);

        for (uint256 i = 0; i < count; i++) {
            assertEq(accounts[i], testAccounts[i]);
        }
    }

    function test_RemoveFromLargeList() public {
        uint256 count = 20;
        address[] memory testAccounts = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            testAccounts[i] = address(uint160(0x3000 + i));
            consumer.add(tokenAddress, actionId, testAccounts[i], 1);
        }

        // Remove middle account
        uint256 removeIndex = 10;
        consumer.remove(tokenAddress, actionId, testAccounts[removeIndex], 2);

        assertEq(consumer.count(tokenAddress, actionId), count - 1);
        address[] memory accounts = consumer.values(tokenAddress, actionId);

        // Last account should be swapped to removeIndex
        assertEq(accounts[removeIndex], testAccounts[count - 1]);
    }

    // ============================================
    // Contains Tests
    // ============================================

    function test_Contains_EmptyList() public view {
        assertFalse(consumer.contains(tokenAddress, actionId, account1));
    }

    function test_Contains_AfterAdd() public {
        assertFalse(consumer.contains(tokenAddress, actionId, account1));
        consumer.add(tokenAddress, actionId, account1, 1);
        assertTrue(consumer.contains(tokenAddress, actionId, account1));
    }

    function test_Contains_AfterRemove() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        assertTrue(consumer.contains(tokenAddress, actionId, account1));
        consumer.remove(tokenAddress, actionId, account1, 2);
        assertFalse(consumer.contains(tokenAddress, actionId, account1));
    }

    function test_Contains_MultipleAccounts() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        assertTrue(consumer.contains(tokenAddress, actionId, account1));
        assertTrue(consumer.contains(tokenAddress, actionId, account2));
        assertTrue(consumer.contains(tokenAddress, actionId, account3));
        assertFalse(consumer.contains(tokenAddress, actionId, account4));
    }

    function test_Contains_AfterMultipleRemovals() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        consumer.remove(tokenAddress, actionId, account2, 2);
        assertTrue(consumer.contains(tokenAddress, actionId, account1));
        assertFalse(consumer.contains(tokenAddress, actionId, account2));
        assertTrue(consumer.contains(tokenAddress, actionId, account3));

        consumer.remove(tokenAddress, actionId, account1, 3);
        assertFalse(consumer.contains(tokenAddress, actionId, account1));
        assertTrue(consumer.contains(tokenAddress, actionId, account3));
    }

    function test_Contains_AddRemoveAdd() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        assertTrue(consumer.contains(tokenAddress, actionId, account1));

        consumer.remove(tokenAddress, actionId, account1, 2);
        assertFalse(consumer.contains(tokenAddress, actionId, account1));

        consumer.add(tokenAddress, actionId, account1, 3);
        assertTrue(consumer.contains(tokenAddress, actionId, account1));
    }

    function test_Contains_MultipleTokenAddresses() public {
        address tokenAddress2 = address(0x2002);

        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress2, actionId, account1, 1);

        assertTrue(consumer.contains(tokenAddress, actionId, account1));
        assertTrue(consumer.contains(tokenAddress2, actionId, account1));
        assertFalse(consumer.contains(tokenAddress, actionId, account2));
    }

    function test_Contains_MultipleActionIds() public {
        uint256 actionId2 = 2;

        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId2, account1, 1);

        assertTrue(consumer.contains(tokenAddress, actionId, account1));
        assertTrue(consumer.contains(tokenAddress, actionId2, account1));
        assertFalse(consumer.contains(tokenAddress, actionId, account2));
    }

    // ============================================
    // ContainsByRound Tests
    // ============================================

    function test_ContainsByRound_EmptyList() public view {
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
    }

    function test_ContainsByRound_AfterAdd() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
    }

    function test_ContainsByRound_AfterRemove() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
        consumer.remove(tokenAddress, actionId, account1, 2);
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account1, 2)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
    }

    function test_ContainsByRound_MultipleRounds() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 2);
        consumer.add(tokenAddress, actionId, account3, 3);

        // Round 1
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account2, 1)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account3, 1)
        );

        // Round 2
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 2)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account2, 2)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account3, 2)
        );

        // Round 3
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 3)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account2, 3)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account3, 3)
        );
    }

    function test_ContainsByRound_HistoryPreserved() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);

        // Remove account2 in round 2
        consumer.remove(tokenAddress, actionId, account2, 2);

        // Round 1 should still contain account2
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account2, 1)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account3, 1)
        );

        // Round 2 should not contain account2
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 2)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account2, 2)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account3, 2)
        );
    }

    function test_ContainsByRound_BetweenRounds() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 5);
        consumer.add(tokenAddress, actionId, account3, 10);

        // Query round 3 (between 1 and 5) should return round 1 state
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 3)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account2, 3)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account3, 3)
        );

        // Query round 7 (between 5 and 10) should return round 5 state
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 7)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account2, 7)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account3, 7)
        );
    }

    function test_ContainsByRound_AfterMultipleRemovals() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, 1);
        consumer.add(tokenAddress, actionId, account3, 1);
        consumer.add(tokenAddress, actionId, account4, 1);

        consumer.remove(tokenAddress, actionId, account2, 2);
        consumer.remove(tokenAddress, actionId, account4, 3);

        // Round 1: all accounts present
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account2, 1)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account3, 1)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account4, 1)
        );

        // Round 2: account2 removed
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 2)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account2, 2)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account3, 2)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account4, 2)
        );

        // Round 3: account2 and account4 removed
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 3)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account2, 3)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account3, 3)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account4, 3)
        );
    }

    function test_ContainsByRound_AddRemoveAdd() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );

        consumer.remove(tokenAddress, actionId, account1, 2);
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account1, 2)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );

        consumer.add(tokenAddress, actionId, account1, 3);
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 3)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account1, 2)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
    }

    function test_ContainsByRound_MultipleTokenAddresses() public {
        address tokenAddress2 = address(0x2002);

        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress2, actionId, account1, 1);

        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress2, actionId, account1, 1)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account2, 1)
        );
    }

    function test_ContainsByRound_MultipleActionIds() public {
        uint256 actionId2 = 2;

        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId2, account1, 1);

        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId2, account1, 1)
        );
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account2, 1)
        );
    }

    function test_ContainsByRound_NonExistentRound() public {
        consumer.add(tokenAddress, actionId, account1, 5);
        // Query round 1 (before account was added) should return false
        assertFalse(
            consumer.containsByRound(tokenAddress, actionId, account1, 1)
        );
        // Query round 5 (when account was added) should return true
        assertTrue(
            consumer.containsByRound(tokenAddress, actionId, account1, 5)
        );
    }

    // ============================================
    // Extreme Round Value Tests
    // ============================================

    function test_Add_ExtremeRoundValue() public {
        consumer.add(tokenAddress, actionId, account1, type(uint256).max);

        assertEq(consumer.count(tokenAddress, actionId), 1);
        assertTrue(consumer.contains(tokenAddress, actionId, account1));
        assertTrue(
            consumer.containsByRound(
                tokenAddress,
                actionId,
                account1,
                type(uint256).max
            )
        );
    }

    function test_Remove_ExtremeRoundValue() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.remove(tokenAddress, actionId, account1, type(uint256).max);

        assertEq(consumer.count(tokenAddress, actionId), 0);
        assertFalse(consumer.contains(tokenAddress, actionId, account1));
    }

    function test_ValuesByRound_ExtremeRoundValue() public {
        consumer.add(tokenAddress, actionId, account1, 1);
        consumer.add(tokenAddress, actionId, account2, type(uint256).max);

        address[] memory round1 = consumer.valuesByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(round1.length, 1);
        assertEq(round1[0], account1);

        address[] memory roundMax = consumer.valuesByRound(
            tokenAddress,
            actionId,
            type(uint256).max
        );
        assertEq(roundMax.length, 2);
        assertEq(roundMax[0], account1);
        assertEq(roundMax[1], account2);
    }
}
