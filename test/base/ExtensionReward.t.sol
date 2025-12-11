// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "../utils/BaseExtensionTest.sol";
import {LOVE20ExtensionBaseJoin} from "../../src/LOVE20ExtensionBaseJoin.sol";
import {IExtensionReward} from "../../src/interface/base/IExtensionReward.sol";
import {ExtensionReward} from "../../src/base/ExtensionReward.sol";
import {MockExtensionFactory} from "../mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockExtensionForReward
 * @notice Mock extension for testing ExtensionReward
 */
contract MockExtensionForReward is LOVE20ExtensionBaseJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Configurable reward calculation
    uint256 public rewardPerAccount;
    mapping(address => uint256) public customRewardByAccount;
    bool public useCustomReward;

    constructor(
        address factory_,
        address tokenAddress_
    ) LOVE20ExtensionBaseJoin(factory_, tokenAddress_) {}

    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    function joinedValue() external view override returns (uint256) {
        return _center.accountsCount(tokenAddress, actionId);
    }

    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        return _center.isAccountJoined(tokenAddress, actionId, account) ? 1 : 0;
    }

    // Configure reward calculation
    function setRewardPerAccount(uint256 reward) external {
        rewardPerAccount = reward;
    }

    function setCustomRewardByAccount(
        address account,
        uint256 reward
    ) external {
        customRewardByAccount[account] = reward;
        useCustomReward = true;
    }

    // Override _calculateReward to return configurable values
    function _calculateReward(
        uint256,
        address account
    ) internal view override returns (uint256) {
        if (useCustomReward) {
            return customRewardByAccount[account];
        }
        // Default: equal distribution if account has joined
        if (
            _center.isAccountJoined(tokenAddress, actionId, account) &&
            _center.accountsCount(tokenAddress, actionId) > 0
        ) {
            return rewardPerAccount;
        }
        return 0;
    }

    // Expose internal reward storage for testing
    function getRewardForRound(uint256 round) external view returns (uint256) {
        return _reward[round];
    }

    function getClaimedReward(
        uint256 round,
        address account
    ) external view returns (uint256) {
        return _claimedReward[round][account];
    }
}

/**
 * @title ExtensionRewardTest
 * @notice Test suite for ExtensionReward
 * @dev Tests reward claiming, calculation, and edge cases
 */
