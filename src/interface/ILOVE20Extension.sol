// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "./base/IExtensionCore.sol";
import "./base/IExtensionJoinedValue.sol";
import "./base/IExtensionAccounts.sol";
import "./base/IExtensionReward.sol";
import "./base/IExtensionVerificationInfo.sol";
import "./base/IExtensionExit.sol";

interface ILOVE20Extension is 
    IExtensionCore,
    IExtensionJoinedValue,
    IExtensionAccounts,
    IExtensionReward,
    IExtensionVerificationInfo,
    IExtensionExit
{
    // ------ user operation ------
    // join&exit actions should be implemented in the extension with different input params
}
