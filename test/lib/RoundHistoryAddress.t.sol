// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {RoundHistoryAddress} from "../../src/lib/RoundHistoryAddress.sol";

using RoundHistoryAddress for RoundHistoryAddress.History;

/**
 * @title MockRoundHistoryAddressConsumer
 * @notice Mock contract to test RoundHistoryAddress library
 */
contract MockRoundHistoryAddressConsumer {
    RoundHistoryAddress.History internal _history;

    function record(uint256 round, address newValue) external {
        _history.record(round, newValue);
    }

    function value(uint256 round) external view returns (address) {
        return _history.value(round);
    }

    function latestValue() external view returns (address) {
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
 * @title RoundHistoryAddressTest
 * @notice Test suite for RoundHistoryAddress library
 */
contract RoundHistoryAddressTest is Test {
    MockRoundHistoryAddressConsumer public consumer;

    function setUp() public {
        consumer = new MockRoundHistoryAddressConsumer();
    }

    // ============================================
    // Record Tests
    // ============================================

    function test_Record_SingleValue() public {
        address addr = address(0x1001);
        consumer.record(1, addr);

        assertEq(consumer.changeRoundsLength(), 1);
        assertEq(consumer.changeRoundAt(0), 1);
        assertEq(consumer.value(1), addr);
    }

    function test_Record_MultipleRounds() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);
        address addr3 = address(0x1003);

        consumer.record(1, addr1);
        consumer.record(5, addr2);
        consumer.record(10, addr3);

        assertEq(consumer.changeRoundsLength(), 3);
        assertEq(consumer.changeRoundAt(0), 1);
        assertEq(consumer.changeRoundAt(1), 5);
        assertEq(consumer.changeRoundAt(2), 10);
    }

    function test_Record_SameRoundUpdatesValue() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);
        address addr3 = address(0x1003);

        consumer.record(5, addr1);
        consumer.record(5, addr2);
        consumer.record(5, addr3);

        // Should only have one entry for round 5
        assertEq(consumer.changeRoundsLength(), 1);
        assertEq(consumer.value(5), addr3);
    }

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);

        consumer.record(10, addr1);

        vm.expectRevert(RoundHistoryAddress.InvalidRound.selector);
        consumer.record(5, addr2);
    }

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound_MultipleRounds() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);
        address addr3 = address(0x1003);
        address addr4 = address(0x1004);

        consumer.record(5, addr1);
        consumer.record(10, addr2);
        consumer.record(15, addr3);

        vm.expectRevert(RoundHistoryAddress.InvalidRound.selector);
        consumer.record(1, addr4);

        vm.expectRevert(RoundHistoryAddress.InvalidRound.selector);
        consumer.record(7, addr4);

        vm.expectRevert(RoundHistoryAddress.InvalidRound.selector);
        consumer.record(12, addr4);
    }

    function test_Record_ZeroAddress() public {
        address addr1 = address(0x1001);
        consumer.record(1, addr1);
        consumer.record(2, address(0));

        assertEq(consumer.value(2), address(0));
        assertEq(consumer.changeRoundsLength(), 2);
    }

    // ============================================
    // Value Query Tests
    // ============================================

    function test_Value_EmptyHistory() public view {
        assertEq(consumer.value(1), address(0));
        assertEq(consumer.value(100), address(0));
    }

    function test_Value_ExactRound() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);

        consumer.record(5, addr1);
        consumer.record(10, addr2);

        assertEq(consumer.value(5), addr1);
        assertEq(consumer.value(10), addr2);
    }

    function test_Value_BetweenRounds() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);

        consumer.record(5, addr1);
        consumer.record(10, addr2);

        // Query between rounds should return the previous value
        assertEq(consumer.value(7), addr1);
        assertEq(consumer.value(8), addr1);
        assertEq(consumer.value(9), addr1);
    }

    function test_Value_AfterLatestRound() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);

        consumer.record(5, addr1);
        consumer.record(10, addr2);

        // Query after latest round should return latest value
        assertEq(consumer.value(15), addr2);
        assertEq(consumer.value(100), addr2);
    }

    function test_Value_BeforeFirstRound() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);

        consumer.record(5, addr1);
        consumer.record(10, addr2);

        // Query before first round should return address(0)
        assertEq(consumer.value(1), address(0));
        assertEq(consumer.value(4), address(0));
    }

    function test_Value_RoundZero() public {
        address addr = address(0x1001);
        consumer.record(0, addr);

        assertEq(consumer.value(0), addr);
        assertEq(consumer.value(5), addr);
    }

    // ============================================
    // LatestValue Tests
    // ============================================

    function test_LatestValue_EmptyHistory() public view {
        assertEq(consumer.latestValue(), address(0));
    }

    function test_LatestValue_SingleRecord() public {
        address addr = address(0x1001);
        consumer.record(5, addr);
        assertEq(consumer.latestValue(), addr);
    }

    function test_LatestValue_MultipleRecords() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);
        address addr3 = address(0x1003);

        consumer.record(1, addr1);
        consumer.record(5, addr2);
        consumer.record(10, addr3);

        assertEq(consumer.latestValue(), addr3);
    }

    function test_LatestValue_AfterSameRoundUpdate() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);

        consumer.record(5, addr1);
        consumer.record(5, addr2);

        assertEq(consumer.latestValue(), addr2);
    }

    // ============================================
    // Binary Search Edge Cases
    // ============================================

    function test_Value_LargeGapBetweenRounds() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);

        consumer.record(1, addr1);
        consumer.record(1000000, addr2);

        assertEq(consumer.value(1), addr1);
        assertEq(consumer.value(500000), addr1);
        assertEq(consumer.value(999999), addr1);
        assertEq(consumer.value(1000000), addr2);
    }

    function test_Value_ManyRounds() public {
        // Record values at rounds 10, 20, 30, ..., 100
        for (uint256 i = 1; i <= 10; i++) {
            consumer.record(i * 10, address(uint160(i * 100)));
        }

        assertEq(consumer.changeRoundsLength(), 10);

        // Test various queries
        assertEq(consumer.value(5), address(0)); // before first
        assertEq(consumer.value(10), address(uint160(100)));
        assertEq(consumer.value(15), address(uint160(100)));
        assertEq(consumer.value(50), address(uint160(500)));
        assertEq(consumer.value(55), address(uint160(500)));
        assertEq(consumer.value(100), address(uint160(1000)));
        assertEq(consumer.value(150), address(uint160(1000)));
    }

    // ============================================
    // Gas Tests
    // ============================================

    function test_Gas_RecordIsEfficient() public {
        uint256 gas1;
        uint256 gas2;

        gas1 = gasleft();
        consumer.record(1, address(0x1001));
        gas1 = gas1 - gasleft();

        // Add many rounds
        for (uint256 i = 2; i <= 100; i++) {
            consumer.record(i, address(uint160(i)));
        }

        gas2 = gasleft();
        consumer.record(101, address(0x101));
        gas2 = gas2 - gasleft();

        // Gas should be similar regardless of history size
        assertTrue(gas2 < gas1 * 2, "Record gas should be O(1)");
    }

    function test_Gas_ValueQueryIsLogarithmic() public {
        // Add 100 rounds
        for (uint256 i = 1; i <= 100; i++) {
            consumer.record(i * 10, address(uint160(i * 100)));
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
    // Extreme Round Value Tests
    // ============================================

    function test_Record_ExtremeRoundValue() public {
        address addr = address(0x1001);
        consumer.record(type(uint256).max, addr);

        assertEq(consumer.value(type(uint256).max), addr);
        assertEq(consumer.latestValue(), addr);
    }

    function test_Value_ExtremeRoundValue() public {
        address addr1 = address(0x1001);
        address addr2 = address(0x1002);

        consumer.record(1, addr1);
        consumer.record(type(uint256).max, addr2);

        assertEq(consumer.value(1), addr1);
        assertEq(consumer.value(type(uint256).max), addr2);
        assertEq(consumer.value(type(uint256).max - 1), addr1);
    }
}