contract ExtensionRewardTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockExtensionForReward public extension;

    event ClaimReward(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );

    function setUp() public {
        setUpBase();

        mockFactory = new MockExtensionFactory(address(center));
        extension = new MockExtensionForReward(
            address(mockFactory),
            address(token)
        );

        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension), address(token));

        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1000e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Setup default reward
        extension.setRewardPerAccount(100e18);
    }

    // ============================================
    // ClaimReward Tests
    // ============================================

    function test_ClaimReward_Success() public {
        // User joins
        vm.prank(user1);
        extension.join(new string[](0));

        // Setup round and reward
        uint256 targetRound = 0;
        uint256 rewardAmount = 100e18;
        verify.setCurrentRound(1); // Make round 0 finished
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        uint256 claimed = extension.claimReward(targetRound);

        assertEq(claimed, rewardAmount, "Claimed amount should match");
        assertEq(
            token.balanceOf(user1),
            balanceBefore + rewardAmount,
            "Balance should increase"
        );
    }

    function test_ClaimReward_EmitEvent() public {
        vm.prank(user1);
        extension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        vm.expectEmit(true, true, true, true);
        emit ClaimReward(address(token), targetRound, ACTION_ID, user1, 100e18);

        vm.prank(user1);
        extension.claimReward(targetRound);
    }

    function test_ClaimReward_RevertIfRoundNotFinished() public {
        vm.prank(user1);
        extension.join(new string[](0));

        // Current round is 0, try to claim round 0
        verify.setCurrentRound(0);

        vm.prank(user1);
        vm.expectRevert(IExtensionReward.RoundNotFinished.selector);
        extension.claimReward(0);
    }

    function test_ClaimReward_RevertIfRoundIsCurrentRound() public {
        vm.prank(user1);
        extension.join(new string[](0));

        verify.setCurrentRound(5);

        vm.prank(user1);
        vm.expectRevert(IExtensionReward.RoundNotFinished.selector);
        extension.claimReward(5);
    }

    function test_ClaimReward_RevertIfAlreadyClaimed() public {
        vm.prank(user1);
        extension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        // First claim succeeds
        vm.prank(user1);
        extension.claimReward(targetRound);

        // Second claim reverts
        vm.prank(user1);
        vm.expectRevert(IExtensionReward.AlreadyClaimed.selector);
        extension.claimReward(targetRound);
    }

    function test_ClaimReward_ZeroReward() public {
        // User joins but has zero reward configured
        vm.prank(user1);
        extension.join(new string[](0));
        extension.setRewardPerAccount(0);

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 0);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        uint256 claimed = extension.claimReward(targetRound);

        assertEq(claimed, 0, "Claimed amount should be zero");
        assertEq(token.balanceOf(user1), balanceBefore, "Balance unchanged");
    }

    function test_ClaimReward_MultipleUsersIndependently() public {
        // Setup custom rewards for different users
        extension.setCustomRewardByAccount(user1, 100e18);
        extension.setCustomRewardByAccount(user2, 200e18);
        extension.setCustomRewardByAccount(user3, 300e18);

        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 600e18);

        // Each user claims their reward
        vm.prank(user1);
        assertEq(extension.claimReward(targetRound), 100e18);

        vm.prank(user2);
        assertEq(extension.claimReward(targetRound), 200e18);

        vm.prank(user3);
        assertEq(extension.claimReward(targetRound), 300e18);
    }

    function test_ClaimReward_MultipleRounds() public {
        vm.prank(user1);
        extension.join(new string[](0));

        // Setup multiple rounds
        mint.setActionReward(address(token), 0, ACTION_ID, 100e18);
        mint.setActionReward(address(token), 1, ACTION_ID, 150e18);
        mint.setActionReward(address(token), 2, ACTION_ID, 200e18);

        verify.setCurrentRound(3);

        // Claim all rounds
        vm.startPrank(user1);
        assertEq(extension.claimReward(0), 100e18);
        assertEq(extension.claimReward(1), 100e18); // rewardPerAccount is 100e18
        assertEq(extension.claimReward(2), 100e18);
        vm.stopPrank();
    }

    // ============================================
    // RewardByAccount Tests
    // ============================================

    function test_RewardByAccount_NotClaimed() public {
        vm.prank(user1);
        extension.join(new string[](0));

        uint256 targetRound = 0;
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            targetRound,
            user1
        );

        assertEq(reward, 100e18, "Reward should match");
        assertFalse(isMinted, "Should not be minted yet");
    }

    function test_RewardByAccount_AlreadyClaimed() public {
        vm.prank(user1);
        extension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        // Claim the reward
        vm.prank(user1);
        extension.claimReward(targetRound);

        // Check reward status
        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            targetRound,
            user1
        );

        assertEq(reward, 100e18, "Reward amount should be recorded");
        assertTrue(isMinted, "Should be marked as minted");
    }

    function test_RewardByAccount_NotJoined() public {
        uint256 targetRound = 0;
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            targetRound,
            user1
        );

        assertEq(reward, 0, "Reward should be zero for non-joined user");
        assertFalse(isMinted, "Should not be minted");
    }

    function test_RewardByAccount_DifferentRounds() public {
        vm.prank(user1);
        extension.join(new string[](0));

        mint.setActionReward(address(token), 0, ACTION_ID, 100e18);
        mint.setActionReward(address(token), 1, ACTION_ID, 200e18);

        (uint256 reward0, ) = extension.rewardByAccount(0, user1);
        (uint256 reward1, ) = extension.rewardByAccount(1, user1);

        assertEq(reward0, 100e18);
        assertEq(reward1, 100e18); // rewardPerAccount is always 100e18
    }

    // ============================================
    // PrepareRewardIfNeeded Tests
    // ============================================

    function test_PrepareReward_OnlyOnce() public {
        vm.prank(user1);
        extension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        // First claim prepares the reward
        vm.prank(user1);
        extension.claimReward(targetRound);

        uint256 storedReward = extension.getRewardForRound(targetRound);
        assertEq(storedReward, 100e18, "Reward should be stored");

        // Second user claiming same round should use stored reward
        extension.setCustomRewardByAccount(user2, 50e18);
        vm.prank(user2);
        extension.join(new string[](0));

        vm.prank(user2);
        extension.claimReward(targetRound);

        // Stored reward should still be the same
        assertEq(
            extension.getRewardForRound(targetRound),
            100e18,
            "Stored reward unchanged"
        );
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_EdgeCase_ClaimOldRound() public {
        vm.prank(user1);
        extension.join(new string[](0));

        // Current round is 100, claim round 0
        verify.setCurrentRound(100);
        mint.setActionReward(address(token), 0, ACTION_ID, 100e18);

        vm.prank(user1);
        uint256 claimed = extension.claimReward(0);
        assertEq(claimed, 100e18);
    }

    function test_EdgeCase_UserNotJoinedCannotClaim() public {
        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        vm.prank(user1);
        uint256 claimed = extension.claimReward(targetRound);

        // User not joined, reward should be 0
        assertEq(claimed, 0, "Non-joined user should get 0 reward");
    }

    function test_EdgeCase_ClaimAfterExit() public {
        // User joins and then exits
        vm.prank(user1);
        extension.join(new string[](0));

        vm.prank(user1);
        extension.exit();

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        // User has exited, should get 0 reward
        vm.prank(user1);
        uint256 claimed = extension.claimReward(targetRound);
        assertEq(claimed, 0, "Exited user should get 0 reward");
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_ClaimReward(uint256 rewardAmount) public {
        rewardAmount = bound(rewardAmount, 1, 1000e18);

        vm.prank(user1);
        extension.join(new string[](0));
        extension.setRewardPerAccount(rewardAmount);

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(
            address(token),
            targetRound,
            ACTION_ID,
            rewardAmount
        );

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        uint256 claimed = extension.claimReward(targetRound);

        assertEq(claimed, rewardAmount);
        assertEq(token.balanceOf(user1), balanceBefore + rewardAmount);
    }

    function testFuzz_ClaimMultipleRounds(uint8 numRounds) public {
        numRounds = uint8(bound(numRounds, 1, 10));

        vm.prank(user1);
        extension.join(new string[](0));

        for (uint256 i = 0; i < numRounds; i++) {
            mint.setActionReward(address(token), i, ACTION_ID, 100e18);
        }

        verify.setCurrentRound(numRounds);

        vm.startPrank(user1);
        for (uint256 i = 0; i < numRounds; i++) {
            extension.claimReward(i);
        }
        vm.stopPrank();

        // Verify all rounds are claimed
        for (uint256 i = 0; i < numRounds; i++) {
            (, bool isMinted) = extension.rewardByAccount(i, user1);
            assertTrue(isMinted, "Round should be claimed");
        }
    }
}
