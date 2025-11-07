// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {
    LOVE20ExtensionSimpleStake
} from "../src/examples/LOVE20ExtensionSimpleStake.sol";
import {
    LOVE20ExtensionFactorySimpleStake
} from "../src/examples/LOVE20ExtensionFactorySimpleStake.sol";
import {
    ILOVE20ExtensionAutoScoreStake
} from "../src/interface/ILOVE20ExtensionAutoScoreStake.sol";
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
 * @title LOVE20ExtensionSimpleStake Test Suite
 * @notice Comprehensive tests for LOVE20ExtensionAutoScoreStake implementation
 */
contract LOVE20ExtensionSimpleStakeTest is Test {
    LOVE20ExtensionFactorySimpleStake public factory;
    LOVE20ExtensionSimpleStake public extension;
    LOVE20ExtensionCenter public center;
    MockERC20 public token;
    MockERC20 public stakeToken;
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
    uint256 constant WAITING_PHASES = 7;
    uint256 constant MIN_GOV_VOTES = 1e18;

    event Stake(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );
    event Unstake(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );
    event Withdraw(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId,
        uint256 amount
    );
    event ClaimReward(
        address indexed account,
        uint256 indexed round,
        uint256 reward
    );

    function setUp() public {
        // Deploy mock contracts
        token = new MockERC20();
        stakeToken = new MockERC20();
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
        factory = new LOVE20ExtensionFactorySimpleStake(address(center));

        // Create extension through factory
        extension = LOVE20ExtensionSimpleStake(
            factory.createExtension(
                address(stakeToken),
                WAITING_PHASES,
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
        uint256 stakeAmount,
        uint256 govVotes
    ) internal {
        stakeToken.mint(user, stakeAmount);
        vm.prank(user);
        stakeToken.approve(address(extension), type(uint256).max);
        stake.setValidGovVotes(address(token), user, govVotes);
    }

    // ============================================
    // IMMUTABLE VARIABLES TESTS
    // ============================================

    function test_ImmutableVariables() public view {
        assertEq(extension.stakeTokenAddress(), address(stakeToken));
        assertEq(extension.waitingPhases(), WAITING_PHASES);
        assertEq(extension.minGovVotes(), MIN_GOV_VOTES);
        assertTrue(extension.factory() != address(0));
    }

    function test_Center() public view {
        assertEq(extension.center(), address(center));
    }

    // ============================================
    // STAKE TESTS
    // ============================================

    function test_Stake() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.stake(amount, new string[](0));

        (uint256 stakedAmount, uint256 requestedUnstakeRound) = extension
            .stakeInfo(user1);
        assertEq(stakedAmount, amount);
        assertEq(requestedUnstakeRound, 0);
        assertEq(extension.totalStakedAmount(), amount);
        assertEq(extension.accountsCount(), 1);
    }

    function test_Stake_EmitEvent() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, true, true, true);
        emit Stake(address(token), user1, ACTION_ID, amount);

        vm.prank(user1);
        extension.stake(amount, new string[](0));
    }

    function test_Stake_MultipleUsers() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        vm.prank(user3);
        extension.stake(300e18, new string[](0));

        assertEq(extension.totalStakedAmount(), 600e18);
        assertEq(extension.accountsCount(), 3);
    }

    function test_Stake_MultipleTimes() public {
        vm.startPrank(user1);
        extension.stake(100e18, new string[](0));
        extension.stake(50e18, new string[](0));
        vm.stopPrank();

        (uint256 amount, ) = extension.stakeInfo(user1);
        assertEq(amount, 150e18);
        assertEq(extension.totalStakedAmount(), 150e18);
    }

    function test_Stake_RevertIfAmountZero() public {
        vm.prank(user1);
        vm.expectRevert(
            ILOVE20ExtensionAutoScoreStake.StakeAmountZero.selector
        );
        extension.stake(0, new string[](0));
    }

    function test_Stake_RevertIfInsufficientGovVotes() public {
        address poorUser = address(0x999);
        stakeToken.mint(poorUser, 1000e18);
        vm.prank(poorUser);
        stakeToken.approve(address(extension), type(uint256).max);
        stake.setValidGovVotes(address(token), poorUser, 0);

        vm.prank(poorUser);
        vm.expectRevert(
            ILOVE20ExtensionAutoScoreStake.InsufficientGovVotes.selector
        );
        extension.stake(100e18, new string[](0));
    }

    function test_Stake_RevertIfUnstakeRequested() public {
        vm.startPrank(user1);
        extension.stake(100e18, new string[](0));
        extension.unstake();

        vm.expectRevert(
            ILOVE20ExtensionAutoScoreStake.UnstakeRequested.selector
        );
        extension.stake(50e18, new string[](0));
        vm.stopPrank();
    }

    function test_Stake_SuccessWithMinimumGovVotes() public {
        address minUser = address(0x888);
        stakeToken.mint(minUser, 1000e18);
        vm.prank(minUser);
        stakeToken.approve(address(extension), type(uint256).max);
        stake.setValidGovVotes(address(token), minUser, MIN_GOV_VOTES);

        vm.prank(minUser);
        extension.stake(100e18, new string[](0));

        (uint256 amount, ) = extension.stakeInfo(minUser);
        assertEq(amount, 100e18);
    }

    // ============================================
    // UNSTAKE TESTS
    // ============================================

    function test_Unstake() public {
        uint256 amount = 100e18;

        vm.startPrank(user1);
        extension.stake(amount, new string[](0));

        uint256 currentRound = join.currentRound();
        extension.unstake();
        vm.stopPrank();

        (uint256 stakedAmount, uint256 requestedUnstakeRound) = extension
            .stakeInfo(user1);
        assertEq(stakedAmount, amount);
        assertEq(requestedUnstakeRound, currentRound);
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), amount);
        assertEq(extension.accountsCount(), 0);
        assertEq(extension.unstakersCount(), 1);
    }

    function test_Unstake_EmitEvent() public {
        uint256 amount = 100e18;

        vm.startPrank(user1);
        extension.stake(amount, new string[](0));

        vm.expectEmit(true, true, true, true);
        emit Unstake(address(token), user1, ACTION_ID, amount);

        extension.unstake();
        vm.stopPrank();
    }

    function test_Unstake_RevertIfNoStakedAmount() public {
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionAutoScoreStake.NoStakedAmount.selector);
        extension.unstake();
    }

    function test_Unstake_RevertIfAlreadyRequested() public {
        vm.startPrank(user1);
        extension.stake(100e18, new string[](0));
        extension.unstake();

        vm.expectRevert(
            ILOVE20ExtensionAutoScoreStake.UnstakeRequested.selector
        );
        extension.unstake();
        vm.stopPrank();
    }

    // ============================================
    // WITHDRAW TESTS
    // ============================================

    function test_Withdraw() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.stake(amount, new string[](0));

        vm.prank(user1);
        extension.unstake();

        // Fast forward phases
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        uint256 balanceBefore = stakeToken.balanceOf(user1);

        vm.prank(user1);
        extension.withdraw();

        assertEq(stakeToken.balanceOf(user1), balanceBefore + amount);
        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 0);
        assertEq(extension.unstakersCount(), 0);

        (uint256 stakedAmount, uint256 requestedUnstakeRound) = extension
            .stakeInfo(user1);
        assertEq(stakedAmount, 0);
        assertEq(requestedUnstakeRound, 0);
    }

    function test_Withdraw_EmitEvent() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.stake(amount, new string[](0));

        vm.prank(user1);
        extension.unstake();

        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(token), user1, ACTION_ID, amount);

        vm.prank(user1);
        extension.withdraw();
    }

    function test_Withdraw_RevertIfNotRequested() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user1);
        vm.expectRevert(
            ILOVE20ExtensionAutoScoreStake.UnstakeNotRequested.selector
        );
        extension.withdraw();
    }

    function test_Withdraw_RevertIfNotEnoughWaitingPhases() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user1);
        extension.unstake();

        // Not enough phases passed
        join.setCurrentRound(join.currentRound() + WAITING_PHASES);

        vm.prank(user1);
        vm.expectRevert(
            ILOVE20ExtensionAutoScoreStake.NotEnoughWaitingPhases.selector
        );
        extension.withdraw();
    }

    function test_Withdraw_ExactlyAtWaitingPhases() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        uint256 unstakeRound = join.currentRound();

        vm.prank(user1);
        extension.unstake();

        // Exactly at the waiting phases threshold + 1
        join.setCurrentRound(unstakeRound + WAITING_PHASES + 1);

        vm.prank(user1);
        extension.withdraw();

        (uint256 amount, ) = extension.stakeInfo(user1);
        assertEq(amount, 0);
    }

    // ============================================
    // UNSTAKERS TESTS
    // ============================================

    function test_Unstakers() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        vm.prank(user1);
        extension.unstake();

        vm.prank(user2);
        extension.unstake();

        assertEq(extension.unstakersCount(), 2);

        address[] memory unstakers = extension.unstakers();
        assertEq(unstakers.length, 2);
        assertEq(unstakers[0], user1);
        assertEq(unstakers[1], user2);
    }

    function test_UnstakersAtIndex() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        vm.prank(user1);
        extension.unstake();

        vm.prank(user2);
        extension.unstake();

        assertEq(extension.unstakersAtIndex(0), user1);
        assertEq(extension.unstakersAtIndex(1), user2);
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
        extension.stake(100e18, new string[](0));

        (uint256 total, uint256[] memory scores) = extension.calculateScores();
        assertEq(total, 100e18);
        assertEq(scores.length, 1);
        assertEq(scores[0], 100e18);
    }

    function test_CalculateScores_MultipleUsers() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        vm.prank(user3);
        extension.stake(300e18, new string[](0));

        (uint256 total, uint256[] memory scores) = extension.calculateScores();
        assertEq(total, 600e18);
        assertEq(scores.length, 3);
        assertEq(scores[0], 100e18);
        assertEq(scores[1], 200e18);
        assertEq(scores[2], 300e18);
    }

    function test_CalculateScore_ExistingAccount() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        (uint256 total, uint256 score) = extension.calculateScore(user1);
        assertEq(total, 300e18);
        assertEq(score, 100e18);
    }

    function test_CalculateScore_NonExistentAccount() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        (uint256 total, uint256 score) = extension.calculateScore(user2);
        assertEq(total, 100e18);
        assertEq(score, 0);
    }

    function test_CalculateScores_AfterUnstake() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        vm.prank(user1);
        extension.unstake();

        // After unstake, user1 is removed from accounts
        (uint256 total, uint256[] memory scores) = extension.calculateScores();
        assertEq(total, 200e18);
        assertEq(scores.length, 1);
        assertEq(scores[0], 200e18);
    }

    // ============================================
    // ACCOUNTS TESTS
    // ============================================

    function test_Accounts() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        address[] memory accounts = extension.accounts();
        assertEq(accounts.length, 2);
        assertEq(accounts[0], user1);
        assertEq(accounts[1], user2);
    }

    function test_AccountsCount() public {
        assertEq(extension.accountsCount(), 0);

        vm.prank(user1);
        extension.stake(100e18, new string[](0));
        assertEq(extension.accountsCount(), 1);

        vm.prank(user2);
        extension.stake(200e18, new string[](0));
        assertEq(extension.accountsCount(), 2);

        vm.prank(user1);
        extension.unstake();
        assertEq(extension.accountsCount(), 1);
    }

    function test_AccountAtIndex() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        assertEq(extension.accountAtIndex(0), user1);
        assertEq(extension.accountAtIndex(1), user2);
    }

    // ============================================
    // REWARD TESTS
    // ============================================

    function test_ClaimReward_RevertIfRoundNotFinished() public {
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        verify.setCurrentRound(1);

        vm.prank(user1);
        vm.expectRevert(ILOVE20Extension.RoundNotFinished.selector);
        extension.claimReward(1);
    }

    // ============================================
    // COMPLEX SCENARIOS
    // ============================================

    function test_StakeUnstakeWithdrawCycle() public {
        // First stake
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        assertEq(extension.totalStakedAmount(), 100e18);
        assertEq(extension.accountsCount(), 1);

        // Unstake
        vm.prank(user1);
        extension.unstake();

        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 100e18);
        assertEq(extension.accountsCount(), 0);
        assertEq(extension.unstakersCount(), 1);

        // Withdraw
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);
        vm.prank(user1);
        extension.withdraw();

        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 0);
        assertEq(extension.unstakersCount(), 0);

        // Stake again
        vm.prank(user1);
        extension.stake(200e18, new string[](0));

        assertEq(extension.totalStakedAmount(), 200e18);
        assertEq(extension.accountsCount(), 1);
    }

    function test_MultipleUsersComplexScenario() public {
        // User1 and User2 stake
        vm.prank(user1);
        extension.stake(100e18, new string[](0));

        vm.prank(user2);
        extension.stake(200e18, new string[](0));

        assertEq(extension.totalStakedAmount(), 300e18);
        assertEq(extension.accountsCount(), 2);

        // User1 unstakes
        vm.prank(user1);
        extension.unstake();

        assertEq(extension.totalStakedAmount(), 200e18);
        assertEq(extension.totalUnstakedAmount(), 100e18);
        assertEq(extension.accountsCount(), 1);
        assertEq(extension.unstakersCount(), 1);

        // User3 stakes
        vm.prank(user3);
        extension.stake(300e18, new string[](0));

        assertEq(extension.totalStakedAmount(), 500e18);
        assertEq(extension.accountsCount(), 2);

        // Fast forward and User1 withdraws
        join.setCurrentRound(join.currentRound() + WAITING_PHASES + 1);
        vm.prank(user1);
        extension.withdraw();

        assertEq(extension.totalStakedAmount(), 500e18);
        assertEq(extension.totalUnstakedAmount(), 0);
        assertEq(extension.unstakersCount(), 0);

        // User2 and User3 unstake
        vm.prank(user2);
        extension.unstake();

        vm.prank(user3);
        extension.unstake();

        assertEq(extension.totalStakedAmount(), 0);
        assertEq(extension.totalUnstakedAmount(), 500e18);
        assertEq(extension.accountsCount(), 0);
        assertEq(extension.unstakersCount(), 2);
    }

    // ============================================
    // FUZZ TESTS
    // ============================================

    function testFuzz_Stake(uint256 amount) public {
        amount = bound(amount, 1, 1000e18);

        vm.prank(user1);
        extension.stake(amount, new string[](0));

        (uint256 stakedAmount, ) = extension.stakeInfo(user1);
        assertEq(stakedAmount, amount);
        assertEq(extension.totalStakedAmount(), amount);
    }

    function testFuzz_Withdraw(uint256 amount, uint256 extraPhases) public {
        amount = bound(amount, 1, 1000e18);
        extraPhases = bound(extraPhases, 0, 100);

        vm.prank(user1);
        extension.stake(amount, new string[](0));

        vm.prank(user1);
        extension.unstake();

        join.setCurrentRound(
            join.currentRound() + WAITING_PHASES + 1 + extraPhases
        );

        uint256 balanceBefore = stakeToken.balanceOf(user1);

        vm.prank(user1);
        extension.withdraw();

        assertEq(stakeToken.balanceOf(user1), balanceBefore + amount);
    }

    function testFuzz_TotalAmounts_MultipleUsers(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    ) public {
        amount1 = bound(amount1, 1, 333e18);
        amount2 = bound(amount2, 1, 333e18);
        amount3 = bound(amount3, 1, 333e18);

        vm.prank(user1);
        extension.stake(amount1, new string[](0));

        vm.prank(user2);
        extension.stake(amount2, new string[](0));

        vm.prank(user3);
        extension.stake(amount3, new string[](0));

        assertEq(extension.totalStakedAmount(), amount1 + amount2 + amount3);

        vm.prank(user1);
        extension.unstake();

        assertEq(extension.totalStakedAmount(), amount2 + amount3);
        assertEq(extension.totalUnstakedAmount(), amount1);
    }
}
