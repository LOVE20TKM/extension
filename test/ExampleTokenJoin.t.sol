// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {ExampleTokenJoin} from "../src/examples/ExampleTokenJoin.sol";
import {
    ExampleFactoryTokenJoin
} from "../src/examples/ExampleFactoryTokenJoin.sol";
import {
    ILOVE20ExtensionTokenJoin
} from "../src/interface/ILOVE20ExtensionTokenJoin.sol";
import {ITokenJoin} from "../src/interface/base/ITokenJoin.sol";
import {ILOVE20Extension} from "../src/interface/ILOVE20Extension.sol";
import {IExtensionReward} from "../src/interface/base/IExtensionReward.sol";
import {LOVE20ExtensionCenter} from "../src/LOVE20ExtensionCenter.sol";

// Import mock contracts
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockStake} from "./mocks/MockStake.sol";
import {MockJoin} from "./mocks/MockJoin.sol";
import {MockVerify} from "./mocks/MockVerify.sol";
import {MockMint} from "./mocks/MockMint.sol";
import {MockSubmit} from "./mocks/MockSubmit.sol";
import {MockLaunch} from "./mocks/MockLaunch.sol";
import {MockVote} from "./mocks/MockVote.sol";
import {MockRandom} from "./mocks/MockRandom.sol";
import {MockUniswapV2Factory} from "./mocks/MockUniswapV2Factory.sol";

/**
 * @title ExampleTokenJoin Test Suite
 * @notice Comprehensive tests for ExampleTokenJoin implementation
 */
