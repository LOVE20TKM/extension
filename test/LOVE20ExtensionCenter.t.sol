// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {LOVE20ExtensionCenter} from "../src/LOVE20ExtensionCenter.sol";
import {
    ILOVE20ExtensionCenter
} from "../src/interface/ILOVE20ExtensionCenter.sol";
import {MockSubmit} from "./mocks/MockSubmit.sol";
import {MockJoin} from "./mocks/MockJoin.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";
import {MockExtension} from "./mocks/MockExtension.sol";
import {MockToken} from "./mocks/MockToken.sol";

/**
 * @title LOVE20ExtensionCenterTest
 * @dev Test contract for LOVE20ExtensionCenter
 */
contract LOVE20ExtensionCenterTest is Test {
    LOVE20ExtensionCenter public extensionCenter;
    MockSubmit public mockSubmit;
    MockJoin public mockJoin;
    MockExtensionFactory public mockFactory;

    address public mockUniswapV2Factory = address(0x2000);
    address public mockLaunch = address(0x2001);
    address public mockStake = address(0x2002);
    address public mockVote = address(0x2003);
    address public mockVerify = address(0x2004);
    address public mockMint = address(0x2005);
    address public mockRandom = address(0x2006);

    address public tokenAddress;
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public govHolder = address(0x1003);

    uint256 public actionId1 = 1;
    uint256 public actionId2 = 2;

    event AccountAdded(
        address indexed tokenAddress,
        uint256 indexed actionId,
        address indexed account
    );
    event AccountRemoved(
        address indexed tokenAddress,
        uint256 indexed actionId,
        address indexed account
    );

    function setUp() public {
        // Deploy mock contracts
        mockSubmit = new MockSubmit();
        mockJoin = new MockJoin();

        // Deploy extension center with all required addresses
        extensionCenter = new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            mockVote,
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );

        // Deploy mock factory
        mockFactory = new MockExtensionFactory(address(extensionCenter));

        // Deploy mock token used by base initialize approve
        MockToken token = new MockToken();
        tokenAddress = address(token);

        // Prepare tokens for factory registration
        token.mint(address(this), 1000e18);
        token.approve(address(mockFactory), type(uint256).max);
    }

    // ------ Constructor tests ------
    function testConstructor() public view {
        assertEq(
            extensionCenter.uniswapV2FactoryAddress(),
            mockUniswapV2Factory
        );
        assertEq(extensionCenter.launchAddress(), mockLaunch);
        assertEq(extensionCenter.stakeAddress(), mockStake);
        assertEq(extensionCenter.submitAddress(), address(mockSubmit));
        assertEq(extensionCenter.voteAddress(), mockVote);
        assertEq(extensionCenter.joinAddress(), address(mockJoin));
        assertEq(extensionCenter.verifyAddress(), mockVerify);
        assertEq(extensionCenter.mintAddress(), mockMint);
        assertEq(extensionCenter.randomAddress(), mockRandom);
    }

    function testConstructorRevertsOnInvalidUniswapV2FactoryAddress() public {
        vm.expectRevert(
            ILOVE20ExtensionCenter.InvalidUniswapV2FactoryAddress.selector
        );
        new LOVE20ExtensionCenter(
            address(0),
            mockLaunch,
            mockStake,
            address(mockSubmit),
            mockVote,
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidLaunchAddress() public {
        vm.expectRevert(ILOVE20ExtensionCenter.InvalidLaunchAddress.selector);
        new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            address(0),
            mockStake,
            address(mockSubmit),
            mockVote,
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidStakeAddress() public {
        vm.expectRevert(ILOVE20ExtensionCenter.InvalidStakeAddress.selector);
        new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            address(0),
            address(mockSubmit),
            mockVote,
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidSubmitAddress() public {
        vm.expectRevert(ILOVE20ExtensionCenter.InvalidSubmitAddress.selector);
        new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(0),
            mockVote,
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidVoteAddress() public {
        vm.expectRevert(ILOVE20ExtensionCenter.InvalidVoteAddress.selector);
        new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            address(0),
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidJoinAddress() public {
        vm.expectRevert(ILOVE20ExtensionCenter.InvalidJoinAddress.selector);
        new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            mockVote,
            address(0),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidVerifyAddress() public {
        vm.expectRevert(ILOVE20ExtensionCenter.InvalidVerifyAddress.selector);
        new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            mockVote,
            address(mockJoin),
            address(0),
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidMintAddress() public {
        vm.expectRevert(ILOVE20ExtensionCenter.InvalidMintAddress.selector);
        new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            mockVote,
            address(mockJoin),
            mockVerify,
            address(0),
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidRandomAddress() public {
        vm.expectRevert(ILOVE20ExtensionCenter.InvalidRandomAddress.selector);
        new LOVE20ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            mockVote,
            address(mockJoin),
            mockVerify,
            mockMint,
            address(0)
        );
    }

    // ------ Extension query tests ------
    function testExtensionQuery() public {
        // Setup extension as whitelist
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Verify extension() returns whiteListAddress from submit
        assertEq(
            extensionCenter.extension(tokenAddress, actionId1),
            address(mockExtension)
        );
    }

    // ------ Account management tests ------
    function testAddAccount() public {
        // Setup extension as whitelist
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Add account from extension
        vm.prank(address(mockExtension));
        vm.expectEmit(true, true, true, false);
        emit AccountAdded(tokenAddress, actionId1, user1);
        extensionCenter.addAccount(tokenAddress, actionId1, user1);

        // Verify
        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
        assertEq(
            extensionCenter.actionIdsByAccountCount(tokenAddress, user1),
            1
        );
        assertEq(
            extensionCenter.actionIdsByAccountAtIndex(tokenAddress, user1, 0),
            actionId1
        );
        uint256[] memory actionIds = extensionCenter.actionIdsByAccount(
            tokenAddress,
            user1
        );
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], actionId1);
    }

    function testAddAccountRevertsIfNotExtension() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Try to add account from non-extension address
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionCenter.OnlyExtensionCanCall.selector);
        extensionCenter.addAccount(tokenAddress, actionId1, user1);
    }

    function testAddAccountRevertsIfAlreadyJoined() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Add account first time
        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(tokenAddress, actionId1, user1);

        // Try to add again
        vm.expectRevert(ILOVE20ExtensionCenter.AccountAlreadyJoined.selector);
        extensionCenter.addAccount(tokenAddress, actionId1, user1);
        vm.stopPrank();
    }

    function testRemoveAccount() public {
        // Setup extension as whitelist
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(tokenAddress, actionId1, user1);

        // Remove account
        vm.expectEmit(true, true, true, false);
        emit AccountRemoved(tokenAddress, actionId1, user1);
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);
        vm.stopPrank();

        // Verify
        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
        assertEq(
            extensionCenter.actionIdsByAccountCount(tokenAddress, user1),
            0
        );
    }

    function testRemoveAccountRevertsIfNotExtension() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(tokenAddress, actionId1, user1);

        // Try to remove from non-extension address
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionCenter.OnlyExtensionCanCall.selector);
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);
    }

    function testRemoveAccountRevertsIfNotJoined() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Try to remove account that was never added
        vm.prank(address(mockExtension));
        vm.expectRevert(ILOVE20ExtensionCenter.AccountNotJoined.selector);
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);
    }

    function testMultipleAccountsAndActions() public {
        // Create two extensions for different actions
        MockExtension mockExtension1 = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension1)
        );

        MockExtension mockExtension2 = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId2,
            address(mockExtension2)
        );

        // Add user1 to both actions
        vm.prank(address(mockExtension1));
        extensionCenter.addAccount(tokenAddress, actionId1, user1);

        vm.prank(address(mockExtension2));
        extensionCenter.addAccount(tokenAddress, actionId2, user1);

        // Add user2 to action1 only
        vm.prank(address(mockExtension1));
        extensionCenter.addAccount(tokenAddress, actionId1, user2);

        // Verify user1 is in both actions
        assertEq(
            extensionCenter.actionIdsByAccountCount(tokenAddress, user1),
            2
        );
        uint256[] memory user1ActionIds = extensionCenter.actionIdsByAccount(
            tokenAddress,
            user1
        );
        assertEq(user1ActionIds.length, 2);

        // Verify user2 is in one action
        assertEq(
            extensionCenter.actionIdsByAccountCount(tokenAddress, user2),
            1
        );
        assertEq(
            extensionCenter.actionIdsByAccountAtIndex(tokenAddress, user2, 0),
            actionId1
        );
    }

    // ------ Edge cases ------
    function testExtensionQueriesForNonExistentData() public view {
        // Query non-existent extension (returns address(0) from submit)
        assertEq(
            extensionCenter.extension(tokenAddress, actionId1),
            address(0)
        );
    }

    function testAccountQueriesForNonExistentData() public view {
        // Query non-existent account
        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
        assertEq(
            extensionCenter.actionIdsByAccountCount(tokenAddress, user1),
            0
        );

        uint256[] memory actionIds = extensionCenter.actionIdsByAccount(
            tokenAddress,
            user1
        );
        assertEq(actionIds.length, 0);
    }
}
