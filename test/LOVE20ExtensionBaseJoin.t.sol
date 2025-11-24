// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {LOVE20ExtensionBaseJoin} from "../src/LOVE20ExtensionBaseJoin.sol";
import {IJoin} from "../src/interface/base/IJoin.sol";
import {IExtensionCore} from "../src/interface/base/IExtensionCore.sol";
import {IExtensionReward} from "../src/interface/base/IExtensionReward.sol";
import {ExtensionReward} from "../src/base/ExtensionReward.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockLOVE20ExtensionBaseJoin
 * @notice LOVE20ExtensionBaseJoin 的具体实现，用于测试
 */
contract MockLOVE20ExtensionBaseJoin is LOVE20ExtensionBaseJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address factory_) LOVE20ExtensionBaseJoin(factory_) {}

    // 实现 ILOVE20Extension 的抽象方法
    function isJoinedValueCalculated() external pure override returns (bool) {
        return true;
    }

    function joinedValue() external view override returns (uint256) {
        return _accounts.length();
    }

    function joinedValueByAccount(
        address account
    ) external view override returns (uint256) {
        // Check if account has joined
        return _accounts.contains(account) ? 1 : 0;
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
}

/**
 * @title LOVE20ExtensionBaseJoinTest
 * @notice LOVE20ExtensionBaseJoin 的测试套件
 * @dev 测试无需代币的 join/exit 功能
 */
