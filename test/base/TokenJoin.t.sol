// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "../utils/BaseExtensionTest.sol";
import {
    LOVE20ExtensionBaseTokenJoin
} from "../../src/LOVE20ExtensionBaseTokenJoin.sol";
import {ITokenJoin} from "../../src/interface/base/ITokenJoin.sol";
import {IExtensionReward} from "../../src/interface/base/IExtensionReward.sol";
import {ExtensionReward} from "../../src/base/ExtensionReward.sol";
import {MockExtensionFactory} from "../mocks/MockExtensionFactory.sol";

/**
 * @title MockExtensionForTokenJoin
 * @notice Mock extension for testing TokenJoin
 */
contract MockExtensionForTokenJoin is LOVE20ExtensionBaseTokenJoin {
    constructor(
        address factory_,
        address tokenAddress_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBaseTokenJoin(
            factory_,
            tokenAddress_,
            joinTokenAddress_,
            waitingBlocks_
        )
    {}

    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    function joinedValue() external view override returns (uint256) {
        return totalJoinedAmount;
    }

    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        (uint256 amount, , ) = this.joinInfo(account);
        return amount;
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
 * @title TokenJoinTest
 * @notice Test suite for TokenJoin (token-based join/exit)
 * @dev Tests join with tokens, waiting period, exit, and reentrancy
 */
contract TokenJoinTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockExtensionForTokenJoin public extension;

    event Join(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount,
        uint256 joinedBlock
    );
    event Exit(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );

    function setUp() public {
        setUpBase();

        mockFactory = new MockExtensionFactory(address(center));
        extension = new MockExtensionForTokenJoin(
            address(mockFactory),
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );

        registerFactory(address(token), address(mockFactory));
        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension), address(token));

        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Setup users with tokens
        setupUser(user1, 1000e18, address(extension));
        setupUser(user2, 2000e18, address(extension));
        setupUser(user3, 3000e18, address(extension));
    }

    // ============================================
    // Constructor Tests
    // ============================================

    function test_Constructor_ImmutableVariables() public view {
        assertEq(extension.joinTokenAddress(), address(joinToken));
        assertEq(extension.waitingBlocks(), WAITING_BLOCKS);
        assertEq(extension.factory(), address(mockFactory));
    }

    function test_Constructor_InitialState() public view {
        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);
    }

    function test_Constructor_RevertsOnZeroJoinTokenAddress() public {
        vm.expectRevert(ITokenJoin.InvalidJoinTokenAddress.selector);
        new MockExtensionForTokenJoin(
            address(mockFactory),
            address(token),
            address(0),
            WAITING_BLOCKS
        );
    }

    // ============================================
    // Join Tests
    // ============================================

    function test_Join_Success() public {
        uint256 amount = 100e18;
        uint256 blockBefore = block.number;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        (
            uint256 joinedAmount,
            uint256 joinedBlock,
            uint256 exitableBlock
        ) = extension.joinInfo(user1);
        assertEq(joinedAmount, amount);
        assertEq(joinedBlock, blockBefore);
        assertEq(exitableBlock, blockBefore + WAITING_BLOCKS);
        assertEq(extension.totalJoinedAmount(), amount);
        assertEq(extension.accountsCount(), 1);
    }

    function test_Join_EmitEvent() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, true, true, true);
        emit Join(address(token), user1, ACTION_ID, amount, block.number);

        vm.prank(user1);
        extension.join(amount, new string[](0));
    }

    function test_Join_TransfersTokens() public {
        uint256 amount = 100e18;
        uint256 userBalanceBefore = joinToken.balanceOf(user1);
        uint256 extensionBalanceBefore = joinToken.balanceOf(
            address(extension)
        );

        vm.prank(user1);
        extension.join(amount, new string[](0));

        assertEq(joinToken.balanceOf(user1), userBalanceBefore - amount);
        assertEq(
            joinToken.balanceOf(address(extension)),
            extensionBalanceBefore + amount
        );
    }

    function test_Join_MultipleUsers() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        assertEq(extension.totalJoinedAmount(), 600e18);
        assertEq(extension.accountsCount(), 3);
    }

    function test_Join_RevertIfAmountZero() public {
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.JoinAmountZero.selector);
        extension.join(0, new string[](0));
    }

    function test_Join_AddMore_Success() public {
        vm.startPrank(user1);
        extension.join(100e18, new string[](0));
        extension.join(50e18, new string[](0));
        vm.stopPrank();

        (uint256 amount, , ) = extension.joinInfo(user1);
        assertEq(amount, 150e18);
        assertEq(extension.totalJoinedAmount(), 150e18);
        assertEq(extension.accountsCount(), 1);
    }

    function test_Join_AddMore_UpdatesJoinedBlock() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));
        uint256 firstJoinBlock = block.number;

        advanceBlocks(50);

        vm.prank(user1);
        extension.join(50e18, new string[](0));

        (, uint256 joinedBlock, uint256 exitableBlock) = extension.joinInfo(
            user1
        );
        assertEq(joinedBlock, firstJoinBlock + 50);
        assertEq(exitableBlock, firstJoinBlock + 50 + WAITING_BLOCKS);
    }

    function test_Join_AddMore_ResetsWaitingPeriod() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Advance to almost exitable
        advanceBlocks(WAITING_BLOCKS - 1);
        (, , uint256 exitableBlock1) = extension.joinInfo(user1);
        assertTrue(block.number < exitableBlock1);

        // Add more resets waiting period
        vm.prank(user1);
        extension.join(50e18, new string[](0));

        // Cannot exit immediately after adding more
        (, , uint256 exitableBlock2) = extension.joinInfo(user1);
        assertTrue(block.number < exitableBlock2);

        // Need to wait full waiting period again
        advanceBlocks(WAITING_BLOCKS);
        (, , uint256 exitableBlock3) = extension.joinInfo(user1);
        assertTrue(block.number >= exitableBlock3);
    }

    function test_Join_AddMore_MultipleTimes() public {
        vm.startPrank(user1);
        extension.join(100e18, new string[](0));
        extension.join(50e18, new string[](0));
        extension.join(25e18, new string[](0));
        extension.join(25e18, new string[](0));
        vm.stopPrank();

        (uint256 amount, , ) = extension.joinInfo(user1);
        assertEq(amount, 200e18);
        assertEq(extension.totalJoinedAmount(), 200e18);
        assertEq(extension.accountsCount(), 1);
    }

    function test_Join_AddMore_EmitEvent() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(10);

        vm.expectEmit(true, true, true, true);
        emit Join(address(token), user1, ACTION_ID, 50e18, block.number);

        vm.prank(user1);
        extension.join(50e18, new string[](0));
    }

    function test_Join_WithVerificationInfo() public {
        string[] memory verificationKeys = new string[](2);
        verificationKeys[0] = "key1";
        verificationKeys[1] = "key2";
        submit.setVerificationKeys(address(token), ACTION_ID, verificationKeys);

        string[] memory verificationInfos = new string[](2);
        verificationInfos[0] = "info1";
        verificationInfos[1] = "info2";

        vm.prank(user1);
        extension.join(100e18, verificationInfos);

        assertEq(extension.totalJoinedAmount(), 100e18);
    }

    // ============================================
    // Exit Tests
    // ============================================

    function test_Exit_Success() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        uint256 balanceBefore = joinToken.balanceOf(user1);

        vm.prank(user1);
        extension.exit();

        assertEq(joinToken.balanceOf(user1), balanceBefore + amount);
        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);

        (
            uint256 joinedAmount,
            uint256 joinedBlock,
            uint256 exitableBlock
        ) = extension.joinInfo(user1);
        assertEq(joinedAmount, 0);
        assertEq(joinedBlock, 0);
        assertEq(exitableBlock, 0);
    }

    function test_Exit_EmitEvent() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        vm.expectEmit(true, true, true, true);
        emit Exit(address(token), user1, ACTION_ID, amount);

        vm.prank(user1);
        extension.exit();
    }

    function test_Exit_RevertIfNotJoined() public {
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NoJoinedAmount.selector);
        extension.exit();
    }

    function test_Exit_RevertIfNotEnoughWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS - 1);

        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();
    }

    function test_Exit_ExactlyAtWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        (uint256 amount, , ) = extension.joinInfo(user1);
        assertEq(amount, 0);
    }

    function test_Exit_MultipleUsersIndependently() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(50);

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        advanceBlocks(50);

        // User1 can exit
        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 200e18);
        assertEq(extension.accountsCount(), 1);

        // User2 cannot exit yet
        vm.prank(user2);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();

        advanceBlocks(50);

        // Now user2 can exit
        vm.prank(user2);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);
    }

    // ============================================
    // JoinInfo Tests
    // ============================================

    function test_JoinInfo_NotJoined() public view {
        (uint256 amount, uint256 joinedBlock, uint256 exitableBlock) = extension
            .joinInfo(user1);
        assertEq(amount, 0);
        assertEq(joinedBlock, 0);
        assertEq(exitableBlock, 0);
    }

    function test_JoinInfo_AfterJoin() public {
        uint256 joinAmount = 100e18;
        uint256 joinBlock = block.number;

        vm.prank(user1);
        extension.join(joinAmount, new string[](0));

        (uint256 amount, uint256 joinedBlock, uint256 exitableBlock) = extension
            .joinInfo(user1);
        assertEq(amount, joinAmount);
        assertEq(joinedBlock, joinBlock);
        assertEq(exitableBlock, joinBlock + WAITING_BLOCKS);
    }

    // ============================================
    // JoinedValue Tests
    // ============================================

    function test_JoinedValue_EmptyAtStart() public view {
        assertEq(extension.joinedValue(), 0);
    }

    function test_JoinedValue_SingleUser() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        assertEq(extension.joinedValue(), 100e18);
    }

    function test_JoinedValue_MultipleUsers() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        assertEq(extension.joinedValue(), 600e18);
    }

    function test_JoinedValue_AfterExit() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.joinedValue(), 200e18);
    }

    function test_JoinedValueByAccount_NotJoined() public view {
        assertEq(extension.joinedValueByAccount(user1), 0);
    }

    function test_JoinedValueByAccount_Joined() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        assertEq(extension.joinedValueByAccount(user1), 100e18);
    }

    function test_JoinedValueByAccount_AfterExit() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.joinedValueByAccount(user1), 0);
    }

    function test_IsJoinedValueCalculated() public view {
        assertTrue(extension.isJoinedValueCalculated());
    }

    // ============================================
    // Zero Waiting Blocks Tests
    // ============================================

    function test_ZeroWaitingBlocks_ExitInSameBlock() public {
        MockExtensionForTokenJoin extensionNoWait = new MockExtensionForTokenJoin(
                address(mockFactory),
                address(token),
                address(joinToken),
                0
            );

        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extensionNoWait), address(token));
        submit.setActionInfo(
            address(token),
            ACTION_ID + 1,
            address(extensionNoWait)
        );
        vote.setVotedActionIds(
            address(token),
            join.currentRound(),
            ACTION_ID + 1
        );
        token.mint(address(extensionNoWait), 1e18);

        vm.prank(user1);
        joinToken.approve(address(extensionNoWait), type(uint256).max);

        // Join triggers auto-initialization
        vm.prank(user1);
        extensionNoWait.join(100e18, new string[](0));

        vm.prank(user1);
        extensionNoWait.exit();

        assertEq(extensionNoWait.totalJoinedAmount(), 0);
    }

    // ============================================
    // Reentrancy Tests
    // ============================================

    function test_Reentrancy_ExitCannotReenter() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NoJoinedAmount.selector);
        extension.exit();
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_EdgeCase_LargeAmount() public {
        uint256 largeAmount = 1e30;
        joinToken.mint(user1, largeAmount);

        vm.prank(user1);
        joinToken.approve(address(extension), largeAmount);

        vm.prank(user1);
        extension.join(largeAmount, new string[](0));

        assertEq(extension.totalJoinedAmount(), largeAmount);
    }

    function test_EdgeCase_MinAmount() public {
        uint256 minAmount = 1;

        vm.prank(user1);
        extension.join(minAmount, new string[](0));

        assertEq(extension.totalJoinedAmount(), minAmount);
    }

    // ============================================
    // Full Lifecycle Test
    // ============================================

    function test_Integration_FullLifecycle() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(10);

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        advanceBlocks(20);

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        assertEq(extension.totalJoinedAmount(), 600e18);
        assertEq(extension.accountsCount(), 3);

        advanceBlocks(70);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 500e18);
        assertEq(extension.accountsCount(), 2);

        advanceBlocks(20);

        vm.prank(user2);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 300e18);
        assertEq(extension.accountsCount(), 1);

        advanceBlocks(10);

        vm.prank(user3);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_Join(uint256 amount) public {
        amount = bound(amount, 1, 1000e18);

        vm.prank(user1);
        extension.join(amount, new string[](0));

        (uint256 joinedAmount, , ) = extension.joinInfo(user1);
        assertEq(joinedAmount, amount);
        assertEq(extension.totalJoinedAmount(), amount);
    }

    function testFuzz_Exit(uint256 amount, uint256 extraBlocks) public {
        amount = bound(amount, 1, 1000e18);
        extraBlocks = bound(extraBlocks, 0, 10000);

        vm.prank(user1);
        extension.join(amount, new string[](0));

        advanceBlocks(WAITING_BLOCKS + extraBlocks);

        uint256 balanceBefore = joinToken.balanceOf(user1);

        vm.prank(user1);
        extension.exit();

        assertEq(joinToken.balanceOf(user1), balanceBefore + amount);
    }
}
