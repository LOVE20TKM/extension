// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

// Default amount of tokens to join with during initialization (1 token)
uint256 constant DEFAULT_JOIN_AMOUNT = 1e18;

interface ILOVE20ExtensionFactory {
    function center() external view returns (address);

    // ------ created extensions, may not be initialized ------
    function extensions() external view returns (address[] memory);

    function extensionsCount() external view returns (uint256);

    function extensionsAtIndex(uint256 index) external view returns (address);

    function exists(address extension) external view returns (bool);
}
