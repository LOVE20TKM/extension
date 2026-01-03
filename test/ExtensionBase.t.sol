// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {ExtensionBaseJoin} from "../src/ExtensionBaseJoin.sol";
import {IReward} from "../src/interface/IReward.sol";
import {ExtensionBase} from "../src/ExtensionBase.sol";
import {ExtensionCore} from "../src/ExtensionCore.sol";
import {IExtensionCore} from "../src/interface/IExtensionCore.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockExtensionForCore
 * @notice Mock extension for testing ExtensionBase
 */
contract MockExtensionForCore is ExtensionBaseJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBaseJoin(factory_, tokenAddress_) {}

    function isJoinedValueConverted()
        external
        pure
        override(ExtensionCore)
        returns (bool)
    {
        return false;
    }

    function joinedValue()
        external
        pure
        override(ExtensionCore)
        returns (uint256)
    {
        return 0;
    }

    function joinedValueByAccount(
        address
    ) external pure override(ExtensionCore) returns (uint256) {
        return 0;
    }

    function rewardByAccount(
        uint256,
        address
    )
        public
        pure
        override(ExtensionBase)
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
contract MockExtensionForReward is ExtensionBaseJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Configurable reward calculation
    uint256 public rewardPerAccount;
    mapping(address => uint256) public customRewardByAccount;
    bool public useCustomReward;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBaseJoin(factory_, tokenAddress_) {}

    function isJoinedValueConverted()
        external
        pure
        override(ExtensionCore)
        returns (bool)
    {
        return true;
    }

    function joinedValue()
        external
        view
        override(ExtensionCore)
        returns (uint256)
    {
        return _center.accountsCount(TOKEN_ADDRESS, actionId);
    }

    function joinedValueByAccount(
        address account
    ) external view override(ExtensionCore) returns (uint256) {
        return
            _center.isAccountJoined(TOKEN_ADDRESS, actionId, account) ? 1 : 0;
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
        return _claimedReward[round][account];
    }
}

/**
 * @title ExtensionBaseTest
 * @notice Test suite for ExtensionBase
 * @dev Tests constructor, initialization, view functions, and reward claiming
 */
contract ExtensionBaseTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockExtensionForCore public extension;
    MockExtensionForReward public rewardExtension;

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
        extension = new MockExtensionForCore(
            address(mockFactory),
            address(token)
        );

        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension), address(token));
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
            extension.CENTER_ADDRESS(),
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
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
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

    // ============================================
    // View Functions Tests
    // ============================================

    function test_Center_ReturnsCorrectAddress() public view {
        assertEq(extension.CENTER_ADDRESS(), address(center));
    }

    function test_Factory_ReturnsCorrectAddress() public view {
        assertEq(extension.FACTORY_ADDRESS(), address(mockFactory));
    }

    function test_TokenAddress_SetAtConstruction() public view {
        // tokenAddress is now set at construction, not at initialization
        assertEq(extension.TOKEN_ADDRESS(), address(token));
    }

    function test_TokenAddress_AfterInit() public {
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
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
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
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
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
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
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Setup second extension with different action ID
        submit.setActionInfo(
            address(token),
            ACTION_ID + 1,
            address(extension2)
        );
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

        submit.setActionInfo(
            address(token),
            ACTION_ID,
            address(rewardExtension)
        );
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
        vm.expectRevert(IExtensionCore.RoundNotFinished.selector);
        rewardExtension.claimReward(0);
    }

    function test_ClaimReward_RevertIfRoundIsCurrentRound() public {
        setUpRewardExtension();

        vm.prank(user1);
        rewardExtension.join(new string[](0));

        verify.setCurrentRound(5);

        vm.prank(user1);
        vm.expectRevert(IExtensionCore.RoundNotFinished.selector);
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
        vm.expectRevert(IReward.AlreadyClaimed.selector);
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
}
