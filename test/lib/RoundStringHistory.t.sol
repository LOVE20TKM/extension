// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {RoundStringHistory} from "../../src/lib/RoundStringHistory.sol";

using RoundStringHistory for RoundStringHistory.History;

/**
 * @title MockRoundStringHistoryConsumer
 * @notice Mock contract to test RoundStringHistory library
 */
contract MockRoundStringHistoryConsumer {
    RoundStringHistory.History internal _history;

    function record(uint256 round, string memory newValue) external {
        _history.record(round, newValue);
    }

    function value(uint256 round) external view returns (string memory) {
        return _history.value(round);
    }

    function latestValue() external view returns (string memory) {
        return _history.latestValue();
    }

    function changeRoundsCount() external view returns (uint256) {
        return _history.changeRoundsCount();
    }

    function changeRoundAtIndex(uint256 index) external view returns (uint256) {
        return _history.changeRoundAtIndex(index);
    }
}

/**
 * @title RoundStringHistoryTest
 * @notice Test suite for RoundStringHistory library
 */
contract RoundStringHistoryTest is Test {
    MockRoundStringHistoryConsumer public consumer;

    function setUp() public {
        consumer = new MockRoundStringHistoryConsumer();
    }

    // ============================================
    // Record Tests
    // ============================================

    function test_Record_SingleValue() public {
        consumer.record(1, "hello");

        assertEq(consumer.changeRoundsCount(), 1);
        assertEq(consumer.changeRoundAtIndex(0), 1);
        assertEq(consumer.value(1), "hello");
    }

    function test_Record_MultipleRounds() public {
        consumer.record(1, "first");
        consumer.record(5, "second");
        consumer.record(10, "third");

        assertEq(consumer.changeRoundsCount(), 3);
        assertEq(consumer.changeRoundAtIndex(0), 1);
        assertEq(consumer.changeRoundAtIndex(1), 5);
        assertEq(consumer.changeRoundAtIndex(2), 10);
    }

    function test_Record_SameRoundUpdatesValue() public {
        consumer.record(5, "first");
        consumer.record(5, "second");
        consumer.record(5, "third");

        // Should only have one entry for round 5
        assertEq(consumer.changeRoundsCount(), 1);
        assertEq(consumer.value(5), "third");
    }

    function test_Record_EmptyString() public {
        consumer.record(1, "hello");
        consumer.record(2, "");

        assertEq(consumer.value(2), "");
        assertEq(consumer.changeRoundsCount(), 2);
    }

    function test_Record_LongString() public {
        string
            memory longString = "This is a very long string that contains a lot of characters to test if the library can handle long strings properly.";
        consumer.record(1, longString);

        assertEq(consumer.value(1), longString);
    }

    function test_Record_SpecialCharacters() public {
        string memory specialChars = unicode"Hello 世界 🌍 @#$%^&*()";
        consumer.record(1, specialChars);

        assertEq(consumer.value(1), specialChars);
    }

    // ============================================
    // Value Query Tests
    // ============================================

    function test_Value_EmptyHistory() public view {
        assertEq(consumer.value(1), "");
        assertEq(consumer.value(100), "");
    }

    function test_Value_ExactRound() public {
        consumer.record(5, "at five");
        consumer.record(10, "at ten");

        assertEq(consumer.value(5), "at five");
        assertEq(consumer.value(10), "at ten");
    }

    function test_Value_BetweenRounds() public {
        consumer.record(5, "at five");
        consumer.record(10, "at ten");

        // Query between rounds should return the previous value
        assertEq(consumer.value(7), "at five");
        assertEq(consumer.value(8), "at five");
        assertEq(consumer.value(9), "at five");
    }

    function test_Value_AfterLatestRound() public {
        consumer.record(5, "at five");
        consumer.record(10, "at ten");

        // Query after latest round should return latest value
        assertEq(consumer.value(15), "at ten");
        assertEq(consumer.value(100), "at ten");
    }

    function test_Value_BeforeFirstRound() public {
        consumer.record(5, "at five");
        consumer.record(10, "at ten");

        // Query before first round should return empty string
        assertEq(consumer.value(1), "");
        assertEq(consumer.value(4), "");
    }

    function test_Value_RoundZero() public {
        consumer.record(0, "at zero");

        assertEq(consumer.value(0), "at zero");
        assertEq(consumer.value(5), "at zero");
    }

    // ============================================
    // LatestValue Tests
    // ============================================

    function test_LatestValue_EmptyHistory() public view {
        assertEq(consumer.latestValue(), "");
    }

    function test_LatestValue_SingleRecord() public {
        consumer.record(5, "single");
        assertEq(consumer.latestValue(), "single");
    }

    function test_LatestValue_MultipleRecords() public {
        consumer.record(1, "first");
        consumer.record(5, "second");
        consumer.record(10, "third");

        assertEq(consumer.latestValue(), "third");
    }

    function test_LatestValue_AfterSameRoundUpdate() public {
        consumer.record(5, "first");
        consumer.record(5, "second");

        assertEq(consumer.latestValue(), "second");
    }

    // ============================================
    // changeRoundsCount and changeRoundAtIndex Tests
    // ============================================

    function test_ChangeRoundsCount_EmptyHistory() public view {
        assertEq(consumer.changeRoundsCount(), 0);
    }

    function test_ChangeRoundsCount_AfterRecords() public {
        consumer.record(1, "first");
        consumer.record(5, "second");
        consumer.record(10, "third");

        assertEq(consumer.changeRoundsCount(), 3);
    }

    function test_ChangeRoundAtIndex_ReturnsCorrectRound() public {
        consumer.record(1, "first");
        consumer.record(5, "second");
        consumer.record(10, "third");

        assertEq(consumer.changeRoundAtIndex(0), 1);
        assertEq(consumer.changeRoundAtIndex(1), 5);
        assertEq(consumer.changeRoundAtIndex(2), 10);
    }

    // ============================================
    // Binary Search Edge Cases
    // ============================================

    function test_Value_LargeGapBetweenRounds() public {
        consumer.record(1, "at one");
        consumer.record(1000000, "at million");

        assertEq(consumer.value(1), "at one");
        assertEq(consumer.value(500000), "at one");
        assertEq(consumer.value(999999), "at one");
        assertEq(consumer.value(1000000), "at million");
    }

    function test_Value_ManyRounds() public {
        // Record values at rounds 10, 20, 30, ..., 100
        for (uint256 i = 1; i <= 10; i++) {
            consumer.record(i * 10, string(abi.encodePacked("round_", vm.toString(i * 10))));
        }

        assertEq(consumer.changeRoundsCount(), 10);

        // Test various queries
        assertEq(consumer.value(5), ""); // before first
        assertEq(consumer.value(10), "round_10");
        assertEq(consumer.value(15), "round_10");
        assertEq(consumer.value(50), "round_50");
        assertEq(consumer.value(55), "round_50");
        assertEq(consumer.value(100), "round_100");
        assertEq(consumer.value(150), "round_100");
    }

    // ============================================
    // Gas Tests
    // ============================================

    function test_Gas_RecordIsEfficient() public {
        uint256 gas1;
        uint256 gas2;

        gas1 = gasleft();
        consumer.record(1, "first");
        gas1 = gas1 - gasleft();

        // Add many rounds
        for (uint256 i = 2; i <= 100; i++) {
            consumer.record(i, string(abi.encodePacked("value_", vm.toString(i))));
        }

        gas2 = gasleft();
        consumer.record(101, "last");
        gas2 = gas2 - gasleft();

        // Gas should be similar regardless of history size
        assertTrue(gas2 < gas1 * 2, "Record gas should be O(1)");
    }

    function test_Gas_ValueQueryIsLogarithmic() public {
        // Add 100 rounds
        for (uint256 i = 1; i <= 100; i++) {
            consumer.record(i * 10, string(abi.encodePacked("value_", vm.toString(i))));
        }

        uint256 gas1 = gasleft();
        consumer.value(50);
        gas1 = gas1 - gasleft();

        uint256 gas2 = gasleft();
        consumer.value(500);
        gas2 = gas2 - gasleft();

        uint256 gas3 = gasleft();
        consumer.value(950);
        gas3 = gas3 - gasleft();

        // All queries should have similar gas (O(log n))
        uint256 avgGas = (gas1 + gas2 + gas3) / 3;
        assertTrue(gas1 < avgGas * 2, "Query gas should be O(log n)");
        assertTrue(gas2 < avgGas * 2, "Query gas should be O(log n)");
        assertTrue(gas3 < avgGas * 2, "Query gas should be O(log n)");
    }
}

