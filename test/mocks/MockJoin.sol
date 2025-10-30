// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title MockJoin
 * @dev Mock Join contract for unit testing
 */
contract MockJoin {
    bool public _joinWillFail;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        internal _amounts;

    function join(
        address tokenAddress,
        uint256 actionId,
        uint256 amount,
        string[] memory /* args */
    ) external returns (bool) {
        if (_joinWillFail) {
            amount = 0;
        }
        // record amount joined by extension (msg.sender)
        _amounts[tokenAddress][actionId][msg.sender] = amount;
        return true;
    }

    function setAmount(
        address tokenAddress,
        uint256 actionId,
        address account,
        uint256 amount
    ) external {
        _amounts[tokenAddress][actionId][account] = amount;
    }

    function setJoinWillFail(bool value) external {
        _joinWillFail = value;
    }

    function amountByActionIdByAccount(
        address tokenAddress,
        uint256 actionId,
        address account
    ) external view returns (uint256) {
        return _amounts[tokenAddress][actionId][account];
    }
}
