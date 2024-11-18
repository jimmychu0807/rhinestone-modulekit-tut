// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <=0.8.29;

import { console } from "forge-std/console.sol";

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { SentinelList4337Lib, SENTINEL } from "sentinellist/SentinelList4337.sol";
import { CheckSignatures } from "src/utils/CheckSignatures.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { ISemaphore, ISemaphoreGroups } from "src/utils/semaphore.sol";

contract SemaphoreMSAValidator is ERC7579ValidatorBase {
    using LibSort for *;
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;

    // Constants
    uint8 constant MAX_OWNERS = 32;

    // custom errors
    error ModuleAlreadyInstalled();
    error ModuleNotInstalled();
    error NotAdmin();

    // OwnableValidator errors
    error CannotRemoveOwner();
    error InvalidOwner();
    error InvalidThreshold();
    error IsOwnerAlready();
    error MaxOwnersReached();
    error NotSortedAndUnique();
    error OwnerNotExisted(address, address);
    error ThresholdNotReached();
    error ThresholdNotSet();

    // Events
    event ModuleInitialized(address indexed account);
    event ModuleUninitialized(address indexed account);

    // OwnableValidator events
    event AddedOwner(address indexed, address indexed);
    event RemovedOwner(address indexed, address indexed);
    event ThresholdSet(address indexed account, uint8 indexed);

    /**
     * Storage
     */
    ISemaphore public semaphore;
    ISemaphoreGroups public groups;
    mapping(address => bool) public inUse;
    mapping(address => uint256) public gIds;

    // Coming from OwnableValidator
    SentinelList4337Lib.SentinelList owners;
    mapping(address account => uint8) public threshold;
    mapping(address account => uint8) public ownerCount;

    // In the Semaphore contract, the admin for any group is the SemaphoreValidator contract.
    // We store the actual smart account admin here. There can only be one admin for now.
    mapping(address => address) public admins;

    // SemaphoreValidator contract has to be the admin of the Semaphore contract

    constructor(ISemaphore _semaphore) {
        semaphore = _semaphore;
        groups = ISemaphoreGroups(address(_semaphore));
    }

    modifier moduleInstalled() {
        if (!inUse[msg.sender]) {
            revert ModuleNotInstalled();
        }
        _;
    }

    modifier moduleNotInstalled() {
        if (inUse[msg.sender]) {
            revert ModuleAlreadyInstalled();
        }
        _;
    }

    modifier isAdmin(bytes calldata data) {
        address user = abi.decode(data, (address));
        uint256 gId = gIds[msg.sender];
        address admin = groups.getGroupAdmin(gId);
        if (user != admin) {
            revert NotAdmin();
        }
        _;
    }

    /**
     * Config
     *
     */
    function isInitialized(address account) public view returns (bool) {
        // return inUse[account];

        // OwnableValidator
        return threshold[account] != 0;
    }

    function onInstall(bytes calldata data) external override {
        // create a new group
        // msg.sender is the smart account that call this contract
        // the address in data is the EOA owner of the smart account
        // you often have to parse the passed in parameters to get the original caller
        // The address of the original caller (the one who sends http request to the bundler) must
        // be passed in from data
        // (address admin, uint256 commitment) = abi.decode(data, (address, uint256));
        // uint256 gId = semaphore.createGroup();
        // inUse[msg.sender] = true;
        // gIds[msg.sender] = gId;
        // admins[msg.sender] = admin;

        // Add the admin commitment in as the first group member.
        // semaphore.addMember(gId, commitment);

        // OwnableValidator
        (uint8 _threshold, address[] memory _owners) = abi.decode(data, (uint8, address[]));

        // Todo: check that module is not installed

        if (!_owners.isSortedAndUniquified()) { revert NotSortedAndUnique(); }
        if (_threshold == 0) { revert ThresholdNotSet(); }

        uint8 ownersLength = uint8(_owners.length);
        if (ownersLength < _threshold) { revert InvalidThreshold(); }
        if (_threshold > MAX_OWNERS) { revert MaxOwnersReached(); }

        (bool found,) = _owners.searchSorted(address(0));
        if (found) { revert InvalidOwner(); }

        address account = msg.sender;
        threshold[account] = _threshold;
        ownerCount[account] = ownersLength;
        owners.init(account);

        for (uint8 i = 0; i < ownersLength; i++) {
            owners.push(account, _owners[i]);
        }

        emit ModuleInitialized(account);
    }

    function onUninstall(bytes calldata) external override {
        // remove from our data structure
        delete inUse[msg.sender];
        delete gIds[msg.sender];
        delete admins[msg.sender];

        // OwnableValidator onUninstall
        // Todo: check that module is installed

        owners.popAll(msg.sender);
        threshold[msg.sender] = 0;
        ownerCount[msg.sender] = 0;
        emit ModuleUninitialized(msg.sender);
    }

    function setThreshold(uint8 newThreshold) external {
        // OwnableValidator
        // 0. check the module is initialized for the acct
        // check it is not 0,
        // check it is not greater than curent owner
        if (!isInitialized(msg.sender)) { revert NotInitialized(msg.sender); }
        if (newThreshold == 0) { revert InvalidThreshold(); }
        if (newThreshold > ownerCount[msg.sender]) { revert InvalidThreshold(); }

        threshold[msg.sender] = newThreshold;
        emit ThresholdSet(msg.sender, newThreshold);
    }

    function addOwner(address newOwner) external {
        if (!isInitialized(msg.sender)) { revert NotInitialized(msg.sender); }
        // 0. check the module is initialized for the acct
        // 1. check newOwner != 0
        // 2. check ownerCount < MAX_OWNERS
        // 3. cehck owner not existed yet
        if (newOwner == address(0)) { revert InvalidOwner(); }
        if (ownerCount[msg.sender] == MAX_OWNERS) { revert MaxOwnersReached(); }
        if (owners.contains(msg.sender, newOwner)) { revert IsOwnerAlready(); }

        owners.push(msg.sender, newOwner);
        ownerCount[msg.sender] += 1;
        emit AddedOwner(msg.sender, newOwner);
    }

    function removeOwner(address prevOwner, address owner) external {
        if (!isInitialized(msg.sender)) { revert NotInitialized(msg.sender); }
        // 1. cannot be lower then threshold after removal
        // 2. owner existed
        // note: DX is bad that I need to specify a prevOwner in removal
        if (ownerCount[msg.sender] == threshold[msg.sender]) { revert CannotRemoveOwner(); }
        if (!owners.contains(msg.sender, owner)) { revert OwnerNotExisted(msg.sender, owner); }

        threshold[msg.sender] -= 1;
        owners.pop(msg.sender, prevOwner, owner);
        emit RemovedOwner(msg.sender, owner);
    }

    function getOwners(address account) external view returns (address[] memory ownersArr) {
        (ownersArr,) = owners.getEntriesPaginated(account, SENTINEL, MAX_OWNERS);
    }

    /**
     * Module logic
     *
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        // bool sigFailed = false;
        // (uint256 sender, bytes memory _signature) = abi.decode(userOp.signature, (uint256, bytes));

        // return _packValidationData(!sigFailed, type(uint48).max, 0);

        // OwnableValidator
        bool isValid = _validateSignatureWithConfig(userOp.sender, userOpHash, userOp.signature);

        if (isValid) { return VALIDATION_SUCCESS; }
        return VALIDATION_FAILED;
    }

    function _validateSignatureWithConfig(
        address sender,
        bytes32 userOpHash,
        bytes calldata signature
    )
        internal
        view
        returns (bool)
    {
        uint8 _threshold = threshold[sender];

        // Can be the case that sender has no module for the acct. In that case threshold == 0
        if (_threshold == 0) { return false; }

        address[] memory signers = CheckSignatures.recoverNSignatures(
            ECDSA.toEthSignedMessageHash(userOpHash),
            signature,
            _threshold
        );

        signers.sort();
        signers.uniquifySorted();
        uint8 signerLen = uint8(signers.length);

        // console.log("signerLen: %s, threshold: %s", signerLen, _threshold);

        if (signerLen < _threshold) { return false; }

        uint8 thresholdNum;

        for (uint8 i = 0; i < signerLen; i++) {
            if (owners.contains(sender, signers[i])) {
                thresholdNum += 1;
            }
        }

        if (thresholdNum >= _threshold) { return true; }
        return false;
    }

    /**
     * Validates an ERC-1271 signature with the sender
     *
     * @param hash bytes32 hash of the data
     * @param signature bytes data containing the signatures
     *
     * @return bytes4 EIP1271_SUCCESS if the signature is valid, EIP1271_FAILED otherwise
     */
    function isValidSignatureWithSender(
        address,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        bool isValid = _validateSignatureWithConfig(msg.sender, hash, signature);

        if (isValid) return EIP1271_SUCCESS;
        return EIP1271_FAILED;
    }

    /**
     * Validates a signature with data only. This is a stateless validation and do not rely on
     *   the contract storage.
     *
     * @param hash bytes32 hash of the data
     * @param signature bytes data containing the signatures
     * @param data bytes data containing the data. Whatever read from the storage is encoded in the `data`.
     *
     * @return bool true if the signature is valid, false otherwise
     */
    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata signature,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bool)
    {
        (uint8 _threshold, address[] memory _owners) = abi.decode(data, (uint8, address[]));

        // `_owners` have to be sorted and unique
        if (!_owners.isSortedAndUniquified()) {
            return false;
        }

        if (_threshold == 0) {
            return false;
        }

        address[] memory signers = CheckSignatures.recoverNSignatures(
            ECDSA.toEthSignedMessageHash(hash), signature, _threshold
        );

        // You need to sort() and uniquifySorted() <- this is the proper way to use it.
        signers.sort();
        signers.uniquifySorted();

        uint8 validSigners;
        uint8 signersLength = uint8(signers.length);
        for (uint256 i = 0; i < signersLength; i++) {
            (bool found,) = _owners.searchSorted(signers[i]);
            if (found) validSigners += 1;
        }

        if (validSigners >= _threshold) return true;
        return false;
    }

    function addMember(uint256 memberCommitment) external
        moduleInstalled
    {
        // The gId of the smart account
        uint256 gId = gIds[msg.sender];

        // TODO: perform checking & error handling once this work
        semaphore.addMember(gId, memberCommitment);
    }

    function removeMember(uint256 identityCommitment, uint256[] calldata merkleProofSiblings) external
        moduleInstalled
    {
        // The gId of the smart account
        uint256 gId = gIds[msg.sender];
        semaphore.removeMember(gId, identityCommitment, merkleProofSiblings);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Check if the module is of a certain type
     *
     * @param typeID The type ID to check
     *
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR || typeID == TYPE_POLICY;
    }

    /**
     * The name of the module
     *
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "SemaphoreValidator";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }
}
