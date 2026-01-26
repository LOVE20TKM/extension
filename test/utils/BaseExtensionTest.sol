// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {ExtensionCenter} from "../../src/ExtensionCenter.sol";
import {IExtensionCenter} from "../../src/interface/IExtensionCenter.sol";

// Import mock contracts
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockStake} from "../mocks/MockStake.sol";
import {MockJoin} from "../mocks/MockJoin.sol";
import {MockVerify} from "../mocks/MockVerify.sol";
import {MockMint} from "../mocks/MockMint.sol";
import {MockSubmit} from "../mocks/MockSubmit.sol";
import {MockLaunch} from "../mocks/MockLaunch.sol";
import {MockVote} from "../mocks/MockVote.sol";
import {MockRandom} from "../mocks/MockRandom.sol";
import {MockUniswapV2Factory} from "../mocks/MockUniswapV2Factory.sol";
import {IExtensionFactory} from "../../src/interface/IExtensionFactory.sol";

/**
 * @title BaseExtensionTest
 * @notice 扩展测试的通用设置和工具类
 * @dev 提供所有扩展测试共用的设置、mock 合约和辅助函数
 */
abstract contract BaseExtensionTest is Test {
    // ============================================
    // 核心合约
    // ============================================

    ExtensionCenter public center;
    MockERC20 public token;
    MockERC20 public joinToken;
    MockUniswapV2Factory public uniswapFactory;

    // ============================================
    // Mock 合约
    // ============================================

    MockStake public stake;
    MockJoin public join;
    MockVerify public verify;
    MockMint public mint;
    MockSubmit public submit;
    MockLaunch public launch;
    MockVote public vote;
    MockRandom public random;

    // ============================================
    // 测试用户
    // ============================================

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public user4 = address(0x4);
    address public deployer = address(this);

    // ============================================
    // 常量
    // ============================================

    uint256 constant ACTION_ID = 1;
    uint256 constant WAITING_BLOCKS = 100;

    // ============================================
    // 设置函数
    // ============================================

    /**
     * @notice 设置基础测试环境
     * @dev 子类应该在 setUp() 中调用此函数
     */
    function setUpBase() internal virtual {
        // 部署 mock 合约
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
        uniswapFactory = new MockUniswapV2Factory();

        // 部署扩展中心
        center = new ExtensionCenter(
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

        // 将 token 标记为 LOVE20 代币
        launch.setLOVE20Token(address(token), true);
        launch.setLOVE20Token(address(joinToken), true);

        // 初始化当前轮次为 0
        verify.setCurrentRound(0);
    }

    /**
     * @notice 设置用户的代币和批准
     * @param user 用户地址
     * @param joinAmount 加入金额
     * @param spender 批准的花费者地址
     */
    function setupUser(
        address user,
        uint256 joinAmount,
        address spender
    ) internal virtual {
        joinToken.mint(user, joinAmount);
        vm.prank(user);
        joinToken.approve(spender, type(uint256).max);
    }

    /**
     * @notice 设置用户的治理投票数
     * @param user 用户地址
     * @param govVotes 治理投票数
     */
    function setupUserGovVotes(
        address user,
        uint256 govVotes
    ) internal virtual {
        stake.setValidGovVotes(address(token), user, govVotes);
    }

    /**
     * @notice 设置用户（包括代币和治理投票）
     * @param user 用户地址
     * @param joinAmount 加入金额
     * @param spender 批准的花费者地址
     * @param govVotes 治理投票数
     */
    function setupUserComplete(
        address user,
        uint256 joinAmount,
        address spender,
        uint256 govVotes
    ) internal virtual {
        setupUser(user, joinAmount, spender);
        setupUserGovVotes(user, govVotes);
    }

    /**
     * @notice 准备 factory 注册 extension 所需的代币
     * @param factory factory 地址
     * @param tokenAddr 代币地址
     */
    function prepareFactoryRegistration(
        address factory,
        address tokenAddr
    ) internal virtual {
        MockERC20(tokenAddr).mint(address(this), 1e18);
        MockERC20(tokenAddr).approve(factory, type(uint256).max);
    }

    /**
     * @notice 准备扩展初始化（设置 mock 数据，实际初始化在首次 join 时自动完成）
     * @param extensionAddress 扩展地址
     * @param tokenAddr 代币地址
     * @param actionId 动作 ID
     * @param factory factory 地址（可选，如果提供则设置 actionAuthor）
     */
    function prepareExtensionInit(
        address extensionAddress,
        address tokenAddr,
        uint256 actionId,
        address factory
    ) internal virtual {
        // 设置动作信息（白名单）
        submit.setActionInfo(tokenAddr, actionId, extensionAddress);

        // 设置 action author 以匹配 extension creator
        if (factory != address(0)) {
            address extensionCreator = IExtensionFactory(factory)
                .extensionCreator(extensionAddress);
            if (extensionCreator != address(0)) {
                submit.setActionAuthor(tokenAddr, actionId, extensionCreator);
            }
        }

        // 设置 vote 返回的 actionId 列表
        vote.setVotedActionIds(tokenAddr, join.currentRound(), actionId);

        // 给 extension mint token 以便初始化时 join
        token.mint(extensionAddress, 1e18);
    }

    /**
     * @notice 准备扩展初始化（不设置 actionAuthor，用于向后兼容）
     * @param extensionAddress 扩展地址
     * @param tokenAddr 代币地址
     * @param actionId 动作 ID
     */
    function prepareExtensionInit(
        address extensionAddress,
        address tokenAddr,
        uint256 actionId
    ) internal virtual {
        prepareExtensionInit(extensionAddress, tokenAddr, actionId, address(0));
    }

    // ============================================
    // 辅助断言函数
    // ============================================

    /**
     * @notice 断言两个数组相等
     * @param actual 实际数组
     * @param expected 期望数组
     * @param message 错误消息
     */
    function assertArrayEq(
        address[] memory actual,
        address[] memory expected,
        string memory message
    ) internal pure {
        assertEq(
            actual.length,
            expected.length,
            string.concat(message, ": length mismatch")
        );
        for (uint256 i = 0; i < actual.length; i++) {
            assertEq(
                actual[i],
                expected[i],
                string.concat(
                    message,
                    ": element mismatch at index ",
                    vm.toString(i)
                )
            );
        }
    }

    /**
     * @notice 断言两个 uint256 数组相等
     * @param actual 实际数组
     * @param expected 期望数组
     * @param message 错误消息
     */
    function assertArrayEq(
        uint256[] memory actual,
        uint256[] memory expected,
        string memory message
    ) internal pure {
        assertEq(
            actual.length,
            expected.length,
            string.concat(message, ": length mismatch")
        );
        for (uint256 i = 0; i < actual.length; i++) {
            assertEq(
                actual[i],
                expected[i],
                string.concat(
                    message,
                    ": element mismatch at index ",
                    vm.toString(i)
                )
            );
        }
    }

    // ============================================
    // 时间辅助函数
    // ============================================

    /**
     * @notice 前进指定数量的区块
     * @param blocks 区块数量
     */
    function advanceBlocks(uint256 blocks) internal {
        vm.roll(block.number + blocks);
    }

    /**
     * @notice 前进到可以退出的区块
     * @param waitingBlocks 等待区块数
     */
    function advanceToExitable(uint256 waitingBlocks) internal {
        vm.roll(block.number + waitingBlocks);
    }
}