contract LOVE20ExtensionBaseJoinTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockLOVE20ExtensionBaseJoin public extension;

    // 事件定义
    event Join(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId
    );
    event Exit(
        address indexed tokenAddress,
        address indexed account,
        uint256 indexed actionId
    );

    function setUp() public {
        setUpBase();

        // 部署 mock factory
        mockFactory = new MockExtensionFactory(address(center));

        // 部署扩展
        extension = new MockLOVE20ExtensionBaseJoin(address(mockFactory));

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
    }

    // ============================================
    // 构造函数测试
    // ============================================

    function test_Constructor_InheritsFromBase() public view {
        assertEq(extension.factory(), address(mockFactory));
        assertEq(extension.center(), address(center));
    }

    // ============================================
    // Join 功能测试
    // ============================================

    function test_Join_Success() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(verificationInfos);

        // 验证账户已添加
        assertEq(extension.accountsCount(), 1, "Should have 1 account");
        assertEq(
            extension.accountAtIndex(0),
            user1,
            "User1 should be first account"
        );

        // 验证 center 中的状态
        assertTrue(
            center.isAccountJoined(address(token), ACTION_ID, user1),
            "User1 should be marked as joined in center"
        );
    }

    function test_Join_EmitEvent() public {
        string[] memory verificationInfos = new string[](0);

        vm.expectEmit(true, true, true, true);
        emit Join(address(token), user1, ACTION_ID);

        vm.prank(user1);
        extension.join(verificationInfos);
    }

    function test_Join_MultipleUsers() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(verificationInfos);

        vm.prank(user2);
        extension.join(verificationInfos);

        vm.prank(user3);
        extension.join(verificationInfos);

        assertEq(extension.accountsCount(), 3, "Should have 3 accounts");

        address[] memory accounts = extension.accounts();
        assertEq(accounts[0], user1);
        assertEq(accounts[1], user2);
        assertEq(accounts[2], user3);
    }

    function test_Join_RevertIfAlreadyJoined() public {
        string[] memory verificationInfos = new string[](0);

        vm.startPrank(user1);
        extension.join(verificationInfos);

        // 尝试再次加入
        vm.expectRevert(IJoin.AlreadyJoined.selector);
        extension.join(verificationInfos);
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
        extension.join(verificationInfos);

        // 验证加入成功
        assertEq(extension.accountsCount(), 1);
    }

    // ============================================
    // Exit 功能测试
    // ============================================

    function test_Exit_Success() public {
        string[] memory verificationInfos = new string[](0);

        // 先加入
        vm.prank(user1);
        extension.join(verificationInfos);

        assertEq(extension.accountsCount(), 1);

        // 退出
        vm.prank(user1);
        extension.exit();

        assertEq(
            extension.accountsCount(),
            0,
            "Should have 0 accounts after exit"
        );
        assertFalse(
            center.isAccountJoined(address(token), ACTION_ID, user1),
            "User1 should not be marked as joined in center"
        );
    }

    function test_Exit_EmitEvent() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(verificationInfos);

        vm.expectEmit(true, true, true, true);
        emit Exit(address(token), user1, ACTION_ID);

        vm.prank(user1);
        extension.exit();
    }

    function test_Exit_RevertIfNotJoined() public {
        vm.prank(user1);
        vm.expectRevert(IJoin.NotJoined.selector);
        extension.exit();
    }

    function test_Exit_MultipleUsers() public {
        string[] memory verificationInfos = new string[](0);

        // 三个用户加入
        vm.prank(user1);
        extension.join(verificationInfos);
        vm.prank(user2);
        extension.join(verificationInfos);
        vm.prank(user3);
        extension.join(verificationInfos);

        assertEq(extension.accountsCount(), 3);

        // User2 退出
        vm.prank(user2);
        extension.exit();

        assertEq(extension.accountsCount(), 2, "Should have 2 accounts");

        // 验证 user2 不在列表中
        address[] memory accounts = extension.accounts();
        assertTrue(accounts[0] == user1 || accounts[0] == user3);
        assertTrue(accounts[1] == user1 || accounts[1] == user3);
        assertTrue(accounts[0] != accounts[1]);
    }

    // ============================================
    // JoinedValue 测试
    // ============================================

    function test_JoinedValue_EmptyAtStart() public view {
        assertEq(
            extension.joinedValue(),
            0,
            "Joined value should be 0 initially"
        );
    }

    function test_JoinedValue_AfterJoin() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(verificationInfos);

        assertEq(
            extension.joinedValue(),
            1,
            "Joined value should be 1 after one user joins"
        );
    }

    function test_JoinedValue_MultipleUsers() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(verificationInfos);
        vm.prank(user2);
        extension.join(verificationInfos);
        vm.prank(user3);
        extension.join(verificationInfos);

        assertEq(extension.joinedValue(), 3, "Joined value should be 3");
    }

    function test_JoinedValueByAccount_NotJoined() public view {
        assertEq(extension.joinedValueByAccount(user1), 0);
    }

    function test_JoinedValueByAccount_Joined() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(verificationInfos);

        assertEq(extension.joinedValueByAccount(user1), 1);
        assertEq(extension.joinedValueByAccount(user2), 0);
    }

    function test_IsJoinedValueCalculated() public view {
        assertTrue(extension.isJoinedValueCalculated());
    }

    // ============================================
    // 账户管理测试
    // ============================================

    function test_Accounts_EmptyInitially() public view {
        address[] memory accounts = extension.accounts();
        assertEq(accounts.length, 0);
        assertEq(extension.accountsCount(), 0);
    }

    function test_Accounts_AfterJoin() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(verificationInfos);

        address[] memory accounts = extension.accounts();
        assertEq(accounts.length, 1);
        assertEq(accounts[0], user1);
    }

    function test_AccountAtIndex() public {
        string[] memory verificationInfos = new string[](0);

        vm.prank(user1);
        extension.join(verificationInfos);
        vm.prank(user2);
        extension.join(verificationInfos);

        assertEq(extension.accountAtIndex(0), user1);
        assertEq(extension.accountAtIndex(1), user2);
    }

    // ============================================
    // 验证信息测试
    // ============================================

    function test_UpdateVerificationInfo() public {
        string[] memory verificationKeys = new string[](1);
        verificationKeys[0] = "key1";
        submit.setVerificationKeys(address(token), ACTION_ID, verificationKeys);

        string[] memory verificationInfos = new string[](1);
        verificationInfos[0] = "updated_info";

        // 先加入
        vm.prank(user1);
        extension.join(new string[](0));

        // 更新验证信息
        vm.prank(user1);
        extension.updateVerificationInfo(verificationInfos);

        // 验证仍然加入
        assertEq(extension.accountsCount(), 1);
    }

    // ============================================
    // 与 Center 集成测试
    // ============================================

    function test_Center_Integration_AddAccount() public {
        string[] memory verificationInfos = new string[](0);

        // 加入前
        assertFalse(center.isAccountJoined(address(token), ACTION_ID, user1));

        // 加入
        vm.prank(user1);
        extension.join(verificationInfos);

        // 加入后
        assertTrue(center.isAccountJoined(address(token), ACTION_ID, user1));

        uint256[] memory actionIds = center.actionIdsByAccount(
            address(token),
            user1
        );
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], ACTION_ID);
    }

    function test_Center_Integration_RemoveAccount() public {
        string[] memory verificationInfos = new string[](0);

        // 加入
        vm.prank(user1);
        extension.join(verificationInfos);

        assertTrue(center.isAccountJoined(address(token), ACTION_ID, user1));

        // 退出
        vm.prank(user1);
        extension.exit();

        assertFalse(center.isAccountJoined(address(token), ACTION_ID, user1));
    }

    // ============================================
    // 复杂场景测试
    // ============================================

    function test_Scenario_JoinExitRejoin() public {
        string[] memory verificationInfos = new string[](0);

        // 第一次加入
        vm.prank(user1);
        extension.join(verificationInfos);
        assertEq(extension.accountsCount(), 1);

        // 退出
        vm.prank(user1);
        extension.exit();
        assertEq(extension.accountsCount(), 0);

        // 再次加入
        vm.prank(user1);
        extension.join(verificationInfos);
        assertEq(extension.accountsCount(), 1);
        assertEq(extension.accountAtIndex(0), user1);
    }

    function test_Scenario_MultipleUsersJoinExit() public {
        string[] memory verificationInfos = new string[](0);

        // 用户 1, 2, 3 加入
        vm.prank(user1);
        extension.join(verificationInfos);
        vm.prank(user2);
        extension.join(verificationInfos);
        vm.prank(user3);
        extension.join(verificationInfos);

        assertEq(extension.accountsCount(), 3);

        // 用户 2 退出
        vm.prank(user2);
        extension.exit();
        assertEq(extension.accountsCount(), 2);

        // 用户 1 退出
        vm.prank(user1);
        extension.exit();
        assertEq(extension.accountsCount(), 1);

        // 验证只剩 user3
        address[] memory accounts = extension.accounts();
        assertEq(accounts[0], user3);

        // 用户 2 再次加入
        vm.prank(user2);
        extension.join(verificationInfos);
        assertEq(extension.accountsCount(), 2);
    }
}
