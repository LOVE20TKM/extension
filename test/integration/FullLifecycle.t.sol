// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "../utils/BaseExtensionTest.sol";
import {ExampleTokenJoin} from "../../src/examples/ExampleTokenJoin.sol";
import {
    ExampleFactoryTokenJoin
} from "../../src/examples/ExampleFactoryTokenJoin.sol";
import {
    ExampleTokenJoinAuto
} from "../../src/examples/ExampleTokenJoinAuto.sol";
import {
    ExampleFactoryTokenJoinAuto
} from "../../src/examples/ExampleFactoryTokenJoinAuto.sol";
import {
    LOVE20ExtensionFactoryBase
} from "../../src/LOVE20ExtensionFactoryBase.sol";

/**
 * @title FullLifecycleIntegrationTest
 * @notice 完整生命周期的集成测试
 * @dev 测试从 Factory 创建到奖励领取的完整流程
 */
contract FullLifecycleIntegrationTest is BaseExtensionTest {
    ExampleFactoryTokenJoin public factoryTokenJoin;
    ExampleFactoryTokenJoinAuto public factoryTokenJoinAuto;

    ExampleTokenJoin public extensionTokenJoin;
    ExampleTokenJoinAuto public extensionTokenJoinAuto;

    uint256 constant ACTION_ID_1 = 1;
    uint256 constant ACTION_ID_2 = 2;

    function setUp() public {
        setUpBase();

        // 部署两种类型的 factory
        factoryTokenJoin = new ExampleFactoryTokenJoin(address(center));
        factoryTokenJoinAuto = new ExampleFactoryTokenJoinAuto(address(center));

        // 注册 factories
        registerFactory(address(token), address(factoryTokenJoin));
        registerFactory(address(token), address(factoryTokenJoinAuto));

        // 创建扩展
        extensionTokenJoin = ExampleTokenJoin(
            factoryTokenJoin.createExtension(
                address(token),
                address(joinToken),
                WAITING_BLOCKS
            )
        );

        extensionTokenJoinAuto = ExampleTokenJoinAuto(
            factoryTokenJoinAuto.createExtension(
                address(token),
                address(joinToken),
                WAITING_BLOCKS
            )
        );

        // 设置行动信息并为扩展铸造代币 (扩展会在首次 join 时自动初始化)
        submit.setActionInfo(
            address(token),
            ACTION_ID_1,
            address(extensionTokenJoin)
        );
        token.mint(address(extensionTokenJoin), 1e18);
        vote.setVotedActionIds(
            address(token),
            join.currentRound(),
            ACTION_ID_1
        );

        submit.setActionInfo(
            address(token),
            ACTION_ID_2,
            address(extensionTokenJoinAuto)
        );
        token.mint(address(extensionTokenJoinAuto), 1e18);
        vote.setVotedActionIds(
            address(token),
            join.currentRound(),
            ACTION_ID_2
        );

        // 为用户设置代币
        setupUser(user1, 1000e18, address(extensionTokenJoin));
        setupUser(user1, 1000e18, address(extensionTokenJoinAuto));
        setupUser(user2, 2000e18, address(extensionTokenJoin));
        setupUser(user2, 2000e18, address(extensionTokenJoinAuto));
        setupUser(user3, 3000e18, address(extensionTokenJoin));
        setupUser(user3, 3000e18, address(extensionTokenJoinAuto));

        // 触发扩展自动初始化 (使用测试合约本身触发，然后退出以保持初始状态干净)
        joinToken.mint(address(this), 200e18);
        joinToken.approve(address(extensionTokenJoin), type(uint256).max);
        joinToken.approve(address(extensionTokenJoinAuto), type(uint256).max);
        extensionTokenJoin.join(100e18, new string[](0));
        extensionTokenJoinAuto.join(100e18, new string[](0));

        // 等待足够的区块后退出，保持初始状态干净
        vm.roll(block.number + WAITING_BLOCKS + 1);
        extensionTokenJoin.exit();
        extensionTokenJoinAuto.exit();

        // 给扩展发放奖励代币
        token.mint(address(extensionTokenJoin), 10000e18);
        token.mint(address(extensionTokenJoinAuto), 10000e18);
    }

    // ============================================
    // Factory 到 Extension 的完整流程
    // ============================================

    function test_FullLifecycle_FactoryToExtension() public view {
        // 验证 factory 注册
        assertTrue(
            center.existsFactory(address(token), address(factoryTokenJoin))
        );
        assertTrue(
            center.existsFactory(address(token), address(factoryTokenJoinAuto))
        );

        // 验证扩展创建
        assertTrue(factoryTokenJoin.exists(address(extensionTokenJoin)));
        assertTrue(
            factoryTokenJoinAuto.exists(address(extensionTokenJoinAuto))
        );

        // 验证扩展初始化
        assertTrue(extensionTokenJoin.initialized());
        assertTrue(extensionTokenJoinAuto.initialized());

        // 验证扩展在 center 中注册
        assertEq(
            center.extension(address(token), ACTION_ID_1),
            address(extensionTokenJoin)
        );
        assertEq(
            center.extension(address(token), ACTION_ID_2),
            address(extensionTokenJoinAuto)
        );
    }

    // ============================================
    // 多扩展共存测试
    // ============================================

    function test_MultipleExtensions_CoExist() public {
        // 用户可以同时参与两个扩展
        vm.prank(user1);
        extensionTokenJoin.join(100e18, new string[](0));

        vm.prank(user1);
        extensionTokenJoinAuto.join(150e18, new string[](0));

        // 验证两个扩展的状态独立
        assertEq(extensionTokenJoin.totalJoinedAmount(), 100e18);
        assertEq(extensionTokenJoinAuto.totalJoinedAmount(), 150e18);

        // 验证 center 中的记录
        assertTrue(center.isAccountJoined(address(token), ACTION_ID_1, user1));
        assertTrue(center.isAccountJoined(address(token), ACTION_ID_2, user1));

        // 验证用户参与的 actionIds
        uint256[] memory actionIds = center.actionIdsByAccount(
            address(token),
            user1
        );
        assertEq(actionIds.length, 2);
    }

    // ============================================
    // 跨轮次奖励测试
    // ============================================

    function test_MultipleRounds_RewardClaim() public {
        // 第一轮：user1 和 user2 参与
        uint256 round0 = verify.currentRound();

        vm.prank(user1);
        extensionTokenJoinAuto.join(100e18, new string[](0));

        vm.prank(user2);
        extensionTokenJoinAuto.join(200e18, new string[](0));

        // 进入第二轮（触发快照）
        verify.setCurrentRound(round0 + 1);

        // 触发快照（包含user1和user2）
        vm.prank(user3);
        extensionTokenJoinAuto.join(1e18, new string[](0));

        // 进入第三轮（第二轮结束）
        uint256 round2 = round0 + 2;
        verify.setCurrentRound(round2);

        // 设置第二轮奖励
        mint.setActionReward(address(token), round0 + 1, ACTION_ID_2, 3000e18);

        // 领取第二轮奖励
        vm.prank(user1);
        uint256 reward1_1 = extensionTokenJoinAuto.claimReward(round0 + 1);
        assertEq(reward1_1, 1000e18); // 100/300 * 3000

        vm.prank(user2);
        uint256 reward1_2 = extensionTokenJoinAuto.claimReward(round0 + 1);
        assertEq(reward1_2, 2000e18); // 200/300 * 3000
    }

    // ============================================
    // 用户在扩展间迁移测试
    // ============================================

    function test_UserMigration_BetweenExtensions() public {
        // User1 先参与 extensionTokenJoin
        vm.prank(user1);
        extensionTokenJoin.join(100e18, new string[](0));

        assertEq(extensionTokenJoin.accountsCount(), 1);
        assertEq(extensionTokenJoinAuto.accountsCount(), 0);

        // User1 退出 extensionTokenJoin
        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extensionTokenJoin.exit();

        assertEq(extensionTokenJoin.accountsCount(), 0);

        // User1 加入 extensionTokenJoinAuto
        vm.prank(user1);
        extensionTokenJoinAuto.join(150e18, new string[](0));

        assertEq(extensionTokenJoinAuto.accountsCount(), 1);

        // 验证 center 中的记录更新
        assertFalse(center.isAccountJoined(address(token), ACTION_ID_1, user1));
        assertTrue(center.isAccountJoined(address(token), ACTION_ID_2, user1));
    }

    // ============================================
    // 复杂多用户多动作场景
    // ============================================

    function test_ComplexScenario_MultipleUsersAndActions() public {
        uint256 round0 = verify.currentRound();

        // 所有用户参与两个扩展
        vm.prank(user1);
        extensionTokenJoin.join(100e18, new string[](0));
        vm.prank(user1);
        extensionTokenJoinAuto.join(100e18, new string[](0));

        vm.prank(user2);
        extensionTokenJoin.join(200e18, new string[](0));
        vm.prank(user2);
        extensionTokenJoinAuto.join(200e18, new string[](0));

        vm.prank(user3);
        extensionTokenJoin.join(300e18, new string[](0));
        vm.prank(user3);
        extensionTokenJoinAuto.join(300e18, new string[](0));

        // 验证两个扩展的状态
        assertEq(extensionTokenJoin.totalJoinedAmount(), 600e18);
        assertEq(extensionTokenJoinAuto.totalJoinedAmount(), 600e18);

        assertEq(extensionTokenJoin.accountsCount(), 3);
        assertEq(extensionTokenJoinAuto.accountsCount(), 3);

        // 进入下一轮（触发快照）
        verify.setCurrentRound(round0 + 1);

        // 创建一个新用户来触发快照（不使用已经加入的用户）
        address user4 = address(0x4);
        setupUser(user4, 1000e18, address(extensionTokenJoinAuto));
        vm.prank(user4);
        extensionTokenJoinAuto.join(1e18, new string[](0));

        // 进入第三轮（第二轮结束）
        verify.setCurrentRound(round0 + 2);

        // 设置第二轮奖励
        mint.setActionReward(address(token), round0 + 1, ACTION_ID_1, 6000e18);
        mint.setActionReward(address(token), round0 + 1, ACTION_ID_2, 6000e18);

        // 所有用户领取两个扩展的奖励
        uint256 totalClaimed1 = 0;
        uint256 totalClaimed2 = 0;

        vm.prank(user1);
        totalClaimed1 += extensionTokenJoin.claimReward(round0 + 1);
        vm.prank(user1);
        totalClaimed2 += extensionTokenJoinAuto.claimReward(round0 + 1);

        vm.prank(user2);
        totalClaimed1 += extensionTokenJoin.claimReward(round0 + 1);
        vm.prank(user2);
        totalClaimed2 += extensionTokenJoinAuto.claimReward(round0 + 1);

        vm.prank(user3);
        totalClaimed1 += extensionTokenJoin.claimReward(round0 + 1);
        vm.prank(user3);
        totalClaimed2 += extensionTokenJoinAuto.claimReward(round0 + 1);

        // 验证总奖励
        assertEq(totalClaimed1, 6000e18);
        assertEq(totalClaimed2, 6000e18);
    }

    // ============================================
    // 扩展状态一致性测试
    // ============================================

    function test_StateConsistency_AcrossRounds() public {
        // 第一轮
        uint256 round0 = verify.currentRound();

        vm.prank(user1);
        extensionTokenJoinAuto.join(100e18, new string[](0));

        // 第一轮快照是空的（在user1加入之前）
        assertEq(extensionTokenJoinAuto.totalScore(round0), 0);

        // 进入第二轮
        verify.setCurrentRound(round0 + 1);

        // 添加更多用户（触发快照）
        vm.prank(user2);
        extensionTokenJoinAuto.join(200e18, new string[](0));

        uint256 round1 = verify.currentRound();
        // round1快照包含user1（100e18）
        assertEq(extensionTokenJoinAuto.totalScore(round1), 100e18);

        // 验证账户快照独立
        address[] memory accounts0 = extensionTokenJoinAuto.accountsByRound(
            round0
        );
        address[] memory accounts1 = extensionTokenJoinAuto.accountsByRound(
            round1
        );

        assertEq(accounts0.length, 0);
        assertEq(accounts1.length, 1);
    }

    // ============================================
    // Factory 功能测试
    // ============================================

    function test_Factory_Extensions() public view {
        address[] memory extensions1 = factoryTokenJoin.extensions();
        address[] memory extensions2 = factoryTokenJoinAuto.extensions();

        assertEq(extensions1.length, 1);
        assertEq(extensions2.length, 1);

        assertEq(extensions1[0], address(extensionTokenJoin));
        assertEq(extensions2[0], address(extensionTokenJoinAuto));
    }

    function test_Factory_CreateMultipleExtensions() public {
        // 创建第二个 TokenJoin 扩展
        ExampleTokenJoin extension2 = ExampleTokenJoin(
            factoryTokenJoin.createExtension(
                address(token),
                address(joinToken),
                WAITING_BLOCKS
            )
        );

        assertTrue(factoryTokenJoin.exists(address(extension2)));
        assertEq(factoryTokenJoin.extensionsCount(), 2);
    }

    // ============================================
    // End-to-End 完整流程测试
    // ============================================

    function test_EndToEnd_CompleteUserJourney() public {
        uint256 round0 = verify.currentRound();

        // 阶段 1: 用户加入
        vm.prank(user1);
        extensionTokenJoinAuto.join(100e18, new string[](0));

        assertEq(extensionTokenJoinAuto.accountsCount(), 1);
        assertTrue(center.isAccountJoined(address(token), ACTION_ID_2, user1));

        // 阶段 2: 更多用户加入
        vm.prank(user2);
        extensionTokenJoinAuto.join(200e18, new string[](0));

        assertEq(extensionTokenJoinAuto.accountsCount(), 2);

        // 阶段 3: 进入下一轮（触发快照）
        verify.setCurrentRound(round0 + 1);

        // 触发快照
        vm.prank(user3);
        extensionTokenJoinAuto.join(1e18, new string[](0));

        // 阶段 4: 轮次结束
        verify.setCurrentRound(round0 + 2);

        // 阶段 5: 奖励生成
        mint.setActionReward(address(token), round0 + 1, ACTION_ID_2, 3000e18);

        // 阶段 6: 用户领取奖励
        uint256 balanceBefore1 = token.balanceOf(user1);
        vm.prank(user1);
        uint256 claimed1 = extensionTokenJoinAuto.claimReward(round0 + 1);

        assertEq(claimed1, 1000e18);
        assertEq(token.balanceOf(user1), balanceBefore1 + 1000e18);

        // 阶段 7: 用户退出
        advanceBlocks(WAITING_BLOCKS);

        uint256 joinTokenBefore = joinToken.balanceOf(user1);
        vm.prank(user1);
        extensionTokenJoinAuto.exit();

        assertEq(joinToken.balanceOf(user1), joinTokenBefore + 100e18);
        assertEq(extensionTokenJoinAuto.accountsCount(), 2);
        assertFalse(center.isAccountJoined(address(token), ACTION_ID_2, user1));

        // 阶段 8: 用户重新加入
        vm.prank(user1);
        extensionTokenJoinAuto.join(150e18, new string[](0));

        assertEq(extensionTokenJoinAuto.accountsCount(), 3);
        assertTrue(center.isAccountJoined(address(token), ACTION_ID_2, user1));
    }
}
