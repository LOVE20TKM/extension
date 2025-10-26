// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title MockJoin
 * @dev Mock Join contract for unit testing
 */
contract MockJoin {
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        internal _amounts;

    function setAmount(
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 amount
    ) external {
        _amounts[tokenAddress][actionId][account] = amount;
    }

    function amountByActionIdByAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (uint256) {
        return _amounts[tokenAddress][actionId][account];
    }
}
