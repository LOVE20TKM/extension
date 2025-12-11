// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "../utils/BaseExtensionTest.sol";
import {LOVE20ExtensionBaseJoin} from "../../src/LOVE20ExtensionBaseJoin.sol";
import {
    IVerificationInfo
} from "../../src/interface/base/IVerificationInfo.sol";
import {IExtensionReward} from "../../src/interface/base/IExtensionReward.sol";
import {ExtensionReward} from "../../src/base/ExtensionReward.sol";
import {MockExtensionFactory} from "../mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockVerificationInfo
 * @notice Mock extension for testing VerificationInfo
 */
contract MockVerificationInfo is LOVE20ExtensionBaseJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(
        address factory_,
        address tokenAddress_
    ) LOVE20ExtensionBaseJoin(factory_, tokenAddress_) {}

    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    function joinedValue() external view override returns (uint256) {
        return _accounts.length();
    }

    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        return _accounts.contains(account) ? 1 : 0;
    }

    function rewardByAccount(
        uint256,
        address
    )
        public
        pure
        override(IExtensionReward, ExtensionReward)
        returns (uint256 reward, bool isMinted)
    {
        return (0, false);
    }

    function _calculateReward(
        uint256,
        address
    ) internal pure override returns (uint256) {
        return 0;
    }
}

/**
 * @title VerificationInfoTest
 * @notice Test suite for VerificationInfo
 * @dev Tests verification info update, retrieval, and round-based queries
 */
