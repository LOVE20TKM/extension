// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "./base/IExtensionCore.sol";
import "./base/IExtensionJoinedValue.sol";
import "./base/IExtensionAccounts.sol";
import "./base/IExtensionReward.sol";
import "./base/IVerificationInfo.sol";

interface ILOVE20Extension is
    IExtensionCore,
    IExtensionJoinedValue,
    IExtensionAccounts,
    IExtensionReward,
    IVerificationInfo
{
    // ------ user operation ------
    // join&exit actions should be implemented in the extension with different input params
}
