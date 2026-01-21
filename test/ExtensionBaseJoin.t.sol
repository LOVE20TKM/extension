// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {BaseExtensionTest} from "./utils/BaseExtensionTest.sol";
import {ExtensionBaseRewardJoin} from "../src/ExtensionBaseRewardJoin.sol";
import {IJoin} from "../src/interface/IJoin.sol";
import {IJoinEvents} from "../src/interface/IJoin.sol";
import {IJoinErrors} from "../src/interface/IJoin.sol";
import {IReward} from "../src/interface/IReward.sol";
import {ExtensionBaseReward} from "../src/ExtensionBaseReward.sol";
import {ExtensionBase} from "../src/ExtensionBase.sol";
import {IExtension} from "../src/interface/IExtension.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockExtensionForJoin
 * @notice Mock extension for testing Join
 */
contract MockExtensionForJoin is ExtensionBaseRewardJoin {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(
        address factory_,
        address tokenAddress_
    ) ExtensionBaseRewardJoin(factory_, tokenAddress_) {}

    function joinedAmount()
        external
        view
        override(ExtensionBase)
        returns (uint256)
    {
        return _center.accountsCount(TOKEN_ADDRESS, actionId);
    }

    function joinedAmountByAccount(
        address account
    ) external view override(ExtensionBase) returns (uint256) {
        return
            _center.isAccountJoined(TOKEN_ADDRESS, actionId, account) ? 1 : 0;
    }

    function joinedAmountTokenAddress()
        external
        view
        override(ExtensionBase)
        returns (address)
    {
        return TOKEN_ADDRESS;
    }

    function rewardByAccount(
        uint256,
        address
    )
        public
        pure
        override(ExtensionBaseReward)
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
 * @title ExtensionBaseRewardJoinTest
 * @notice Test suite for ExtensionBaseRewardJoin
 * @dev Tests join, exit, and verification info integration
 */
contract ExtensionBaseJoinTest is BaseExtensionTest, IJoinEvents {
    MockExtensionFactory public mockFactory;
    MockExtensionForJoin public extension;

    function setUp() public {
        setUpBase();

        mockFactory = new MockExtensionFactory(address(center));
        extension = new MockExtensionForJoin(
            address(mockFactory),
            address(token)
        );

        prepareFactoryRegistration(address(mockFactory), address(token));
        mockFactory.registerExtension(address(extension), address(token));

        submit.setActionInfo(address(token), ACTION_ID, address(extension));
        // Set action author to match extension creator
        address extensionCreator = mockFactory.extensionCreator(
            address(extension)
        );
        if (extensionCreator != address(0)) {
            submit.setActionAuthor(address(token), ACTION_ID, extensionCreator);
        }
        token.mint(address(extension), 1e18);
        vote.setVotedActionIds(address(token), join.currentRound(), ACTION_ID);
    }

    // ============================================
    // Join Tests
    // ============================================

    function test_Join_Success() public {
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
        assertEq(center.accountsAtIndex(address(token), ACTION_ID, 0), user1);
        assertTrue(center.isAccountJoined(address(token), ACTION_ID, user1));
    }

    function test_Join_EmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Join(address(token), join.currentRound(), ACTION_ID, user1);

        vm.prank(user1);
        extension.join(new string[](0));
    }

    function test_Join_MultipleUsers() public {
        vm.prank(user1);
        extension.join(new string[](0));

        vm.prank(user2);
        extension.join(new string[](0));

        vm.prank(user3);
        extension.join(new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 3);

        address[] memory accounts = center.accounts(address(token), ACTION_ID);
        assertEq(accounts[0], user1);
        assertEq(accounts[1], user2);
        assertEq(accounts[2], user3);
    }

    function test_Join_RevertIfAlreadyJoined() public {
        vm.startPrank(user1);
        extension.join(new string[](0));

        vm.expectRevert(IJoinErrors.AlreadyJoined.selector);
        extension.join(new string[](0));
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

        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
        assertEq(
            center.verificationInfo(address(token), ACTION_ID, user1, "key1"),
            "info1"
        );
        assertEq(
            center.verificationInfo(address(token), ACTION_ID, user1, "key2"),
            "info2"
        );
    }

    function test_Join_EmptyVerificationInfo() public {
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
    }

    // ============================================
    // Exit Tests
    // ============================================

    function test_Exit_Success() public {
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 1);

        vm.prank(user1);
        extension.exit();

        assertEq(center.accountsCount(address(token), ACTION_ID), 0);
        assertFalse(center.isAccountJoined(address(token), ACTION_ID, user1));
    }

    function test_Exit_EmitEvent() public {
        vm.prank(user1);
        extension.join(new string[](0));

        vm.expectEmit(true, true, true, true);
        emit Exit(address(token), join.currentRound(), ACTION_ID, user1);

        vm.prank(user1);
        extension.exit();
    }

    function test_Exit_RevertIfNotJoined() public {
        vm.prank(user1);
        vm.expectRevert(IJoinErrors.NotJoined.selector);
        extension.exit();
    }

    function test_Exit_MultipleUsers() public {
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 3);

        vm.prank(user2);
        extension.exit();

        assertEq(center.accountsCount(address(token), ACTION_ID), 2);

        address[] memory accounts = center.accounts(address(token), ACTION_ID);
        assertTrue(accounts[0] == user1 || accounts[0] == user3);
        assertTrue(accounts[1] == user1 || accounts[1] == user3);
        assertTrue(accounts[0] != accounts[1]);
    }

    // ============================================
    // JoinedAmount Tests
    // ============================================

    function test_JoinedAmount_EmptyAtStart() public view {
        assertEq(extension.joinedAmount(), 0);
    }

    function test_JoinedAmount_AfterJoin() public {
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(extension.joinedAmount(), 1);
    }

    function test_JoinedAmount_MultipleUsers() public {
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        assertEq(extension.joinedAmount(), 3);
    }

    function test_JoinedAmountByAccount_NotJoined() public view {
        assertEq(extension.joinedAmountByAccount(user1), 0);
    }

    function test_JoinedAmountByAccount_Joined() public {
        vm.prank(user1);
        extension.join(new string[](0));

        assertEq(extension.joinedAmountByAccount(user1), 1);
        assertEq(extension.joinedAmountByAccount(user2), 0);
    }

    // ============================================
    // Center Integration Tests
    // ============================================

    function test_Center_AddAccount() public {
        assertFalse(center.isAccountJoined(address(token), ACTION_ID, user1));

        vm.prank(user1);
        extension.join(new string[](0));

        assertTrue(center.isAccountJoined(address(token), ACTION_ID, user1));

        (uint256[] memory actionIds, , ) = center.actionIdsByAccount(
            address(token),
            user1,
            new address[](0)
        );
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], ACTION_ID);
    }

    function test_Center_RemoveAccount() public {
        vm.prank(user1);
        extension.join(new string[](0));

        assertTrue(center.isAccountJoined(address(token), ACTION_ID, user1));

        vm.prank(user1);
        extension.exit();

        assertFalse(center.isAccountJoined(address(token), ACTION_ID, user1));
    }

    // ============================================
    // Complex Scenarios
    // ============================================

    function test_Scenario_JoinExitRejoin() public {
        vm.prank(user1);
        extension.join(new string[](0));
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);

        vm.prank(user1);
        extension.exit();
        assertEq(center.accountsCount(address(token), ACTION_ID), 0);

        vm.prank(user1);
        extension.join(new string[](0));
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);
        assertEq(center.accountsAtIndex(address(token), ACTION_ID, 0), user1);
    }

    function test_Scenario_MultipleUsersJoinExit() public {
        vm.prank(user1);
        extension.join(new string[](0));
        vm.prank(user2);
        extension.join(new string[](0));
        vm.prank(user3);
        extension.join(new string[](0));

        assertEq(center.accountsCount(address(token), ACTION_ID), 3);

        vm.prank(user2);
        extension.exit();
        assertEq(center.accountsCount(address(token), ACTION_ID), 2);

        vm.prank(user1);
        extension.exit();
        assertEq(center.accountsCount(address(token), ACTION_ID), 1);

        address[] memory accounts = center.accounts(address(token), ACTION_ID);
        assertEq(accounts[0], user3);

        vm.prank(user2);
        extension.join(new string[](0));
        assertEq(center.accountsCount(address(token), ACTION_ID), 2);
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_JoinMultipleUsers(uint8 numUsers) public {
        numUsers = uint8(bound(numUsers, 1, 50));

        for (uint256 i = 0; i < numUsers; i++) {
            address user = address(uint160(1000 + i));
            vm.prank(user);
            extension.join(new string[](0));
        }

        assertEq(center.accountsCount(address(token), ACTION_ID), numUsers);
        assertEq(extension.joinedAmount(), numUsers);
    }
}
