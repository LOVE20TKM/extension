// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {
    LOVE20ExtensionBaseTokenJoin
} from "../src/LOVE20ExtensionBaseTokenJoin.sol";
import {ITokenJoin} from "../src/interface/base/ITokenJoin.sol";
import {IExtensionExit} from "../src/interface/base/IExtensionExit.sol";
import {IExtensionReward} from "../src/interface/base/IExtensionReward.sol";
import {ExtensionReward} from "../src/base/ExtensionReward.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";

/**
 * @title MockLOVE20ExtensionBaseTokenJoin
 * @notice LOVE20ExtensionBaseTokenJoin 的具体实现，用于测试
 */
contract MockLOVE20ExtensionBaseTokenJoin is LOVE20ExtensionBaseTokenJoin {
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    )
        LOVE20ExtensionBaseTokenJoin(
            factory_,
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
        (uint256 amount, , ) = this.joinInfo(account);
        return amount;
    }

    // 实现 IExtensionReward 的抽象方法
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
 * @title LOVE20ExtensionBaseTokenJoinTest
 * @notice LOVE20ExtensionBaseTokenJoin 的测试套件
 * @dev 测试基于代币的 join/exit 功能
 */
contract LOVE20ExtensionBaseTokenJoinTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockLOVE20ExtensionBaseTokenJoin public extension;

    // 事件定义
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

        // 部署 mock factory
        mockFactory = new MockExtensionFactory(address(center));

        // 部署扩展
        extension = new MockLOVE20ExtensionBaseTokenJoin(
            address(mockFactory),
            address(joinToken),
            WAITING_BLOCKS
        );

        // 注册 factory
        registerFactory(address(token), address(mockFactory));

        // 将扩展注册到 factory
        mockFactory.registerExtension(address(extension));

        // 初始化扩展
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );

        // 为用户设置代币
        setupUser(user1, 1000e18, address(extension));
        setupUser(user2, 2000e18, address(extension));
        setupUser(user3, 3000e18, address(extension));
    }

    // ============================================
    // 构造函数和不可变变量测试
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

    // ============================================
    // Join 功能测试
    // ============================================

    function test_Join_Success() public {
        uint256 amount = 100e18;
        uint256 blockBefore = block.number;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        // 验证 joinInfo
        (
            uint256 joinedAmount,
            uint256 joinedBlock,
            uint256 exitableBlock
        ) = extension.joinInfo(user1);
        assertEq(joinedAmount, amount);
        assertEq(joinedBlock, blockBefore);
        assertEq(exitableBlock, blockBefore + WAITING_BLOCKS);

        // 验证总金额
        assertEq(extension.totalJoinedAmount(), amount);

        // 验证账户计数
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

    function test_Join_RevertIfAlreadyJoined() public {
        vm.startPrank(user1);
        extension.join(100e18, new string[](0));

        vm.expectRevert(ITokenJoin.AlreadyJoined.selector);
        extension.join(50e18, new string[](0));
        vm.stopPrank();
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
    // Exit 功能测试
    // ============================================

    function test_Exit_Success() public {
        uint256 amount = 100e18;

        vm.prank(user1);
        extension.join(amount, new string[](0));

        // 前进区块
        advanceBlocks(WAITING_BLOCKS);

        uint256 balanceBefore = joinToken.balanceOf(user1);

        vm.prank(user1);
        extension.exit();

        assertEq(joinToken.balanceOf(user1), balanceBefore + amount);
        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);

        // 验证 joinInfo 被清除
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

        // 不足的等待区块
        advanceBlocks(WAITING_BLOCKS - 1);

        vm.prank(user1);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();
    }

    function test_Exit_ExactlyAtWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 正好等待区块数
        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        (uint256 amount, , ) = extension.joinInfo(user1);
        assertEq(amount, 0);
    }

    function test_Exit_MultipleUsersIndependently() public {
        // User1 在区块 0 加入
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        // 前进 50 区块
        advanceBlocks(50);

        // User2 在区块 50 加入
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        // 再前进 50 区块 (user1 总共 100 区块)
        advanceBlocks(50);

        // User1 可以退出
        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 200e18);
        assertEq(extension.accountsCount(), 1);

        // User2 还不能退出（只过了 50 区块）
        vm.prank(user2);
        vm.expectRevert(ITokenJoin.NotEnoughWaitingBlocks.selector);
        extension.exit();

        // 再前进 50 区块
        advanceBlocks(50);

        // 现在 user2 可以退出
        vm.prank(user2);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);
    }

    // ============================================
    // CanExit 测试
    // ============================================

    function test_CanExit_False_NotJoined() public view {
        assertFalse(extension.canExit(user1));
    }

    function test_CanExit_False_NotEnoughBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS - 1);
        assertFalse(extension.canExit(user1));
    }

    function test_CanExit_True_AfterWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);
        assertTrue(extension.canExit(user1));
    }

    function test_CanExit_True_WellAfterWaitingBlocks() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS + 1000);
        assertTrue(extension.canExit(user1));
    }

    // ============================================
    // JoinInfo 测试
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
    // JoinedValue 测试
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
    // 账户列表测试
    // ============================================

    function test_Accounts_EmptyAtStart() public view {
        address[] memory accounts = extension.accounts();
        assertEq(accounts.length, 0);
        assertEq(extension.accountsCount(), 0);
    }

    function test_Accounts_AfterJoin() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        address[] memory accounts = extension.accounts();
        assertEq(accounts.length, 1);
        assertEq(accounts[0], user1);
    }

    function test_Accounts_AfterExit() public {
        vm.prank(user1);
        extension.join(100e18, new string[](0));
        vm.prank(user2);
        extension.join(200e18, new string[](0));

        advanceBlocks(WAITING_BLOCKS);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.accountsCount(), 1);
        address[] memory accounts = extension.accounts();
        assertEq(accounts[0], user2);
    }

    // ============================================
    // 边缘情况测试
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
    // 集成测试
    // ============================================

    function test_Integration_FullLifecycle() public {
        // 多个用户在不同时间加入
        vm.prank(user1);
        extension.join(100e18, new string[](0));

        advanceBlocks(10);

        vm.prank(user2);
        extension.join(200e18, new string[](0));

        advanceBlocks(20);

        vm.prank(user3);
        extension.join(300e18, new string[](0));

        // 检查总额
        assertEq(extension.totalJoinedAmount(), 600e18);
        assertEq(extension.accountsCount(), 3);

        // 前进足够让 user1 退出
        advanceBlocks(70);

        vm.prank(user1);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 500e18);
        assertEq(extension.accountsCount(), 2);

        // 前进让 user2 退出
        advanceBlocks(20);

        vm.prank(user2);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 300e18);
        assertEq(extension.accountsCount(), 1);

        // 前进让 user3 退出
        advanceBlocks(10);

        vm.prank(user3);
        extension.exit();

        assertEq(extension.totalJoinedAmount(), 0);
        assertEq(extension.accountsCount(), 0);
    }

    // ============================================
    // 模糊测试
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
