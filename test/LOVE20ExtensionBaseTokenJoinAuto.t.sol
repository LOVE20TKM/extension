// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {
    LOVE20ExtensionBaseTokenJoinAuto
} from "../src/LOVE20ExtensionBaseTokenJoinAuto.sol";
import {ITokenJoin} from "../src/interface/base/ITokenJoin.sol";
import {IExtensionReward} from "../src/interface/base/IExtensionReward.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockLOVE20ExtensionBaseTokenJoinAuto
 * @notice LOVE20ExtensionBaseTokenJoinAuto 的具体实现，用于测试
 * @dev 实现简单的分数计算：每个账户的分数等于其加入的金额
 */
contract MockLOVE20ExtensionBaseTokenJoinAuto is
    LOVE20ExtensionBaseTokenJoinAuto
{
    using EnumerableSet for EnumerableSet.AddressSet;
    constructor(
        address factory_,
        address tokenAddress_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBaseTokenJoinAuto(
            factory_,
            tokenAddress_,
            joinTokenAddress_,
            waitingBlocks_
        )
    {}

    // 实现 ILOVE20Extension 的抽象方法
    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    function joinedValue() external view override returns (uint256) {
        return totalJoinedAmount;
    }

    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        (, uint256 amount, , ) = this.joinInfo(account);
        return amount;
    }

    // 实现抽象方法：分数等于加入金额
    function calculateScores()
        public
        view
        override
        returns (uint256 total, uint256[] memory scores)
    {
        uint256 count = _center.accountsCount(tokenAddress, actionId);
        scores = new uint256[](count);
        total = 0;

        for (uint256 i = 0; i < count; i++) {
            address account = _center.accountsAtIndex(
                tokenAddress,
                actionId,
                i
            );
            (, uint256 amount, , ) = this.joinInfo(account);
            scores[i] = amount;
            total += amount;
        }
    }

    function calculateScore(
        address account
    ) public view override returns (uint256 total, uint256 score) {
        (total, ) = calculateScores();
        (, uint256 amount, , ) = this.joinInfo(account);
        score = amount;
    }
}

/**
 * @title LOVE20ExtensionBaseTokenJoinAutoTest
 * @notice LOVE20ExtensionBaseTokenJoinAuto 的测试套件
 * @dev 测试自动分数计算和基于分数的奖励分配
 */
