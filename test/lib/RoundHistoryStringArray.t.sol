// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/Test.sol";
import {
    RoundHistoryStringArray
} from "../../src/lib/RoundHistoryStringArray.sol";

using RoundHistoryStringArray for RoundHistoryStringArray.History;

/// @title MockRoundHistoryStringArrayConsumer
/// @notice Mock contract to test RoundHistoryStringArray library
contract MockRoundHistoryStringArrayConsumer {
    RoundHistoryStringArray.History internal _history;

    function record(uint256 round, string[] memory newValues) external {
        _history.record(round, newValues);
    }

    function values(uint256 round) external view returns (string[] memory) {
        return _history.values(round);
    }

    function latestValues() external view returns (string[] memory) {
        return _history.latestValues();
    }

    function changeRoundsLength() external view returns (uint256) {
        return _history.changeRounds.length;
    }
}

/// @title RoundHistoryStringArrayTest
/// @notice Test suite for RoundHistoryStringArray library
contract RoundHistoryStringArrayTest is Test {
    MockRoundHistoryStringArrayConsumer public consumer;

    function setUp() public {
        consumer = new MockRoundHistoryStringArrayConsumer();
    }

    // ============================================
    // Record Tests
    // ============================================

    function test_Record_SingleString() public {
        string[] memory vals = new string[](1);
        vals[0] = "a";
        consumer.record(1, vals);

        string[] memory result = consumer.values(1);
        assertEq(result.length, 1);
        assertEq(result[0], "a");
    }

    function test_Record_MultipleStrings() public {
        string[] memory vals = new string[](3);
        vals[0] = "one";
        vals[1] = "two";
        vals[2] = "three";
        consumer.record(1, vals);

        string[] memory result = consumer.values(1);
        assertEq(result.length, 3);
        assertEq(result[0], "one");
        assertEq(result[1], "two");
        assertEq(result[2], "three");
    }

    function test_Record_EmptyArray() public {
        string[] memory empty = new string[](0);
        consumer.record(1, empty);

        string[] memory result = consumer.values(1);
        assertEq(result.length, 0);

        string[] memory latest = consumer.latestValues();
        assertEq(latest.length, 0);
    }

    function test_Record_EmptyStringInArray() public {
        string[] memory vals = new string[](2);
        vals[0] = "";
        vals[1] = "x";
        consumer.record(1, vals);

        string[] memory result = consumer.values(1);
        assertEq(result.length, 2);
        assertEq(result[0], "");
        assertEq(result[1], "x");
    }

    function test_Record_SameRoundUpdatesValue() public {
        string[] memory vals1 = new string[](2);
        vals1[0] = "a";
        vals1[1] = "b";
        consumer.record(5, vals1);

        string[] memory vals2 = new string[](1);
        vals2[0] = "c";
        consumer.record(5, vals2);

        assertEq(consumer.changeRoundsLength(), 1);
        string[] memory result = consumer.values(5);
        assertEq(result.length, 1);
        assertEq(result[0], "c");
    }

    function test_Record_MultipleRounds() public {
        string[] memory r1 = new string[](1);
        r1[0] = "r1";
        consumer.record(1, r1);

        string[] memory r2 = new string[](2);
        r2[0] = "r2a";
        r2[1] = "r2b";
        consumer.record(5, r2);

        string[] memory r3 = new string[](1);
        r3[0] = "r3";
        consumer.record(10, r3);

        assertEq(consumer.changeRoundsLength(), 3);
        string[] memory v1 = consumer.values(1);
        assertEq(v1.length, 1);
        assertEq(v1[0], "r1");

        string[] memory v5 = consumer.values(5);
        assertEq(v5.length, 2);
        assertEq(v5[0], "r2a");
        assertEq(v5[1], "r2b");

        string[] memory v10 = consumer.values(10);
        assertEq(v10.length, 1);
        assertEq(v10[0], "r3");
    }

    // ============================================
    // InvalidRound Tests
    // ============================================

    function test_Record_InvalidRound_RevertsWhenRoundIsLessThanLastRound()
        public
    {
        string[] memory vals1 = new string[](1);
        vals1[0] = "a";
        consumer.record(10, vals1);

        string[] memory vals2 = new string[](1);
        vals2[0] = "b";
        vm.expectRevert(RoundHistoryStringArray.InvalidRound.selector);
        consumer.record(5, vals2);
    }

    function test_Record_InvalidRound_MultipleRounds() public {
        string[] memory v = new string[](1);
        v[0] = "x";
        consumer.record(5, v);
        consumer.record(10, v);
        consumer.record(15, v);

        string[] memory invalid = new string[](1);
        invalid[0] = "y";
        vm.expectRevert(RoundHistoryStringArray.InvalidRound.selector);
        consumer.record(1, invalid);

        vm.expectRevert(RoundHistoryStringArray.InvalidRound.selector);
        consumer.record(7, invalid);

        vm.expectRevert(RoundHistoryStringArray.InvalidRound.selector);
        consumer.record(12, invalid);
    }

    // ============================================
    // LatestValues Tests
    // ============================================

    function test_LatestValues_EmptyHistory() public view {
        string[] memory result = consumer.latestValues();
        assertEq(result.length, 0);
    }

    function test_LatestValues_SingleRecord() public {
        string[] memory vals = new string[](2);
        vals[0] = "a";
        vals[1] = "b";
        consumer.record(1, vals);

        string[] memory result = consumer.latestValues();
        assertEq(result.length, 2);
        assertEq(result[0], "a");
        assertEq(result[1], "b");
    }

    function test_LatestValues_MultipleRecords() public {
        string[] memory v1 = new string[](1);
        v1[0] = "r1";
        consumer.record(1, v1);

        string[] memory v5 = new string[](1);
        v5[0] = "r5";
        consumer.record(5, v5);

        string[] memory v10 = new string[](1);
        v10[0] = "r10";
        consumer.record(10, v10);

        string[] memory result = consumer.latestValues();
        assertEq(result.length, 1);
        assertEq(result[0], "r10");
    }

    function test_LatestValues_AfterSameRoundUpdate() public {
        string[] memory vals = new string[](2);
        vals[0] = "a";
        vals[1] = "b";
        consumer.record(5, vals);

        string[] memory vals2 = new string[](1);
        vals2[0] = "c";
        consumer.record(5, vals2);

        string[] memory result = consumer.latestValues();
        assertEq(result.length, 1);
        assertEq(result[0], "c");
    }

    // ============================================
    // Binary Search / values() Tests
    // ============================================

    function test_Values_BeforeFirstRound() public {
        string[] memory v = new string[](1);
        v[0] = "a";
        consumer.record(5, v);
        consumer.record(10, v);

        string[] memory result1 = consumer.values(1);
        assertEq(result1.length, 0);

        string[] memory result4 = consumer.values(4);
        assertEq(result4.length, 0);
    }

    function test_Values_AfterLatestRound() public {
        string[] memory v5 = new string[](1);
        v5[0] = "five";
        consumer.record(5, v5);

        string[] memory v10 = new string[](1);
        v10[0] = "ten";
        consumer.record(10, v10);

        string[] memory result15 = consumer.values(15);
        assertEq(result15.length, 1);
        assertEq(result15[0], "ten");

        string[] memory result100 = consumer.values(100);
        assertEq(result100.length, 1);
        assertEq(result100[0], "ten");
    }

    function test_Values_BetweenRounds_InheritsNearest() public {
        string[] memory v1 = new string[](1);
        v1[0] = "round1";
        consumer.record(1, v1);

        string[] memory v100 = new string[](1);
        v100[0] = "round100";
        consumer.record(100, v100);

        string[] memory at50 = consumer.values(50);
        assertEq(at50.length, 1);
        assertEq(at50[0], "round1");

        string[] memory at99 = consumer.values(99);
        assertEq(at99.length, 1);
        assertEq(at99[0], "round1");

        string[] memory at100 = consumer.values(100);
        assertEq(at100.length, 1);
        assertEq(at100[0], "round100");
    }

    function test_Values_ManyRounds() public {
        for (uint256 i = 1; i <= 10; i++) {
            string[] memory vals = new string[](1);
            vals[0] = _uintToStr(i * 10);
            consumer.record(i * 10, vals);
        }

        assertEq(consumer.changeRoundsLength(), 10);

        string[] memory beforeFirst = consumer.values(5);
        assertEq(beforeFirst.length, 0);

        string[] memory at10 = consumer.values(10);
        assertEq(at10.length, 1);
        assertEq(at10[0], "10");

        string[] memory at55 = consumer.values(55);
        assertEq(at55.length, 1);
        assertEq(at55[0], "50");

        string[] memory at100 = consumer.values(100);
        assertEq(at100.length, 1);
        assertEq(at100[0], "100");

        string[] memory afterLast = consumer.values(150);
        assertEq(afterLast.length, 1);
        assertEq(afterLast[0], "100");
    }

    function test_Values_ExactRoundMatch() public {
        string[] memory vals = new string[](2);
        vals[0] = "exact";
        vals[1] = "match";
        consumer.record(7, vals);

        string[] memory result = consumer.values(7);
        assertEq(result.length, 2);
        assertEq(result[0], "exact");
        assertEq(result[1], "match");
    }

    // ============================================
    // Extreme Round Value Tests
    // ============================================

    function test_Record_ExtremeRoundValue() public {
        string[] memory vals = new string[](1);
        vals[0] = "max";
        consumer.record(type(uint256).max, vals);

        string[] memory result = consumer.values(type(uint256).max);
        assertEq(result.length, 1);
        assertEq(result[0], "max");

        string[] memory latest = consumer.latestValues();
        assertEq(latest.length, 1);
        assertEq(latest[0], "max");
    }

    function test_Values_ExtremeRoundValue() public {
        string[] memory v1 = new string[](1);
        v1[0] = "low";
        consumer.record(1, v1);

        string[] memory vMax = new string[](1);
        vMax[0] = "high";
        consumer.record(type(uint256).max, vMax);

        string[] memory result1 = consumer.values(1);
        assertEq(result1.length, 1);
        assertEq(result1[0], "low");

        string[] memory resultMax = consumer.values(type(uint256).max);
        assertEq(resultMax.length, 1);
        assertEq(resultMax[0], "high");
    }

    // ============================================
    // Helper
    // ============================================

    function _uintToStr(uint256 n) internal pure returns (string memory) {
        if (n == 0) return "0";
        uint256 j = n;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory b = new bytes(len);
        uint256 k = len;
        while (n != 0) {
            k = k - 1;
            uint8 t = uint8(48 + n % 10);
            b[k] = bytes1(t);
            n /= 10;
        }
        return string(b);
    }
}
