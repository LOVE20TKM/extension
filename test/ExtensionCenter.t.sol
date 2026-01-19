// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {ExtensionCenter} from "../src/ExtensionCenter.sol";
import {IExtensionCenter} from "../src/interface/IExtensionCenter.sol";
import {MockSubmit} from "./mocks/MockSubmit.sol";
import {MockJoin} from "./mocks/MockJoin.sol";
import {MockVote} from "./mocks/MockVote.sol";
import {MockExtensionFactory} from "./mocks/MockExtensionFactory.sol";
import {MockExtension} from "./mocks/MockExtension.sol";
import {MockToken} from "./mocks/MockToken.sol";

/**
 * @title ExtensionCenterTest
 * @dev Test contract for ExtensionCenter
 */
contract ExtensionCenterTest is Test {
    ExtensionCenter public extensionCenter;
    MockSubmit public mockSubmit;
    MockJoin public mockJoin;
    MockVote public mockVote;
    MockExtensionFactory public mockFactory;

    address public mockUniswapV2Factory = address(0x2000);
    address public mockLaunch = address(0x2001);
    address public mockStake = address(0x2002);
    address public mockVerify = address(0x2004);
    address public mockMint = address(0x2005);
    address public mockRandom = address(0x2006);

    address public tokenAddress;
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public govHolder = address(0x1003);

    uint256 public actionId1 = 1;
    uint256 public actionId2 = 2;

    event AddAccount(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account
    );
    event RemoveAccount(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account
    );
    event UpdateVerificationInfo(
        address indexed tokenAddress,
        uint256 round,
        uint256 indexed actionId,
        address indexed account,
        string verificationKey,
        string verificationInfo
    );

    function setUp() public {
        // Deploy mock contracts
        mockSubmit = new MockSubmit();
        mockJoin = new MockJoin();
        mockVote = new MockVote();

        // Deploy extension center with all required addresses
        extensionCenter = new ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            address(mockVote),
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

    function _registerAction(
        address tokenAddress_,
        uint256 actionId_
    ) internal {
        extensionCenter.registerActionIfNeeded(tokenAddress_, actionId_);
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
        assertEq(extensionCenter.voteAddress(), address(mockVote));
        assertEq(extensionCenter.joinAddress(), address(mockJoin));
        assertEq(extensionCenter.verifyAddress(), mockVerify);
        assertEq(extensionCenter.mintAddress(), mockMint);
        assertEq(extensionCenter.randomAddress(), mockRandom);
    }

    function testConstructorRevertsOnInvalidUniswapV2FactoryAddress() public {
        vm.expectRevert();
        new ExtensionCenter(
            address(0),
            mockLaunch,
            mockStake,
            address(mockSubmit),
            address(mockVote),
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidLaunchAddress() public {
        vm.expectRevert();
        new ExtensionCenter(
            mockUniswapV2Factory,
            address(0),
            mockStake,
            address(mockSubmit),
            address(mockVote),
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidStakeAddress() public {
        vm.expectRevert();
        new ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            address(0),
            address(mockSubmit),
            address(mockVote),
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidSubmitAddress() public {
        vm.expectRevert();
        new ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(0),
            address(mockVote),
            address(mockJoin),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidVoteAddress() public {
        vm.expectRevert();
        new ExtensionCenter(
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
        vm.expectRevert();
        new ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            address(mockVote),
            address(0),
            mockVerify,
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidVerifyAddress() public {
        vm.expectRevert();
        new ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            address(mockVote),
            address(mockJoin),
            address(0),
            mockMint,
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidMintAddress() public {
        vm.expectRevert();
        new ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            address(mockVote),
            address(mockJoin),
            mockVerify,
            address(0),
            mockRandom
        );
    }

    function testConstructorRevertsOnInvalidRandomAddress() public {
        vm.expectRevert();
        new ExtensionCenter(
            mockUniswapV2Factory,
            mockLaunch,
            mockStake,
            address(mockSubmit),
            address(mockVote),
            address(mockJoin),
            mockVerify,
            mockMint,
            address(0)
        );
    }

    // ------ Extension query tests ------
    function testExtensionQueryWithNoRegistration() public {
        // Setup extension as whitelist
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Verify extension() returns 0 if not registered
        assertEq(
            extensionCenter.extension(tokenAddress, actionId1),
            address(0)
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
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // Add account from extension
        vm.expectEmit(true, true, true, false);
        emit AddAccount(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1,
            user1
        );
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Verify
        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );

        // Verify extension and factory are recorded
        assertEq(
            extensionCenter.extension(tokenAddress, actionId1),
            address(mockExtension)
        );
        assertEq(
            extensionCenter.factory(tokenAddress, actionId1),
            address(mockFactory)
        );

        // Verify actionIdsByAccount with empty factories (returns all)
        (
            uint256[] memory actionIds,
            address[] memory extensions,
            address[] memory factories_
        ) = extensionCenter.actionIdsByAccount(
                tokenAddress,
                user1,
                new address[](0)
            );
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], actionId1);
        assertEq(extensions.length, 1);
        assertEq(extensions[0], address(mockExtension));
        assertEq(factories_.length, 1);
        assertEq(factories_[0], address(mockFactory));

        // Verify actionIdsByAccount with factory filter
        address[] memory filterFactories = new address[](1);
        filterFactories[0] = address(mockFactory);
        (actionIds, extensions, factories_) = extensionCenter
            .actionIdsByAccount(tokenAddress, user1, filterFactories);
        assertEq(actionIds.length, 1);
        assertEq(actionIds[0], actionId1);
        assertEq(extensions[0], address(mockExtension));
        assertEq(factories_[0], address(mockFactory));
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

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // Try to add account from non-extension address
        vm.prank(user1);
        vm.expectRevert(IExtensionCenter.OnlyExtensionOrDelegate.selector);
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );
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
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // Add account first time
        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Try to add again
        vm.expectRevert(IExtensionCenter.AccountAlreadyJoined.selector);
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );
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
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Remove account
        vm.expectEmit(true, true, true, false);
        emit RemoveAccount(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1,
            user1
        );
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);
        vm.stopPrank();

        // Verify
        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
        (uint256[] memory actionIds, , ) = extensionCenter.actionIdsByAccount(
            tokenAddress,
            user1,
            new address[](0)
        );
        assertEq(actionIds.length, 0);
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
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Try to remove from non-extension address
        vm.prank(user1);
        vm.expectRevert(IExtensionCenter.OnlyExtensionOrDelegate.selector);
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);
    }

    function testRemoveAccountRevertsIfNotBoundToExtension() public {
        // No registration, should revert
        vm.prank(user1);
        vm.expectRevert(IExtensionCenter.OnlyExtensionOrDelegate.selector);
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
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        MockExtension mockExtension2 = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId2,
            address(mockExtension2)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId2
        );

        // Register actions before calling write functions
        _registerAction(tokenAddress, actionId1);
        _registerAction(tokenAddress, actionId2);

        // Add user1 to both actions
        vm.prank(address(mockExtension1));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        vm.prank(address(mockExtension2));
        extensionCenter.addAccount(
            tokenAddress,
            actionId2,
            user1,
            new string[](0)
        );

        // Add user2 to action1 only
        vm.prank(address(mockExtension1));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );

        // Verify user1 is in both actions
        (
            uint256[] memory user1ActionIds,
            address[] memory user1Extensions,
            address[] memory user1Factories
        ) = extensionCenter.actionIdsByAccount(
                tokenAddress,
                user1,
                new address[](0)
            );
        assertEq(user1ActionIds.length, 2);
        assertEq(user1Extensions.length, 2);
        assertEq(user1Factories.length, 2);

        // Verify user2 is in one action
        (
            uint256[] memory user2ActionIds,
            address[] memory user2Extensions,
            address[] memory user2Factories
        ) = extensionCenter.actionIdsByAccount(
                tokenAddress,
                user2,
                new address[](0)
            );
        assertEq(user2ActionIds.length, 1);
        assertEq(user2ActionIds[0], actionId1);
        assertEq(user2Extensions.length, 1);
        assertEq(user2Extensions[0], address(mockExtension1));
        assertEq(user2Factories.length, 1);
        assertEq(user2Factories[0], address(mockFactory));
    }

    // ------ Extension and Factory queries tests ------

    function testActionIdsByAccountWithFactoryFilter() public {
        // Create two extensions with different factories
        MockExtensionFactory mockFactory2 = new MockExtensionFactory(
            address(extensionCenter)
        );
        // Approve token for mockFactory2
        MockToken(tokenAddress).approve(
            address(mockFactory2),
            type(uint256).max
        );

        MockExtension mockExtension1 = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        MockExtension mockExtension2 = MockExtension(
            mockFactory2.createExtension(tokenAddress)
        );

        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension1)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId2,
            address(mockExtension2)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId2
        );

        // Register actions before calling write functions
        _registerAction(tokenAddress, actionId1);
        _registerAction(tokenAddress, actionId2);

        // Add user1 to both actions
        vm.prank(address(mockExtension1));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        vm.prank(address(mockExtension2));
        extensionCenter.addAccount(
            tokenAddress,
            actionId2,
            user1,
            new string[](0)
        );

        // Test with empty factories array (should return all)
        (
            uint256[] memory actionIds,
            address[] memory extensions,
            address[] memory factories_
        ) = extensionCenter.actionIdsByAccount(
                tokenAddress,
                user1,
                new address[](0)
            );
        assertEq(actionIds.length, 2);
        assertEq(extensions.length, 2);
        assertEq(factories_.length, 2);

        // Verify factories are recorded
        assertEq(
            extensionCenter.factory(tokenAddress, actionId1),
            address(mockFactory),
            "Factory should be recorded for actionId1"
        );
        assertEq(
            extensionCenter.factory(tokenAddress, actionId2),
            address(mockFactory2),
            "Factory should be recorded for actionId2"
        );

        // Test with factory filter (only mockFactory)
        address[] memory filterFactories = new address[](1);
        filterFactories[0] = address(mockFactory);
        (actionIds, extensions, factories_) = extensionCenter
            .actionIdsByAccount(tokenAddress, user1, filterFactories);
        assertEq(actionIds.length, 1, "Should have 1 actionId for mockFactory");
        assertEq(extensions.length, 1, "Should have 1 extension");
        assertEq(factories_.length, 1, "Should have 1 factory");
        assertEq(actionIds[0], actionId1);
        assertEq(extensions[0], address(mockExtension1));
        assertEq(factories_[0], address(mockFactory));

        // Test with factory filter (only mockFactory2)
        filterFactories[0] = address(mockFactory2);
        (actionIds, extensions, factories_) = extensionCenter
            .actionIdsByAccount(tokenAddress, user1, filterFactories);
        assertEq(
            actionIds.length,
            1,
            "Should have 1 actionId for mockFactory2"
        );
        assertEq(extensions.length, 1, "Should have 1 extension");
        assertEq(factories_.length, 1, "Should have 1 factory");
        assertEq(actionIds[0], actionId2);
        assertEq(extensions[0], address(mockExtension2));
        assertEq(factories_[0], address(mockFactory2));

        // Test with both factories in filter
        filterFactories = new address[](2);
        filterFactories[0] = address(mockFactory);
        filterFactories[1] = address(mockFactory2);
        (actionIds, extensions, factories_) = extensionCenter
            .actionIdsByAccount(tokenAddress, user1, filterFactories);
        assertEq(actionIds.length, 2);
        assertEq(extensions.length, 2);
        assertEq(factories_.length, 2);
    }

    function testAddAccountRecordsExtensionAndFactoryOnlyOnce() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // First addAccount should record extension and factory
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        address recordedExtension = extensionCenter.extension(
            tokenAddress,
            actionId1
        );
        address recordedFactory = extensionCenter.factory(
            tokenAddress,
            actionId1
        );

        // Second addAccount should not change the recorded extension and factory
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );

        assertEq(
            extensionCenter.extension(tokenAddress, actionId1),
            recordedExtension
        );
        assertEq(
            extensionCenter.factory(tokenAddress, actionId1),
            recordedFactory
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

        (
            uint256[] memory actionIds,
            address[] memory extensions,
            address[] memory factories_
        ) = extensionCenter.actionIdsByAccount(
                tokenAddress,
                user1,
                new address[](0)
            );
        assertEq(actionIds.length, 0);
        assertEq(extensions.length, 0);
        assertEq(factories_.length, 0);
    }

    // ------ Verification info tests ------
    function testAddAccountWithVerificationInfo() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Set verification keys
        string[] memory keys = new string[](2);
        keys[0] = "email";
        keys[1] = "twitter";
        mockSubmit.setVerificationKeys(tokenAddress, actionId1, keys);

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // Add account with verification info
        string[] memory infos = new string[](2);
        infos[0] = "user1@example.com";
        infos[1] = "@user1";

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(tokenAddress, actionId1, user1, infos);

        // Verify
        assertEq(
            extensionCenter.verificationInfo(
                tokenAddress,
                actionId1,
                user1,
                "email"
            ),
            "user1@example.com"
        );
        assertEq(
            extensionCenter.verificationInfo(
                tokenAddress,
                actionId1,
                user1,
                "twitter"
            ),
            "@user1"
        );
    }

    function testUpdateVerificationInfo() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Set verification keys
        string[] memory keys = new string[](1);
        keys[0] = "email";
        mockSubmit.setVerificationKeys(tokenAddress, actionId1, keys);

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // Add account first
        string[] memory infos = new string[](1);
        infos[0] = "old@example.com";
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(tokenAddress, actionId1, user1, infos);

        // Update verification info
        string[] memory newInfos = new string[](1);
        newInfos[0] = "new@example.com";

        vm.prank(address(mockExtension));
        extensionCenter.updateVerificationInfo(
            tokenAddress,
            actionId1,
            user1,
            newInfos
        );

        // Verify updated
        assertEq(
            extensionCenter.verificationInfo(
                tokenAddress,
                actionId1,
                user1,
                "email"
            ),
            "new@example.com"
        );
    }

    function testUpdateVerificationInfoEmitsEvent() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        string[] memory keys = new string[](1);
        keys[0] = "email";
        mockSubmit.setVerificationKeys(tokenAddress, actionId1, keys);

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        string[] memory newInfos = new string[](1);
        newInfos[0] = "test@example.com";

        uint256 currentRound = mockJoin.currentRound();

        vm.prank(address(mockExtension));
        vm.expectEmit(true, true, true, true);
        emit UpdateVerificationInfo(
            tokenAddress,
            currentRound,
            actionId1,
            user1,
            "email",
            "test@example.com"
        );
        extensionCenter.updateVerificationInfo(
            tokenAddress,
            actionId1,
            user1,
            newInfos
        );
    }

    function testUpdateVerificationInfoRevertsIfNotExtensionOrAccount() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        string[] memory infos = new string[](0);

        vm.prank(user1);
        extensionCenter.updateVerificationInfo(
            tokenAddress,
            actionId1,
            user1,
            infos
        );

        vm.prank(user2);
        vm.expectRevert(
            IExtensionCenter.OnlyUserOrExtensionOrDelegate.selector
        );
        extensionCenter.updateVerificationInfo(
            tokenAddress,
            actionId1,
            user1,
            infos
        );
    }

    function testVerificationInfoByRound() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        string[] memory keys = new string[](1);
        keys[0] = "email";
        mockSubmit.setVerificationKeys(tokenAddress, actionId1, keys);

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // Add account at round 1
        string[] memory infos1 = new string[](1);
        infos1[0] = "round1@example.com";
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(tokenAddress, actionId1, user1, infos1);

        uint256 round1 = mockJoin.currentRound();

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);

        // Update at round 2
        string[] memory infos2 = new string[](1);
        infos2[0] = "round2@example.com";
        vm.prank(address(mockExtension));
        extensionCenter.updateVerificationInfo(
            tokenAddress,
            actionId1,
            user1,
            infos2
        );

        // Query by round
        assertEq(
            extensionCenter.verificationInfoByRound(
                tokenAddress,
                actionId1,
                user1,
                "email",
                round1
            ),
            "round1@example.com"
        );
        assertEq(
            extensionCenter.verificationInfoByRound(
                tokenAddress,
                actionId1,
                user1,
                "email",
                round1 + 1
            ),
            "round2@example.com"
        );
        // Latest should be round2
        assertEq(
            extensionCenter.verificationInfo(
                tokenAddress,
                actionId1,
                user1,
                "email"
            ),
            "round2@example.com"
        );
    }

    function testAddAccountRevertsOnVerificationInfoLengthMismatch() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Set 2 verification keys
        string[] memory keys = new string[](2);
        keys[0] = "email";
        keys[1] = "twitter";
        mockSubmit.setVerificationKeys(tokenAddress, actionId1, keys);

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // Try to add with only 1 info (mismatch)
        string[] memory infos = new string[](1);
        infos[0] = "user1@example.com";

        vm.prank(address(mockExtension));
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionCenter.VerificationInfoLengthMismatch.selector,
                2,
                1
            )
        );
        extensionCenter.addAccount(tokenAddress, actionId1, user1, infos);
    }

    function testUpdateVerificationInfoRevertsOnLengthMismatch() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Set 2 verification keys
        string[] memory keys = new string[](2);
        keys[0] = "email";
        keys[1] = "twitter";
        mockSubmit.setVerificationKeys(tokenAddress, actionId1, keys);

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        // Add account without verification info (empty array skips check)
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Try to update with mismatched length
        string[] memory infos = new string[](1);
        infos[0] = "user1@example.com";

        vm.prank(address(mockExtension));
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionCenter.VerificationInfoLengthMismatch.selector,
                2,
                1
            )
        );
        extensionCenter.updateVerificationInfo(
            tokenAddress,
            actionId1,
            user1,
            infos
        );
    }

    function testVerificationInfoEmptyForNonExistentKey() public view {
        // Query non-existent verification info
        assertEq(
            extensionCenter.verificationInfo(
                tokenAddress,
                actionId1,
                user1,
                "nonexistent"
            ),
            ""
        );
    }

    // ------ accounts by round tests ------
    function testAccountsByRound() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Add accounts at round 1
        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );
        vm.stopPrank();

        // Verify accountsByRound at round 1
        address[] memory accountsRound1 = extensionCenter.accountsByRound(
            tokenAddress,
            actionId1,
            round1
        );
        assertEq(accountsRound1.length, 2);
        assertTrue(
            (accountsRound1[0] == user1 || accountsRound1[0] == user2) &&
                (accountsRound1[1] == user1 || accountsRound1[1] == user2)
        );
        assertTrue(accountsRound1[0] != accountsRound1[1]);

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Remove user1 first (since user1 already joined in round 1, must remove before adding in round 2)
        vm.prank(address(mockExtension));
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        uint256 round2 = mockJoin.currentRound();

        // Verify accountsByRound at round 2
        // Note: After removing user1, user2 moves to index 0 (swap-and-pop), then user1 is added at index 1
        address[] memory accountsRound2 = extensionCenter.accountsByRound(
            tokenAddress,
            actionId1,
            round2
        );
        assertEq(accountsRound2.length, 2);
        assertEq(accountsRound2[0], user2); // user2 moved to index 0 after user1 removal
        assertEq(accountsRound2[1], user1); // user1 added at index 1

        // Verify round 1 data is still accessible
        address[] memory accountsRound1Again = extensionCenter.accountsByRound(
            tokenAddress,
            actionId1,
            round1
        );
        assertEq(accountsRound1Again.length, 2);
    }

    function testAccountsByRoundCount() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Add accounts at round 1
        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );
        vm.stopPrank();

        // Verify accountsByRoundCount at round 1
        assertEq(
            extensionCenter.accountsByRoundCount(
                tokenAddress,
                actionId1,
                round1
            ),
            2
        );

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Verify that round 2 initially has the same count as round 1 (before any changes in round 2)
        assertEq(
            extensionCenter.accountsByRoundCount(
                tokenAddress,
                actionId1,
                round1 + 1
            ),
            2
        );

        // Remove user1 first (since user1 already joined in round 1, must remove before adding in round 2)
        vm.prank(address(mockExtension));
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        uint256 round2 = mockJoin.currentRound();

        // Verify accountsByRoundCount at round 2
        assertEq(
            extensionCenter.accountsByRoundCount(
                tokenAddress,
                actionId1,
                round2
            ),
            2
        );

        // Verify round 1 count is still 2
        assertEq(
            extensionCenter.accountsByRoundCount(
                tokenAddress,
                actionId1,
                round1
            ),
            2
        );
    }

    function testAccountsByRoundAtIndex() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Add accounts at round 1
        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );
        vm.stopPrank();

        // Verify accountsByRoundAtIndex at round 1
        address account0 = extensionCenter.accountsByRoundAtIndex(
            tokenAddress,
            actionId1,
            0,
            round1
        );
        address account1 = extensionCenter.accountsByRoundAtIndex(
            tokenAddress,
            actionId1,
            1,
            round1
        );
        // Verify order: user1 added first (index 0), user2 added second (index 1)
        assertEq(account0, user1);
        assertEq(account1, user2);

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Remove user1 first (since user1 already joined in round 1, must remove before adding in round 2)
        vm.prank(address(mockExtension));
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        uint256 round2 = mockJoin.currentRound();

        // Verify accountsByRoundAtIndex at round 2
        // Note: After removing user1, user2 moves to index 0 (swap-and-pop), then user1 is added at index 1
        address account0Round2 = extensionCenter.accountsByRoundAtIndex(
            tokenAddress,
            actionId1,
            0,
            round2
        );
        address account1Round2 = extensionCenter.accountsByRoundAtIndex(
            tokenAddress,
            actionId1,
            1,
            round2
        );
        assertEq(account0Round2, user2); // user2 moved to index 0 after user1 removal
        assertEq(account1Round2, user1); // user1 added at index 1

        // Verify round 1 data is still accessible
        address account0Round1Again = extensionCenter.accountsByRoundAtIndex(
            tokenAddress,
            actionId1,
            0,
            round1
        );
        assertEq(account0Round1Again, user1); // user1 was at index 0 in round 1
    }

    function testAccountsByRoundMultipleRounds() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Add user1 at round 1
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Add user2 at round 2
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );

        uint256 round2 = mockJoin.currentRound();

        // Verify round 1 has only user1
        assertEq(
            extensionCenter.accountsByRoundCount(
                tokenAddress,
                actionId1,
                round1
            ),
            1
        );
        address[] memory accountsRound1 = extensionCenter.accountsByRound(
            tokenAddress,
            actionId1,
            round1
        );
        assertEq(accountsRound1.length, 1);
        assertEq(accountsRound1[0], user1);

        // Verify round 2 has both users
        assertEq(
            extensionCenter.accountsByRoundCount(
                tokenAddress,
                actionId1,
                round2
            ),
            2
        );
        address[] memory accountsRound2 = extensionCenter.accountsByRound(
            tokenAddress,
            actionId1,
            round2
        );
        assertEq(accountsRound2.length, 2);
        assertEq(accountsRound2[0], user1); // user1 from round 1
        assertEq(accountsRound2[1], user2); // user2 added in round 2
    }

    function testAccountsByRoundEmpty() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );

        uint256 round1 = mockJoin.currentRound();

        // Query empty accounts by round
        assertEq(
            extensionCenter.accountsByRoundCount(
                tokenAddress,
                actionId1,
                round1
            ),
            0
        );
        address[] memory accounts = extensionCenter.accountsByRound(
            tokenAddress,
            actionId1,
            round1
        );
        assertEq(accounts.length, 0);
    }

    function testAccountsByRoundConsistency() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Register action before calling write function
        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Add multiple accounts
        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );
        vm.stopPrank();

        // Verify consistency between accountsByRound, accountsByRoundCount, and accountsByRoundAtIndex
        uint256 count = extensionCenter.accountsByRoundCount(
            tokenAddress,
            actionId1,
            round1
        );
        address[] memory accounts = extensionCenter.accountsByRound(
            tokenAddress,
            actionId1,
            round1
        );

        assertEq(count, accounts.length);
        assertEq(count, 2);

        for (uint256 i = 0; i < count; i++) {
            address accountAtIndex = extensionCenter.accountsByRoundAtIndex(
                tokenAddress,
                actionId1,
                i,
                round1
            );
            assertEq(accountAtIndex, accounts[i]);
        }
    }

    // ============================================
    // isAccountJoined Tests
    // ============================================

    function testIsAccountJoined_NotJoined() public view {
        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
    }

    function testIsAccountJoined_AfterAdd() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
    }

    function testIsAccountJoined_AfterRemove() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );
        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );

        extensionCenter.removeAccount(tokenAddress, actionId1, user1);
        vm.stopPrank();

        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
    }

    function testIsAccountJoined_MultipleAccounts() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        vm.startPrank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );
        vm.stopPrank();

        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user2)
        );
        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, govHolder)
        );
    }

    function testIsAccountJoined_MultipleActions() public {
        MockExtension mockExtension1 = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension1)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        MockExtension mockExtension2 = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId2,
            address(mockExtension2)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId2
        );

        _registerAction(tokenAddress, actionId1);
        _registerAction(tokenAddress, actionId2);

        vm.prank(address(mockExtension1));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        vm.prank(address(mockExtension2));
        extensionCenter.addAccount(
            tokenAddress,
            actionId2,
            user1,
            new string[](0)
        );

        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId2, user1)
        );
        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user2)
        );
        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId2, user2)
        );
    }

    // ============================================
    // isAccountJoinedByRound Tests
    // ============================================

    function testIsAccountJoinedByRound_NotJoined() public view {
        assertFalse(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                1
            )
        );
    }

    function testIsAccountJoinedByRound_AfterAdd() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        assertFalse(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round1
            )
        );

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round1
            )
        );
    }

    function testIsAccountJoinedByRound_MultipleRounds() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Add user1 at round 1
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        // Add user2 at round 2
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );

        uint256 round2 = mockJoin.currentRound();

        // Verify round 1: user1 joined, user2 not joined
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round1
            )
        );
        assertFalse(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user2,
                round1
            )
        );

        // Verify round 2: both users joined
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round2
            )
        );
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user2,
                round2
            )
        );
    }

    function testIsAccountJoinedByRound_AfterRemove() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round1
            )
        );

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        uint256 round2 = mockJoin.currentRound();

        // Remove user1 at round 2
        vm.prank(address(mockExtension));
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);

        // Verify round 1: user1 still joined (historical state)
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round1
            )
        );

        // Verify round 2: user1 not joined
        assertFalse(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round2
            )
        );
    }

    function testIsAccountJoinedByRound_RejoinAfterRemove() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Add user1 at round 1
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        uint256 round2 = mockJoin.currentRound();

        // Remove user1 at round 2
        vm.prank(address(mockExtension));
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);

        // Rejoin user1 at round 2
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Verify round 1: user1 joined
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round1
            )
        );

        // Verify round 2: user1 joined (after rejoin)
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round2
            )
        );
    }

    function testIsAccountJoinedByRound_FutureRound() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Query future round (should return false as account not joined in future)
        vm.expectRevert(
            abi.encodeWithSelector(
                IExtensionCenter.RoundExceedsJoinRound.selector,
                round1 + 100,
                round1
            )
        );
        extensionCenter.isAccountJoinedByRound(
            tokenAddress,
            actionId1,
            user1,
            round1 + 100
        );
    }

    function testIsAccountJoinedByRound_PastRound() public {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Query past round before account joined (should return false)
        assertFalse(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round1 - 1
            )
        );

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Query round 0 (should return false if round1 > 0)
        if (round1 > 0) {
            assertFalse(
                extensionCenter.isAccountJoinedByRound(
                    tokenAddress,
                    actionId1,
                    user1,
                    0
                )
            );
        }
    }

    function testIsAccountJoinedByRound_MultipleAccountsMultipleRounds()
        public
    {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        uint256 round1 = mockJoin.currentRound();

        // Add user1 at round 1
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // Advance to round 2
        mockJoin.setCurrentRound(round1 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        uint256 round2 = mockJoin.currentRound();

        // Add user2 at round 2
        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user2,
            new string[](0)
        );

        // Advance to round 3
        mockJoin.setCurrentRound(round2 + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        uint256 round3 = mockJoin.currentRound();

        // Remove user1 at round 3
        vm.prank(address(mockExtension));
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);

        // Verify all rounds for both users
        // Round 1
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round1
            )
        );
        assertFalse(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user2,
                round1
            )
        );

        // Round 2
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round2
            )
        );
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user2,
                round2
            )
        );

        // Round 3
        assertFalse(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                round3
            )
        );
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user2,
                round3
            )
        );
    }

    function testIsAccountJoinedByRound_ConsistencyWithIsAccountJoined()
        public
    {
        MockExtension mockExtension = MockExtension(
            mockFactory.createExtension(tokenAddress)
        );
        mockSubmit.setActionInfo(
            tokenAddress,
            actionId1,
            address(mockExtension)
        );
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        _registerAction(tokenAddress, actionId1);

        uint256 currentRound = mockJoin.currentRound();

        vm.prank(address(mockExtension));
        extensionCenter.addAccount(
            tokenAddress,
            actionId1,
            user1,
            new string[](0)
        );

        // isAccountJoined should match isAccountJoinedByRound for current round
        assertTrue(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                currentRound
            )
        );

        // Advance to next round
        mockJoin.setCurrentRound(currentRound + 1);
        mockVote.setVotedActionIds(
            tokenAddress,
            mockJoin.currentRound(),
            actionId1
        );

        uint256 newRound = mockJoin.currentRound();

        // Remove user1
        vm.prank(address(mockExtension));
        extensionCenter.removeAccount(tokenAddress, actionId1, user1);

        // isAccountJoined should be false
        assertFalse(
            extensionCenter.isAccountJoined(tokenAddress, actionId1, user1)
        );

        // But historical round should still show joined
        assertTrue(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                currentRound
            )
        );

        // Current round should show not joined
        assertFalse(
            extensionCenter.isAccountJoinedByRound(
                tokenAddress,
                actionId1,
                user1,
                newRound
            )
        );
    }
}
