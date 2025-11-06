// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {
    LOVE20ExtensionSimpleJoin
} from "../src/examples/LOVE20ExtensionSimpleJoin.sol";
import {
    LOVE20ExtensionFactorySimpleJoin
} from "../src/examples/LOVE20ExtensionFactorySimpleJoin.sol";
import {
    ILOVE20ExtensionAutoScoreJoin
} from "../src/interface/ILOVE20ExtensionAutoScoreJoin.sol";
import {ILOVE20Extension} from "../src/interface/ILOVE20Extension.sol";
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
 * @title LOVE20ExtensionSimpleJoin Test Suite
 * @notice Comprehensive tests for LOVE20ExtensionAutoScoreJoin implementation
 */
contract LOVE20ExtensionSimpleJoinTest is Test {
    LOVE20ExtensionFactorySimpleJoin public factory;
    LOVE20ExtensionSimpleJoin public extension;
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
    uint256 constant MIN_GOV_VOTES = 1e18;

    event Join(address indexed account, uint256 amount, uint256 joinedBlock);
    event Withdraw(address indexed account, uint256 amount);
    event ClaimReward(
        address indexed account,
        uint256 indexed round,
        uint256 reward
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
        factory = new LOVE20ExtensionFactorySimpleJoin(address(center));

        // Create extension through factory
        extension = LOVE20ExtensionSimpleJoin(
            factory.createExtension(
                address(joinToken),
                WAITING_BLOCKS,
                MIN_GOV_VOTES
            )
        );

        // Register factory to center (needs canSubmit permission)
        submit.setCanSubmit(address(token), address(this), true);
        center.addFactory(address(token), address(factory));

        // Set action info whiteListAddress to extension address
        submit.setActionInfo(address(token), ACTION_ID, address(extension));

        // Initialize extension through center
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );

        // Setup users with tokens and governance votes
        _setupUser(user1, 1000e18, 10e18);
        _setupUser(user2, 2000e18, 20e18);
        _setupUser(user3, 3000e18, 30e18);
    }

    function _setupUser(
        address user,
        uint256 joinAmount,
        uint256 govVotes
    ) internal {
        joinToken.mint(user, joinAmount);
        vm.prank(user);
        joinToken.approve(address(extension), type(uint256).max);
        stake.setValidGovVotes(address(token), user, govVotes);
    }

    // ============================================
    // IMMUTABLE VARIABLES TESTS
    // ============================================

    function test_ImmutableVariables() public view {
        assertEq(extension.joinTokenAddress(), address(joinToken));
        assertEq(extension.waitingBlocks(), WAITING_BLOCKS);
        assertEq(extension.minGovVotes(), MIN_GOV_VOTES);
        // factory is MockExtensionFactory, not center
        assertTrue(extension.factory() != address(0));
    }

    function test_Center() public view {
        assertEq(extension.center(), address(center));
    }

    // ============================================
    // JOIN TESTS
    // ============================================

    function test_Join() public {
        uint256 amount = 100e18;
        uint256 blockBefore = block.number;

        vm.prank(user1);
        extension.join(amount);

        (uint256 joinedAmount, uint256 joinedBlock) = extension.joinInfo(user1);
        assertEq(joinedAmount, amount);
        assertEq(joinedBlock, blockBefore);
        assertEq(extension.totalJoinedAmount(), amount);
        assertEq(extension.accountsCount(), 1);
    }

    function test_Join_EmitEvent() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, false, false, true);
        emit Join(user1, amount, block.number);

        vm.prank(user1);
        extension.join(amount);
    }

    function test_Join_MultipleUsers() public {
        vm.prank(user1);
        extension.join(100e18);

        vm.prank(user2);
        extension.join(200e18);

        vm.prank(user3);
        extension.join(300e18);

        assertEq(extension.totalJoinedAmount(), 600e18);
        assertEq(extension.accountsCount(), 3);
    }

    function test_Join_RevertIfAmountZero() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionAutoScoreJoin.JoinAmountZero.selector);
        extension.join(0);
    }

    function test_Join_RevertIfInsufficientGovVotes() public {
        address poorUser = address(0x999);
        joinToken.mint(poorUser, 1000e18);
        vm.prank(poorUser);
        joinToken.approve(address(extension), type(uint256).max);
        stake.setValidGovVotes(address(token), poorUser, 0);

        vm.prank(poorUser);
        vm.expectRevert(
            ILOVE20ExtensionAutoScoreJoin.InsufficientGovVotes.selector
        );
        extension.join(100e18);
    }

    function test_Join_RevertIfAlreadyJoined() public {
        vm.startPrank(user1);
        extension.join(100e18);

        vm.expectRevert(ILOVE20ExtensionAutoScoreJoin.AlreadyJoined.selector);
        extension.join(50e18);
        vm.stopPrank();
    }

    function test_Join_SuccessWithMinimumGovVotes() public {
        address minUser = address(0x888);
        joinToken.mint(minUser, 1000e18);
        vm.prank(minUser);
        joinToken.approve(address(extension), type(uint256).max);
        stake.setValidGovVotes(address(token), minUser, MIN_GOV_VOTES);

        vm.prank(minUser);
        extension.join(100e18);

        (uint256 amount, ) = extension.joinInfo(minUser);
        assertEq(amount, 100e18);
    }

    // ============================================
    // WITHDRAW TESTS
    // ============================================

    function test_Withdraw() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount);

        // Fast forward blocks
        vm.roll(block.number + WAITING_BLOCKS);

        uint256 balanceBefore = joinToken.balanceOf(user1);

        vm.prank(user1);
        extension.withdraw();

        assertEq(joinToken.balanceOf(user1), balanceBefore + amount);
        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);

        (uint256 joinedAmount, uint256 joinedBlock) = extension.joinInfo(user1);
        assertEq(joinedAmount, 0);
        assertEq(joinedBlock, 0);
    }

    function test_Withdraw_EmitEvent() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount);

        vm.roll(block.number + WAITING_BLOCKS);

        vm.expectEmit(true, false, false, true);
        emit Withdraw(user1, amount);

        vm.prank(user1);
        extension.withdraw();
    }

    function test_Withdraw_RevertIfNotJoined() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionAutoScoreJoin.NoJoinedAmount.selector);
        extension.withdraw();
    }

    function test_Withdraw_RevertIfNotEnoughWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18);

        // Not enough blocks passed
        vm.roll(block.number + WAITING_BLOCKS - 1);

        vm.prank(user1);
        vm.expectRevert(
            ILOVE20ExtensionAutoScoreJoin.NotEnoughWaitingBlocks.selector
        );
        extension.withdraw();
    }

    function test_Withdraw_ExactlyAtWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18);

        // Exactly at the waiting blocks threshold
        vm.roll(block.number + WAITING_BLOCKS);

        vm.prank(user1);
        extension.withdraw();

        (uint256 amount, ) = extension.joinInfo(user1);
        assertEq(amount, 0);
    }

    // ============================================
    // CAN WITHDRAW TESTS
    // ============================================

    function test_CanWithdraw_False_NotJoined() public view {
        assertFalse(extension.canWithdraw(user1));
    }

    function test_CanWithdraw_False_NotEnoughBlocks() public {
        vm.prank(user1);
        extension.join(100e18);

        vm.roll(block.number + WAITING_BLOCKS - 1);
        assertFalse(extension.canWithdraw(user1));
    }

    function test_CanWithdraw_True_AfterWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18);

        vm.roll(block.number + WAITING_BLOCKS);
        assertTrue(extension.canWithdraw(user1));
    }

    // ============================================
    // WITHDRAWABLE BLOCK TESTS
    // ============================================

    function test_WithdrawableBlock_Zero_NotJoined() public view {
        assertEq(extension.withdrawableBlock(user1), 0);
    }

    function test_WithdrawableBlock_Correct() public {
        uint256 joinBlock = block.number;

        vm.prank(user1);
        extension.join(100e18);

        assertEq(
            extension.withdrawableBlock(user1),
            joinBlock + WAITING_BLOCKS
        );
    }

    // ============================================
    // SCORE CALCULATION TESTS
    // ============================================

    function test_CalculateScores_EmptyAccounts() public view {
        (uint256 total, uint256[] memory scores) = extension.calculateScores();
        assertEq(total, 0);
        assertEq(scores.length, 0);
    }

    function test_CalculateScores_SingleUser() public {
        vm.prank(user1);
        extension.join(100e18);

        (uint256 total, uint256[] memory scores) = extension.calculateScores();
        assertEq(total, 100e18);
        assertEq(scores.length, 1);
        assertEq(scores[0], 100e18);
    }

    function test_CalculateScores_MultipleUsers() public {
        vm.prank(user1);
        extension.join(100e18);

        vm.prank(user2);
        extension.join(200e18);

        vm.prank(user3);
        extension.join(300e18);

        (uint256 total, uint256[] memory scores) = extension.calculateScores();
        assertEq(total, 600e18);
        assertEq(scores.length, 3);
        assertEq(scores[0], 100e18);
        assertEq(scores[1], 200e18);
        assertEq(scores[2], 300e18);
    }

    function test_CalculateScore_ExistingAccount() public {
        vm.prank(user1);
        extension.join(100e18);

        vm.prank(user2);
        extension.join(200e18);

        (uint256 total, uint256 score) = extension.calculateScore(user1);
        assertEq(total, 300e18);
        assertEq(score, 100e18);
    }

    function test_CalculateScore_NonExistentAccount() public {
        vm.prank(user1);
        extension.join(100e18);

        (uint256 total, uint256 score) = extension.calculateScore(user2);
        assertEq(total, 100e18);
        assertEq(score, 0);
    }

    // ============================================
    // ACCOUNTS TESTS
    // ============================================

    function test_Accounts() public {
        vm.prank(user1);
        extension.join(100e18);

        vm.prank(user2);
        extension.join(200e18);

        address[] memory accounts = extension.accounts();
        assertEq(accounts.length, 2);
        assertEq(accounts[0], user1);
        assertEq(accounts[1], user2);
    }

    function test_AccountsCount() public {
        assertEq(extension.accountsCount(), 0);

        vm.prank(user1);
        extension.join(100e18);
        assertEq(extension.accountsCount(), 1);

        vm.prank(user2);
        extension.join(200e18);
        assertEq(extension.accountsCount(), 2);
    }

    function test_AccountAtIndex() public {
        vm.prank(user1);
        extension.join(100e18);

        vm.prank(user2);
        extension.join(200e18);

        assertEq(extension.accountAtIndex(0), user1);
        assertEq(extension.accountAtIndex(1), user2);
    }

    // ============================================
    // REWARD TESTS
    // ============================================

    function test_ClaimReward_RevertIfRoundNotFinished() public {
        vm.prank(user1);
        extension.join(100e18);

        verify.setCurrentRound(1);

        vm.prank(user1);
        vm.expectRevert(ILOVE20Extension.RoundNotFinished.selector);
        extension.claimReward(1);
    }

    // ============================================
    // COMPLEX SCENARIOS
    // ============================================

    function test_JoinWithdrawJoinCycle() public {
        // First join
        vm.prank(user1);
        extension.join(100e18);

        assertEq(extension.totalJoinedAmount(), 100e18);
        assertEq(extension.accountsCount(), 1);

        // Withdraw
        vm.roll(block.number + WAITING_BLOCKS);
        vm.prank(user1);
        extension.withdraw();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);

        // Join again
        vm.prank(user1);
        extension.join(200e18);

        assertEq(extension.totalJoinedAmount(), 200e18);
        assertEq(extension.accountsCount(), 1);
    }

    function test_MultipleUsersComplexScenario() public {
        // User1 joins
        vm.prank(user1);
        extension.join(100e18);

        // User2 joins
        vm.prank(user2);
        extension.join(200e18);

        assertEq(extension.totalJoinedAmount(), 300e18);
        assertEq(extension.accountsCount(), 2);

        // Fast forward
        vm.roll(block.number + WAITING_BLOCKS);

        // User1 withdraws
        vm.prank(user1);
        extension.withdraw();

        assertEq(extension.totalJoinedAmount(), 200e18);
        assertEq(extension.accountsCount(), 1);

        // User3 joins
        vm.prank(user3);
        extension.join(300e18);

        assertEq(extension.totalJoinedAmount(), 500e18);
        assertEq(extension.accountsCount(), 2);

        // Fast forward again
        vm.roll(block.number + WAITING_BLOCKS);

        // User2 and User3 withdraw
        vm.prank(user2);
        extension.withdraw();

        vm.prank(user3);
        extension.withdraw();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);
    }

    // ============================================
    // FUZZ TESTS
    // ============================================

    function testFuzz_Join(uint256 amount) public {
        amount = bound(amount, 1, 1000e18);

        vm.prank(user1);
        extension.join(amount);

        (uint256 joinedAmount, ) = extension.joinInfo(user1);
        assertEq(joinedAmount, amount);
        assertEq(extension.totalJoinedAmount(), amount);
    }

    function testFuzz_Withdraw(uint256 amount, uint256 extraBlocks) public {
        amount = bound(amount, 1, 1000e18);
        extraBlocks = bound(extraBlocks, 0, 10000);

        vm.prank(user1);
        extension.join(amount);

        vm.roll(block.number + WAITING_BLOCKS + extraBlocks);

        uint256 balanceBefore = joinToken.balanceOf(user1);

        vm.prank(user1);
        extension.withdraw();

        assertEq(joinToken.balanceOf(user1), balanceBefore + amount);
    }

    function testFuzz_TotalJoinedAmount_MultipleUsers(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    ) public {
        amount1 = bound(amount1, 1, 333e18);
        amount2 = bound(amount2, 1, 333e18);
        amount3 = bound(amount3, 1, 333e18);

        vm.prank(user1);
        extension.join(amount1);

        vm.prank(user2);
        extension.join(amount2);

        vm.prank(user3);
        extension.join(amount3);

        assertEq(extension.totalJoinedAmount(), amount1 + amount2 + amount3);
    }
}
