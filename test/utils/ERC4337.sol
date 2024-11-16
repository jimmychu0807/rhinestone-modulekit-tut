// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

function getEmptyUserOperation() returns (PackedUserOperation memory) {
    return PackedUserOperation({
        sender: address(0),
        nonce: 0,
        initCode: "",
        callData: "",
        accountGasLimits: 0,
        preVerificationGas: 0,
        gasFees: "",
        paymasterAndData: "",
        signature: ""
    });
}
