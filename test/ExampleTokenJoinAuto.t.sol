// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {ExampleTokenJoinAuto} from "../src/examples/ExampleTokenJoinAuto.sol";
import {
    ExampleFactoryTokenJoinAuto
} from "../src/examples/ExampleFactoryTokenJoinAuto.sol";
import {
    ILOVE20ExtensionTokenJoinAuto
} from "../src/interface/ILOVE20ExtensionTokenJoinAuto.sol";
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
 * @title ExampleTokenJoinAuto Test Suite
 * @notice Comprehensive tests for ExampleTokenJoinAuto implementation
 */
contract ExampleTokenJoinAutoTest is Test {
    ExampleFactoryTokenJoinAuto public factory;
    ExampleTokenJoinAuto public extension;
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
        factory = new ExampleFactoryTokenJoinAuto(address(center));

        // Create extension through factory
        extension = ExampleTokenJoinAuto(
            factory.createExtension(address(joinToken), WAITING_BLOCKS)
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

    function test_Join_RevertIfAlreadyJoined() public {
        vm.startPrank(user1);
        extension.join(100e18, new string[](0));

        vm.expectRevert(ITokenJoin.AlreadyJoined.selector);
        extension.join(50e18, new string[](0));
        vm.stopPrank();
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

        vm.roll(block.number + WAITING_BLOCKS);

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

        (uint256 amount, , ) = extension.joinInfo(user1);
        assertEq(amount, 0);
    }

    // ============================================
    // CAN EXIT TESTS
    // ============================================

    function test_CanExit_False_NotJoined() public view {
        assertFalse(extension.canExit(user1));
    }

    function test_CanExit_False_NotEnoughBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.roll(block.number + WAITING_BLOCKS - 1);
        assertFalse(extension.canExit(user1));
    }

    function test_CanExit_True_AfterWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.roll(block.number + WAITING_BLOCKS);
        assertTrue(extension.canExit(user1));
    }

    // ============================================
    // EXITABLE BLOCK TESTS
    // ============================================

    function test_ExitableBlock_Zero_NotJoined() public view {
        (, , uint256 exitableBlock) = extension.joinInfo(user1);
        assertEq(exitableBlock, 0);
    }

    function test_ExitableBlock_Correct() public {
        uint256 joinBlock = block.number;

        vm.prank(user1);
        extension.join(100e18, new string[](0));

        (, , uint256 exitableBlock) = extension.joinInfo(user1);
        assertEq(exitableBlock, joinBlock + WAITING_BLOCKS);
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
        extension.join(100e18, new string[](0));

        (uint256 total, uint256[] memory scores) = extension.calculateScores();
        assertEq(total, 100e18);
        assertEq(scores.length, 1);
        assertEq(scores[0], 100e18);
    }

    function test_CalculateScores_MultipleUsers() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        (uint256 total, uint256[] memory scores) = extension.calculateScores();
        assertEq(total, 600e18);
        assertEq(scores.length, 3);
        assertEq(scores[0], 100e18);
        assertEq(scores[1], 200e18);
        assertEq(scores[2], 300e18);
    }

    function test_CalculateScore_ExistingAccount() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        (uint256 total, uint256 score) = extension.calculateScore(user1);
        assertEq(total, 300e18);
        assertEq(score, 100e18);
    }

    function test_CalculateScore_NonExistentAccount() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        (uint256 total, uint256 score) = extension.calculateScore(user2);
        assertEq(total, 100e18);
        assertEq(score, 0);
    }

    // ============================================
    // ACCOUNTS TESTS
    // ============================================

    function test_Accounts() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        address[] memory accounts = extension.accounts();
        assertEq(accounts.length, 2);
        assertEq(accounts[0], user1);
        assertEq(accounts[1], user2);
    }

    function test_AccountsCount() public {
        assertEq(extension.accountsCount(), 0);

        vm.prank(user1);
        extension.join(100e18, new string[](0));
        assertEq(extension.accountsCount(), 1);

        vm.prank(user2);
        extension.join(200e18, new string[](0));
        assertEq(extension.accountsCount(), 2);
    }

    function test_AccountAtIndex() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        assertEq(extension.accountAtIndex(0), user1);
        assertEq(extension.accountAtIndex(1), user2);
    }

    // ============================================
    // REWARD TESTS
    // ============================================

    function test_ClaimReward_RevertIfRoundNotFinished() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        verify.setCurrentRound(1);

        vm.prank(user1);
        vm.expectRevert(IExtensionReward.RoundNotFinished.selector);
        extension.claimReward(1);
    }

    // ============================================
    // COMPLEX SCENARIOS
    // ============================================

    function test_JoinExitJoinCycle() public {
        // First join
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        assertEq(extension.totalJoinedAmount(), 100e18);
        assertEq(extension.accountsCount(), 1);

        // Exit
        vm.roll(block.number + WAITING_BLOCKS);
        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);

        // Join again
        vm.prank(user1);
        extension.join(200e18, new string[](0));

        assertEq(extension.totalJoinedAmount(), 200e18);
        assertEq(extension.accountsCount(), 1);
    }

    function test_MultipleUsersComplexScenario() public {
        // User1 joins
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // User2 joins
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        assertEq(extension.totalJoinedAmount(), 300e18);
        assertEq(extension.accountsCount(), 2);

        // Fast forward
        vm.roll(block.number + WAITING_BLOCKS);

        // User1 exits
        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 200e18);
        assertEq(extension.accountsCount(), 1);

        // User3 joins
        vm.prank(user3);
        extension.join(300e18, new string[](0));

        assertEq(extension.totalJoinedAmount(), 500e18);
        assertEq(extension.accountsCount(), 2);

        // Fast forward again
        vm.roll(block.number + WAITING_BLOCKS);

        // User2 and User3 exit
        vm.prank(user2);
        extension.exit();

        vm.prank(user3);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);
    }

    // ============================================
    // FUZZ TESTS
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

        vm.roll(block.number + WAITING_BLOCKS + extraBlocks);

        uint256 balanceBefore = joinToken.balanceOf(user1);

        vm.prank(user1);
        extension.exit();

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
        extension.join(amount1, new string[](0));

        vm.prank(user2);
        extension.join(amount2, new string[](0));

        vm.prank(user3);
        extension.join(amount3, new string[](0));

        assertEq(extension.totalJoinedAmount(), amount1 + amount2 + amount3);
    }
}
