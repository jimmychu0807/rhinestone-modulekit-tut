// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

library FlatBytesLib {
    using FlatBytesLib for *;

    error InvalidDataLength();

    uint256 private constant MAX_SLOT = 32;

    struct Data {
        bytes32[MAX_SLOT] slot1;
    }

    struct Bytes {
        uint256 totalLength;
        Data data;
    }

    // Store the data in storage
    function store(Bytes storage self, bytes memory data) internal {
        if (data.length > MAX_SLOT * 32) revert InvalidDataLength();

        bytes32[] memory entries;

        (self.totalLength, entries) = data.toArray();

        uint256 length = entries.length;

        Data storage _data = self.data;
        for (uint256 i; i < length; i++) {
            bytes32 val = entries[i];
            assembly {
                sstore(add(_data.slot, i), val)
            }
        }
    }

    function load(Bytes storage self) internal returns(bytes memory) {
        return self.toBytes();
    }

    function toArray(bytes memory data)
        internal pure
        returns (uint256 totalLen, bytes32[] memory dataList)
    {
        totalLen = data.length;
        if (totalLen > MAX_SLOT * 32) revert InvalidDataLength();

        uint256 dataNb = (totalLen + 31) / 32;

        dataList = new bytes32[](dataNb);
        for (uint256 i = 0; i < dataNb; i++) {
            bytes32 temp;
            assembly {
                temp := mload(add(data, mul(add(i, 1), 32)))
            }
            dataList[i] = temp;
        }
    }

    function toBytes(Bytes storage self) internal view returns (bytes memory data) {
        uint256 totalLength = self.totalLength;
        uint256 slotsCnt = (totalLength + 31) / 32;

        Data storage _data = self.data;

        bytes32[] memory entries = new bytes32[](slotsCnt);
        for (uint256 i; i < slotsCnt; i++) {
            bytes32 tmp;
            assembly {
                tmp := sload(add(_data.slot, i))
            }
            entries[i] = tmp;
        }

        data = abi.encodePacked(entries);
        assembly {
            mstore(data, totalLength)
        }
    }
}
