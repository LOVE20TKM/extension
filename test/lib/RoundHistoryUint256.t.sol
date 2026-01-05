// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {RoundHistoryUint256} from "../../src/lib/RoundHistoryUint256.sol";

using RoundHistoryUint256 for RoundHistoryUint256.History;

/**
 * @title MockRoundHistoryUint256Consumer
 * @notice Mock contract to test RoundHistoryUint256 library
 */
contract MockRoundHistoryUint256Consumer {
    RoundHistoryUint256.History internal _history;

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

    function increase(uint256 round, uint256 increaseValue) external {
        _history.increase(round, increaseValue);
    }

    function decrease(uint256 round, uint256 decreaseValue) external {
        _history.decrease(round, decreaseValue);
    }
}

/**
 * @title RoundHistoryUint256Test
 * @notice Test suite for RoundHistoryUint256 library
 */
contract RoundHistoryUint256Test is Test {
    MockRoundHistoryUint256Consumer public consumer;

    function setUp() public {
        consumer = new MockRoundHistoryUint256Consumer();
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

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound() public {
        consumer.record(10, 100);

        vm.expectRevert(RoundHistoryUint256.InvalidRound.selector);
        consumer.record(5, 200);
    }

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound_MultipleRounds() public {
        consumer.record(5, 100);
        consumer.record(10, 200);
        consumer.record(15, 300);

        vm.expectRevert(RoundHistoryUint256.InvalidRound.selector);
        consumer.record(1, 50);

        vm.expectRevert(RoundHistoryUint256.InvalidRound.selector);
        consumer.record(7, 150);

        vm.expectRevert(RoundHistoryUint256.InvalidRound.selector);
        consumer.record(12, 250);
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

    // ============================================
    // Increase Tests
    // ============================================

    function test_Increase_FromEmptyHistory() public {
        consumer.increase(1, 100);

        assertEq(consumer.changeRoundsLength(), 1);
        assertEq(consumer.changeRoundAt(0), 1);
        assertEq(consumer.value(1), 100);
    }

    function test_Increase_OnExistingValue() public {
        consumer.record(1, 100);
        consumer.increase(2, 50);

        assertEq(consumer.changeRoundsLength(), 2);
        assertEq(consumer.value(1), 100);
        assertEq(consumer.value(2), 150);
    }

    function test_Increase_SameRoundMultipleTimes() public {
        consumer.increase(5, 100);
        consumer.increase(5, 50);
        consumer.increase(5, 25);

        assertEq(consumer.changeRoundsLength(), 1);
        assertEq(consumer.changeRoundAt(0), 5);
        assertEq(consumer.value(5), 175);
    }

    function test_Increase_MultipleRounds() public {
        consumer.record(1, 100);
        consumer.increase(5, 50);
        consumer.increase(10, 30);

        assertEq(consumer.changeRoundsLength(), 3);
        assertEq(consumer.value(1), 100);
        assertEq(consumer.value(5), 150);
        assertEq(consumer.value(10), 180);
    }

    function test_Increase_ZeroValue() public {
        consumer.record(1, 100);
        consumer.increase(2, 0);

        assertEq(consumer.value(1), 100);
        assertEq(consumer.value(2), 100);
        assertEq(consumer.changeRoundsLength(), 2);
    }

    function test_Increase_LargeValue() public {
        consumer.record(1, 1000);
        consumer.increase(2, type(uint256).max - 1000);

        assertEq(consumer.value(2), type(uint256).max);
    }

    function test_Increase_OnPreviousRoundValue() public {
        consumer.record(5, 100);
        consumer.record(10, 200);

        // Increase at round 15, should use value from round 10 (200)
        consumer.increase(15, 50);

        assertEq(consumer.value(15), 250);
        assertEq(consumer.changeRoundsLength(), 3);
    }

    function test_Increase_InvalidRound_Reverts() public {
        consumer.record(10, 100);

        vm.expectRevert(RoundHistoryUint256.InvalidRound.selector);
        consumer.increase(5, 50);
    }

    // ============================================
    // Decrease Tests
    // ============================================

    function test_Decrease_OnExistingValue() public {
        consumer.record(1, 100);
        consumer.decrease(2, 30);

        assertEq(consumer.changeRoundsLength(), 2);
        assertEq(consumer.value(1), 100);
        assertEq(consumer.value(2), 70);
    }

    function test_Decrease_SameRoundMultipleTimes() public {
        consumer.record(5, 200);
        consumer.decrease(5, 50);
        consumer.decrease(5, 30);
        consumer.decrease(5, 20);

        assertEq(consumer.changeRoundsLength(), 1);
        assertEq(consumer.changeRoundAt(0), 5);
        assertEq(consumer.value(5), 100);
    }

    function test_Decrease_ToZero() public {
        consumer.record(1, 100);
        consumer.decrease(2, 100);

        assertEq(consumer.value(1), 100);
        assertEq(consumer.value(2), 0);
        assertEq(consumer.changeRoundsLength(), 2);
    }

    function test_Decrease_ZeroValue() public {
        consumer.record(1, 100);
        consumer.decrease(2, 0);

        assertEq(consumer.value(1), 100);
        assertEq(consumer.value(2), 100);
        assertEq(consumer.changeRoundsLength(), 2);
    }

    function test_Decrease_MultipleRounds() public {
        consumer.record(1, 200);
        consumer.decrease(5, 50);
        consumer.decrease(10, 30);

        assertEq(consumer.changeRoundsLength(), 3);
        assertEq(consumer.value(1), 200);
        assertEq(consumer.value(5), 150);
        assertEq(consumer.value(10), 120);
    }

    function test_Decrease_OnPreviousRoundValue() public {
        consumer.record(5, 200);
        consumer.record(10, 300);

        // Decrease at round 15, should use value from round 10 (300)
        consumer.decrease(15, 50);

        assertEq(consumer.value(15), 250);
        assertEq(consumer.changeRoundsLength(), 3);
    }

    function test_Decrease_FromEmptyHistory_Reverts() public {
        // Decreasing from empty history (value = 0) will cause underflow
        vm.expectRevert();
        consumer.decrease(1, 100);
    }

    function test_Decrease_ExceedsCurrentValue_Reverts() public {
        consumer.record(1, 100);

        // Try to decrease more than current value
        vm.expectRevert();
        consumer.decrease(2, 150);
    }

    function test_Decrease_InvalidRound_Reverts() public {
        consumer.record(5, 100);
        consumer.record(10, 200);

        // Round 7 is between recorded rounds, value(7) returns 100
        // But round 7 < last round 10, so record will revert InvalidRound
        vm.expectRevert(RoundHistoryUint256.InvalidRound.selector);
        consumer.decrease(7, 50);
    }

    function test_Decrease_BeforeFirstRound_Reverts() public {
        consumer.record(10, 100);

        // Round 5 is before first round, value(5) returns 0
        // 0 - 50 causes underflow revert before InvalidRound check
        vm.expectRevert();
        consumer.decrease(5, 50);
    }

    // ============================================
    // Increase and Decrease Combined Tests
    // ============================================

    function test_IncreaseThenDecrease() public {
        consumer.record(1, 100);
        consumer.increase(2, 50);
        consumer.decrease(3, 30);

        assertEq(consumer.value(1), 100);
        assertEq(consumer.value(2), 150);
        assertEq(consumer.value(3), 120);
    }

    function test_DecreaseThenIncrease() public {
        consumer.record(1, 200);
        consumer.decrease(2, 50);
        consumer.increase(3, 30);

        assertEq(consumer.value(1), 200);
        assertEq(consumer.value(2), 150);
        assertEq(consumer.value(3), 180);
    }

    function test_IncreaseAndDecrease_SameRound() public {
        consumer.record(1, 100);
        consumer.increase(5, 50);
        consumer.decrease(5, 20);
        consumer.increase(5, 10);

        assertEq(consumer.value(5), 140);
        assertEq(consumer.changeRoundsLength(), 2);
    }
}
