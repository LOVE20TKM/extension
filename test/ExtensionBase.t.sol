// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {ExtensionBaseRewardJoin} from "../src/ExtensionBaseRewardJoin.sol";
import {IReward} from "../src/interface/IReward.sol";
import {IRewardEvents} from "../src/interface/IReward.sol";
import {IRewardErrors} from "../src/interface/IReward.sol";
import {ExtensionBaseReward} from "../src/ExtensionBaseReward.sol";
import {ExtensionBase} from "../src/ExtensionBase.sol";
import {IExtension} from "../src/interface/IExtension.sol";
import {IExtensionErrors} from "../src/interface/IExtension.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockExtensionForCore
 * @notice Mock extension for testing ExtensionBaseReward
 */
contract MockExtensionForCore is ExtensionBaseRewardJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBaseRewardJoin(factory_, tokenAddress_) {}

    function joinedAmount()
        external
        pure
        override(ExtensionBase)
        returns (uint256)
    {
        return 0;
    }

    function joinedAmountByAccount(
        address
    ) external pure override(ExtensionBase) returns (uint256) {
        return 0;
    }

    function joinedAmountTokenAddress()
        external
        view
        override(ExtensionBase)
        returns (address)
    {
        return TOKEN_ADDRESS;
    }

    function rewardByAccount(
        uint256,
        address
    )
        public
        pure
        override(ExtensionBaseReward)
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
 * @title MockExtensionForReward
 * @notice Mock extension for testing ExtensionReward
 */
contract MockExtensionForReward is ExtensionBaseRewardJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Configurable reward calculation
    uint256 public rewardPerAccount;
    mapping(address => uint256) public customRewardByAccount;
    bool public useCustomReward;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBaseRewardJoin(factory_, tokenAddress_) {}

    function joinedAmount()
        external
        view
        override(ExtensionBase)
        returns (uint256)
    {
        return _center.accountsCount(TOKEN_ADDRESS, actionId);
    }

    function joinedAmountByAccount(
        address account
    ) external view override(ExtensionBase) returns (uint256) {
        return
            _center.isAccountJoined(TOKEN_ADDRESS, actionId, account) ? 1 : 0;
    }

    function joinedAmountTokenAddress()
        external
        view
        override(ExtensionBase)
        returns (address)
    {
        return TOKEN_ADDRESS;
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
            _center.isAccountJoined(TOKEN_ADDRESS, actionId, account) &&
            _center.accountsCount(TOKEN_ADDRESS, actionId) > 0
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
        return _claimedRewardByAccount[round][account];
    }
}

/**
 * @title ExtensionBaseRewardTest
 * @notice Test suite for ExtensionBaseReward
 * @dev Tests constructor, initialization, view functions, and reward claiming
 */
