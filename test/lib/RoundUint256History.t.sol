// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {RoundUint256History} from "../../src/lib/RoundUint256History.sol";

using RoundUint256History for RoundUint256History.History;

/**
 * @title MockRoundUint256HistoryConsumer
 * @notice Mock contract to test RoundUint256History library
 */
contract MockRoundUint256HistoryConsumer {
    RoundUint256History.History internal _history;

    function record(uint256 round, uint256 newValue) external {
        _history.record(round, newValue);
    }

    function value(uint256 round) external view returns (uint256) {
        return _history.value(round);
    }

    function latestValue() external view returns (uint256) {
        return _history.latestValue();
    }

    function changeRoundsLength() external view returns (uint256) {
        return _history.changeRounds.length;
    }

    function changeRoundAt(uint256 index) external view returns (uint256) {
        return _history.changeRounds[index];
    }
}

/**
 * @title RoundUint256HistoryTest
 * @notice Test suite for RoundUint256History library
 */
contract RoundUint256HistoryTest is Test {
    MockRoundUint256HistoryConsumer public consumer;

    function setUp() public {
        consumer = new MockRoundUint256HistoryConsumer();
    }

    // ============================================
    // Record Tests
    // ============================================

    function test_Record_SingleValue() public {
        consumer.record(1, 100);

        assertEq(consumer.changeRoundsLength(), 1);
        assertEq(consumer.changeRoundAt(0), 1);
        assertEq(consumer.value(1), 100);
    }

    function test_Record_MultipleRounds() public {
        consumer.record(1, 100);
        consumer.record(5, 200);
        consumer.record(10, 300);

        assertEq(consumer.changeRoundsLength(), 3);
        assertEq(consumer.changeRoundAt(0), 1);
        assertEq(consumer.changeRoundAt(1), 5);
        assertEq(consumer.changeRoundAt(2), 10);
    }

    function test_Record_SameRoundUpdatesValue() public {
        consumer.record(5, 100);
        consumer.record(5, 200);
        consumer.record(5, 300);

        // Should only have one entry for round 5
        assertEq(consumer.changeRoundsLength(), 1);
        assertEq(consumer.value(5), 300);
    }

    function test_Record_ZeroValue() public {
        consumer.record(1, 100);
        consumer.record(2, 0);

        assertEq(consumer.value(2), 0);
        assertEq(consumer.changeRoundsLength(), 2);
    }

    // ============================================
    // Value Query Tests
    // ============================================

    function test_Value_EmptyHistory() public view {
        assertEq(consumer.value(1), 0);
        assertEq(consumer.value(100), 0);
    }

    function test_Value_ExactRound() public {
        consumer.record(5, 100);
        consumer.record(10, 200);

        assertEq(consumer.value(5), 100);
        assertEq(consumer.value(10), 200);
    }

    function test_Value_BetweenRounds() public {
        consumer.record(5, 100);
        consumer.record(10, 200);

        // Query between rounds should return the previous value
        assertEq(consumer.value(7), 100);
        assertEq(consumer.value(8), 100);
        assertEq(consumer.value(9), 100);
    }

    function test_Value_AfterLatestRound() public {
        consumer.record(5, 100);
        consumer.record(10, 200);

        // Query after latest round should return latest value
        assertEq(consumer.value(15), 200);
        assertEq(consumer.value(100), 200);
    }

    function test_Value_BeforeFirstRound() public {
        consumer.record(5, 100);
        consumer.record(10, 200);

        // Query before first round should return 0
        assertEq(consumer.value(1), 0);
        assertEq(consumer.value(4), 0);
    }

    function test_Value_RoundZero() public {
        consumer.record(0, 100);

        assertEq(consumer.value(0), 100);
        assertEq(consumer.value(5), 100);
    }

    // ============================================
    // LatestValue Tests
    // ============================================

    function test_LatestValue_EmptyHistory() public view {
        assertEq(consumer.latestValue(), 0);
    }

    function test_LatestValue_SingleRecord() public {
        consumer.record(5, 100);
        assertEq(consumer.latestValue(), 100);
    }

    function test_LatestValue_MultipleRecords() public {
        consumer.record(1, 100);
        consumer.record(5, 200);
        consumer.record(10, 300);

        assertEq(consumer.latestValue(), 300);
    }

    function test_LatestValue_AfterSameRoundUpdate() public {
        consumer.record(5, 100);
        consumer.record(5, 200);

        assertEq(consumer.latestValue(), 200);
    }

    // ============================================
    // Binary Search Edge Cases
    // ============================================

    function test_Value_LargeGapBetweenRounds() public {
        consumer.record(1, 100);
        consumer.record(1000000, 200);

        assertEq(consumer.value(1), 100);
        assertEq(consumer.value(500000), 100);
        assertEq(consumer.value(999999), 100);
        assertEq(consumer.value(1000000), 200);
    }

    function test_Value_ManyRounds() public {
        // Record values at rounds 10, 20, 30, ..., 100
        for (uint256 i = 1; i <= 10; i++) {
            consumer.record(i * 10, i * 100);
        }

        assertEq(consumer.changeRoundsLength(), 10);

        // Test various queries
        assertEq(consumer.value(5), 0); // before first
        assertEq(consumer.value(10), 100);
        assertEq(consumer.value(15), 100);
        assertEq(consumer.value(50), 500);
        assertEq(consumer.value(55), 500);
        assertEq(consumer.value(100), 1000);
        assertEq(consumer.value(150), 1000);
    }

    // ============================================
    // Gas Tests
    // ============================================

    function test_Gas_RecordIsEfficient() public {
        uint256 gas1;
        uint256 gas2;

        gas1 = gasleft();
        consumer.record(1, 100);
        gas1 = gas1 - gasleft();

        // Add many rounds
        for (uint256 i = 2; i <= 100; i++) {
            consumer.record(i, i * 100);
        }

        gas2 = gasleft();
        consumer.record(101, 10100);
        gas2 = gas2 - gasleft();

        // Gas should be similar regardless of history size
        assertTrue(gas2 < gas1 * 2, "Record gas should be O(1)");
    }

    function test_Gas_ValueQueryIsLogarithmic() public {
        // Add 100 rounds
        for (uint256 i = 1; i <= 100; i++) {
            consumer.record(i * 10, i * 100);
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
