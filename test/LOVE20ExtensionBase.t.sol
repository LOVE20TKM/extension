// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {LOVE20ExtensionBase} from "../src/LOVE20ExtensionBase.sol";
import {ILOVE20Extension} from "../src/interface/ILOVE20Extension.sol";
import {IExtensionCore} from "../src/interface/base/IExtensionCore.sol";
import {IExtensionReward} from "../src/interface/base/IExtensionReward.sol";
import {ExtensionReward} from "../src/base/ExtensionReward.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";

/**
 * @title MockLOVE20ExtensionBase
 * @notice LOVE20ExtensionBase 的具体实现，用于测试
 */
contract MockLOVE20ExtensionBase is LOVE20ExtensionBase {
    constructor(address factory_) LOVE20ExtensionBase(factory_) {}

    // 实现 ILOVE20Extension 的抽象方法
    function isJoinedValueCalculated() external pure override returns (bool) {
        return false;
    }

    function joinedValue() external pure override returns (uint256) {
        return 0;
    }

    function joinedValueByAccount(
        address
    ) external pure override returns (uint256) {
        return 0;
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

    // 实现 IExtensionExit 的抽象方法
    function exit() external pure {
        revert("Exit not implemented in mock");
    }
}

/**
 * @title LOVE20ExtensionBaseTest
 * @notice LOVE20ExtensionBase 的测试套件
 * @dev 测试基础扩展合约的核心功能
 */
contract LOVE20ExtensionBaseTest is BaseExtensionTest {
    MockExtensionFactory public mockFactory;
    MockLOVE20ExtensionBase public extension;

    function setUp() public {
        setUpBase();

        // 部署 mock factory
        mockFactory = new MockExtensionFactory(address(center));

        // 部署扩展
        extension = new MockLOVE20ExtensionBase(address(mockFactory));

        // 注册 factory
        registerFactory(address(token), address(mockFactory));

        // 将扩展注册到 factory
        mockFactory.registerExtension(address(extension));
    }

    // ============================================
    // 构造函数测试
    // ============================================

    function test_Constructor_StoresFactory() public view {
        assertEq(
            extension.factory(),
            address(mockFactory),
            "Factory should be stored"
        );
    }

    function test_Constructor_RetrievesCenter() public view {
        assertEq(
            extension.center(),
            address(center),
            "Center should be retrieved from factory"
        );
    }

    function test_Constructor_NotInitialized() public view {
        assertFalse(
            extension.initialized(),
            "Should not be initialized at construction"
        );
    }

    function test_Constructor_TokenAddressZero() public view {
        assertEq(
            extension.tokenAddress(),
            address(0),
            "Token address should be zero before init"
        );
    }

    function test_Constructor_ActionIdZero() public view {
        assertEq(
            extension.actionId(),
            0,
            "Action ID should be zero before init"
        );
    }

    // ============================================
    // 初始化测试
    // ============================================

    function test_Initialize_Success() public {
        // 设置 action info
        submit.setActionInfo(address(token), ACTION_ID, address(extension));

        // 给扩展发放代币用于 join
        token.mint(address(extension), 1e18);

        // 通过 center 初始化
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );

        // 验证状态
        assertTrue(extension.initialized(), "Should be initialized");
        assertEq(
            extension.tokenAddress(),
            address(token),
            "Token address should be set"
        );
        assertEq(extension.actionId(), ACTION_ID, "Action ID should be set");
    }

    function test_Initialize_RevertIfNotCenter() public {
        vm.expectRevert(IExtensionCore.OnlyCenterCanCall.selector);
        extension.initialize(address(token), ACTION_ID);
    }

    function test_Initialize_RevertIfAlreadyInitialized() public {
        // 第一次初始化
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );

        // 尝试第二次初始化
        submit.setActionInfo(address(token), ACTION_ID + 1, address(extension));
        vm.expectRevert(IExtensionCore.AlreadyInitialized.selector);
        vm.prank(address(center));
        extension.initialize(address(token), ACTION_ID + 1);
    }

    function test_Initialize_RevertIfInvalidTokenAddress() public {
        vm.expectRevert(IExtensionCore.InvalidTokenAddress.selector);
        vm.prank(address(center));
        extension.initialize(address(0), ACTION_ID);
    }

    // ============================================
    // 账户管理测试
    // ============================================

    function test_Accounts_EmptyAtStart() public view {
        address[] memory accs = extension.accounts();
        assertEq(accs.length, 0, "Accounts should be empty initially");
        assertEq(extension.accountsCount(), 0, "Accounts count should be 0");
    }

    // ============================================
    // 接口实现测试
    // ============================================

    function test_Interface_ILOVE20Extension() public view {
        // 测试 joinedValue 相关方法
        assertFalse(extension.isJoinedValueCalculated(), "Should return false");
        assertEq(extension.joinedValue(), 0, "Should return 0");
        assertEq(
            extension.joinedValueByAccount(user1),
            0,
            "Should return 0 for any account"
        );
    }

    // ============================================
    // 多重继承测试
    // ============================================

    function test_Inheritance_ExtensionCore() public view {
        // 测试 ExtensionCore 功能
        assertEq(extension.factory(), address(mockFactory));
        assertEq(extension.center(), address(center));
    }

    function test_Inheritance_ExtensionAccounts() public view {
        // 测试 ExtensionAccounts 功能
        assertEq(extension.accountsCount(), 0);
    }

    // ============================================
    // 集成测试
    // ============================================

    function test_Integration_FullInitialization() public {
        // 完整的初始化流程
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);

        // 初始化前的状态
        assertFalse(extension.initialized());
        assertEq(extension.tokenAddress(), address(0));
        assertEq(extension.actionId(), 0);

        // 执行初始化
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );

        // 初始化后的状态
        assertTrue(extension.initialized());
        assertEq(extension.tokenAddress(), address(token));
        assertEq(extension.actionId(), ACTION_ID);
        assertEq(extension.factory(), address(mockFactory));
        assertEq(extension.center(), address(center));
    }

    function test_Integration_MultipleExtensions() public {
        // 创建多个扩展实例
        MockLOVE20ExtensionBase extension2 = new MockLOVE20ExtensionBase(
            address(mockFactory)
        );
        mockFactory.registerExtension(address(extension2));

        // 初始化第一个扩展
        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        token.mint(address(extension), 1e18);
        center.initializeExtension(
            address(extension),
            address(token),
            ACTION_ID
        );

        // 初始化第二个扩展（不同的 action ID）
        submit.setActionInfo(
            address(token),
            ACTION_ID + 1,
            address(extension2)
        );
        token.mint(address(extension2), 1e18);
        center.initializeExtension(
            address(extension2),
            address(token),
            ACTION_ID + 1
        );

        // 验证两个扩展都正确初始化
        assertTrue(extension.initialized());
        assertTrue(extension2.initialized());
        assertEq(extension.actionId(), ACTION_ID);
        assertEq(extension2.actionId(), ACTION_ID + 1);
    }
}
