// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { ECDSA } from "solady/utils/ECDSA.sol";

library CheckSignatures {
    bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;
    error WrongContractSignatureFormat(uint256 s, uint256 contractSignatureLen, uint256 signaturesLen);
    error WrongContractSignature(bytes contractSignature);

    function recoverNSignatures(
        bytes32 dataHash,
        bytes memory signatures,
        uint8 threshold
    ) public view returns (address[] memory recoveredSigners) {
        uint256 requiredSignatureLength = threshold * 65;
        uint256 signaturesLength = signatures.length;
        recoveredSigners = new address[](threshold);

        for (uint256 i = 0; i < threshold; i++) {
            // split v, r, s from signatures
            address _signer;
            (uint8 v, bytes32 r, bytes32 s) = signatureSplit({ signatures: signatures, pos: i });
            if (v == 0) {
                // If v is 0, then it is a contract signature. In that case r is the signer contract
                _signer = address(uint160(uint256(r)));

                if (uint256(s) < 65 * threshold) {
                    revert WrongContractSignatureFormat(uint256(s), 0, 0);
                }

                if (uint256(s) + 32 > signaturesLength) {
                    revert WrongContractSignatureFormat(uint256(s), 0, signaturesLength);
                }

                uint256 contractSignatureLen;
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 32))
                }
                if (uint256(s) + 32 + contractSignatureLen > signaturesLength) {
                    revert WrongContractSignatureFormat(uint256(s), contractSignatureLen, signaturesLength);
                }

                // Check signature
                bytes memory contractSignature;
                assembly {
                    contractSignature := add(add(signatures, s), 0x20)
                }

                if (ISignatureValidator(_signer).isValidSignature(dataHash, contractSignature) != EIP1271_MAGIC_VALUE) {
                    revert WrongContractSignature(contractSignature);
                }
            } else if (v > 30) {
                _signer = ECDSA.tryRecover({
                    hash: ECDSA.toEthSignedMessageHash(dataHash),
                    v: v - 4,
                    r: r,
                    s: s
                });
            } else {
                _signer = ECDSA.tryRecover({ hash: dataHash, v: v, r: r, s: s });
            }
            recoveredSigners[i] = _signer;
        }
    }

    function signatureSplit(bytes memory signatures, uint256 pos) internal pure returns(uint8 v, bytes32 r, bytes32 s) {
        assembly {
            let signaturePos := mul(65, pos)
            // why the signature is starting from 0x20?
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            v := byte(0, mload(add(signatures, add(signaturePos, 0x60))))
        }
    }
}

abstract contract ISignatureValidator {
    function isValidSignature(bytes32 _dataHash, bytes memory _signature) public view virtual returns (bytes4);
}
