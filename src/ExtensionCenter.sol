// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    IExtensionCenter,
    TokenActionPair
} from "./interface/IExtensionCenter.sol";
import {ILOVE20Submit, ActionInfo} from "@core/interfaces/ILOVE20Submit.sol";
import {ILOVE20Join} from "@core/interfaces/ILOVE20Join.sol";
import {ILOVE20Vote} from "@core/interfaces/ILOVE20Vote.sol";
import {ArrayUtils} from "@core/lib/ArrayUtils.sol";
import {RoundHistoryUint256} from "./lib/RoundHistoryUint256.sol";
import {RoundHistoryAddress} from "./lib/RoundHistoryAddress.sol";
import {RoundHistoryString} from "./lib/RoundHistoryString.sol";
import {IExtensionFactory} from "./interface/IExtensionFactory.sol";
import {IExtensionCore} from "./interface/IExtensionCore.sol";

contract ExtensionCenter is IExtensionCenter {
    using RoundHistoryUint256 for RoundHistoryUint256.History;
    using RoundHistoryAddress for RoundHistoryAddress.History;
    using RoundHistoryString for RoundHistoryString.History;

    address public immutable uniswapV2FactoryAddress;
    address public immutable launchAddress;
    address public immutable stakeAddress;
    address public immutable submitAddress;
    address public immutable voteAddress;
    address public immutable joinAddress;
    address public immutable verifyAddress;
    address public immutable mintAddress;
    address public immutable randomAddress;

    // tokenAddress => actionId => account => isJoined
    mapping(address => mapping(uint256 => mapping(address => bool)))
        internal _isAccountJoined;

    // tokenAddress => account => actionIds
    mapping(address => mapping(address => uint256[]))
        internal _actionIdsByAccount;

    // tokenAddress => actionId => accountsCount
    mapping(address => mapping(uint256 => RoundHistoryUint256.History))
        internal _accountsCountHistory;

    // tokenAddress => actionId => index => account
    mapping(address => mapping(uint256 => mapping(uint256 => RoundHistoryAddress.History)))
        internal _accountsAtIndexHistory;

    // tokenAddress => actionId => account => index
    mapping(address => mapping(uint256 => mapping(address => RoundHistoryUint256.History)))
        internal _accountsIndexHistory;

    // tokenAddress => actionId => account => verificationKey => verificationInfo
    mapping(address => mapping(uint256 => mapping(address => mapping(string => RoundHistoryString.History))))
        internal _verificationInfoHistory;

    // extension => delegate
    mapping(address => address) internal _extensionDelegate;

    // tokenAddress => actionId => extension
    mapping(address => mapping(uint256 => address))
        internal _extensionByActionId;

    // tokenAddress => actionId => factory
    mapping(address => mapping(uint256 => address)) internal _factoryByActionId;

    // extension => TokenActionPair
    mapping(address => TokenActionPair) internal _extensionTokenActionPair;

    function _getExtensionAddress(
        address tokenAddress,
        uint256 actionId
    ) internal view returns (address) {
        address extensionAddress = _extensionByActionId[tokenAddress][actionId];
        if (extensionAddress != address(0)) {
            return extensionAddress;
        }

        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        extensionAddress = actionInfo.body.whiteListAddress;
        if (extensionAddress == address(0)) {
            return address(0);
        }
        address factoryAddress = _getValidFactory(extensionAddress);
        if (factoryAddress == address(0)) {
            return address(0);
        }

        if (
            _extensionTokenActionPair[extensionAddress].tokenAddress !=
            address(0)
        ) {
            return address(0);
        }

        return extensionAddress;
    }

    function _getActualExtensionAddress(
        address tokenAddress,
        uint256 actionId,
        address caller
    ) internal view returns (address) {
        address extensionAddress = _extensionByActionId[tokenAddress][actionId];

        if (extensionAddress == address(0)) {
            ActionInfo memory actionInfo = ILOVE20Submit(submitAddress)
                .actionInfo(tokenAddress, actionId);
            extensionAddress = actionInfo.body.whiteListAddress;
        }

        if (caller == extensionAddress) return extensionAddress;
        if (caller == _extensionDelegate[extensionAddress])
            return extensionAddress;

        return address(0);
    }

    function _getValidFactory(
        address extensionAddress
    ) internal view returns (address factoryAddress) {
        try IExtensionCore(extensionAddress).factory() returns (
            address factory_
        ) {
            if (factory_ == address(0)) {
                return address(0);
            }
            factoryAddress = factory_;
        } catch {
            return address(0);
        }
        if (!IExtensionFactory(factoryAddress).exists(extensionAddress)) {
            return address(0);
        }
        return factoryAddress;
    }

    function _bindActionIfNeeded(
        address tokenAddress,
        uint256 actionId
    ) internal returns (address extensionAddress) {
        extensionAddress = _getActualExtensionAddress(
            tokenAddress,
            actionId,
            msg.sender
        );
        if (extensionAddress == address(0)) {
            revert OnlyExtensionCanCall();
        }

        address factoryAddress = _factoryByActionId[tokenAddress][actionId];
        if (factoryAddress != address(0)) {
            return extensionAddress;
        }

        factoryAddress = _getValidFactory(extensionAddress);
        if (factoryAddress == address(0)) {
            revert ExtensionNotFoundInFactory();
        }

        TokenActionPair memory existingPair = _extensionTokenActionPair[
            extensionAddress
        ];
        if (existingPair.tokenAddress != address(0)) {
            if (
                existingPair.tokenAddress != tokenAddress ||
                existingPair.actionId != actionId
            ) {
                revert InvalidExtensionFactory();
            }
            return extensionAddress;
        }

        _extensionByActionId[tokenAddress][actionId] = extensionAddress;
        _factoryByActionId[tokenAddress][actionId] = factoryAddress;
        _extensionTokenActionPair[extensionAddress] = TokenActionPair({
            tokenAddress: tokenAddress,
            actionId: actionId
        });

        emit BindAction(
            tokenAddress,
            actionId,
            extensionAddress,
            factoryAddress
        );

        return extensionAddress;
    }

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

    function extension(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address) {
        return _getExtensionAddress(tokenAddress, actionId);
    }

    function factory(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address) {
        address factoryAddress = _factoryByActionId[tokenAddress][actionId];
        if (factoryAddress != address(0)) {
            return factoryAddress;
        }

        address extensionAddress = _extensionByActionId[tokenAddress][actionId];
        if (extensionAddress != address(0)) {
            return _getValidFactory(extensionAddress);
        }

        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        extensionAddress = actionInfo.body.whiteListAddress;
        if (extensionAddress == address(0)) {
            return address(0);
        }

        if (
            _extensionTokenActionPair[extensionAddress].tokenAddress !=
            address(0)
        ) {
            return address(0);
        }

        return _getValidFactory(extensionAddress);
    }

    function setExtensionDelegate(address delegate) external {
        address extensionAddress = msg.sender;

        _extensionDelegate[extensionAddress] = delegate;

        emit ExtensionDelegateSet(extensionAddress, delegate);
    }

    function bindActionIfNeeded(
        address tokenAddress,
        uint256 actionId
    ) external returns (address extensionAddress) {
        return _bindActionIfNeeded(tokenAddress, actionId);
    }

    function extensionDelegate(
        address extensionAddress
    ) external view returns (address) {
        return _extensionDelegate[extensionAddress];
    }

    function addAccount(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external {
        address extensionAddress = _bindActionIfNeeded(tokenAddress, actionId);
        if (
            msg.sender != extensionAddress &&
            msg.sender != _extensionDelegate[extensionAddress]
        ) {
            revert OnlyExtensionCanCall();
        }

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

        _isAccountJoined[tokenAddress][actionId][account] = true;

        _actionIdsByAccount[tokenAddress][account].push(actionId);

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
    ) external {
        address extensionAddress = _bindActionIfNeeded(tokenAddress, actionId);
        if (
            msg.sender != extensionAddress &&
            msg.sender != _extensionDelegate[extensionAddress]
        ) {
            revert OnlyExtensionCanCall();
        }

        _removeAccount(tokenAddress, actionId, account);
    }

    function forceRemove(address tokenAddress, uint256 actionId) external {
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

        _isAccountJoined[tokenAddress][actionId][account] = false;

        ArrayUtils.remove(_actionIdsByAccount[tokenAddress][account], actionId);

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
        }

        _accountsAtIndexHistory[tokenAddress][actionId][lastIndex].record(
            currentRound,
            address(0)
        );
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

        actionIds = new uint256[](length);
        extensions = new address[](length);
        factories_ = new address[](length);
        uint256 count = 0;
        bool noFilter = factories.length == 0;

        for (uint256 i = 0; i < length; ) {
            uint256 actionId = allActionIds[i];
            address factory_ = _factoryByActionId[tokenAddress][actionId];

            if (noFilter || _isFactoryInArray(factory_, factories)) {
                actionIds[count] = actionId;
                extensions[count] = _extensionByActionId[tokenAddress][
                    actionId
                ];
                factories_[count] = factory_;
                unchecked {
                    count++;
                }
            }

            unchecked {
                i++;
            }
        }

        if (count != length) {
            assembly {
                mstore(actionIds, count)
                mstore(extensions, count)
                mstore(factories_, count)
            }
        }
    }

    function _isFactoryInArray(
        address factory_,
        address[] calldata factories
    ) private pure returns (bool) {
        uint256 len = factories.length;
        for (uint256 i = 0; i < len; ) {
            if (factories[i] == factory_) {
                return true;
            }
            unchecked {
                i++;
            }
        }
        return false;
    }

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

    function updateVerificationInfo(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external {
        if (account != msg.sender) {
            _bindActionIfNeeded(tokenAddress, actionId);
        }

        uint256 currentRound = ILOVE20Join(joinAddress).currentRound();
        _storeVerificationInfo(
            tokenAddress,
            actionId,
            account,
            verificationInfos,
            currentRound
        );
    }

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
