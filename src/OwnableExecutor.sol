// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ExecutorBase } from "modulekit/Modules.sol";
import { IERC7579Account } from "modulekit/Accounts.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import {SentinelListLib, SENTINEL } from "src/utils/SentinelList.sol";

contract OwnableExecutor is ERC7579ExecutorBase {
    using SentinelListLib for SentinelListLib.SentinelList;

    // Errors
    error InvalidOwner(address);
    error OwnerExisted(address, address);
    error UnauthorizedAccess(address);

    // Events
    event ModuleInitialized(address, address);
    event ModuleUninitialized(address);
    event OwnerAdded(address, address);
    event OwnerRemoved(address, address);

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address subAccount => SentinelListLib.SentinelList) accountOwners;
    mapping(address => uint256) public ownerCount;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     *
     * @param data encoded data containing the owner
     */
    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        address owner = address(bytes20(data[:20]));

        if (owner == address(0)) revert InvalidOwner(owner);

        accountOwners[account].init();
        accountOwners[account].push(owner);
        ownerCount[account] = 1;

        emit ModuleInitialized(account, owner);
    }

    /**
     * De-initialize the module with the given data
     */
    function onUninstall(bytes calldata) external override {
        accountOwners[msg.sender].popAll();

        ownerCount[msg.sender] = 0;

        emit ModuleUninitialized(msg.sender);
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return ownerCount[smartAccount] > 0;
    }

    function addOwner(address newOwner) external {
        if (newOwner == address(0)) revert InvalidOwner(newOwner);

        address acct = msg.sender;
        if (accountOwners[acct].contains(newOwner)) revert OwnerExisted(acct, newOwner);

        accountOwners[acct].push(newOwner);
        ownerCount[acct] += 1;

        emit OwnerAdded(acct, newOwner);
    }

    function removeOwner(address prevOwner, address delOwner) external {
        accountOwners[msg.sender].pop(prevOwner, delOwner);
        ownerCount[msg.sender] -= 1;

        emit OwnerRemoved(msg.sender, delOwner);
    }

    function getOwners(address smartAcct) external view returns(address[] memory owners) {
        (owners,) = accountOwners[smartAcct].getEntriesPaginated(SENTINEL, ownerCount[smartAcct]);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * ERC-7579 does not define any specific interface for executors, so the
     * executor can implement any logic that is required for the specific usecase.
     */

    /**
     * Execute the given data
     * @dev This is an example function that can be used to execute arbitrary data
     * @dev This function is not part of the ERC-7579 standard
     *
     * @param data The data to execute
     */
    function execute(bytes calldata data) external {
        IERC7579Account(msg.sender).executeFromExecutor(ModeLib.encodeSimpleSingle(), data);
    }

    function executeOnOwnedAccount(
        address ownedAccount,
        bytes calldata callData
    )
        external
        payable
    {
        if (!accountOwners[ownedAccount].contains(msg.sender)) revert UnauthorizedAccess(ownedAccount);

        IERC7579Account(ownedAccount).executeFromExecutor{ value: msg.value }(
            ModeLib.encodeSimpleSingle(),
            callData
        );
    }

    function executeBatchOnOwnedAccount(
        address ownedAccount,
        bytes calldata callData
    )
        external
        payable
    {
        if (!accountOwners[ownedAccount].contains(msg.sender)) revert UnauthorizedAccess(ownedAccount);

        IERC7579Account(ownedAccount).executeFromExecutor{ value: msg.value }(
            ModeLib.encodeSimpleBatch(),
            callData
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     *
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "OwnableExecutor";
    }

    /**
     * The version of the module
     *
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /**
     * Check if the module is of a certain type
     *
     * @param typeID The type ID to check
     *
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
