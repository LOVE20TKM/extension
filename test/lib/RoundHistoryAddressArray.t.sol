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
}
