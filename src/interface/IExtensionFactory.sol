// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

uint256 constant DEFAULT_JOIN_AMOUNT = 1e18;

interface IExtensionFactory {
    event ExtensionCreate(address extension, address tokenAddress);

    function CENTER_ADDRESS() external view returns (address);

    function exists(address extension) external view returns (bool);

    function extensions() external view returns (address[] memory);
    function extensionsCount() external view returns (uint256);
    function extensionsAtIndex(uint256 index) external view returns (address);
}
