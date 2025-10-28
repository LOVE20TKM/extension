// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "./interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20ExtensionFactory} from "./interface/ILOVE20ExtensionFactory.sol";
import {ILOVE20Extension} from "./interface/ILOVE20Extension.sol";
import {ILOVE20Submit, ActionInfo} from "@love20/interfaces/ILOVE20Submit.sol";
import {ILOVE20Join} from "@love20/interfaces/ILOVE20Join.sol";
import {ArrayUtils} from "@love20/lib/ArrayUtils.sol";

contract LOVE20ExtensionCenter is ILOVE20ExtensionCenter {
    // ------ state variables ------
    address public immutable uniswapV2FactoryAddress;
    address public immutable launchAddress;
    address public immutable stakeAddress;
    address public immutable submitAddress;
    address public immutable voteAddress;
    address public immutable joinAddress;
    address public immutable verifyAddress;
    address public immutable mintAddress;
    address public immutable randomAddress;

    // tokenAddress => factory[]
    mapping(address => address[]) internal _factories;
    // tokenAddress => factory => bool
    mapping(address => mapping(address => bool)) internal _existsFactory;

    // tokenAddress => actionId => extension
    mapping(address => mapping(uint256 => address)) internal _extension;

    // extension => (tokenAddress, actionId)
    mapping(address => ExtensionInfo) internal _extensionInfos;

    // tokenAddress => extensions array
    mapping(address => address[]) internal _extensions;

    // tokenAddress => actionId => account => bool
    mapping(address => mapping(uint256 => mapping(address => bool)))
        internal _isAccountJoined;

    // tokenAddress => account => actionIds array
    mapping(address => mapping(address => uint256[]))
        internal _actionIdsByAccount;

    // ------ modifiers ------
    modifier onlyExtension(address tokenAddress, uint256 actionId) {
        if (_extension[tokenAddress][actionId] != msg.sender) {
            revert OnlyExtensionCanCall();
        }
        _;
    }

    // ------ constructor ------
    constructor(
        address uniswapV2FactoryAddress_,
        address launchAddress_,
        address stakeAddress_,
        address submitAddress_,
        address voteAddress_,
        address joinAddress_,
        address verifyAddress_,
        address mintAddress_,
        address randomAddress_
    ) {
        if (uniswapV2FactoryAddress_ == address(0))
            revert InvalidUniswapV2FactoryAddress();
        if (launchAddress_ == address(0)) revert InvalidLaunchAddress();
        if (stakeAddress_ == address(0)) revert InvalidStakeAddress();
        if (submitAddress_ == address(0)) revert InvalidSubmitAddress();
        if (voteAddress_ == address(0)) revert InvalidVoteAddress();
        if (joinAddress_ == address(0)) revert InvalidJoinAddress();
        if (verifyAddress_ == address(0)) revert InvalidVerifyAddress();
        if (mintAddress_ == address(0)) revert InvalidMintAddress();
        if (randomAddress_ == address(0)) revert InvalidRandomAddress();

        uniswapV2FactoryAddress = uniswapV2FactoryAddress_;
        launchAddress = launchAddress_;
        stakeAddress = stakeAddress_;
        submitAddress = submitAddress_;
        voteAddress = voteAddress_;
        joinAddress = joinAddress_;
        verifyAddress = verifyAddress_;
        mintAddress = mintAddress_;
        randomAddress = randomAddress_;
    }

    // ------ register extension factory ------
    function addFactory(address tokenAddress, address factory) external {
        if (ILOVE20ExtensionFactory(factory).center() != address(this)) {
            revert InvalidExtensionFactory();
        }
        if (_existsFactory[tokenAddress][factory])
            revert ExtensionFactoryAlreadyExists();

        if (!ILOVE20Submit(submitAddress).canSubmit(tokenAddress, msg.sender))
            revert NotEnoughGovVotes();
        emit ExtensionFactoryAdded(tokenAddress, factory);
        _existsFactory[tokenAddress][factory] = true;
        _factories[tokenAddress].push(factory);
    }

    function existsFactory(
        address tokenAddress,
        address factory
    ) external view returns (bool) {
        return _existsFactory[tokenAddress][factory];
    }

    function factories(
        address tokenAddress
    ) external view returns (address[] memory) {
        return _factories[tokenAddress];
    }

    function factoriesCount(
        address tokenAddress
    ) external view returns (uint256) {
        return _factories[tokenAddress].length;
    }

    function factoriesAtIndex(
        address tokenAddress,
        uint256 index
    ) external view returns (address) {
        return _factories[tokenAddress][index];
    }

    // ------ extensions management ------
    function initializeExtension(
        address extensionAddress,
        address tokenAddress,
        uint256 actionId
    ) external {
        ILOVE20Extension ext = ILOVE20Extension(extensionAddress);
        // check if extension already exists for this tokenAddress and actionId
        if (_extension[tokenAddress][actionId] != address(0)) {
            revert ExtensionAlreadyExists();
        }

        if (!_existsFactory[tokenAddress][ext.factory()])
            revert InvalidExtensionFactory();

        ILOVE20ExtensionFactory extFactory = ILOVE20ExtensionFactory(
            ext.factory()
        );
        if (!extFactory.exists(extensionAddress))
            revert ExtensionNotFoundInFactory();

        // initialize the extension
        try ext.initialize(tokenAddress, actionId) {
            // check if extension is in white list
            ILOVE20Submit submit = ILOVE20Submit(submitAddress);
            ActionInfo memory actionInfo = submit.actionInfo(
                tokenAddress,
                actionId
            );
            if (actionInfo.body.whiteListAddress != extensionAddress)
                revert InvalidWhiteListAddress();

            // check if already successfully joined through joinAddress
            ILOVE20Join join = ILOVE20Join(joinAddress);
            if (
                join.amountByActionIdByAccount(
                    tokenAddress,
                    actionId,
                    extensionAddress
                ) == 0
            ) {
                revert ExtensionNotJoinedAction();
            }

            // register extension
            _extension[tokenAddress][actionId] = extensionAddress;
            _extensionInfos[extensionAddress] = ExtensionInfo({
                tokenAddress: tokenAddress,
                actionId: actionId
            });
            _extensions[tokenAddress].push(extensionAddress);

            emit ExtensionInitialized(tokenAddress, actionId, extensionAddress);
        } catch {
            revert InitializeFailed();
        }
    }

    function extension(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address) {
        return _extension[tokenAddress][actionId];
    }

    function extensionInfo(
        address extensionAddress
    ) external view returns (address tokenAddress, uint256 actionId) {
        ExtensionInfo memory info = _extensionInfos[extensionAddress];
        return (info.tokenAddress, info.actionId);
    }

    function extensions(
        address tokenAddress
    ) external view returns (address[] memory) {
        return _extensions[tokenAddress];
    }

    function extensionsCount(
        address tokenAddress
    ) external view returns (uint256) {
        return _extensions[tokenAddress].length;
    }

    function extensionsAtIndex(
        address tokenAddress,
        uint256 index
    ) external view returns (address) {
        return _extensions[tokenAddress][index];
    }

    // ------ account management (only extension can call) ------
    function addAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external onlyExtension(tokenAddress, actionId) {
        if (_isAccountJoined[tokenAddress][actionId][account]) {
            revert AccountAlreadyJoined();
        }

        // set account joined
        _isAccountJoined[tokenAddress][actionId][account] = true;

        // add actionId to account's list
        _actionIdsByAccount[tokenAddress][account].push(actionId);

        emit AccountAdded(tokenAddress, actionId, account);
    }

    function removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external onlyExtension(tokenAddress, actionId) {
        if (!_isAccountJoined[tokenAddress][actionId][account]) {
            revert AccountNotJoined();
        }

        // set account joined to false
        _isAccountJoined[tokenAddress][actionId][account] = false;

        // remove actionId from account's list
        ArrayUtils.remove(_actionIdsByAccount[tokenAddress][account], actionId);

        emit AccountRemoved(tokenAddress, actionId, account);
    }

    // ------ account status queries ------
    function isAccountJoined(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (bool) {
        return _isAccountJoined[tokenAddress][actionId][account];
    }

    function actionIdsByAccount(
        address tokenAddress,
        address account
    ) external view returns (uint256[] memory) {
        return _actionIdsByAccount[tokenAddress][account];
    }

    function actionIdsByAccountCount(
        address tokenAddress,
        address account
    ) external view returns (uint256) {
        return _actionIdsByAccount[tokenAddress][account].length;
    }

    function actionIdsByAccountAtIndex(
        address tokenAddress,
        address account,
        uint256 index
    ) external view returns (uint256) {
        return _actionIdsByAccount[tokenAddress][account][index];
    }
}
