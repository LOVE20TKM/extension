// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {
    RoundHistoryAddressArray
} from "../../src/lib/RoundHistoryAddressArray.sol";

using RoundHistoryAddressArray for RoundHistoryAddressArray.History;

/// @title MockRoundHistoryAddressArrayConsumer
/// @notice Mock contract to test RoundHistoryAddressArray library
contract MockRoundHistoryAddressArrayConsumer {
    RoundHistoryAddressArray.History internal _history;

    function record(uint256 round, address[] memory newValues) external {
        _history.record(round, newValues);
    }

    function values(uint256 round) external view returns (address[] memory) {
        return _history.values(round);
    }

    function latestValues() external view returns (address[] memory) {
        return _history.latestValues();
    }

    function add(uint256 round, address value) external {
        _history.add(round, value);
    }

    function remove(uint256 round, address value) external returns (bool) {
        return _history.remove(round, value);
    }

    function changeRoundsLength() external view returns (uint256) {
        return _history.changeRounds.length;
    }
}

/// @title RoundHistoryAddressArrayTest
/// @notice Test suite for RoundHistoryAddressArray library
contract RoundHistoryAddressArrayTest is Test {
    MockRoundHistoryAddressArrayConsumer public consumer;

    address constant ADDR1 = address(0x1111);
    address constant ADDR2 = address(0x2222);
    address constant ADDR3 = address(0x3333);
    address constant ADDR_NOT_EXIST = address(0x9999);

    function setUp() public {
        consumer = new MockRoundHistoryAddressArrayConsumer();
    }

    // ============================================
    // Add Tests
    // ============================================

    function test_Add_ToEmptyArray() public {
        consumer.add(1, ADDR1);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], ADDR1);
    }

    function test_Add_NewValue() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR2);
    }

    function test_Add_DuplicateValue_NoChange() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR1);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], ADDR1);
    }

    function test_Add_MultipleValues() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);
        consumer.add(1, ADDR3);
        consumer.add(1, ADDR2); // duplicate, should not add

        address[] memory result = consumer.values(1);
        assertEq(result.length, 3);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR2);
        assertEq(result[2], ADDR3);
    }

    function test_Add_ZeroAddress() public {
        consumer.add(1, address(0));
        consumer.add(1, ADDR1);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], address(0));
        assertEq(result[1], ADDR1);
    }

    // ============================================
    // Remove Tests
    // ============================================

    function test_Remove_ExistingValue_ReturnsTrue() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);

        bool removed = consumer.remove(1, ADDR1);
        assertTrue(removed);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], ADDR2);
    }

    function test_Remove_NonExistentValue_ReturnsFalse() public {
        consumer.add(1, ADDR1);

        bool removed = consumer.remove(1, ADDR_NOT_EXIST);
        assertFalse(removed);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 1);
    }

    function test_Remove_FromEmptyArray_ReturnsFalse() public {
        bool removed = consumer.remove(1, ADDR1);
        assertFalse(removed);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 0);
    }

    function test_Remove_LastElement() public {
        consumer.add(1, ADDR1);

        bool removed = consumer.remove(1, ADDR1);
        assertTrue(removed);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 0);
    }

    function test_Remove_MiddleElement() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);
        consumer.add(1, ADDR3);

        bool removed = consumer.remove(1, ADDR2);
        assertTrue(removed);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR3);
    }

    function test_Remove_FirstElement() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);
        consumer.add(1, ADDR3);

        bool removed = consumer.remove(1, ADDR1);
        assertTrue(removed);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], ADDR2);
        assertEq(result[1], ADDR3);
    }

    // ============================================
    // Cross-Round Tests
    // ============================================

    function test_AddRemove_AcrossRounds() public {
        // Round 1: add values
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);

        // Round 5: add more, remove one
        consumer.add(5, ADDR3);
        consumer.remove(5, ADDR1);

        // Check round 1 (should be unchanged)
        address[] memory round1 = consumer.values(1);
        assertEq(round1.length, 2);
        assertEq(round1[0], ADDR1);
        assertEq(round1[1], ADDR2);

        // Check round 5
        address[] memory round5 = consumer.values(5);
        assertEq(round5.length, 2);
        assertEq(round5[0], ADDR2);
        assertEq(round5[1], ADDR3);

        // Check round 3 (should inherit from round 1)
        address[] memory round3 = consumer.values(3);
        assertEq(round3.length, 2);
        assertEq(round3[0], ADDR1);
        assertEq(round3[1], ADDR2);
    }

    function test_Add_InheritsPreviousRoundValues() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);

        // Adding in round 5 should inherit round 1's values
        consumer.add(5, ADDR3);

        address[] memory result = consumer.values(5);
        assertEq(result.length, 3);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR2);
        assertEq(result[2], ADDR3);
    }

    function test_Remove_InheritsPreviousRoundValues() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);
        consumer.add(1, ADDR3);

        // Removing in round 5 should inherit and modify
        consumer.remove(5, ADDR2);

        address[] memory result = consumer.values(5);
        assertEq(result.length, 2);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR3);

        // Round 1 should be unchanged
        address[] memory round1 = consumer.values(1);
        assertEq(round1.length, 3);
    }

    // ============================================
    // Record Compatibility Tests
    // ============================================

    function test_Record_ThenAdd() public {
        address[] memory initial = new address[](2);
        initial[0] = ADDR1;
        initial[1] = ADDR2;
        consumer.record(1, initial);

        consumer.add(1, ADDR3);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 3);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR2);
        assertEq(result[2], ADDR3);
    }

    function test_Add_ThenRecord_Overwrites() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);

        address[] memory newValues = new address[](1);
        newValues[0] = ADDR3;
        consumer.record(1, newValues);

        address[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], ADDR3);
    }

    // ============================================
    // InvalidRound Tests
    // ============================================

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound()
        public
    {
        address[] memory values1 = new address[](1);
        values1[0] = ADDR1;
        consumer.record(10, values1);

        address[] memory values2 = new address[](1);
        values2[0] = ADDR2;
        vm.expectRevert(RoundHistoryAddressArray.InvalidRound.selector);
        consumer.record(5, values2);
    }

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound_MultipleRounds()
        public
    {
        address[] memory values1 = new address[](1);
        values1[0] = ADDR1;
        consumer.record(5, values1);

        address[] memory values2 = new address[](1);
        values2[0] = ADDR2;
        consumer.record(10, values2);

        address[] memory values3 = new address[](1);
        values3[0] = ADDR3;
        consumer.record(15, values3);

        address[] memory invalid = new address[](1);
        invalid[0] = ADDR_NOT_EXIST;

        vm.expectRevert(RoundHistoryAddressArray.InvalidRound.selector);
        consumer.record(1, invalid);

        vm.expectRevert(RoundHistoryAddressArray.InvalidRound.selector);
        consumer.record(7, invalid);

        vm.expectRevert(RoundHistoryAddressArray.InvalidRound.selector);
        consumer.record(12, invalid);
    }

    function test_Record_SameRoundUpdatesValue() public {
        address[] memory values1 = new address[](2);
        values1[0] = ADDR1;
        values1[1] = ADDR2;
        consumer.record(5, values1);

        address[] memory values2 = new address[](1);
        values2[0] = ADDR3;
        consumer.record(5, values2);

        // Should only have one entry for round 5
        assertEq(consumer.changeRoundsLength(), 1);
        address[] memory result = consumer.values(5);
        assertEq(result.length, 1);
        assertEq(result[0], ADDR3);
    }

    // ============================================
    // LatestValues Tests
    // ============================================

    function test_LatestValues_EmptyHistory() public view {
        address[] memory result = consumer.latestValues();
        assertEq(result.length, 0);
    }

    function test_LatestValues_SingleRecord() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);

        address[] memory result = consumer.latestValues();
        assertEq(result.length, 2);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR2);
    }

    function test_LatestValues_MultipleRecords() public {
        consumer.add(1, ADDR1);
        consumer.add(1, ADDR2);
        consumer.add(5, ADDR3);
        address addr4 = address(0x4444);
        consumer.add(10, addr4);

        address[] memory result = consumer.latestValues();
        assertEq(result.length, 4);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR2);
        assertEq(result[2], ADDR3);
        assertEq(result[3], addr4);
    }

    function test_LatestValues_AfterSameRoundUpdate() public {
        consumer.add(5, ADDR1);
        consumer.add(5, ADDR2);
        consumer.add(5, ADDR3);

        address[] memory result = consumer.latestValues();
        assertEq(result.length, 3);
        assertEq(result[0], ADDR1);
        assertEq(result[1], ADDR2);
        assertEq(result[2], ADDR3);
    }

    function test_LatestValues_AfterRecord() public {
        address[] memory values1 = new address[](2);
        values1[0] = ADDR1;
        values1[1] = ADDR2;
        consumer.record(1, values1);

        address[] memory values2 = new address[](1);
        values2[0] = ADDR3;
        consumer.record(5, values2);

        address[] memory result = consumer.latestValues();
        assertEq(result.length, 1);
        assertEq(result[0], ADDR3);
    }

    // ============================================
    // Binary Search Edge Cases
    // ============================================

    function test_Value_LargeGapBetweenRounds() public {
        address[] memory values1 = new address[](1);
        values1[0] = ADDR1;
        consumer.record(1, values1);

        address[] memory values2 = new address[](1);
        values2[0] = ADDR2;
        consumer.record(1000000, values2);

        address[] memory result1 = consumer.values(1);
        assertEq(result1.length, 1);
        assertEq(result1[0], ADDR1);

        address[] memory result500k = consumer.values(500000);
        assertEq(result500k.length, 1);
        assertEq(result500k[0], ADDR1);

        address[] memory result999k = consumer.values(999999);
        assertEq(result999k.length, 1);
        assertEq(result999k[0], ADDR1);

        address[] memory result1m = consumer.values(1000000);
        assertEq(result1m.length, 1);
        assertEq(result1m[0], ADDR2);
    }

    function test_Value_ManyRounds() public {
        // Record values at rounds 10, 20, 30, ..., 100
        for (uint256 i = 1; i <= 10; i++) {
            address[] memory vals = new address[](1);
            vals[0] = address(uint160(i * 100));
            consumer.record(i * 10, vals);
        }

        assertEq(consumer.changeRoundsLength(), 10);

        // Test various queries
        address[] memory beforeFirst = consumer.values(5);
        assertEq(beforeFirst.length, 0); // before first

        address[] memory at10 = consumer.values(10);
        assertEq(at10.length, 1);
        assertEq(at10[0], address(uint160(100)));

        address[] memory at15 = consumer.values(15);
        assertEq(at15.length, 1);
        assertEq(at15[0], address(uint160(100)));

        address[] memory at50 = consumer.values(50);
        assertEq(at50.length, 1);
        assertEq(at50[0], address(uint160(500)));

        address[] memory at55 = consumer.values(55);
        assertEq(at55.length, 1);
        assertEq(at55[0], address(uint160(500)));

        address[] memory at100 = consumer.values(100);
        assertEq(at100.length, 1);
        assertEq(at100[0], address(uint160(1000)));

        address[] memory afterLast = consumer.values(150);
        assertEq(afterLast.length, 1);
        assertEq(afterLast[0], address(uint160(1000)));
    }

    function test_Value_BeforeFirstRound() public {
        address[] memory values1 = new address[](1);
        values1[0] = ADDR1;
        consumer.record(5, values1);

        address[] memory values2 = new address[](1);
        values2[0] = ADDR2;
        consumer.record(10, values2);

        address[] memory result1 = consumer.values(1);
        assertEq(result1.length, 0);

        address[] memory result4 = consumer.values(4);
        assertEq(result4.length, 0);
    }

    function test_Value_AfterLatestRound() public {
        address[] memory values1 = new address[](1);
        values1[0] = ADDR1;
        consumer.record(5, values1);

        address[] memory values2 = new address[](1);
        values2[0] = ADDR2;
        consumer.record(10, values2);

        address[] memory result15 = consumer.values(15);
        assertEq(result15.length, 1);
        assertEq(result15[0], ADDR2);

        address[] memory result100 = consumer.values(100);
        assertEq(result100.length, 1);
        assertEq(result100[0], ADDR2);
    }

    // ============================================
    // Gas Tests
    // ============================================

    function test_Gas_RecordIsEfficient() public {
        uint256 gas1;
        uint256 gas2;

        address[] memory values1 = new address[](1);
        values1[0] = ADDR1;
        gas1 = gasleft();
        consumer.record(1, values1);
        gas1 = gas1 - gasleft();

        // Add many rounds
        for (uint256 i = 2; i <= 100; i++) {
            address[] memory vals = new address[](1);
            vals[0] = address(uint160(i));
            consumer.record(i, vals);
        }

        address[] memory values2 = new address[](1);
        values2[0] = address(0x101);
        gas2 = gasleft();
        consumer.record(101, values2);
        gas2 = gas2 - gasleft();

        // Gas should be similar regardless of history size
        assertTrue(gas2 < gas1 * 2, "Record gas should be O(1)");
    }

    function test_Gas_ValueQueryIsLogarithmic() public {
        // Add 100 rounds
        for (uint256 i = 1; i <= 100; i++) {
            address[] memory vals = new address[](1);
            vals[0] = address(uint160(i * 100));
            consumer.record(i * 10, vals);
        }

        uint256 gas1 = gasleft();
        consumer.values(50);
        gas1 = gas1 - gasleft();

        uint256 gas2 = gasleft();
        consumer.values(500);
        gas2 = gas2 - gasleft();

        uint256 gas3 = gasleft();
        consumer.values(950);
        gas3 = gas3 - gasleft();

        // All queries should have similar gas (O(log n))
        uint256 avgGas = (gas1 + gas2 + gas3) / 3;
        assertTrue(gas1 < avgGas * 2, "Query gas should be O(log n)");
        assertTrue(gas2 < avgGas * 2, "Query gas should be O(log n)");
        assertTrue(gas3 < avgGas * 2, "Query gas should be O(log n)");
    }
}
