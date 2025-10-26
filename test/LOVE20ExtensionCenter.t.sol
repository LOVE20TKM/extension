// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {LOVE20ExtensionCenter} from "../src/LOVE20ExtensionCenter.sol";
import {ILOVE20ExtensionCenter} from "../src/interface/ILOVE20ExtensionCenter.sol";
import {MockSubmit} from "./mocks/MockSubmit.sol";
import {MockJoin} from "./mocks/MockJoin.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";
import {MockExtension} from "./mocks/MockExtension.sol";

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

    address public tokenAddress = address(0x1000);
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public govHolder = address(0x1003);

    uint256 public actionId1 = 1;
    uint256 public actionId2 = 2;

    event ExtensionFactoryAdded(
        address indexed tokenAddress,
        address indexed factory
    );
    event ExtensionInitialized(
        address indexed tokenAddress,
        uint256 indexed actionId,
        address indexed extension
    );
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

    // ------ Extension Factory tests ------
    function testAddFactory() public {
        // Setup: give govHolder permission to submit
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);

        assertEq(
            extensionCenter.existsFactory(tokenAddress, address(mockFactory)),
            false
        );

        // Execute
        vm.prank(govHolder);
        vm.expectEmit(true, true, false, false);
        emit ExtensionFactoryAdded(tokenAddress, address(mockFactory));
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        assertEq(
            extensionCenter.existsFactory(tokenAddress, address(mockFactory)),
            true
        );
    }

    function testAddFactoryRevertsInvalidExtensionFactory() public {
        mockFactory = new MockExtensionFactory(address(0x111));

        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        vm.expectRevert(
            ILOVE20ExtensionCenter.InvalidExtensionFactory.selector
        );
        extensionCenter.addFactory(tokenAddress, address(mockFactory));
    }

    function testAddFactoryRevertsIfNotEnoughGovVotes() public {
        // Don't give govHolder permission
        mockSubmit.setCanSubmit(tokenAddress, govHolder, false);

        vm.prank(govHolder);
        vm.expectRevert(ILOVE20ExtensionCenter.NotEnoughGovVotes.selector);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));
    }

    function testAddFactoryRevertsIfAlreadyExists() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);

        vm.startPrank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        vm.expectRevert(
            ILOVE20ExtensionCenter.ExtensionFactoryAlreadyExists.selector
        );
        extensionCenter.addFactory(tokenAddress, address(mockFactory));
        vm.stopPrank();
    }

    // ------ Extension initialization tests ------
    function testInitializeExtension() public {
        // Setup
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        // Create mock extension
        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );

        // Add extension to factory
        mockFactory.addExtension(tokenAddress, address(mockExtension));

        // Setup action info with extension as whitelist
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Setup join amount (extension has joined the action)
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );

        // Execute
        vm.expectEmit(true, true, true, false);
        emit ExtensionInitialized(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        extensionCenter.initializeExtension(address(mockExtension));

        // Verify
        assertEq(
            extensionCenter.extension(tokenAddress, actionId1),
            address(mockExtension)
        );
        assertTrue(mockExtension.initializeCalled());
        assertEq(extensionCenter.extensionsCount(tokenAddress), 1);
        assertEq(
            extensionCenter.extensionsAtIndex(tokenAddress, 0),
            address(mockExtension)
        );
    }

    function testInitializeExtensionRevertsIfAlreadyExists() public {
        // Setup first extension
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension1 = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension1));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension1)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension1),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension1));

        // Try to add another extension with same tokenAddress and actionId
        MockExtension mockExtension2 = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension2));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension2)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension2),
            1000
        );

        vm.expectRevert(ILOVE20ExtensionCenter.ExtensionAlreadyExists.selector);
        extensionCenter.initializeExtension(address(mockExtension2));
    }

    function testInitializeExtensionRevertsIfInvalidFactory() public {
        // Don't add factory to extension center
        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );

        mockFactory.addExtension(tokenAddress, address(mockExtension));

        vm.expectRevert(
            ILOVE20ExtensionCenter.InvalidExtensionFactory.selector
        );
        extensionCenter.initializeExtension(address(mockExtension));
    }

    function testInitializeExtensionRevertsIfNotFoundInFactory() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        // Don't add extension to factory

        vm.expectRevert(
            ILOVE20ExtensionCenter.ExtensionNotFoundInFactory.selector
        );
        extensionCenter.initializeExtension(address(mockExtension));
    }

    function testInitializeExtensionRevertsIfInvalidWhiteListAddress() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));

        // Set wrong whitelist address
        mockSubmit.setActionInfo(tokenAddress, actionId1, address(0x9999));
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );

        vm.expectRevert(
            ILOVE20ExtensionCenter.InvalidWhiteListAddress.selector
        );
        extensionCenter.initializeExtension(address(mockExtension));
    }

    function testInitializeExtensionRevertsIfNotJoinedAction() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Don't set join amount (extension hasn't joined)
        mockJoin.setAmount(tokenAddress, actionId1, address(mockExtension), 0);

        vm.expectRevert(
            ILOVE20ExtensionCenter.ExtensionNotJoinedAction.selector
        );
        extensionCenter.initializeExtension(address(mockExtension));
    }

    function testInitializeExtensionRevertsIfInitializeFails() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockExtension.setShouldFailInitialize(true);

        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );

        vm.expectRevert(ILOVE20ExtensionCenter.InitializeFailed.selector);
        extensionCenter.initializeExtension(address(mockExtension));
    }

    // ------ Extension info queries ------
    function testExtensionInfo() public {
        // Setup and initialize extension
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension));

        // Test extensionInfo
        (address returnedToken, uint256 returnedActionId) = extensionCenter
            .extensionInfo(address(mockExtension));
        assertEq(returnedToken, tokenAddress);
        assertEq(returnedActionId, actionId1);
    }

    function testMultipleExtensions() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        // Create and initialize first extension
        MockExtension mockExtension1 = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension1));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension1)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension1),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension1));

        // Create and initialize second extension
        MockExtension mockExtension2 = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId2
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension2));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId2,
            address(mockExtension2)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId2,
            address(mockExtension2),
            2000
        );
        extensionCenter.initializeExtension(address(mockExtension2));

        // Verify
        assertEq(extensionCenter.extensionsCount(tokenAddress), 2);
        assertEq(
            extensionCenter.extensionsAtIndex(tokenAddress, 0),
            address(mockExtension1)
        );
        assertEq(
            extensionCenter.extensionsAtIndex(tokenAddress, 1),
            address(mockExtension2)
        );
    }

    // ------ Account management tests ------
    function testAddAccount() public {
        // Setup extension
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension));

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
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension));

        // Try to add account from non-extension address
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionCenter.OnlyExtensionCanCall.selector);
        extensionCenter.addAccount(tokenAddress, actionId1, user1);
    }

    function testAddAccountRevertsIfAlreadyJoined() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension));

        // Add account first time
        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(tokenAddress, actionId1, user1);

        // Try to add again
        vm.expectRevert(ILOVE20ExtensionCenter.AccountAlreadyJoined.selector);
        extensionCenter.addAccount(tokenAddress, actionId1, user1);
        vm.stopPrank();
    }

    function testRemoveAccount() public {
        // Setup and add account first
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension));

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
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension));

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(tokenAddress, actionId1, user1);

        // Try to remove from non-extension address
        vm.prank(user1);
        vm.expectRevert(ILOVE20ExtensionCenter.OnlyExtensionCanCall.selector);
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);
    }

    function testRemoveAccountRevertsIfNotJoined() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        MockExtension mockExtension = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension));

        // Try to remove account that was never added
        vm.prank(address(mockExtension));
        vm.expectRevert(ILOVE20ExtensionCenter.AccountNotJoined.selector);
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);
    }

    function testMultipleAccountsAndActions() public {
        mockSubmit.setCanSubmit(tokenAddress, govHolder, true);
        vm.prank(govHolder);
        extensionCenter.addFactory(tokenAddress, address(mockFactory));

        // Create two extensions
        MockExtension mockExtension1 = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId1
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension1));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension1)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId1,
            address(mockExtension1),
            1000
        );
        extensionCenter.initializeExtension(address(mockExtension1));

        MockExtension mockExtension2 = new MockExtension(
            address(extensionCenter),
            address(mockFactory),
            tokenAddress,
            actionId2
        );
        mockFactory.addExtension(tokenAddress, address(mockExtension2));
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId2,
            address(mockExtension2)
        );
        mockJoin.setAmount(
            tokenAddress,
            actionId2,
            address(mockExtension2),
            2000
        );
        extensionCenter.initializeExtension(address(mockExtension2));

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
        // Query non-existent extension
        assertEq(
            extensionCenter.extension(tokenAddress, actionId1),
            address(0)
        );

        // Query non-existent extension info
        (address token, uint256 action) = extensionCenter.extensionInfo(
            address(0x9999)
        );
        assertEq(token, address(0));
        assertEq(action, 0);

        // Query extensions count for non-existent token
        assertEq(extensionCenter.extensionsCount(address(0x9999)), 0);
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
