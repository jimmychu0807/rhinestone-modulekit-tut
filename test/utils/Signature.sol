// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { Vm } from "forge-std/Test.sol";
import { console } from "forge-std/Console.sol";

// this line comes from:
// https://github.com/foundry-rs/forge-std/blob/master/src/StdCheats.sol#L643
address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

function signHash(uint256 sk, bytes32 digest) view returns (bytes memory) {
    Vm vm = Vm(VM_ADDR);
    // whatever data, before signing with a private key of ECDSA, need to go thru this procedure ECDSA.toEthSignedMessageHash()
    bytes32 signedHash = ECDSA.toEthSignedMessageHash(digest);
    // the signature is 65 bytes
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(sk, signedHash);

    // sanity check
    address signer = ECDSA.recover(signedHash, v, r, s);
    require(signer == vm.addr(sk), "Invalid signature");

    bytes memory signature = abi.encodePacked(r, s, v);
    // console.log("signHash");
    // console.logBytes(signature);
    return signature;
}
