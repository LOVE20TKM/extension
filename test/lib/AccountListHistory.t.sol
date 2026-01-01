// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {AccountListHistory} from "../../src/lib/AccountListHistory.sol";

using AccountListHistory for AccountListHistory.Storage;

/**
 * @title MockAccountListHistoryConsumer
 * @notice Mock contract to test AccountListHistory library
 */
contract MockAccountListHistoryConsumer {
    AccountListHistory.Storage internal _storage;

    function addAccount(
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 currentRound
    ) external {
        _storage.addAccount(tokenAddress, actionId, account, currentRound);
    }

    function removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 currentRound
    ) external {
        _storage.removeAccount(tokenAddress, actionId, account, currentRound);
    }

    function accounts(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address[] memory) {
        return _storage.accounts(tokenAddress, actionId);
    }

    function accountsCount(
        address tokenAddress,
        uint256 actionId
    ) external view returns (uint256) {
        return _storage.accountsCount(tokenAddress, actionId);
    }

    function accountsAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index
    ) external view returns (address) {
        return _storage.accountsAtIndex(tokenAddress, actionId, index);
    }

    function accountsByRound(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view returns (address[] memory) {
        return _storage.accountsByRound(tokenAddress, actionId, round);
    }

    function accountsCountByRound(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view returns (uint256) {
        return _storage.accountsCountByRound(tokenAddress, actionId, round);
    }

    function accountsByRoundAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index,
        uint256 round
    ) external view returns (address) {
        return
            _storage.accountsByRoundAtIndex(
                tokenAddress,
                actionId,
                index,
                round
            );
    }

    function accountIndex(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (uint256) {
        return _storage.accountIndex(tokenAddress, actionId, account);
    }
}

/**
 * @title AccountListHistoryTest
 * @notice Test suite for AccountListHistory library
 */
contract AccountListHistoryTest is Test {
    MockAccountListHistoryConsumer public consumer;

    address public tokenAddress = address(0x2001);
    uint256 public actionId = 1;

    address public account1 = address(0x1001);
    address public account2 = address(0x1002);
    address public account3 = address(0x1003);
    address public account4 = address(0x1004);
    address public account5 = address(0x1005);

    function setUp() public {
        consumer = new MockAccountListHistoryConsumer();
    }

    // ============================================
    // AddAccount Tests
    // ============================================

    function test_AddAccount_SingleAccount() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 1);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 1);
        assertEq(accounts[0], account1);
        assertEq(consumer.accountsAtIndex(tokenAddress, actionId, 0), account1);
        assertEq(consumer.accountIndex(tokenAddress, actionId, account1), 0);
    }

    function test_AddAccount_MultipleAccounts() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 1);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 3);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 3);
        assertEq(accounts[0], account1);
        assertEq(accounts[1], account2);
        assertEq(accounts[2], account3);

        assertEq(consumer.accountIndex(tokenAddress, actionId, account1), 0);
        assertEq(consumer.accountIndex(tokenAddress, actionId, account2), 1);
        assertEq(consumer.accountIndex(tokenAddress, actionId, account3), 2);
    }

    function test_AddAccount_DifferentRounds() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 2);
        consumer.addAccount(tokenAddress, actionId, account3, 3);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 3);

        // Check round 1
        assertEq(consumer.accountsCountByRound(tokenAddress, actionId, 1), 1);
        address[] memory round1Accounts = consumer.accountsByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(round1Accounts.length, 1);
        assertEq(round1Accounts[0], account1);

        // Check round 2
        assertEq(consumer.accountsCountByRound(tokenAddress, actionId, 2), 2);
        address[] memory round2Accounts = consumer.accountsByRound(
            tokenAddress,
            actionId,
            2
        );
        assertEq(round2Accounts.length, 2);
        assertEq(round2Accounts[0], account1);
        assertEq(round2Accounts[1], account2);

        // Check round 3
        assertEq(consumer.accountsCountByRound(tokenAddress, actionId, 3), 3);
    }

    function test_AddAccount_EmptyList() public view {
        assertEq(consumer.accountsCount(tokenAddress, actionId), 0);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 0);
    }

    // ============================================
    // RemoveAccount Tests
    // ============================================

    function test_RemoveAccount_SingleAccount() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.removeAccount(tokenAddress, actionId, account1, 2);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 0);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 0);
        assertEq(
            consumer.accountIndex(tokenAddress, actionId, account1),
            type(uint256).max
        );
    }

    function test_RemoveAccount_LastAccount() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 1);

        consumer.removeAccount(tokenAddress, actionId, account3, 2);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 2);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 2);
        assertEq(accounts[0], account1);
        assertEq(accounts[1], account2);
        assertEq(
            consumer.accountIndex(tokenAddress, actionId, account3),
            type(uint256).max
        );
    }

    function test_RemoveAccount_MiddleAccount() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 1);

        consumer.removeAccount(tokenAddress, actionId, account2, 2);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 2);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 2);
        assertEq(accounts[0], account1);
        assertEq(accounts[1], account3);

        // account3 should now be at index 1 (swapped from index 2)
        assertEq(consumer.accountIndex(tokenAddress, actionId, account3), 1);
        assertEq(
            consumer.accountIndex(tokenAddress, actionId, account2),
            type(uint256).max
        );
    }

    function test_RemoveAccount_FirstAccount() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 1);

        consumer.removeAccount(tokenAddress, actionId, account1, 2);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 2);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 2);
        assertEq(accounts[0], account3); // account3 swapped to index 0
        assertEq(accounts[1], account2);

        assertEq(consumer.accountIndex(tokenAddress, actionId, account3), 0);
        assertEq(consumer.accountIndex(tokenAddress, actionId, account2), 1);
        assertEq(
            consumer.accountIndex(tokenAddress, actionId, account1),
            type(uint256).max
        );
    }

    function test_RemoveAccount_MultipleRemovals() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 1);
        consumer.addAccount(tokenAddress, actionId, account4, 1);
        consumer.addAccount(tokenAddress, actionId, account5, 1);

        consumer.removeAccount(tokenAddress, actionId, account2, 2);
        consumer.removeAccount(tokenAddress, actionId, account4, 3);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 3);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 3);
        assertEq(accounts[0], account1);
        assertEq(accounts[1], account5); // swapped from index 4
        assertEq(accounts[2], account3);
    }

    function test_RemoveAccount_HistoryPreserved() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 1);

        // Remove in round 2
        consumer.removeAccount(tokenAddress, actionId, account2, 2);

        // Round 1 should still have 3 accounts
        assertEq(consumer.accountsCountByRound(tokenAddress, actionId, 1), 3);
        address[] memory round1Accounts = consumer.accountsByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(round1Accounts.length, 3);
        assertEq(round1Accounts[0], account1);
        assertEq(round1Accounts[1], account2);
        assertEq(round1Accounts[2], account3);

        // Round 2 should have 2 accounts
        assertEq(consumer.accountsCountByRound(tokenAddress, actionId, 2), 2);
        address[] memory round2Accounts = consumer.accountsByRound(
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
        assertEq(consumer.accountsCount(tokenAddress, actionId), 0);
    }

    function test_Accounts_Empty() public view {
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 0);
    }

    function test_AccountsAtIndex_OutOfBounds() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);

        // Should return address(0) for out of bounds
        assertEq(
            consumer.accountsAtIndex(tokenAddress, actionId, 1),
            address(0)
        );
    }

    function test_AccountsByRound_Empty() public view {
        address[] memory accounts = consumer.accountsByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(accounts.length, 0);
        assertEq(consumer.accountsCountByRound(tokenAddress, actionId, 1), 0);
    }

    function test_AccountsByRound_ExactRound() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 2);

        address[] memory round1Accounts = consumer.accountsByRound(
            tokenAddress,
            actionId,
            1
        );
        assertEq(round1Accounts.length, 2);
        assertEq(round1Accounts[0], account1);
        assertEq(round1Accounts[1], account2);

        address[] memory round2Accounts = consumer.accountsByRound(
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
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 5);
        consumer.addAccount(tokenAddress, actionId, account3, 10);

        // Query round 3 (between 1 and 5) should return round 1 state
        address[] memory round3Accounts = consumer.accountsByRound(
            tokenAddress,
            actionId,
            3
        );
        assertEq(round3Accounts.length, 1);
        assertEq(round3Accounts[0], account1);

        // Query round 7 (between 5 and 10) should return round 5 state
        address[] memory round7Accounts = consumer.accountsByRound(
            tokenAddress,
            actionId,
            7
        );
        assertEq(round7Accounts.length, 2);
        assertEq(round7Accounts[0], account1);
        assertEq(round7Accounts[1], account2);
    }

    function test_AccountsByRoundAtIndex() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 2);

        assertEq(
            consumer.accountsByRoundAtIndex(tokenAddress, actionId, 0, 1),
            account1
        );
        assertEq(
            consumer.accountsByRoundAtIndex(tokenAddress, actionId, 1, 1),
            account2
        );
        assertEq(
            consumer.accountsByRoundAtIndex(tokenAddress, actionId, 0, 2),
            account1
        );
        assertEq(
            consumer.accountsByRoundAtIndex(tokenAddress, actionId, 2, 2),
            account3
        );
    }

    // ============================================
    // Multiple TokenAddress/ActionId Tests
    // ============================================

    function test_MultipleTokenAddresses() public {
        address tokenAddress2 = address(0x2002);

        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress2, actionId, account2, 1);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 1);
        assertEq(consumer.accountsCount(tokenAddress2, actionId), 1);

        address[] memory accounts1 = consumer.accounts(tokenAddress, actionId);
        address[] memory accounts2 = consumer.accounts(tokenAddress2, actionId);

        assertEq(accounts1.length, 1);
        assertEq(accounts1[0], account1);
        assertEq(accounts2.length, 1);
        assertEq(accounts2[0], account2);
    }

    function test_MultipleActionIds() public {
        uint256 actionId2 = 2;

        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId2, account2, 1);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 1);
        assertEq(consumer.accountsCount(tokenAddress, actionId2), 1);

        address[] memory accounts1 = consumer.accounts(tokenAddress, actionId);
        address[] memory accounts2 = consumer.accounts(tokenAddress, actionId2);

        assertEq(accounts1.length, 1);
        assertEq(accounts1[0], account1);
        assertEq(accounts2.length, 1);
        assertEq(accounts2[0], account2);
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_AddRemoveAdd_SameAccount() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.removeAccount(tokenAddress, actionId, account1, 2);
        consumer.addAccount(tokenAddress, actionId, account1, 3);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 1);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 1);
        assertEq(accounts[0], account1);
        assertEq(consumer.accountIndex(tokenAddress, actionId, account1), 0);
    }

    function test_RemoveAllAccounts() public {
        consumer.addAccount(tokenAddress, actionId, account1, 1);
        consumer.addAccount(tokenAddress, actionId, account2, 1);
        consumer.addAccount(tokenAddress, actionId, account3, 1);

        consumer.removeAccount(tokenAddress, actionId, account1, 2);
        consumer.removeAccount(tokenAddress, actionId, account3, 3);
        consumer.removeAccount(tokenAddress, actionId, account2, 4);

        assertEq(consumer.accountsCount(tokenAddress, actionId), 0);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, 0);
    }

    function test_LargeNumberOfAccounts() public {
        uint256 count = 50;
        address[] memory testAccounts = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            testAccounts[i] = address(uint160(0x3000 + i));
            consumer.addAccount(tokenAddress, actionId, testAccounts[i], 1);
        }

        assertEq(consumer.accountsCount(tokenAddress, actionId), count);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);
        assertEq(accounts.length, count);

        for (uint256 i = 0; i < count; i++) {
            assertEq(accounts[i], testAccounts[i]);
            assertEq(
                consumer.accountIndex(tokenAddress, actionId, testAccounts[i]),
                i
            );
        }
    }

    function test_RemoveFromLargeList() public {
        uint256 count = 20;
        address[] memory testAccounts = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            testAccounts[i] = address(uint160(0x3000 + i));
            consumer.addAccount(tokenAddress, actionId, testAccounts[i], 1);
        }

        // Remove middle account
        uint256 removeIndex = 10;
        consumer.removeAccount(
            tokenAddress,
            actionId,
            testAccounts[removeIndex],
            2
        );

        assertEq(consumer.accountsCount(tokenAddress, actionId), count - 1);
        address[] memory accounts = consumer.accounts(tokenAddress, actionId);

        // Last account should be swapped to removeIndex
        assertEq(accounts[removeIndex], testAccounts[count - 1]);
        assertEq(
            consumer.accountIndex(
                tokenAddress,
                actionId,
                testAccounts[count - 1]
            ),
            removeIndex
        );
    }
}