contract LOVE20ExtensionBaseTokenJoinAutoTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockLOVE20ExtensionBaseTokenJoinAuto public extension;

    function setUp() public {
        setUpBase();

        // 部署 mock factory
        mockFactory = new MockExtensionFactory(address(center));

        // 部署扩展
        extension = new MockLOVE20ExtensionBaseTokenJoinAuto(
            address(mockFactory),
            address(token),
            address(joinToken),
            WAITING_BLOCKS
        );

        // 将扩展注册到 factory
        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension), address(token));

        // 初始化扩展
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);

        // 为用户设置代币
        setupUser(user1, 1000e18, address(extension));
        setupUser(user2, 2000e18, address(extension));
        setupUser(user3, 3000e18, address(extension));

        // 给扩展发放代币用于奖励
        token.mint(address(extension), 10000e18);

        // 设置初始轮次为 0
        verify.setCurrentRound(0);
    }

    // ============================================
    // 分数计算测试
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

    function test_CalculateScore_EmptyAccounts() public view {
        (uint256 total, uint256 score) = extension.calculateScore(user1);
        assertEq(total, 0);
        assertEq(score, 0);
    }

    // ============================================
    // 分数快照测试（_prepareVerifyResultIfNeeded）
    // ============================================

    function test_PrepareVerifyResult_OnJoin() public {
        uint256 currentRound = verify.currentRound();

        // 第一次 join 会触发快照（但快照的是 join 之前的状态，即空状态）
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 在同一轮次，第二次操作不会再次快照
        // 所以分数仍然是第一次快照时的值（此时user1已在列表中）

        // 进入下一轮
        verify.setCurrentRound(currentRound + 1);

        // 在新轮次进行操作，会生成新的快照
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // 验证新轮次的分数已保存（包含 user1 但不包含 user2）
        uint256 round1 = currentRound + 1;
        assertEq(extension.totalScore(round1), 100e18);

        // 验证账户快照
        address[] memory accountsSnapshot = extension.accountsByRound(round1);
        assertEq(accountsSnapshot.length, 1);
        assertEq(accountsSnapshot[0], user1);
    }

    function test_PrepareVerifyResult_OnlyOncePerRound() public {
        uint256 currentRound = verify.currentRound();

        // 第一次 join
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        uint256 score1 = extension.totalScore(currentRound);

        // 第二次 join（同一轮次）
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // 分数不应该更新（已经生成过了）
        assertEq(extension.totalScore(currentRound), score1);
    }

    function test_PrepareVerifyResult_NewRound() public {
        // 第一轮
        uint256 round1 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 第一轮快照是空的（在user1加入之前）
        assertEq(extension.totalScore(round1), 0);

        // 进入下一轮
        verify.setCurrentRound(round1 + 1);

        // 新轮次的 join 会触发新快照（此时有user1）
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // 新轮次的快照包含user1但不包含user2
        uint256 round2 = verify.currentRound();
        assertEq(extension.totalScore(round2), 100e18);
    }

    // ============================================
    // 分数查询测试
    // ============================================

    function test_TotalScore_BeforeGeneration() public view {
        uint256 currentRound = verify.currentRound();
        assertEq(extension.totalScore(currentRound), 0);
    }

    function test_AccountsByRound_BeforeGeneration() public view {
        uint256 currentRound = verify.currentRound();
        address[] memory accounts = extension.accountsByRound(currentRound);
        assertEq(accounts.length, 0);
    }

    function test_AccountsByRoundCount() public {
        // 第一轮：user1 加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 第一轮快照是空的
        assertEq(extension.accountsByRoundCount(round0), 0);

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 第二轮的操作会生成快照（包含user1）
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        uint256 round1 = verify.currentRound();
        assertEq(extension.accountsByRoundCount(round1), 1);
    }

    function test_AccountsByRoundAtIndex() public {
        // 第一轮：user1 加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 第二轮的操作会生成快照（包含user1）
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        uint256 round1 = verify.currentRound();
        assertEq(extension.accountsByRoundAtIndex(round1, 0), user1);
    }

    function test_Scores() public {
        // 第一轮：user1 加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 第二轮的操作会生成快照（包含user1）
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        uint256 round1 = verify.currentRound();
        uint256[] memory scores = extension.scores(round1);
        assertEq(scores.length, 1);
        assertEq(scores[0], 100e18);
    }

    function test_ScoresCount() public {
        // 第一轮：user1 加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 第二轮的操作会生成快照
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        uint256 round1 = verify.currentRound();
        assertEq(extension.scoresCount(round1), 1);
    }

    function test_ScoresAtIndex() public {
        // 第一轮：user1 加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 第二轮的操作会生成快照
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        uint256 round1 = verify.currentRound();
        assertEq(extension.scoresAtIndex(round1, 0), 100e18);
    }

    function test_ScoreByAccount() public {
        // 第一轮：user1 加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 第二轮的操作会生成快照
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        uint256 round1 = verify.currentRound();
        assertEq(extension.scoreByAccount(round1, user1), 100e18);
        assertEq(extension.scoreByAccount(round1, user2), 0);
    }

    // ============================================
    // 奖励计算测试
    // ============================================

    function test_RewardByAccount_NotFinished() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        uint256 currentRound = verify.currentRound();

        // 当前轮次还未完成
        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            currentRound,
            user1
        );
        assertEq(reward, 0);
        assertFalse(isMinted);
    }

    function test_RewardByAccount_Proportional() public {
        // 第一轮：用户加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // 进入第二轮（这会为 round1 生成快照用于奖励计算）
        verify.setCurrentRound(round0 + 1);

        // 触发第二轮的快照生成
        vm.prank(user3);
        extension.join(1e18, new string[](0));

        // 进入第三轮（第二轮结束）
        verify.setCurrentRound(round0 + 2);

        // 设置第二轮的奖励（注意：快照包含user1和user2）
        uint256 totalReward = 3000e18;
        mint.setActionReward(
            address(token),
            round0 + 1,
            ACTION_ID,
            totalReward
        );

        // User1 应得 1000e18 (100/300 * 3000)
        (uint256 reward1, bool isMinted1) = extension.rewardByAccount(
            round0 + 1,
            user1
        );
        assertEq(reward1, 1000e18);
        assertFalse(isMinted1);

        // User2 应得 2000e18 (200/300 * 3000)
        (uint256 reward2, bool isMinted2) = extension.rewardByAccount(
            round0 + 1,
            user2
        );
        assertEq(reward2, 2000e18);
        assertFalse(isMinted2);
    }

    function test_RewardByAccount_ZeroTotalScore() public {
        uint256 round = verify.currentRound();

        // 没有人加入，直接进入下一轮
        verify.setCurrentRound(round + 1);

        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            round,
            user1
        );
        assertEq(reward, 0);
        assertFalse(isMinted);
    }

    function test_RewardByAccount_AlreadyClaimed() public {
        // 第一轮：用户加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 触发快照
        vm.prank(user2);
        extension.join(1e18, new string[](0));

        // 进入第三轮
        verify.setCurrentRound(round0 + 2);

        // 设置奖励
        mint.setActionReward(address(token), round0 + 1, ACTION_ID, 1000e18);

        // 领取奖励
        vm.prank(user1);
        extension.claimReward(round0 + 1);

        // 再次查询应该返回已领取
        (uint256 reward, bool isMinted) = extension.rewardByAccount(
            round0 + 1,
            user1
        );
        assertEq(reward, 1000e18);
        assertTrue(isMinted);
    }

    // ============================================
    // 领取奖励测试
    // ============================================

    function test_ClaimReward_Success() public {
        // 第一轮：用户加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 触发快照
        vm.prank(user2);
        extension.join(1e18, new string[](0));

        // 进入第三轮（奖励轮次必须完成）
        verify.setCurrentRound(round0 + 2);

        // 设置第二轮的奖励
        uint256 totalReward = 1000e18;
        mint.setActionReward(
            address(token),
            round0 + 1,
            ACTION_ID,
            totalReward
        );

        uint256 balanceBefore = token.balanceOf(user1);

        // 领取第二轮的奖励
        vm.prank(user1);
        uint256 claimed = extension.claimReward(round0 + 1);

        assertEq(claimed, totalReward);
        assertEq(token.balanceOf(user1), balanceBefore + totalReward);
    }

    function test_ClaimReward_RevertIfNotFinished() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        uint256 round = verify.currentRound();

        // 尝试领取当前轮次的奖励
        vm.prank(user1);
        vm.expectRevert(IExtensionReward.RoundNotFinished.selector);
        extension.claimReward(round);
    }

    function test_ClaimReward_RevertIfAlreadyClaimed() public {
        // 第一轮：用户加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 触发快照
        vm.prank(user2);
        extension.join(1e18, new string[](0));

        // 进入第三轮
        verify.setCurrentRound(round0 + 2);

        // 设置奖励
        mint.setActionReward(address(token), round0 + 1, ACTION_ID, 1000e18);

        // 第一次领取
        vm.prank(user1);
        extension.claimReward(round0 + 1);

        // 第二次领取应该失败
        vm.prank(user1);
        vm.expectRevert(IExtensionReward.AlreadyClaimed.selector);
        extension.claimReward(round0 + 1);
    }

    function test_ClaimReward_MultipleUsers() public {
        // 第一轮：用户加入
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 触发快照
        vm.prank(user3);
        extension.join(1e18, new string[](0));

        // 进入第三轮
        verify.setCurrentRound(round0 + 2);

        // 设置奖励
        uint256 totalReward = 3000e18;
        mint.setActionReward(
            address(token),
            round0 + 1,
            ACTION_ID,
            totalReward
        );

        // User1 领取
        vm.prank(user1);
        uint256 claimed1 = extension.claimReward(round0 + 1);
        assertEq(claimed1, 1000e18);

        // User2 领取
        vm.prank(user2);
        uint256 claimed2 = extension.claimReward(round0 + 1);
        assertEq(claimed2, 2000e18);
    }

    function test_ClaimReward_PrepareVerifyResultIfNeeded() public {
        // 用户加入但不触发快照
        uint256 currentRound = verify.currentRound();

        // 模拟已经进入下一轮但没有触发过快照
        verify.setCurrentRound(currentRound + 1);

        // 在新轮次加入
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // claimReward 应该触发快照生成
        uint256 round = currentRound + 1;
        verify.setCurrentRound(round + 1);

        mint.setActionReward(address(token), round, ACTION_ID, 1000e18);

        vm.prank(user1);
        extension.claimReward(round);
    }

    // ============================================
    // Exit 时的快照测试
    // ============================================

    function test_Exit_TriggersVerifyResult() public {
        uint256 round0 = verify.currentRound();

        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入下一轮
        verify.setCurrentRound(round0 + 1);

        advanceBlocks(WAITING_BLOCKS);

        // exit 会触发新轮次的快照
        vm.prank(user1);
        extension.exit();

        // 验证新轮次的快照已生成（包含user1）
        uint256 round1 = verify.currentRound();
        assertEq(extension.totalScore(round1), 100e18);
    }

    // ============================================
    // 多轮次测试
    // ============================================

    function test_MultipleRounds_IndependentScores() public {
        // 第一轮
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 第二轮有不同的参与者
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        uint256 round1 = verify.currentRound();
        // round1的快照包含user1（100e18）
        assertEq(extension.totalScore(round1), 100e18);

        // 验证两轮的分数独立
        assertEq(extension.scoreByAccount(round0, user1), 0); // round0快照时user1还未加入
        assertEq(extension.scoreByAccount(round1, user1), 100e18); // round1快照包含user1
        assertEq(extension.scoreByAccount(round1, user2), 0); // round1快照不包含user2（在快照后加入）
    }

    function test_MultipleRounds_ClaimRewards() public {
        // 第一轮
        uint256 round0 = verify.currentRound();
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 触发round1快照（包含user1）
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // 进入第三轮
        uint256 round2 = round0 + 2;
        verify.setCurrentRound(round2);

        // 触发round2快照（包含user1和user2）
        vm.prank(user3);
        extension.join(1e18, new string[](0));

        // 进入第四轮（让round2完成）
        verify.setCurrentRound(round2 + 1);

        mint.setActionReward(address(token), round0 + 1, ACTION_ID, 1000e18);
        mint.setActionReward(address(token), round2, ACTION_ID, 3000e18);

        // 领取第一轮奖励（round1的快照只有user1）
        vm.prank(user1);
        uint256 reward1 = extension.claimReward(round0 + 1);
        assertEq(reward1, 1000e18);

        // 领取第二轮奖励（round2快照有user1和user2）
        vm.prank(user1);
        uint256 reward2a = extension.claimReward(round2);
        assertEq(reward2a, 1000e18); // 100/300 * 3000

        vm.prank(user2);
        uint256 reward2b = extension.claimReward(round2);
        assertEq(reward2b, 2000e18); // 200/300 * 3000
    }

    // ============================================
    // 集成测试
    // ============================================

    function test_Integration_CompleteFlow() public {
        uint256 round0 = verify.currentRound();

        // 三个用户加入
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        // round0的快照是空的（在第一个用户加入之前）
        assertEq(extension.totalScore(round0), 0);

        // 进入下一轮
        verify.setCurrentRound(round0 + 1);

        // 等待足够的区块以便user1可以退出
        advanceBlocks(WAITING_BLOCKS);

        // 触发新轮次快照（包含所有3个用户）
        vm.prank(user1);
        extension.exit();

        uint256 round1 = verify.currentRound();

        // 验证分数快照
        assertEq(extension.totalScore(round1), 600e18);
        assertEq(extension.scoreByAccount(round1, user1), 100e18);
        assertEq(extension.scoreByAccount(round1, user2), 200e18);
        assertEq(extension.scoreByAccount(round1, user3), 300e18);

        // 进入下一轮（让round1完成）
        verify.setCurrentRound(round1 + 1);

        // 设置奖励
        uint256 totalReward = 6000e18;
        mint.setActionReward(address(token), round1, ACTION_ID, totalReward);

        // 所有用户领取奖励
        vm.prank(user1);
        uint256 reward1 = extension.claimReward(round1);
        assertEq(reward1, 1000e18); // 100/600 * 6000

        vm.prank(user2);
        uint256 reward2 = extension.claimReward(round1);
        assertEq(reward2, 2000e18); // 200/600 * 6000

        vm.prank(user3);
        uint256 reward3 = extension.claimReward(round1);
        assertEq(reward3, 3000e18); // 300/600 * 6000

        // 验证总奖励
        assertEq(reward1 + reward2 + reward3, totalReward);
    }
}
