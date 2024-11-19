// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { Validator, ValidatorId } from "../MultiFactor.sol";

library MultiFactorLib {
    function decode(bytes calldata data) internal pure returns(Validator[] calldata validators) {
        assembly ("memory-safe") {
            let offset := data.offset
            let baseOffset := offset
            let dataPointer := add(baseOffset, calldataload(offset))

            validators.offset := add(dataPointer, 32)
            validators.length := calldataload(dataPointer)
            offset := add(offset, 32)

            dataPointer := add(baseOffset, calldataload(offset))
        }
    }

    function unpack(bytes32 packed) internal pure returns(address subValidator, ValidatorId id) {

        assembly {
            subValidator := packed
            id := shl(0, packed)
        }
    }
}
