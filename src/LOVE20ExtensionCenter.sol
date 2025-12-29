// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20ExtensionCenter} from "./interface/ILOVE20ExtensionCenter.sol";
import {ILOVE20Submit, ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {ILOVE20Join} from "@core/interfaces/ILOVE20Join.sol";
import {ILOVE20Vote} from "@core/interfaces/ILOVE20Vote.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";
import {RoundHistoryUint256} from "./lib/RoundHistoryUint256.sol";
import {RoundHistoryAddress} from "./lib/RoundHistoryAddress.sol";
import {RoundHistoryString} from "./lib/RoundHistoryString.sol";
import {IExtensionCore} from "./interface/base/IExtensionCore.sol";
import {ILOVE20ExtensionFactory} from "./interface/ILOVE20ExtensionFactory.sol";

contract LOVE20ExtensionCenter is ILOVE20ExtensionCenter {
    using RoundHistoryUint256 for RoundHistoryUint256.History;
    using RoundHistoryAddress for RoundHistoryAddress.History;
    using RoundHistoryString for RoundHistoryString.History;

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

    // tokenAddress => actionId => account => bool
    mapping(address => mapping(uint256 => mapping(address => bool)))
        internal _isAccountJoined;

    // tokenAddress => account => actionIds array
    mapping(address => mapping(address => uint256[]))
        internal _actionIdsByAccount;

    // tokenAddress => actionId => accountsCount history
    mapping(address => mapping(uint256 => RoundHistoryUint256.History))
        internal _accountsCountHistory;

    // tokenAddress => actionId => index => account history
    mapping(address => mapping(uint256 => mapping(uint256 => RoundHistoryAddress.History)))
        internal _accountsAtIndexHistory;

    // tokenAddress => actionId => account => index history
    mapping(address => mapping(uint256 => mapping(address => RoundHistoryUint256.History)))
        internal _accountsIndexHistory;

    // tokenAddress => actionId => account => verificationKey => History
    mapping(address => mapping(uint256 => mapping(address => mapping(string => RoundHistoryString.History))))
        internal _verificationInfoHistory;

    // extension => delegate address
    mapping(address => address) internal _extensionDelegate;

    // tokenAddress => actionId => extension address
    mapping(address => mapping(uint256 => address))
        internal _extensionByActionId;

    // tokenAddress => actionId => factory address
    mapping(address => mapping(uint256 => address)) internal _factoryByActionId;

    // ------ modifiers ------
    modifier onlyExtension(address tokenAddress, uint256 actionId) {
        if (!_isValidExtensionOrDelegate(tokenAddress, actionId, msg.sender)) {
            revert OnlyExtensionCanCall();
        }
        _;
    }

    // ------ internal helpers ------
    function _isValidExtensionOrDelegate(
        address tokenAddress,
        uint256 actionId,
        address caller
    ) internal view returns (bool) {
        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        address extensionAddress = actionInfo.body.whiteListAddress;
        if (caller == extensionAddress) return true;

        address delegateAddress = _extensionDelegate[extensionAddress];
        return caller == delegateAddress;
    }

    function _getExtensionAddress(
        address tokenAddress,
        uint256 actionId,
        address caller
    ) internal view returns (address) {
        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        address extensionAddress = actionInfo.body.whiteListAddress;
        if (caller == extensionAddress) return extensionAddress;

        address delegateAddress = _extensionDelegate[extensionAddress];
        if (caller == delegateAddress) return extensionAddress;

        return address(0);
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

    // ------ extension query ------
    function extension(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address) {
        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        return actionInfo.body.whiteListAddress;
    }

    function extensionByActionId(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address) {
        return _extensionByActionId[tokenAddress][actionId];
    }

    function factoryByActionId(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address) {
        return _factoryByActionId[tokenAddress][actionId];
    }

    // ------ extension delegate management ------
    /// @inheritdoc ILOVE20ExtensionCenter
    function setExtensionDelegate(address delegate) external {
        address extensionAddress = msg.sender;

        _extensionDelegate[extensionAddress] = delegate;

        emit ExtensionDelegateSet(extensionAddress, delegate);
    }

    /// @inheritdoc ILOVE20ExtensionCenter
    function extensionDelegate(
        address extensionAddress
    ) external view returns (address) {
        return _extensionDelegate[extensionAddress];
    }

    // ------ account management (only extension can call) ------
    function addAccount(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external onlyExtension(tokenAddress, actionId) {
        uint256 currentRound = ILOVE20Join(joinAddress).currentRound();

        if (
            !ILOVE20Vote(voteAddress).isActionIdVoted(
                tokenAddress,
                currentRound,
                actionId
            )
        ) {
            revert ActionNotVotedInCurrentRound();
        }

        if (_isAccountJoined[tokenAddress][actionId][account]) {
            revert AccountAlreadyJoined();
        }

        // Get extension address and verify factory
        address extensionAddress = _getExtensionAddress(
            tokenAddress,
            actionId,
            msg.sender
        );
        if (extensionAddress == address(0)) {
            revert OnlyExtensionCanCall();
        }

        // If extension and factory are already recorded, skip verification
        address factoryAddress = _factoryByActionId[tokenAddress][actionId];
        if (factoryAddress == address(0)) {
            // Get factory from extension and verify
            try IExtensionCore(extensionAddress).factory() returns (
                address factory
            ) {
                if (factory == address(0)) {
                    revert InvalidExtensionFactory();
                }
                factoryAddress = factory;
            } catch {
                revert InvalidExtensionFactory();
            }
            // Verify extension exists in factory
            if (
                !ILOVE20ExtensionFactory(factoryAddress).exists(
                    extensionAddress
                )
            ) {
                revert ExtensionNotFoundInFactory();
            }

            // Record extension and factory for this actionId
            _extensionByActionId[tokenAddress][actionId] = extensionAddress;
            _factoryByActionId[tokenAddress][actionId] = factoryAddress;
        }

        // set account joined
        _isAccountJoined[tokenAddress][actionId][account] = true;

        // add actionId to account's list
        _actionIdsByAccount[tokenAddress][account].push(actionId);

        // add account to action's list using RoundHistory
        uint256 accountCount = _accountsCountHistory[tokenAddress][actionId]
            .latestValue();
        _accountsAtIndexHistory[tokenAddress][actionId][accountCount].record(
            currentRound,
            account
        );
        _accountsIndexHistory[tokenAddress][actionId][account].record(
            currentRound,
            accountCount
        );
        _accountsCountHistory[tokenAddress][actionId].record(
            currentRound,
            accountCount + 1
        );

        // store verification info
        _storeVerificationInfo(
            tokenAddress,
            actionId,
            account,
            verificationInfos,
            currentRound
        );

        emit AccountAdded(tokenAddress, actionId, account);
    }

    function removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external onlyExtension(tokenAddress, actionId) {
        _removeAccount(tokenAddress, actionId, account);
    }

    function forceExit(address tokenAddress, uint256 actionId) external {
        _removeAccount(tokenAddress, actionId, msg.sender);
    }

    function _removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) internal {
        if (!_isAccountJoined[tokenAddress][actionId][account]) {
            return;
        }

        uint256 currentRound = ILOVE20Join(joinAddress).currentRound();

        // set account joined to false
        _isAccountJoined[tokenAddress][actionId][account] = false;

        // remove actionId from account's list
        ArrayUtils.remove(_actionIdsByAccount[tokenAddress][account], actionId);

        // remove account from action's list using swap-and-pop
        uint256 index = _accountsIndexHistory[tokenAddress][actionId][account]
            .latestValue();
        uint256 lastIndex = _accountsCountHistory[tokenAddress][actionId]
            .latestValue() - 1;

        if (index != lastIndex) {
            address lastAccount = _accountsAtIndexHistory[tokenAddress][
                actionId
            ][lastIndex].latestValue();
            _accountsAtIndexHistory[tokenAddress][actionId][index].record(
                currentRound,
                lastAccount
            );
            _accountsIndexHistory[tokenAddress][actionId][lastAccount].record(
                currentRound,
                index
            );
            _accountsAtIndexHistory[tokenAddress][actionId][lastIndex].record(
                currentRound,
                address(0)
            );
        } else {
            // Clear the last index when removing the last element
            _accountsAtIndexHistory[tokenAddress][actionId][lastIndex].record(
                currentRound,
                address(0)
            );
        }
        _accountsCountHistory[tokenAddress][actionId].record(
            currentRound,
            lastIndex
        );
        _accountsIndexHistory[tokenAddress][actionId][account].record(
            currentRound,
            type(uint256).max
        );

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
        address account,
        address[] calldata factories
    )
        external
        view
        returns (
            uint256[] memory actionIds,
            address[] memory extensions,
            address[] memory factories_
        )
    {
        uint256[] memory allActionIds = _actionIdsByAccount[tokenAddress][
            account
        ];
        uint256 length = allActionIds.length;

        // Pre-allocate arrays with max size
        actionIds = new uint256[](length);
        extensions = new address[](length);
        factories_ = new address[](length);
        uint256 count = 0;
        bool noFilter = factories.length == 0;

        // Single pass: collect matching actionIds
        // If factories is empty, all actionIds match; otherwise check if factory is in array
        for (uint256 i = 0; i < length; ) {
            uint256 actionId = allActionIds[i];
            address factory = _factoryByActionId[tokenAddress][actionId];

            // If no filter or factory is in factories array, include it
            if (noFilter || _isFactoryInArray(factory, factories)) {
                actionIds[count] = actionId;
                extensions[count] = _extensionByActionId[tokenAddress][
                    actionId
                ];
                factories_[count] = factory;
                unchecked {
                    count++;
                }
            }

            unchecked {
                i++;
            }
        }

        // Resize arrays to exact count using mstore
        // Always resize if count != length to ensure correct array size
        if (count != length) {
            assembly {
                mstore(actionIds, count)
                mstore(extensions, count)
                mstore(factories_, count)
            }
        }
    }

    function _isFactoryInArray(
        address factory,
        address[] calldata factories
    ) private pure returns (bool) {
        uint256 len = factories.length;
        for (uint256 i = 0; i < len; ) {
            if (factories[i] == factory) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

    // ------ accounts by action queries (current) ------
    function accounts(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address[] memory) {
        uint256 count = _accountsCountHistory[tokenAddress][actionId]
            .latestValue();
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = _accountsAtIndexHistory[tokenAddress][actionId][i]
                .latestValue();
        }
        return result;
    }

    function accountsCount(
        address tokenAddress,
        uint256 actionId
    ) external view returns (uint256) {
        return _accountsCountHistory[tokenAddress][actionId].latestValue();
    }

    function accountsAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index
    ) external view returns (address) {
        return
            _accountsAtIndexHistory[tokenAddress][actionId][index]
                .latestValue();
    }

    // ------ accounts by action queries (by round) ------
    function accountsByRound(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view returns (address[] memory) {
        uint256 count = _accountsCountHistory[tokenAddress][actionId].value(
            round
        );
        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = _accountsAtIndexHistory[tokenAddress][actionId][i]
                .value(round);
        }
        return result;
    }

    function accountsByRoundCount(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view returns (uint256) {
        return _accountsCountHistory[tokenAddress][actionId].value(round);
    }

    function accountsByRoundAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index,
        uint256 round
    ) external view returns (address) {
        return
            _accountsAtIndexHistory[tokenAddress][actionId][index].value(round);
    }

    // ------ verification info (only extension can call) ------
    function updateVerificationInfo(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external onlyExtension(tokenAddress, actionId) {
        uint256 currentRound = ILOVE20Join(joinAddress).currentRound();
        _storeVerificationInfo(
            tokenAddress,
            actionId,
            account,
            verificationInfos,
            currentRound
        );
    }

    // ------ verification info queries ------
    function verificationInfo(
        address tokenAddress,
        uint256 actionId,
        address account,
        string calldata verificationKey
    ) external view returns (string memory) {
        return
            _verificationInfoHistory[tokenAddress][actionId][account][
                verificationKey
            ].latestValue();
    }

    function verificationInfoByRound(
        address tokenAddress,
        uint256 actionId,
        address account,
        string calldata verificationKey,
        uint256 round
    ) external view returns (string memory) {
        return
            _verificationInfoHistory[tokenAddress][actionId][account][
                verificationKey
            ].value(round);
    }

    // ------ internal functions ------
    function _storeVerificationInfo(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos,
        uint256 currentRound
    ) internal {
        if (verificationInfos.length == 0) {
            return;
        }

        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        string[] memory verificationKeys = actionInfo.body.verificationKeys;

        if (verificationKeys.length != verificationInfos.length) {
            revert VerificationInfoLengthMismatch();
        }

        for (uint256 i = 0; i < verificationKeys.length; i++) {
            _verificationInfoHistory[tokenAddress][actionId][account][
                verificationKeys[i]
            ].record(currentRound, verificationInfos[i]);

            emit UpdateVerificationInfo(
                tokenAddress,
                currentRound,
                actionId,
                account,
                verificationKeys[i],
                verificationInfos[i]
            );
        }
    }
}
