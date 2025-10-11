// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
interface ILOVE20ExtensionFactory {
    // ------ created extensions, may not be initialized ------
    function extensionsCount(
        address tokenAddress
    ) external view returns (uint256);

    function extensionsAtIndex(
        address tokenAddress,
        uint256 index
    ) external view returns (address);

    function exists(address extension) external view returns (bool);
}
