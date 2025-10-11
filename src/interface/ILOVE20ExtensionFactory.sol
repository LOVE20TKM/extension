// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;
interface ILOVE20ExtensionFactory {
    // ------ Center should not trust, only for reference ------
    function name() external view returns (string memory);
    function version() external view returns (string memory);

    // ------ created extensions, may not be initialized ------
    function extensionsCount(
        address tokenAddress
    ) external view returns (uint256);

    function extensionsAtIndex(
        address tokenAddress,
        uint256 index
    ) external view returns (address);
}
