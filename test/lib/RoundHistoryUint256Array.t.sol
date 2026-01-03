// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {RoundHistoryUint256Array} from "../../src/lib/RoundHistoryUint256Array.sol";

using RoundHistoryUint256Array for RoundHistoryUint256Array.History;

/// @title MockRoundHistoryUint256ArrayConsumer
/// @notice Mock contract to test RoundHistoryUint256Array library
contract MockRoundHistoryUint256ArrayConsumer {
    RoundHistoryUint256Array.History internal _history;

    function record(uint256 round, uint256[] memory newValues) external {
        _history.record(round, newValues);
    }

    function values(uint256 round) external view returns (uint256[] memory) {
        return _history.values(round);
    }

    function latestValues() external view returns (uint256[] memory) {
        return _history.latestValues();
    }

    function add(uint256 round, uint256 value) external {
        _history.add(round, value);
    }

    function remove(uint256 round, uint256 value) external returns (bool) {
        return _history.remove(round, value);
    }

    function changeRoundsLength() external view returns (uint256) {
        return _history.changeRounds.length;
    }
}

/// @title RoundHistoryUint256ArrayTest
/// @notice Test suite for RoundHistoryUint256Array library
contract RoundHistoryUint256ArrayTest is Test {
    MockRoundHistoryUint256ArrayConsumer public consumer;

    function setUp() public {
        consumer = new MockRoundHistoryUint256ArrayConsumer();
    }

    // ============================================
    // Add Tests
    // ============================================

    function test_Add_ToEmptyArray() public {
        consumer.add(1, 100);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], 100);
    }

    function test_Add_NewValue() public {
        consumer.add(1, 100);
        consumer.add(1, 200);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], 100);
        assertEq(result[1], 200);
    }

    function test_Add_DuplicateValue_NoChange() public {
        consumer.add(1, 100);
        consumer.add(1, 100);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], 100);
    }

    function test_Add_MultipleValues() public {
        consumer.add(1, 100);
        consumer.add(1, 200);
        consumer.add(1, 300);
        consumer.add(1, 200); // duplicate, should not add

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 3);
        assertEq(result[0], 100);
        assertEq(result[1], 200);
        assertEq(result[2], 300);
    }

    function test_Add_ZeroValue() public {
        consumer.add(1, 0);
        consumer.add(1, 100);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], 0);
        assertEq(result[1], 100);
    }

    // ============================================
    // Remove Tests
    // ============================================

    function test_Remove_ExistingValue_ReturnsTrue() public {
        consumer.add(1, 100);
        consumer.add(1, 200);

        bool removed = consumer.remove(1, 100);
        assertTrue(removed);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], 200);
    }

    function test_Remove_NonExistentValue_ReturnsFalse() public {
        consumer.add(1, 100);

        bool removed = consumer.remove(1, 999);
        assertFalse(removed);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 1);
    }

    function test_Remove_FromEmptyArray_ReturnsFalse() public {
        bool removed = consumer.remove(1, 100);
        assertFalse(removed);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 0);
    }

    function test_Remove_LastElement() public {
        consumer.add(1, 100);

        bool removed = consumer.remove(1, 100);
        assertTrue(removed);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 0);
    }

    function test_Remove_MiddleElement() public {
        consumer.add(1, 100);
        consumer.add(1, 200);
        consumer.add(1, 300);

        bool removed = consumer.remove(1, 200);
        assertTrue(removed);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], 100);
        assertEq(result[1], 300);
    }

    function test_Remove_FirstElement() public {
        consumer.add(1, 100);
        consumer.add(1, 200);
        consumer.add(1, 300);

        bool removed = consumer.remove(1, 100);
        assertTrue(removed);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], 200);
        assertEq(result[1], 300);
    }

    // ============================================
    // Cross-Round Tests
    // ============================================

    function test_AddRemove_AcrossRounds() public {
        // Round 1: add values
        consumer.add(1, 100);
        consumer.add(1, 200);

        // Round 5: add more, remove one
        consumer.add(5, 300);
        consumer.remove(5, 100);

        // Check round 1 (should be unchanged)
        uint256[] memory round1 = consumer.values(1);
        assertEq(round1.length, 2);
        assertEq(round1[0], 100);
        assertEq(round1[1], 200);

        // Check round 5
        uint256[] memory round5 = consumer.values(5);
        assertEq(round5.length, 2);
        assertEq(round5[0], 200);
        assertEq(round5[1], 300);

        // Check round 3 (should inherit from round 1)
        uint256[] memory round3 = consumer.values(3);
        assertEq(round3.length, 2);
        assertEq(round3[0], 100);
        assertEq(round3[1], 200);
    }

    function test_Add_InheritsPreviousRoundValues() public {
        consumer.add(1, 100);
        consumer.add(1, 200);

        // Adding in round 5 should inherit round 1's values
        consumer.add(5, 300);

        uint256[] memory result = consumer.values(5);
        assertEq(result.length, 3);
        assertEq(result[0], 100);
        assertEq(result[1], 200);
        assertEq(result[2], 300);
    }

    function test_Remove_InheritsPreviousRoundValues() public {
        consumer.add(1, 100);
        consumer.add(1, 200);
        consumer.add(1, 300);

        // Removing in round 5 should inherit and modify
        consumer.remove(5, 200);

        uint256[] memory result = consumer.values(5);
        assertEq(result.length, 2);
        assertEq(result[0], 100);
        assertEq(result[1], 300);

        // Round 1 should be unchanged
        uint256[] memory round1 = consumer.values(1);
        assertEq(round1.length, 3);
    }

    // ============================================
    // Record Compatibility Tests
    // ============================================

    function test_Record_ThenAdd() public {
        uint256[] memory initial = new uint256[](2);
        initial[0] = 100;
        initial[1] = 200;
        consumer.record(1, initial);

        consumer.add(1, 300);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 3);
        assertEq(result[0], 100);
        assertEq(result[1], 200);
        assertEq(result[2], 300);
    }

    function test_Add_ThenRecord_Overwrites() public {
        consumer.add(1, 100);
        consumer.add(1, 200);

        uint256[] memory newValues = new uint256[](1);
        newValues[0] = 999;
        consumer.record(1, newValues);

        uint256[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], 999);
    }

    // ============================================
    // InvalidRound Tests
    // ============================================

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound() public {
        uint256[] memory values1 = new uint256[](1);
        values1[0] = 100;
        consumer.record(10, values1);

        uint256[] memory values2 = new uint256[](1);
        values2[0] = 200;
        vm.expectRevert(RoundHistoryUint256Array.InvalidRound.selector);
        consumer.record(5, values2);
    }

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound_MultipleRounds() public {
        uint256[] memory values1 = new uint256[](1);
        values1[0] = 100;
        consumer.record(5, values1);

        uint256[] memory values2 = new uint256[](1);
        values2[0] = 200;
        consumer.record(10, values2);

        uint256[] memory values3 = new uint256[](1);
        values3[0] = 300;
        consumer.record(15, values3);

        uint256[] memory invalid = new uint256[](1);
        invalid[0] = 50;

        vm.expectRevert(RoundHistoryUint256Array.InvalidRound.selector);
        consumer.record(1, invalid);

        vm.expectRevert(RoundHistoryUint256Array.InvalidRound.selector);
        consumer.record(7, invalid);

        vm.expectRevert(RoundHistoryUint256Array.InvalidRound.selector);
        consumer.record(12, invalid);
    }

    function test_Record_SameRoundUpdatesValue() public {
        uint256[] memory values1 = new uint256[](2);
        values1[0] = 100;
        values1[1] = 200;
        consumer.record(5, values1);

        uint256[] memory values2 = new uint256[](1);
        values2[0] = 300;
        consumer.record(5, values2);

        // Should only have one entry for round 5
        assertEq(consumer.changeRoundsLength(), 1);
        uint256[] memory result = consumer.values(5);
        assertEq(result.length, 1);
        assertEq(result[0], 300);
    }
}