contract ExtensionBaseTest is BaseExtensionTest, IRewardEvents {
    MockExtensionFactory public mockFactory;
    MockExtensionForCore public extension;
    MockExtensionForReward public rewardExtension;

    function setUp() public {
        setUpBase();

        mockFactory = new MockExtensionFactory(address(center));
        extension = new MockExtensionForCore(
            address(mockFactory),
            address(token)
        );

        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension), address(token));
    }

    // Helper function to set action info with author
    function _setActionInfoWithAuthor(
        address extensionAddress,
        uint256 actionId
    ) internal {
        submit.setActionInfo(address(token), actionId, extensionAddress);
        address extensionCreator = mockFactory.extensionCreator(
            extensionAddress
        );
        if (extensionCreator != address(0)) {
            submit.setActionAuthor(address(token), actionId, extensionCreator);
        }
    }

    // ============================================
    // Constructor Tests
    // ============================================

    function test_Constructor_StoresFactory() public view {
        assertEq(
            extension.FACTORY_ADDRESS(),
            address(mockFactory),
            "Factory should be stored"
        );
    }

    function test_Constructor_RetrievesCenter() public view {
        assertEq(
            mockFactory.CENTER_ADDRESS(),
            address(center),
            "Center should be retrieved from factory"
        );
    }

    function test_Constructor_NotInitialized() public view {
        assertFalse(
            extension.initialized(),
            "Should not be initialized at construction"
        );
    }

    function test_Constructor_TokenAddressSet() public view {
        assertEq(
            extension.TOKEN_ADDRESS(),
            address(token),
            "Token address should be set at construction"
        );
    }

    function test_Constructor_ActionIdZero() public view {
        assertEq(
            extension.actionId(),
            0,
            "Action ID should be zero before init"
        );
    }

    // ============================================
    // Initialize Tests
    // ============================================

    function test_Initialize_Success() public {
        _setActionInfoWithAuthor(address(extension), ACTION_ID);
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(new string[](0));

        assertTrue(extension.initialized(), "Should be initialized");
        assertEq(
            extension.TOKEN_ADDRESS(),
            address(token),
            "Token address should be set"
        );
        assertEq(extension.actionId(), ACTION_ID, "Action ID should be set");
    }

    function test_Initialize_RevertIfExtensionCreatorMismatch() public {
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        address differentAuthor = address(0x999);
        submit.setActionAuthor(address(token), ACTION_ID, differentAuthor);
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        vm.prank(user1);
        vm.expectRevert(IExtensionErrors.ActionIdNotFound.selector);
        extension.join(new string[](0));
    }

    function test_Initialize_MultipleActionIds_OnlyOneMatches() public {
        uint256 actionId1 = ACTION_ID;
        uint256 actionId2 = ACTION_ID + 1;
        uint256 actionId3 = ACTION_ID + 2;

        address extensionCreator = mockFactory.extensionCreator(
            address(extension)
        );

        // Action 1: matches whiteListAddress but not author
        submit.setActionInfo(address(token), actionId1, address(extension));
        submit.setActionAuthor(address(token), actionId1, address(0x999));

        // Action 2: matches both whiteListAddress and author
        submit.setActionInfo(address(token), actionId2, address(extension));
        submit.setActionAuthor(address(token), actionId2, extensionCreator);

        // Action 3: matches whiteListAddress but not author
        submit.setActionInfo(address(token), actionId3, address(extension));
        submit.setActionAuthor(address(token), actionId3, address(0x888));

        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), actionId1);
        vote.setVotedActionIds(address(token), join.currentRound(), actionId2);
        vote.setVotedActionIds(address(token), join.currentRound(), actionId3);

        vm.prank(user1);
        extension.join(new string[](0));

        assertTrue(extension.initialized());
        assertEq(extension.actionId(), actionId2);
    }

    function test_Initialize_MultipleActionIds_NoneMatches() public {
        uint256 actionId1 = ACTION_ID;
        uint256 actionId2 = ACTION_ID + 1;

        // Both actions match whiteListAddress but not author
        submit.setActionInfo(address(token), actionId1, address(extension));
        submit.setActionAuthor(address(token), actionId1, address(0x999));

        submit.setActionInfo(address(token), actionId2, address(extension));
        submit.setActionAuthor(address(token), actionId2, address(0x888));

        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), actionId1);
        vote.setVotedActionIds(address(token), join.currentRound(), actionId2);

        vm.prank(user1);
        vm.expectRevert(IExtensionErrors.ActionIdNotFound.selector);
        extension.join(new string[](0));
    }

    // ============================================
    // View Functions Tests
    // ============================================

    function test_Center_ReturnsCorrectAddress() public view {
        assertEq(mockFactory.CENTER_ADDRESS(), address(center));
    }

    function test_Factory_ReturnsCorrectAddress() public view {
        assertEq(extension.FACTORY_ADDRESS(), address(mockFactory));
    }

    function test_TokenAddress_SetAtConstruction() public view {
        // tokenAddress is now set at construction, not at initialization
        assertEq(extension.TOKEN_ADDRESS(), address(token));
    }

    function test_TokenAddress_AfterInit() public {
        _setActionInfoWithAuthor(address(extension), ACTION_ID);
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(extension.TOKEN_ADDRESS(), address(token));
    }

    function test_ActionId_BeforeInit() public view {
        assertEq(extension.actionId(), 0);
    }

    function test_ActionId_AfterInit() public {
        _setActionInfoWithAuthor(address(extension), ACTION_ID);
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(extension.actionId(), ACTION_ID);
    }

    function test_Initialized_BeforeInit() public view {
        assertFalse(extension.initialized());
    }

    function test_Initialized_AfterInit() public {
        _setActionInfoWithAuthor(address(extension), ACTION_ID);
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(new string[](0));

        assertTrue(extension.initialized());
    }

    // ============================================
    // Multiple Extensions Tests
    // ============================================

    function test_MultipleExtensions_IndependentInit() public {
        MockExtensionForCore extension2 = new MockExtensionForCore(
            address(mockFactory),
            address(token)
        );
        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension2), address(token));

        // Setup first extension
        _setActionInfoWithAuthor(address(extension), ACTION_ID);
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Setup second extension with different action ID
        _setActionInfoWithAuthor(address(extension2), ACTION_ID + 1);
        token.mint(address(extension2), 1e18);
        vote.setVotedActionIds(
            address(token),
            join.currentRound(),
            ACTION_ID + 1
        );

        // First extension auto-initializes when user joins
        vm.prank(user1);
        extension.join(new string[](0));

        // Second extension auto-initializes when user joins
        vm.prank(user1);
        extension2.join(new string[](0));

        // Verify both are independently initialized
        assertTrue(extension.initialized());
        assertTrue(extension2.initialized());
        assertEq(extension.actionId(), ACTION_ID);
        assertEq(extension2.actionId(), ACTION_ID + 1);
    }

    // ============================================
    // ClaimReward Tests
    // ============================================

    function setUpRewardExtension() internal {
        rewardExtension = new MockExtensionForReward(
            address(mockFactory),
            address(token)
        );
        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(rewardExtension), address(token));

        _setActionInfoWithAuthor(address(rewardExtension), ACTION_ID);
        token.mint(address(rewardExtension), 1000e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Setup default reward
        rewardExtension.setRewardPerAccount(100e18);
    }

    function test_ClaimReward_Success() public {
        setUpRewardExtension();

        // User joins
        vm.prank(user1);
        rewardExtension.join(new string[](0));

        // Setup round and reward
        uint256 targetRound = 0;
        uint256 rewardAmount = 100e18;
        verify.setCurrentRound(1); // Make round 0 finished
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        uint256 claimed = rewardExtension.claimReward(targetRound);

        assertEq(claimed, rewardAmount, "Claimed amount should match");
        assertEq(
            token.balanceOf(user1),
            balanceBefore + rewardAmount,
            "Balance should increase"
        );
    }

    function test_ClaimReward_EmitEvent() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        vm.expectEmit(true, true, true, true);
        emit ClaimReward(address(token), targetRound, ACTION_ID, user1, 100e18);

        vm.prank(user1);
        rewardExtension.claimReward(targetRound);
    }

    function test_ClaimReward_RevertIfRoundNotFinished() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        // Current round is 0, try to claim round 0
        verify.setCurrentRound(0);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionErrors.RoundNotFinished.selector,
                0
            )
        );
        rewardExtension.claimReward(0);
    }

    function test_ClaimReward_RevertIfRoundIsCurrentRound() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        verify.setCurrentRound(5);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionErrors.RoundNotFinished.selector,
                5
            )
        );
        rewardExtension.claimReward(5);
    }

    function test_ClaimReward_RevertIfAlreadyClaimed() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        // First claim succeeds
        vm.prank(user1);
        rewardExtension.claimReward(targetRound);

        // Second claim reverts
        vm.prank(user1);
        vm.expectRevert(IRewardErrors.AlreadyClaimed.selector);
        rewardExtension.claimReward(targetRound);
    }

    function test_ClaimReward_ZeroReward() public {
        setUpRewardExtension();

        // User joins but has zero reward configured
        vm.prank(user1);
        rewardExtension.join(new string[](0));
        rewardExtension.setRewardPerAccount(0);

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 0);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        uint256 claimed = rewardExtension.claimReward(targetRound);

        assertEq(claimed, 0, "Claimed amount should be zero");
        assertEq(token.balanceOf(user1), balanceBefore, "Balance unchanged");
    }

    function test_ClaimReward_MultipleUsersIndependently() public {
        setUpRewardExtension();

        // Setup custom rewards for different users
        rewardExtension.setCustomRewardByAccount(user1, 100e18);
        rewardExtension.setCustomRewardByAccount(user2, 200e18);
        rewardExtension.setCustomRewardByAccount(user3, 300e18);

        vm.prank(user1);
        rewardExtension.join(new string[](0));
        vm.prank(user2);
        rewardExtension.join(new string[](0));
        vm.prank(user3);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 600e18);

        // Each user claims their reward
        vm.prank(user1);
        assertEq(rewardExtension.claimReward(targetRound), 100e18);

        vm.prank(user2);
        assertEq(rewardExtension.claimReward(targetRound), 200e18);

        vm.prank(user3);
        assertEq(rewardExtension.claimReward(targetRound), 300e18);
    }

    function test_ClaimReward_MultipleRounds() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        // Setup multiple rounds
        mint.setActionReward(address(token), 0, ACTION_ID, 100e18);
        mint.setActionReward(address(token), 1, ACTION_ID, 150e18);
        mint.setActionReward(address(token), 2, ACTION_ID, 200e18);

        verify.setCurrentRound(3);

        // Claim all rounds
        vm.startPrank(user1);
        assertEq(rewardExtension.claimReward(0), 100e18);
        assertEq(rewardExtension.claimReward(1), 100e18); // rewardPerAccount is 100e18
        assertEq(rewardExtension.claimReward(2), 100e18);
        vm.stopPrank();
    }

    function test_ClaimRewards_SkipUnfinishedAndClaimed() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        mint.setActionReward(address(token), 0, ACTION_ID, 100e18);
        mint.setActionReward(address(token), 1, ACTION_ID, 100e18);
        verify.setCurrentRound(2);

        vm.prank(user1);
        rewardExtension.claimReward(1);

        uint256[] memory rounds = new uint256[](3);
        rounds[0] = 0;
        rounds[1] = 1;
        rounds[2] = 2;

        vm.prank(user1);
        (
            uint256[] memory claimedRounds,
            uint256[] memory rewards
        ) = rewardExtension.claimRewards(rounds);

        assertEq(claimedRounds.length, 1);
        assertEq(rewards.length, 1);
        assertEq(claimedRounds[0], 0);
        assertEq(rewards[0], 100e18);
    }

    // ============================================
    // RewardByAccount Tests
    // ============================================

    function test_RewardByAccount_NotClaimed() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        (uint256 reward, bool isMinted) = rewardExtension.rewardByAccount(
            targetRound,
            user1
        );

        assertEq(reward, 100e18, "Reward should match");
        assertFalse(isMinted, "Should not be minted yet");
    }

    function test_RewardByAccount_AlreadyClaimed() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        // Claim the reward
        vm.prank(user1);
        rewardExtension.claimReward(targetRound);

        // Check reward status
        (uint256 reward, bool isMinted) = rewardExtension.rewardByAccount(
            targetRound,
            user1
        );

        assertEq(reward, 100e18, "Reward amount should be recorded");
        assertTrue(isMinted, "Should be marked as minted");
    }

    function test_RewardByAccount_NotJoined() public {
        setUpRewardExtension();

        uint256 targetRound = 0;
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        (uint256 reward, bool isMinted) = rewardExtension.rewardByAccount(
            targetRound,
            user1
        );

        assertEq(reward, 0, "Reward should be zero for non-joined user");
        assertFalse(isMinted, "Should not be minted");
    }

    function test_RewardByAccount_DifferentRounds() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        mint.setActionReward(address(token), 0, ACTION_ID, 100e18);
        mint.setActionReward(address(token), 1, ACTION_ID, 200e18);

        (uint256 reward0, ) = rewardExtension.rewardByAccount(0, user1);
        (uint256 reward1, ) = rewardExtension.rewardByAccount(1, user1);

        assertEq(reward0, 100e18);
        assertEq(reward1, 100e18); // rewardPerAccount is always 100e18
    }

    // ============================================
    // PrepareRewardIfNeeded Tests
    // ============================================

    function test_PrepareReward_OnlyOnce() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        // First claim prepares the reward
        vm.prank(user1);
        rewardExtension.claimReward(targetRound);

        uint256 storedReward = rewardExtension.getRewardForRound(targetRound);
        assertEq(storedReward, 100e18, "Reward should be stored");

        // Second user claiming same round should use stored reward
        rewardExtension.setCustomRewardByAccount(user2, 50e18);
        vm.prank(user2);
        rewardExtension.join(new string[](0));

        vm.prank(user2);
        rewardExtension.claimReward(targetRound);

        // Stored reward should still be the same
        assertEq(
            rewardExtension.getRewardForRound(targetRound),
            100e18,
            "Stored reward unchanged"
        );
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_EdgeCase_ClaimOldRound() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        // Current round is 100, claim round 0
        verify.setCurrentRound(100);
        mint.setActionReward(address(token), 0, ACTION_ID, 100e18);

        vm.prank(user1);
        uint256 claimed = rewardExtension.claimReward(0);
        assertEq(claimed, 100e18);
    }

    function test_EdgeCase_UserNotJoinedCannotClaim() public {
        setUpRewardExtension();

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        vm.prank(user1);
        uint256 claimed = rewardExtension.claimReward(targetRound);

        // User not joined, reward should be 0
        assertEq(claimed, 0, "Non-joined user should get 0 reward");
    }

    function test_EdgeCase_ClaimAfterExit() public {
        setUpRewardExtension();

        // User joins and then exits
        vm.prank(user1);
        rewardExtension.join(new string[](0));

        vm.prank(user1);
        rewardExtension.exit();

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 100e18);

        // User has exited, should get 0 reward
        vm.prank(user1);
        uint256 claimed = rewardExtension.claimReward(targetRound);
        assertEq(claimed, 0, "Exited user should get 0 reward");
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_ClaimReward(uint256 rewardAmount) public {
        setUpRewardExtension();

        rewardAmount = bound(rewardAmount, 1, 1000e18);

        vm.prank(user1);
        rewardExtension.join(new string[](0));
        rewardExtension.setRewardPerAccount(rewardAmount);

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
        uint256 claimed = rewardExtension.claimReward(targetRound);

        assertEq(claimed, rewardAmount);
        assertEq(token.balanceOf(user1), balanceBefore + rewardAmount);
    }

    function testFuzz_ClaimMultipleRounds(uint8 numRounds) public {
        setUpRewardExtension();

        numRounds = uint8(bound(numRounds, 1, 10));

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        for (uint256 i = 0; i < numRounds; i++) {
            mint.setActionReward(address(token), i, ACTION_ID, 100e18);
        }

        verify.setCurrentRound(numRounds);

        vm.startPrank(user1);
        for (uint256 i = 0; i < numRounds; i++) {
            rewardExtension.claimReward(i);
        }
        vm.stopPrank();

        // Verify all rounds are claimed
        for (uint256 i = 0; i < numRounds; i++) {
            (, bool isMinted) = rewardExtension.rewardByAccount(i, user1);
            assertTrue(isMinted, "Round should be claimed");
        }
    }

    // ============================================
    // BurnRewardIfNeeded Tests
    // ============================================

    function test_BurnRewardIfNeeded_AllAccountsZeroReward() public {
        setUpRewardExtension();

        // Setup: users join but have zero reward
        rewardExtension.setRewardPerAccount(0);

        vm.prank(user1);
        rewardExtension.join(new string[](0));
        vm.prank(user2);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        uint256 totalReward = 100e18;
        mint.setActionReward(address(token), targetRound, ACTION_ID, totalReward);

        // Mint tokens to contract for burning
        token.mint(address(rewardExtension), totalReward);

        uint256 tokenBalanceBefore = token.balanceOf(address(rewardExtension));

        // Burn should succeed and burn all reward (all accounts have 0 reward)
        rewardExtension.burnRewardIfNeeded(targetRound);

        // Verify tokens were burned
        uint256 tokenBalanceAfter = token.balanceOf(address(rewardExtension));
        assertEq(
            tokenBalanceAfter,
            tokenBalanceBefore - totalReward,
            "Token should be burned when all accounts have zero reward"
        );

        // Verify burn info
        (uint256 burnAmount, bool burned) = rewardExtension.burnInfo(targetRound);
        assertEq(burnAmount, totalReward, "Burn amount should match total reward");
        assertTrue(burned, "Should be burned");
    }

    function test_BurnRewardIfNeeded_SomeAccountsHaveReward() public {
        setUpRewardExtension();

        // Setup: user1 has reward, user2 has zero reward
        rewardExtension.setCustomRewardByAccount(user1, 50e18);
        rewardExtension.setCustomRewardByAccount(user2, 0);

        vm.prank(user1);
        rewardExtension.join(new string[](0));
        vm.prank(user2);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        uint256 totalReward = 100e18;
        mint.setActionReward(address(token), targetRound, ACTION_ID, totalReward);

        // Mint tokens to contract for burning
        token.mint(address(rewardExtension), totalReward);

        uint256 tokenBalanceBefore = token.balanceOf(address(rewardExtension));

        // Burn should not happen (some accounts have reward > 0)
        rewardExtension.burnRewardIfNeeded(targetRound);

        // Verify no tokens were burned
        uint256 tokenBalanceAfter = token.balanceOf(address(rewardExtension));
        assertEq(
            tokenBalanceAfter,
            tokenBalanceBefore,
            "Token should not be burned when some accounts have reward"
        );

        // Verify burn info
        (uint256 burnAmount, bool burned) = rewardExtension.burnInfo(targetRound);
        assertEq(burnAmount, 0, "Burn amount should be 0");
        assertFalse(burned, "Should not be burned");
    }

    function test_BurnRewardIfNeeded_RevertRoundNotFinished() public {
        setUpRewardExtension();

        uint256 currentRound = verify.currentRound();
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionErrors.RoundNotFinished.selector,
                currentRound
            )
        );
        rewardExtension.burnRewardIfNeeded(currentRound);
    }

    function test_BurnRewardIfNeeded_AlreadyBurned() public {
        setUpRewardExtension();

        // Setup: all accounts have zero reward
        rewardExtension.setRewardPerAccount(0);

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        uint256 totalReward = 100e18;
        mint.setActionReward(address(token), targetRound, ACTION_ID, totalReward);

        // Mint tokens to contract for burning
        token.mint(address(rewardExtension), totalReward);

        // Burn first time
        rewardExtension.burnRewardIfNeeded(targetRound);

        // Try to burn again (should return early)
        uint256 tokenBalanceBefore = token.balanceOf(address(rewardExtension));
        rewardExtension.burnRewardIfNeeded(targetRound);
        uint256 tokenBalanceAfter = token.balanceOf(address(rewardExtension));

        // Verify no additional burn
        assertEq(
            tokenBalanceAfter,
            tokenBalanceBefore,
            "No additional burn on second call"
        );
    }

    function test_BurnRewardIfNeeded_ZeroTotalReward() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        mint.setActionReward(address(token), targetRound, ACTION_ID, 0);

        uint256 tokenBalanceBefore = token.balanceOf(address(rewardExtension));

        // Burn should return early (total reward is 0)
        rewardExtension.burnRewardIfNeeded(targetRound);

        // Verify no tokens were burned
        uint256 tokenBalanceAfter = token.balanceOf(address(rewardExtension));
        assertEq(
            tokenBalanceAfter,
            tokenBalanceBefore,
            "Token should not be burned when total reward is 0"
        );
    }

    // ============================================
    // BurnInfo Tests
    // ============================================

    function test_BurnInfo_NoReward() public view {
        (uint256 burnAmount, bool burned) = rewardExtension.burnInfo(verify.currentRound());
        assertEq(burnAmount, 0);
        assertFalse(burned);
    }

    function test_BurnInfo_RoundNotFinished() public view {
        uint256 currentRound = verify.currentRound();
        (uint256 burnAmount, bool burned) = rewardExtension.burnInfo(currentRound);
        assertEq(burnAmount, 0);
        assertFalse(burned);
    }

    function test_BurnInfo_AlreadyBurned() public {
        setUpRewardExtension();

        // Setup: all accounts have zero reward
        rewardExtension.setRewardPerAccount(0);

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        uint256 totalReward = 100e18;
        mint.setActionReward(address(token), targetRound, ACTION_ID, totalReward);

        // Mint tokens to contract for burning
        token.mint(address(rewardExtension), totalReward);

        // Burn the reward
        rewardExtension.burnRewardIfNeeded(targetRound);

        // Verify burn info shows burned
        (uint256 burnAmount, bool burned) = rewardExtension.burnInfo(targetRound);
        assertEq(burnAmount, totalReward, "Burn amount should match");
        assertTrue(burned, "Should be burned");
    }

    function test_BurnInfo_NotBurnedYet_AllZeroReward() public {
        setUpRewardExtension();

        // Setup: all accounts have zero reward
        rewardExtension.setRewardPerAccount(0);

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        uint256 totalReward = 100e18;
        mint.setActionReward(address(token), targetRound, ACTION_ID, totalReward);

        // Verify burn info before burning
        (uint256 burnAmount, bool burned) = rewardExtension.burnInfo(targetRound);
        assertEq(burnAmount, totalReward, "Burn amount should equal total reward");
        assertFalse(burned, "Should not be burned yet");
    }

    function test_BurnInfo_NotBurnedYet_SomeHaveReward() public {
        setUpRewardExtension();

        // Setup: user1 has reward
        rewardExtension.setCustomRewardByAccount(user1, 50e18);

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        uint256 targetRound = 0;
        verify.setCurrentRound(1);
        uint256 totalReward = 100e18;
        mint.setActionReward(address(token), targetRound, ACTION_ID, totalReward);

        // Verify burn info before burning
        (uint256 burnAmount, bool burned) = rewardExtension.burnInfo(targetRound);
        assertEq(burnAmount, 0, "Burn amount should be 0 when some accounts have reward");
        assertFalse(burned, "Should not be burned yet");
    }
}
