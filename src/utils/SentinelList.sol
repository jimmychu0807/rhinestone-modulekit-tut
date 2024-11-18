// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Sentinel address
address constant SENTINEL = address(0x1);
// Zero address
address constant ZERO_ADDRESS = address(0x0);

library SentinelListLib {
    error InvalidEntry(address);


    struct SentinelList {
        mapping(address => address) entries;
    }

    error LinkedList_AlreadyInitialized();
    error LinkedList_InvalidPage();
    error LinkedList_InvalidEntry(address entry);
    error LinkedList_EntryExisted(address entry);

    function init(SentinelList storage self) internal {
        if (alreadyInitialized(self)) revert LinkedList_AlreadyInitialized();
        self.entries[SENTINEL] = SENTINEL;
    }

    function alreadyInitialized(SentinelList storage self) public view returns (bool) {
        return self.entries[SENTINEL] != ZERO_ADDRESS;
    }

    function push(SentinelList storage self, address newEntry) internal {
        if (newEntry == SENTINEL || newEntry == ZERO_ADDRESS) {
            revert InvalidEntry(newEntry);
        }

        if (self.entries[newEntry] != ZERO_ADDRESS) revert LinkedList_EntryExisted(newEntry);
        self.entries[newEntry] = self.entries[SENTINEL];
        self.entries[SENTINEL] = newEntry;
    }

    function pop(SentinelList storage self, address prev, address del) internal {
        if (del == ZERO_ADDRESS || del == SENTINEL) {
            revert LinkedList_InvalidEntry(del);
        }

        if (self.entries[prev] != del) revert LinkedList_InvalidEntry(del);
        self.entries[prev] = self.entries[del];
        self.entries[del] = ZERO_ADDRESS;
    }

    function popAll(SentinelList storage self) internal {
        address next = self.entries[SENTINEL];
        while (next != ZERO_ADDRESS) {
            address current = next;
            next = self.entries[next];
            delete self.entries[current];
        }
    }

    function contains(SentinelList storage self, address entry) internal view returns (bool) {
        return SENTINEL != entry && self.entries[entry] != ZERO_ADDRESS;
    }

    function getEntriesPaginated(SentinelList storage self, address start, uint256 pageSize)
        internal
        view
        returns (address[] memory array, address next)
    {
        if (start != SENTINEL && !contains(self, start)) revert LinkedList_InvalidEntry(start);
        if (pageSize == 0) revert LinkedList_InvalidPage();

        array = new address[](pageSize);
        uint256 cnt = 0;
        next = self.entries[start];
        while (next != ZERO_ADDRESS && next != SENTINEL && cnt < pageSize) {
            array[cnt] = next;
            next = self.entries[next];
            cnt += 1;
        }

        if (next != SENTINEL && cnt > 0) next = array[cnt - 1];

        assembly {
            mstore(array, cnt)
        }
    }
}
