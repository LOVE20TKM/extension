// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ExampleTokenJoin} from "./ExampleTokenJoin.sol";
import {ExtensionFactoryBase} from "../ExtensionFactoryBase.sol";

contract ExampleFactoryTokenJoin is ExtensionFactoryBase {
    mapping(address => ExtensionParams) private _extensionParams;

    struct ExtensionParams {
        address tokenAddress;
        address joinTokenAddress;
        uint256 waitingBlocks;
    }

    constructor(address center_) ExtensionFactoryBase(center_) {}

    function createExtension(
        address tokenAddress_,
        address joinTokenAddress_,
        uint256 waitingBlocks_
    ) external returns (address) {
        ExampleTokenJoin extension = new ExampleTokenJoin(
            address(this),
            tokenAddress_,
            joinTokenAddress_,
            waitingBlocks_
        );

        _extensionParams[address(extension)] = ExtensionParams({
            tokenAddress: tokenAddress_,
            joinTokenAddress: joinTokenAddress_,
            waitingBlocks: waitingBlocks_
        });

        _registerExtension(address(extension), tokenAddress_);

        return address(extension);
    }

    function extensionParams(
        address extension_
    )
        external
        view
        returns (
            address tokenAddress,
            address joinTokenAddress,
            uint256 waitingBlocks
        )
    {
        ExtensionParams memory params = _extensionParams[extension_];
        return (
            params.tokenAddress,
            params.joinTokenAddress,
            params.waitingBlocks
        );
    }
}
