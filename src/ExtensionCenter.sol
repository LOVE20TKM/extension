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
import {RoundHistoryString} from "./lib/RoundHistoryString.sol";
import {RoundHistoryAddressSet} from "./lib/RoundHistoryAddressSet.sol";
import {IExtensionFactory} from "./interface/IExtensionFactory.sol";
import {IExtension} from "./interface/IExtension.sol";

contract ExtensionCenter is IExtensionCenter {
    using RoundHistoryString for RoundHistoryString.History;
    using RoundHistoryAddressSet for RoundHistoryAddressSet.Storage;

    address public immutable uniswapV2FactoryAddress;
    address public immutable launchAddress;
    address public immutable stakeAddress;
    address public immutable submitAddress;
    address public immutable voteAddress;
    address public immutable joinAddress;
    address public immutable verifyAddress;
    address public immutable mintAddress;
    address public immutable randomAddress;

    // tokenAddress => account => actionIds
    mapping(address => mapping(address => uint256[]))
        internal _actionIdsByAccount;

    // tokenAddress => actionId => RoundHistoryAddressSet.Storage
    mapping(address => mapping(uint256 => RoundHistoryAddressSet.Storage))
        internal _accountsHistory;

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

    modifier onlyExtensionOrDelegate(address tokenAddress, uint256 actionId) {
        if (!_isExtensionOrDelegate(tokenAddress, actionId)) {
            revert OnlyExtensionOrDelegate();
        }
        _;
    }

    modifier onlyUserOrExtensionOrDelegate(
        address tokenAddress,
        uint256 actionId,
        address account
    ) {
        if (
            msg.sender != account &&
            !_isExtensionOrDelegate(tokenAddress, actionId)
        ) {
            revert OnlyUserOrExtensionOrDelegate();
        }
        _;
    }

    modifier validRound(uint256 round) {
        uint256 currentRound = ILOVE20Join(joinAddress).currentRound();
        if (round > currentRound) {
            revert RoundExceedsJoinRound();
        }
        _;
    }

    function _isExtensionOrDelegate(
        address tokenAddress,
        uint256 actionId
    ) internal view returns (bool) {
        address extensionAddress = _extensionByActionId[tokenAddress][actionId];
        return
            msg.sender == extensionAddress ||
            msg.sender == _extensionDelegate[extensionAddress];
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
        require(
            uniswapV2FactoryAddress_ != address(0),
            "uniswapV2FactoryAddress is not set"
        );
        require(launchAddress_ != address(0), "launchAddress is not set");
        require(stakeAddress_ != address(0), "stakeAddress is not set");
        require(submitAddress_ != address(0), "submitAddress is not set");
        require(voteAddress_ != address(0), "voteAddress is not set");
        require(joinAddress_ != address(0), "joinAddress is not set");
        require(verifyAddress_ != address(0), "verifyAddress is not set");
        require(mintAddress_ != address(0), "mintAddress is not set");
        require(randomAddress_ != address(0), "randomAddress is not set");

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
        return _extensionByActionId[tokenAddress][actionId];
    }

    function factory(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address) {
        return _factoryByActionId[tokenAddress][actionId];
    }

    function setExtensionDelegate(address delegate) external {
        _extensionDelegate[msg.sender] = delegate;

        emit SetExtensionDelegate({extension: msg.sender, delegate: delegate});
    }

    function extensionDelegate(
        address extensionAddress
    ) external view returns (address) {
        return _extensionDelegate[extensionAddress];
    }

    function extensionTokenActionPair(
        address extensionAddress
    ) external view returns (address tokenAddress, uint256 actionId) {
        TokenActionPair memory pair = _extensionTokenActionPair[
            extensionAddress
        ];
        return (pair.tokenAddress, pair.actionId);
    }

    function addAccount(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external onlyExtensionOrDelegate(tokenAddress, actionId) {
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

        if (_accountsHistory[tokenAddress][actionId].contains(account)) {
            revert AccountAlreadyJoined();
        }

        _actionIdsByAccount[tokenAddress][account].push(actionId);

        _accountsHistory[tokenAddress][actionId].add(currentRound, account);
        _updateVerificationInfo(
            tokenAddress,
            actionId,
            account,
            verificationInfos,
            currentRound
        );

        emit AddAccount(tokenAddress, actionId, account);
    }

    function removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external onlyExtensionOrDelegate(tokenAddress, actionId) returns (bool) {
        return _removeAccount(tokenAddress, actionId, account);
    }

    function forceRemove(
        address tokenAddress,
        uint256 actionId
    ) external returns (bool) {
        return _removeAccount(tokenAddress, actionId, msg.sender);
    }

    function isAccountJoined(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (bool) {
        return _accountsHistory[tokenAddress][actionId].contains(account);
    }

    function isAccountJoinedByRound(
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 round
    ) external view validRound(round) returns (bool) {
        return
            _accountsHistory[tokenAddress][actionId].containsByRound(
                account,
                round
            );
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

    function accounts(
        address tokenAddress,
        uint256 actionId
    ) external view returns (address[] memory) {
        return _accountsHistory[tokenAddress][actionId].values();
    }

    function accountsCount(
        address tokenAddress,
        uint256 actionId
    ) external view returns (uint256) {
        return _accountsHistory[tokenAddress][actionId].count();
    }

    function accountsAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index
    ) external view returns (address) {
        return _accountsHistory[tokenAddress][actionId].atIndex(index);
    }

    function accountsByRound(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view validRound(round) returns (address[] memory) {
        return _accountsHistory[tokenAddress][actionId].valuesByRound(round);
    }

    function accountsByRoundCount(
        address tokenAddress,
        uint256 actionId,
        uint256 round
    ) external view validRound(round) returns (uint256) {
        return _accountsHistory[tokenAddress][actionId].countByRound(round);
    }

    function accountsByRoundAtIndex(
        address tokenAddress,
        uint256 actionId,
        uint256 index,
        uint256 round
    ) external view validRound(round) returns (address) {
        return
            _accountsHistory[tokenAddress][actionId].atIndexByRound(
                index,
                round
            );
    }

    function updateVerificationInfo(
        address tokenAddress,
        uint256 actionId,
        address account,
        string[] calldata verificationInfos
    ) external onlyUserOrExtensionOrDelegate(tokenAddress, actionId, account) {
        uint256 currentRound = ILOVE20Join(joinAddress).currentRound();
        _updateVerificationInfo(
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
    ) external view validRound(round) returns (string memory) {
        return
            _verificationInfoHistory[tokenAddress][actionId][account][
                verificationKey
            ].value(round);
    }

    function _getValidFactory(
        address extensionAddress
    ) internal view returns (address factoryAddress) {
        try IExtension(extensionAddress).FACTORY_ADDRESS() returns (
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

    function registerActionIfNeeded(
        address tokenAddress,
        uint256 actionId
    ) external returns (address extensionAddress) {
        extensionAddress = _extensionByActionId[tokenAddress][actionId];
        if (extensionAddress != address(0)) {
            return extensionAddress;
        }

        ActionInfo memory actionInfo = ILOVE20Submit(submitAddress).actionInfo(
            tokenAddress,
            actionId
        );
        extensionAddress = actionInfo.body.whiteListAddress;
        if (extensionAddress == address(0)) {
            revert InvalidExtensionAddress();
        }

        address factoryAddress = _getValidFactory(extensionAddress);
        if (factoryAddress == address(0)) {
            revert ExtensionNotFoundInFactory();
        }

        TokenActionPair memory existingPair = _extensionTokenActionPair[
            extensionAddress
        ];
        if (existingPair.tokenAddress != address(0)) {
            revert ActionAlreadyRegisteredToOtherAction();
        }

        _extensionByActionId[tokenAddress][actionId] = extensionAddress;
        _factoryByActionId[tokenAddress][actionId] = factoryAddress;
        _extensionTokenActionPair[extensionAddress] = TokenActionPair({
            tokenAddress: tokenAddress,
            actionId: actionId
        });

        emit RegisterAction({
            tokenAddress: tokenAddress,
            actionId: actionId,
            extension: extensionAddress,
            factory: factoryAddress
        });

        return extensionAddress;
    }

    function _removeAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) internal returns (bool) {
        if (!_accountsHistory[tokenAddress][actionId].contains(account)) {
            return false;
        }

        uint256 currentRound = ILOVE20Join(joinAddress).currentRound();

        ArrayUtils.remove(_actionIdsByAccount[tokenAddress][account], actionId);

        _accountsHistory[tokenAddress][actionId].remove(currentRound, account);

        emit RemoveAccount(tokenAddress, actionId, account);

        return true;
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

    function _updateVerificationInfo(
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

        uint256 len = verificationKeys.length;
        for (uint256 i = 0; i < len; ) {
            _verificationInfoHistory[tokenAddress][actionId][account][
                verificationKeys[i]
            ].record(currentRound, verificationInfos[i]);

            emit UpdateVerificationInfo({
                tokenAddress: tokenAddress,
                round: currentRound,
                actionId: actionId,
                account: account,
                verificationKey: verificationKeys[i],
                verificationInfo: verificationInfos[i]
            });

            unchecked {
                i++;
            }
        }
    }
}
