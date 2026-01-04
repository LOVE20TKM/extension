// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {
    ExtensionBaseRewardTokenJoin
} from "../src/ExtensionBaseRewardTokenJoin.sol";
import {ITokenJoin} from "../src/interface/ITokenJoin.sol";
import {IReward} from "../src/interface/IReward.sol";
import {ExtensionBaseReward} from "../src/ExtensionBaseReward.sol";
import {ExtensionBase} from "../src/ExtensionBase.sol";
import {IExtension} from "../src/interface/IExtension.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";

/**
 * @title MockExtensionForTokenJoin
 * @notice Mock extension for testing TokenJoin
 */
contract MockExtensionForTokenJoin is ExtensionBaseRewardTokenJoin {
    constructor(
        address factory_,
        address tokenAddress_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        ExtensionBaseRewardTokenJoin(
            factory_,
            tokenAddress_,
            joinTokenAddress_,
            waitingBlocks_
        )
    {}

    function isJoinedValueConverted()
        external
        pure
        override(ExtensionBase)
        returns (bool)
    {
        return true;
    }

    function joinedValue()
        external
        view
        override(ExtensionBase)
        returns (uint256)
    {
        return totalJoinedAmount();
    }

    function joinedValueByAccount(
        address account
    ) external view override(ExtensionBase) returns (uint256) {
        (, uint256 amount, , ) = this.joinInfo(account);
        return amount;
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
 * @title ExtensionBaseRewardTokenJoinTest
 * @notice Test suite for ExtensionBaseRewardTokenJoin
 * @dev Tests join with tokens, waiting period, exit, and reentrancy
 */
contract ExtensionBaseTokenJoinTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockExtensionForTokenJoin public extension;

    event Join(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );
    event Exit(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
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
        assertEq(extension.JOIN_TOKEN_ADDRESS(), address(joinToken));
        assertEq(extension.WAITING_BLOCKS(), WAITING_BLOCKS);
        assertEq(extension.FACTORY_ADDRESS(), address(mockFactory));
    }

    function test_Constructor_InitialState() public view {
        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(center.accountsCount(address(token), ACTION_ID), 0);
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
            ,
            uint256 joinedAmount,
            uint256 joinedBlock,
            uint256 exitableBlock
        ) = extension.joinInfo(user1);
        assertEq(joinedAmount, amount);
        assertEq(joinedBlock, blockBefore);
        assertEq(exitableBlock, blockBefore + WAITING_BLOCKS);
        assertEq(extension.totalJoinedAmount(), amount);
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
    }

    function test_Join_EmitEvent() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, true, true, true);
        emit Join(
            address(token),
            join.currentRound(),
            ACTION_ID,
            user1,
            amount
        );

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
        assertEq(center.accountsCount(address(token), ACTION_ID), 3);
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

        (, uint256 amount, , ) = extension.joinInfo(user1);
        assertEq(amount, 150e18);
        assertEq(extension.totalJoinedAmount(), 150e18);
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
    }

    function test_Join_AddMore_UpdatesJoinedBlock() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));
        uint256 firstJoinBlock = block.number;

        advanceBlocks(50);

        vm.prank(user1);
        extension.join(50e18, new string[](0));

        (, , uint256 joinedBlock, uint256 exitableBlock) = extension.joinInfo(
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
        (, , , uint256 exitableBlock1) = extension.joinInfo(user1);
        assertTrue(block.number < exitableBlock1);

        // Add more resets waiting period
        vm.prank(user1);
        extension.join(50e18, new string[](0));

        // Cannot exit immediately after adding more
        (, , , uint256 exitableBlock2) = extension.joinInfo(user1);
        assertTrue(block.number < exitableBlock2);

        // Need to wait full waiting period again
        advanceBlocks(WAITING_BLOCKS);
        (, , , uint256 exitableBlock3) = extension.joinInfo(user1);
        assertTrue(block.number >= exitableBlock3);
    }

    function test_Join_AddMore_MultipleTimes() public {
        vm.startPrank(user1);
        extension.join(100e18, new string[](0));
        extension.join(50e18, new string[](0));
        extension.join(25e18, new string[](0));
        extension.join(25e18, new string[](0));
        vm.stopPrank();

        (, uint256 amount, , ) = extension.joinInfo(user1);
        assertEq(amount, 200e18);
        assertEq(extension.totalJoinedAmount(), 200e18);
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
    }

    function test_Join_AddMore_EmitEvent() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(10);

        vm.expectEmit(true, true, true, true);
        emit Join(address(token), join.currentRound(), ACTION_ID, user1, 50e18);

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
        assertEq(center.accountsCount(address(token), ACTION_ID), 0);

        (
            ,
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
        emit Exit(
            address(token),
            join.currentRound(),
            ACTION_ID,
            user1,
            amount
        );

        vm.prank(user1);
        extension.exit();
    }

    function test_Exit_RevertIfNotJoined() public {
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NotJoined.selector);
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

        (, uint256 amount, , ) = extension.joinInfo(user1);
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
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);

        // User2 cannot exit yet
        vm.prank(user2);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();

        advanceBlocks(50);

        // Now user2 can exit
        vm.prank(user2);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(center.accountsCount(address(token), ACTION_ID), 0);
    }

    // ============================================
    // JoinInfo Tests
    // ============================================

    function test_JoinInfo_NotJoined() public view {
        (
            ,
            uint256 amount,
            uint256 joinedBlock,
            uint256 exitableBlock
        ) = extension.joinInfo(user1);
        assertEq(amount, 0);
        assertEq(joinedBlock, 0);
        assertEq(exitableBlock, 0);
    }

    function test_JoinInfo_AfterJoin() public {
        uint256 joinAmount = 100e18;
        uint256 joinBlock = block.number;

        vm.prank(user1);
        extension.join(joinAmount, new string[](0));

        (
            ,
            uint256 amount,
            uint256 joinedBlock,
            uint256 exitableBlock
        ) = extension.joinInfo(user1);
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

    function test_isJoinedValueConverted() public view {
        assertTrue(extension.isJoinedValueConverted());
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
        vm.expectRevert(ITokenJoin.NotJoined.selector);
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
        assertEq(center.accountsCount(address(token), ACTION_ID), 3);

        advanceBlocks(70);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 500e18);
        assertEq(center.accountsCount(address(token), ACTION_ID), 2);

        advanceBlocks(20);

        vm.prank(user2);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 300e18);
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);

        advanceBlocks(10);

        vm.prank(user3);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(center.accountsCount(address(token), ACTION_ID), 0);
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_Join(uint256 amount) public {
        amount = bound(amount, 1, 1000e18);

        vm.prank(user1);
        extension.join(amount, new string[](0));

        (, uint256 joinedAmount, , ) = extension.joinInfo(user1);
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

    // ============================================
    // Account Management Tests
    // ============================================

    function test_AccountManagement_RemoveMiddleAccount() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));
        vm.prank(user2);
        extension.join(200e18, new string[](0));
        vm.prank(user3);
        extension.join(300e18, new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 3);

        advanceBlocks(WAITING_BLOCKS);
        vm.prank(user2);
        extension.exit();

        assertEq(center.accountsCount(address(token), ACTION_ID), 2);
        address[] memory accs = center.accounts(address(token), ACTION_ID);
        assertEq(accs.length, 2);
        assertTrue(
            (accs[0] == user1 || accs[0] == user3) &&
                (accs[1] == user1 || accs[1] == user3),
            "Should contain user1 and user3"
        );
    }

    function test_AccountManagement_MultipleAddRemove() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);
        vm.prank(user1);
        extension.exit();

        assertEq(center.accountsCount(address(token), ACTION_ID), 0);

        joinToken.mint(user1, 100e18);
        advanceBlocks(1);
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
        assertEq(center.accountsAtIndex(address(token), ACTION_ID, 0), user1);
    }

    function test_AccountManagement_LargeNumberOfAccounts() public {
        uint256 numAccounts = 50;
        address[] memory accounts = new address[](numAccounts);

        for (uint256 i = 0; i < numAccounts; i++) {
            accounts[i] = address(uint160(1000 + i));
            joinToken.mint(accounts[i], 1000e18);
            vm.prank(accounts[i]);
            joinToken.approve(address(extension), type(uint256).max);
            vm.prank(accounts[i]);
            extension.join(100e18, new string[](0));
        }

        assertEq(center.accountsCount(address(token), ACTION_ID), numAccounts);

        advanceBlocks(WAITING_BLOCKS);
        vm.prank(accounts[25]);
        extension.exit();

        assertEq(
            center.accountsCount(address(token), ACTION_ID),
            numAccounts - 1
        );
    }

    // ============================================
    // Interface Consistency Tests
    // ============================================

    function test_Interface_TokenAddressIsView() public view {
        address tokenAddr = extension.TOKEN_ADDRESS();
        assertEq(tokenAddr, address(token));
    }

    function test_Interface_ActionIdIsView() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        uint256 actionIdVal = extension.actionId();
        assertEq(actionIdVal, ACTION_ID);
    }

    // ============================================
    // Additional Edge Cases
    // ============================================

    function test_EdgeCase_ExitBeforeWaitingPeriod() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();

        advanceBlocks(WAITING_BLOCKS - 1);
        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();

        advanceBlocks(1);
        vm.prank(user1);
        extension.exit();
    }

    function test_EdgeCase_StorageLayoutOptimization() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        assertEq(extension.TOKEN_ADDRESS(), address(token));
        assertTrue(extension.initialized());
        assertEq(extension.actionId(), ACTION_ID);
    }

    // ============================================
    // Gas Optimization Tests
    // ============================================

    function test_Gas_AddAccountIsConstant() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        address user4 = address(0x4);
        address user5 = address(0x5);
        address user6 = address(0x6);

        joinToken.mint(user4, 1000e18);
        joinToken.mint(user5, 1000e18);
        joinToken.mint(user6, 1000e18);

        vm.prank(user4);
        joinToken.approve(address(extension), type(uint256).max);
        vm.prank(user5);
        joinToken.approve(address(extension), type(uint256).max);
        vm.prank(user6);
        joinToken.approve(address(extension), type(uint256).max);

        uint256 gas1;
        uint256 gas2;
        uint256 gas3;

        vm.prank(user4);
        gas1 = gasleft();
        extension.join(100e18, new string[](0));
        gas1 = gas1 - gasleft();

        vm.prank(user5);
        gas2 = gasleft();
        extension.join(200e18, new string[](0));
        gas2 = gas2 - gasleft();

        vm.prank(user6);
        gas3 = gasleft();
        extension.join(300e18, new string[](0));
        gas3 = gas3 - gasleft();

        uint256 avgGas = (gas1 + gas2 + gas3) / 3;
        assertTrue(gas1 < (avgGas * 11) / 10, "gas1 too high");
        assertTrue(gas2 < (avgGas * 11) / 10, "gas2 too high");
        assertTrue(gas3 < (avgGas * 11) / 10, "gas3 too high");
    }

    // ============================================
    // amountByAccount Tests
    // ============================================

    function test_amountByAccount_NotJoined() public view {
        assertEq(extension.amountByAccount(user1), 0);
    }

    function test_amountByAccount_AfterJoin() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        assertEq(extension.amountByAccount(user1), amount);
    }

    function test_amountByAccount_MultipleJoins() public {
        vm.startPrank(user1);
        extension.join(100e18, new string[](0));
        assertEq(extension.amountByAccount(user1), 100e18);

        extension.join(50e18, new string[](0));
        assertEq(extension.amountByAccount(user1), 150e18);

        extension.join(25e18, new string[](0));
        assertEq(extension.amountByAccount(user1), 175e18);
        vm.stopPrank();
    }

    function test_amountByAccount_AfterExit() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.amountByAccount(user1), 0);
    }

    function test_amountByAccount_MultipleUsers() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        assertEq(extension.amountByAccount(user1), 100e18);
        assertEq(extension.amountByAccount(user2), 200e18);
        assertEq(extension.amountByAccount(user3), 300e18);
    }

    function test_amountByAccount_IndependentAfterExit() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.amountByAccount(user1), 0);
        assertEq(extension.amountByAccount(user2), 200e18);
    }

    // ============================================
    // amountByAccountByRound Tests
    // ============================================

    function test_amountByAccountByRound_NotJoined() public view {
        assertEq(extension.amountByAccountByRound(user1, 1), 0);
        assertEq(extension.amountByAccountByRound(user1, 2), 0);
    }

    function test_amountByAccountByRound_JoinRound() public {
        uint256 joinRound = join.currentRound();
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        assertEq(extension.amountByAccountByRound(user1, joinRound), amount);
    }

    function test_amountByAccountByRound_SubsequentRounds() public {
        uint256 round1 = join.currentRound();
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        // Advance to next round
        join.setCurrentRound(round1 + 1);
        assertEq(extension.amountByAccountByRound(user1, round1), amount);
        assertEq(extension.amountByAccountByRound(user1, round1 + 1), amount);

        // Advance to another round
        join.setCurrentRound(round1 + 2);
        assertEq(extension.amountByAccountByRound(user1, round1), amount);
        assertEq(extension.amountByAccountByRound(user1, round1 + 1), amount);
        assertEq(extension.amountByAccountByRound(user1, round1 + 2), amount);
    }

    function test_amountByAccountByRound_AddMoreInNewRound() public {
        uint256 round1 = join.currentRound();
        uint256 amount1 = 100e18;

        vm.prank(user1);
        extension.join(amount1, new string[](0));

        // Advance to next round and add more
        join.setCurrentRound(round1 + 1);
        vote.setVotedActionIds(address(token), round1 + 1, ACTION_ID);
        uint256 amount2 = 50e18;

        vm.prank(user1);
        extension.join(amount2, new string[](0));

        assertEq(extension.amountByAccountByRound(user1, round1), amount1);
        assertEq(
            extension.amountByAccountByRound(user1, round1 + 1),
            amount1 + amount2
        );
    }

    function test_amountByAccountByRound_ExitRound() public {
        uint256 joinRound = join.currentRound();
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        // Advance to next round before exit
        join.setCurrentRound(joinRound + 1);
        vote.setVotedActionIds(address(token), joinRound + 1, ACTION_ID);
        advanceBlocks(WAITING_BLOCKS);

        uint256 exitRound = join.currentRound();
        vm.prank(user1);
        extension.exit();

        assertEq(extension.amountByAccountByRound(user1, joinRound), amount);
        assertEq(extension.amountByAccountByRound(user1, exitRound), 0);
    }

    function test_amountByAccountByRound_AfterExitSubsequentRounds() public {
        uint256 amount = 100e18;
        uint256 joinRound = join.currentRound();

        vm.prank(user1);
        extension.join(amount, new string[](0));

        // Advance to next round before exit
        join.setCurrentRound(joinRound + 1);
        vote.setVotedActionIds(address(token), joinRound + 1, ACTION_ID);
        advanceBlocks(WAITING_BLOCKS);

        uint256 exitRound = join.currentRound();
        vm.prank(user1);
        extension.exit();

        // Advance to future rounds
        join.setCurrentRound(exitRound + 1);
        assertEq(extension.amountByAccountByRound(user1, exitRound), 0);
        assertEq(extension.amountByAccountByRound(user1, exitRound + 1), 0);

        join.setCurrentRound(exitRound + 5);
        assertEq(extension.amountByAccountByRound(user1, exitRound + 5), 0);
    }

    function test_amountByAccountByRound_MultipleUsersDifferentRounds() public {
        uint256 round1 = join.currentRound();

        vm.prank(user1);
        extension.join(100e18, new string[](0));

        join.setCurrentRound(round1 + 1);
        vote.setVotedActionIds(address(token), round1 + 1, ACTION_ID);

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        join.setCurrentRound(round1 + 2);
        vote.setVotedActionIds(address(token), round1 + 2, ACTION_ID);

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        // Check round1: only user1
        assertEq(extension.amountByAccountByRound(user1, round1), 100e18);
        assertEq(extension.amountByAccountByRound(user2, round1), 0);
        assertEq(extension.amountByAccountByRound(user3, round1), 0);

        // Check round1 + 1: user1 and user2
        assertEq(extension.amountByAccountByRound(user1, round1 + 1), 100e18);
        assertEq(extension.amountByAccountByRound(user2, round1 + 1), 200e18);
        assertEq(extension.amountByAccountByRound(user3, round1 + 1), 0);

        // Check round1 + 2: all users
        assertEq(extension.amountByAccountByRound(user1, round1 + 2), 100e18);
        assertEq(extension.amountByAccountByRound(user2, round1 + 2), 200e18);
        assertEq(extension.amountByAccountByRound(user3, round1 + 2), 300e18);
    }

    function test_amountByAccountByRound_ComplexScenario() public {
        uint256 round1 = join.currentRound();

        // User1 joins in round1
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Round 2: User1 adds more, User2 joins
        join.setCurrentRound(round1 + 1);
        vote.setVotedActionIds(address(token), round1 + 1, ACTION_ID);
        vm.prank(user1);
        extension.join(50e18, new string[](0));
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // Round 3: User3 joins
        join.setCurrentRound(round1 + 2);
        vote.setVotedActionIds(address(token), round1 + 2, ACTION_ID);
        vm.prank(user3);
        extension.join(300e18, new string[](0));

        // Round 4: User1 exits
        advanceBlocks(WAITING_BLOCKS);
        join.setCurrentRound(round1 + 3);
        vote.setVotedActionIds(address(token), round1 + 3, ACTION_ID);
        vm.prank(user1);
        extension.exit();

        // Verify historical data
        assertEq(extension.amountByAccountByRound(user1, round1), 100e18);
        assertEq(extension.amountByAccountByRound(user1, round1 + 1), 150e18);
        assertEq(extension.amountByAccountByRound(user1, round1 + 2), 150e18);
        assertEq(extension.amountByAccountByRound(user1, round1 + 3), 0);

        assertEq(extension.amountByAccountByRound(user2, round1 + 1), 200e18);
        assertEq(extension.amountByAccountByRound(user2, round1 + 3), 200e18);

        assertEq(extension.amountByAccountByRound(user3, round1 + 2), 300e18);
        assertEq(extension.amountByAccountByRound(user3, round1 + 3), 300e18);
    }

    function test_amountByAccountByRound_ConsistencyWithAmountByAccount()
        public
    {
        uint256 round1 = join.currentRound();

        vm.prank(user1);
        extension.join(100e18, new string[](0));

        uint256 currentRound = join.currentRound();
        assertEq(
            extension.amountByAccount(user1),
            extension.amountByAccountByRound(user1, currentRound)
        );

        join.setCurrentRound(round1 + 5);
        assertEq(
            extension.amountByAccount(user1),
            extension.amountByAccountByRound(user1, join.currentRound())
        );
    }
}