contract ExampleTokenJoinTest is Test {
    ExampleFactoryTokenJoin public factory;
    ExampleTokenJoin public extension;
    LOVE20ExtensionCenter public center;
    MockERC20 public token;
    MockERC20 public joinToken;
    MockStake public stake;
    MockJoin public join;
    MockVerify public verify;
    MockMint public mint;
    MockSubmit public submit;
    MockLaunch public launch;
    MockVote public vote;
    MockRandom public random;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    uint256 constant ACTION_ID = 1;
    uint256 constant WAITING_BLOCKS = 100;

    event Join(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount,
        uint256 joinedBlock
    );
    event Exit(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );
    event ClaimReward(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        uint256 amount
    );

    function setUp() public {
        // Deploy mock contracts
        token = new MockERC20();
        joinToken = new MockERC20();
        stake = new MockStake();
        join = new MockJoin();
        verify = new MockVerify();
        mint = new MockMint();
        submit = new MockSubmit();
        launch = new MockLaunch();
        vote = new MockVote();
        random = new MockRandom();
        MockUniswapV2Factory uniswapFactory = new MockUniswapV2Factory();

        // Deploy real LOVE20ExtensionCenter
        center = new LOVE20ExtensionCenter(
            address(uniswapFactory),
            address(launch),
            address(stake),
            address(submit),
            address(vote),
            address(join),
            address(verify),
            address(mint),
            address(random)
        );

        // Deploy factory
        factory = new ExampleFactoryTokenJoin(address(center));

        // Prepare tokens for factory registration
        token.mint(address(this), 1e18);
        token.approve(address(factory), type(uint256).max);

        // Create extension through factory
        extension = ExampleTokenJoin(
            factory.createExtension(
                address(token),
                address(joinToken),
                WAITING_BLOCKS
            )
        );

        // Set action info whiteListAddress to extension address
        submit.setActionInfo(address(token), ACTION_ID, address(extension));

        // Set vote mock to return actionId for auto-initialization
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // Give extension tokens for auto-initialization join
        token.mint(address(extension), 1e18);

        // Setup users with tokens
        _setupUser(user1, 1000e18);
        _setupUser(user2, 2000e18);
        _setupUser(user3, 3000e18);
    }

    function _setupUser(address user, uint256 joinAmount) internal {
        joinToken.mint(user, joinAmount);
        vm.prank(user);
        joinToken.approve(address(extension), type(uint256).max);
    }

    // ============================================
    // IMMUTABLE VARIABLES TESTS
    // ============================================

    function test_ImmutableVariables() public view {
        assertEq(extension.joinTokenAddress(), address(joinToken));
        assertEq(extension.waitingBlocks(), WAITING_BLOCKS);
        assertTrue(extension.factory() != address(0));
    }

    function test_Center() public view {
        assertEq(extension.center(), address(center));
    }

    function test_TokenAddress() public view {
        assertEq(extension.tokenAddress(), address(token));
    }

    function test_ActionId() public {
        // Trigger auto-initialization by joining
        vm.prank(user1);
        extension.join(100e18, new string[](0));
        assertEq(extension.actionId(), ACTION_ID);
    }

    // ============================================
    // JOIN TESTS
    // ============================================

    function test_Join() public {
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
            amount,
            block.number
        );

        vm.prank(user1);
        extension.join(amount, new string[](0));
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

    function test_Join_WithVerificationInfo() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(100e18, verificationInfos);

        // Verification info functionality requires action setup with verification keys
        // which is beyond the scope of this basic test
        assertEq(extension.totalJoinedAmount(), 100e18);
    }

    // ============================================
    // EXIT TESTS
    // ============================================

    function test_Exit() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        // Fast forward blocks
        vm.roll(block.number + WAITING_BLOCKS);

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

        vm.roll(block.number + WAITING_BLOCKS);

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
        vm.expectRevert(ITokenJoin.NoJoinedAmount.selector);
        extension.exit();
    }

    function test_Exit_RevertIfNotEnoughWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Not enough blocks passed
        vm.roll(block.number + WAITING_BLOCKS - 1);

        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();
    }

    function test_Exit_ExactlyAtWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Exactly at the waiting blocks threshold
        vm.roll(block.number + WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        (, uint256 amount, , ) = extension.joinInfo(user1);
        assertEq(amount, 0);
    }

    function test_Exit_MultipleUsersIndependently() public {
        // User1 joins at block 0
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Move forward 50 blocks
        vm.roll(block.number + 50);

        // User2 joins at block 50
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // Move forward another 50 blocks (total 100 from user1's join)
        vm.roll(block.number + 50);

        // User1 can exit now
        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 200e18); // Only user2's amount
        assertEq(center.accountsCount(address(token), ACTION_ID), 1); // Only user2

        // User2 cannot exit yet (only 50 blocks passed since their join)
        vm.prank(user2);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();

        // Move forward another 50 blocks
        vm.roll(block.number + 50);

        // Now user2 can exit
        vm.prank(user2);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(center.accountsCount(address(token), ACTION_ID), 0);
    }

    // ============================================
    // EXITABLE BLOCK TESTS
    // ============================================

    function test_ExitableBlock_Zero_NotJoined() public view {
        (, , , uint256 exitableBlock) = extension.joinInfo(user1);
        assertEq(exitableBlock, 0);
    }

    function test_ExitableBlock_Correct() public {
        uint256 joinBlock = block.number;

        vm.prank(user1);
        extension.join(100e18, new string[](0));

        (, , , uint256 exitableBlock) = extension.joinInfo(user1);
        assertEq(exitableBlock, joinBlock + WAITING_BLOCKS);
    }

    // ============================================
    // JOINED VALUE CALCULATION TESTS
    // ============================================

    function test_IsJoinedValueCalculated() public view {
        assertTrue(extension.isJoinedValueCalculated());
    }

    function test_JoinedValue_Empty() public view {
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

        vm.roll(block.number + WAITING_BLOCKS);

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

        vm.roll(block.number + WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.joinedValueByAccount(user1), 0);
    }

    // ============================================
    // ACCOUNTS TESTS
    // ============================================

    function test_AccountsCount_Empty() public view {
        assertEq(center.accountsCount(address(token), ACTION_ID), 0);
    }

    function test_AccountsCount_SingleUser() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
        address[] memory accountsList = center.accounts(
            address(token),
            ACTION_ID
        );
        assertEq(accountsList[0], user1);
    }

    function test_AccountsCount_MultipleUsers() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 3);
        address[] memory accountsList = center.accounts(
            address(token),
            ACTION_ID
        );
        assertEq(accountsList[0], user1);
        assertEq(accountsList[1], user2);
        assertEq(accountsList[2], user3);
    }

    function test_AccountsCount_AfterExit() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        vm.roll(block.number + WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
        address[] memory accountsList = center.accounts(
            address(token),
            ACTION_ID
        );
        assertEq(accountsList[0], user2);
    }

    // ============================================
    // TOKEN TRANSFER TESTS
    // ============================================

    function test_Join_TransfersTokensFromUser() public {
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

    function test_Exit_TransfersTokensToUser() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        vm.roll(block.number + WAITING_BLOCKS);

        uint256 userBalanceBefore = joinToken.balanceOf(user1);
        uint256 extensionBalanceBefore = joinToken.balanceOf(
            address(extension)
        );

        vm.prank(user1);
        extension.exit();

        assertEq(joinToken.balanceOf(user1), userBalanceBefore + amount);
        assertEq(
            joinToken.balanceOf(address(extension)),
            extensionBalanceBefore - amount
        );
    }

    // ============================================
    // EDGE CASE TESTS
    // ============================================

    function test_Join_LargeAmount() public {
        uint256 largeAmount = 1e30; // 1 billion tokens with 18 decimals
        joinToken.mint(user1, largeAmount);

        vm.prank(user1);
        joinToken.approve(address(extension), largeAmount);

        vm.prank(user1);
        extension.join(largeAmount, new string[](0));

        assertEq(extension.totalJoinedAmount(), largeAmount);
    }

    function test_Join_MinAmount() public {
        uint256 minAmount = 1;

        vm.prank(user1);
        extension.join(minAmount, new string[](0));

        assertEq(extension.totalJoinedAmount(), minAmount);
    }

    function test_Exit_ImmediatelyAtThreshold() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // Roll exactly to the threshold
        vm.roll(block.number + WAITING_BLOCKS);

        // Should be able to withdraw immediately
        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
    }

    // ============================================
    // INTEGRATION TESTS
    // ============================================

    function test_Integration_FullLifecycle() public {
        // Multiple users join at different times
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.roll(block.number + 10);

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        vm.roll(block.number + 20);

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        // Check total
        assertEq(extension.totalJoinedAmount(), 600e18);
        assertEq(center.accountsCount(address(token), ACTION_ID), 3);

        // Move forward enough for user1 to withdraw
        vm.roll(block.number + 70); // Total 100 blocks from user1's join

        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 500e18);
        assertEq(center.accountsCount(address(token), ACTION_ID), 2);

        // Move forward for user2
        vm.roll(block.number + 20); // Total 120 blocks from user2's join (10+20+70+20)

        vm.prank(user2);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 300e18);
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);

        // Move forward for user3
        vm.roll(block.number + 10); // Total 120 blocks from user3's join

        vm.prank(user3);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(center.accountsCount(address(token), ACTION_ID), 0);
    }
}