contract VerificationInfoTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockVerificationInfo public extension;

    event UpdateVerificationInfo(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        string verificationKey,
        string verificationInfo
    );

    function setUp() public {
        setUpBase();

        mockFactory = new MockExtensionFactory(address(center));
        extension = new MockVerificationInfo(
            address(mockFactory),
            address(token)
        );

        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension), address(token));

        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1000e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Set initial round
        join.setCurrentRound(1);
    }

    // ============================================
    // UpdateVerificationInfo Tests
    // ============================================

    function test_UpdateVerificationInfo_Success() public {
        // Setup verification keys
        string[] memory keys = new string[](2);
        keys[0] = "email";
        keys[1] = "twitter";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        // User joins first
        vm.prank(user1);
        extension.join(new string[](0));

        // Update verification info
        string[] memory infos = new string[](2);
        infos[0] = "user1@example.com";
        infos[1] = "@user1_twitter";

        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        // Verify stored info
        assertEq(
            extension.verificationInfo(user1, "email"),
            "user1@example.com"
        );
        assertEq(
            extension.verificationInfo(user1, "twitter"),
            "@user1_twitter"
        );
    }

    function test_UpdateVerificationInfo_EmitEvent() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos = new string[](1);
        infos[0] = "test@example.com";

        vm.expectEmit(true, true, true, true);
        emit UpdateVerificationInfo(
            address(token),
            1, // current round
            ACTION_ID,
            user1,
            "email",
            "test@example.com"
        );

        vm.prank(user1);
        extension.updateVerificationInfo(infos);
    }

    function test_UpdateVerificationInfo_EmptyArray() public {
        vm.prank(user1);
        extension.join(new string[](0));

        // Empty array should not revert
        string[] memory emptyInfos = new string[](0);
        vm.prank(user1);
        extension.updateVerificationInfo(emptyInfos);
    }

    function test_UpdateVerificationInfo_RevertLengthMismatch() public {
        string[] memory keys = new string[](2);
        keys[0] = "email";
        keys[1] = "twitter";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        // Only provide 1 info but 2 keys configured
        string[] memory infos = new string[](1);
        infos[0] = "test@example.com";

        vm.prank(user1);
        vm.expectRevert(
            IVerificationInfo.VerificationInfoLengthMismatch.selector
        );
        extension.updateVerificationInfo(infos);
    }

    function test_UpdateVerificationInfo_MultipleUpdates() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        // First update
        string[] memory infos1 = new string[](1);
        infos1[0] = "first@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos1);

        assertEq(
            extension.verificationInfo(user1, "email"),
            "first@example.com"
        );

        // Second update in same round
        string[] memory infos2 = new string[](1);
        infos2[0] = "second@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos2);

        assertEq(
            extension.verificationInfo(user1, "email"),
            "second@example.com"
        );
    }

    // ============================================
    // VerificationInfo (Latest) Tests
    // ============================================

    function test_VerificationInfo_NoData() public view {
        string memory info = extension.verificationInfo(user1, "email");
        assertEq(info, "", "Should return empty string for no data");
    }

    function test_VerificationInfo_MultipleKeys() public {
        string[] memory keys = new string[](3);
        keys[0] = "email";
        keys[1] = "twitter";
        keys[2] = "github";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos = new string[](3);
        infos[0] = "user@example.com";
        infos[1] = "@user_twitter";
        infos[2] = "user_github";

        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        assertEq(
            extension.verificationInfo(user1, "email"),
            "user@example.com"
        );
        assertEq(extension.verificationInfo(user1, "twitter"), "@user_twitter");
        assertEq(extension.verificationInfo(user1, "github"), "user_github");
    }

    function test_VerificationInfo_MultipleUsers() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        // User1 joins and sets info
        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos1 = new string[](1);
        infos1[0] = "user1@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos1);

        // User2 joins and sets different info
        vm.prank(user2);
        extension.join(new string[](0));

        string[] memory infos2 = new string[](1);
        infos2[0] = "user2@example.com";
        vm.prank(user2);
        extension.updateVerificationInfo(infos2);

        // Verify each user has their own info
        assertEq(
            extension.verificationInfo(user1, "email"),
            "user1@example.com"
        );
        assertEq(
            extension.verificationInfo(user2, "email"),
            "user2@example.com"
        );
    }

    // ============================================
    // VerificationInfoByRound Tests
    // ============================================

    function test_VerificationInfoByRound_ExactMatch() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos = new string[](1);
        infos[0] = "round1@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        // Query exact round
        string memory info = extension.verificationInfoByRound(
            user1,
            "email",
            1
        );
        assertEq(info, "round1@example.com");
    }

    function test_VerificationInfoByRound_FindNearest() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        // Update at round 1
        join.setCurrentRound(1);
        string[] memory infos1 = new string[](1);
        infos1[0] = "round1@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos1);

        // Update at round 5
        join.setCurrentRound(5);
        string[] memory infos5 = new string[](1);
        infos5[0] = "round5@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos5);

        // Query round 3 should return round 1's data
        string memory info = extension.verificationInfoByRound(
            user1,
            "email",
            3
        );
        assertEq(
            info,
            "round1@example.com",
            "Should return nearest left value"
        );

        // Query round 5 should return round 5's data
        info = extension.verificationInfoByRound(user1, "email", 5);
        assertEq(info, "round5@example.com");

        // Query round 10 should return round 5's data
        info = extension.verificationInfoByRound(user1, "email", 10);
        assertEq(info, "round5@example.com", "Should return latest available");
    }

    function test_VerificationInfoByRound_NoDataForRound() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        // Update at round 5
        join.setCurrentRound(5);
        string[] memory infos = new string[](1);
        infos[0] = "round5@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        // Query round 3 (before any updates)
        string memory info = extension.verificationInfoByRound(
            user1,
            "email",
            3
        );
        assertEq(
            info,
            "",
            "Should return empty for rounds before first update"
        );
    }

    function test_VerificationInfoByRound_NoData() public view {
        string memory info = extension.verificationInfoByRound(
            user1,
            "email",
            1
        );
        assertEq(info, "", "Should return empty for non-existent data");
    }

    // ============================================
    // VerificationInfoUpdateRoundsCount Tests
    // ============================================

    function test_VerificationInfoUpdateRoundsCount_NoUpdates() public view {
        uint256 count = extension.verificationInfoUpdateRoundsCount(
            user1,
            "email"
        );
        assertEq(count, 0, "Should be 0 for no updates");
    }

    function test_VerificationInfoUpdateRoundsCount_SingleUpdate() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos = new string[](1);
        infos[0] = "test@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        uint256 count = extension.verificationInfoUpdateRoundsCount(
            user1,
            "email"
        );
        assertEq(count, 1, "Should be 1 after single update");
    }

    function test_VerificationInfoUpdateRoundsCount_MultipleUpdates() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        // Update at round 1
        join.setCurrentRound(1);
        string[] memory infos = new string[](1);
        infos[0] = "round1@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        // Update at round 3
        join.setCurrentRound(3);
        infos[0] = "round3@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        // Update at round 5
        join.setCurrentRound(5);
        infos[0] = "round5@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        uint256 count = extension.verificationInfoUpdateRoundsCount(
            user1,
            "email"
        );
        assertEq(
            count,
            3,
            "Should be 3 after three updates in different rounds"
        );
    }

    function test_VerificationInfoUpdateRoundsCount_SameRoundCounts() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        // Multiple updates in same round
        string[] memory infos = new string[](1);
        infos[0] = "first@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        infos[0] = "second@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        uint256 count = extension.verificationInfoUpdateRoundsCount(
            user1,
            "email"
        );
        assertEq(count, 1, "Should be 1 for multiple updates in same round");
    }

    // ============================================
    // VerificationInfoUpdateRoundsAtIndex Tests
    // ============================================

    function test_VerificationInfoUpdateRoundsAtIndex() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        // Update at round 1
        join.setCurrentRound(1);
        string[] memory infos = new string[](1);
        infos[0] = "round1@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        // Update at round 5
        join.setCurrentRound(5);
        infos[0] = "round5@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        // Update at round 10
        join.setCurrentRound(10);
        infos[0] = "round10@example.com";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        // Check indexed values
        assertEq(
            extension.verificationInfoUpdateRoundsAtIndex(user1, "email", 0),
            1
        );
        assertEq(
            extension.verificationInfoUpdateRoundsAtIndex(user1, "email", 1),
            5
        );
        assertEq(
            extension.verificationInfoUpdateRoundsAtIndex(user1, "email", 2),
            10
        );
    }

    // ============================================
    // Integration with Join Tests
    // ============================================

    function test_Integration_JoinWithVerificationInfo() public {
        string[] memory keys = new string[](2);
        keys[0] = "email";
        keys[1] = "twitter";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        string[] memory infos = new string[](2);
        infos[0] = "user@example.com";
        infos[1] = "@user_twitter";

        // Join with verification info
        vm.prank(user1);
        extension.join(infos);

        // Verify stored
        assertEq(
            extension.verificationInfo(user1, "email"),
            "user@example.com"
        );
        assertEq(extension.verificationInfo(user1, "twitter"), "@user_twitter");
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_EdgeCase_EmptyKey() public {
        string[] memory keys = new string[](1);
        keys[0] = "";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos = new string[](1);
        infos[0] = "some_value";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        assertEq(extension.verificationInfo(user1, ""), "some_value");
    }

    function test_EdgeCase_EmptyValue() public {
        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos = new string[](1);
        infos[0] = "";
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        assertEq(extension.verificationInfo(user1, "email"), "");
    }

    function test_EdgeCase_LongValue() public {
        string[] memory keys = new string[](1);
        keys[0] = "bio";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        // Create a long string
        string
            memory longBio = "This is a very long bio that contains a lot of text. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";

        string[] memory infos = new string[](1);
        infos[0] = longBio;
        vm.prank(user1);
        extension.updateVerificationInfo(infos);

        assertEq(extension.verificationInfo(user1, "bio"), longBio);
    }

    function test_EdgeCase_DifferentKeysForDifferentUsers() public {
        string[] memory keys = new string[](2);
        keys[0] = "email";
        keys[1] = "twitter";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        // User1 only sets email
        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos1 = new string[](2);
        infos1[0] = "user1@example.com";
        infos1[1] = "";
        vm.prank(user1);
        extension.updateVerificationInfo(infos1);

        // User2 only sets twitter
        vm.prank(user2);
        extension.join(new string[](0));

        string[] memory infos2 = new string[](2);
        infos2[0] = "";
        infos2[1] = "@user2_twitter";
        vm.prank(user2);
        extension.updateVerificationInfo(infos2);

        // Verify
        assertEq(
            extension.verificationInfo(user1, "email"),
            "user1@example.com"
        );
        assertEq(extension.verificationInfo(user1, "twitter"), "");
        assertEq(extension.verificationInfo(user2, "email"), "");
        assertEq(
            extension.verificationInfo(user2, "twitter"),
            "@user2_twitter"
        );
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_UpdateRounds(uint8 numRounds) public {
        numRounds = uint8(bound(numRounds, 1, 20));

        string[] memory keys = new string[](1);
        keys[0] = "email";
        submit.setVerificationKeys(address(token), ACTION_ID, keys);

        vm.prank(user1);
        extension.join(new string[](0));

        string[] memory infos = new string[](1);

        for (uint256 i = 1; i <= numRounds; i++) {
            join.setCurrentRound(i);
            infos[0] = string(abi.encodePacked("email_round_", vm.toString(i)));
            vm.prank(user1);
            extension.updateVerificationInfo(infos);
        }

        uint256 count = extension.verificationInfoUpdateRoundsCount(
            user1,
            "email"
        );
        assertEq(count, numRounds);

        // Verify last update
        string memory expected = string(
            abi.encodePacked("email_round_", vm.toString(numRounds))
        );
        assertEq(extension.verificationInfo(user1, "email"), expected);
    }
}
