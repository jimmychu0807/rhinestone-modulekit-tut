// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";

import { OwnableExecutor } from "src/OwnableExecutor.sol";
import { MockTarget } from "test/utils/MockTarget.sol";

contract OwnableExecutorUnitTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using LibSort for *;

    OwnableExecutor internal executor;
    MockTarget internal target;

    address[] $owners;

    function setUp() public {
        executor = new OwnableExecutor();
        target = new MockTarget();

        address o1 = makeAddr("owner1");
        address o2 = makeAddr("owner2");
        $owners = [o1, o2];
        $owners.sort();
    }

    function test_OnInstallRevertWhen_ModuleIsInitialized() public {
        bytes memory data = abi.encodePacked($owners[0]);

        executor.onInstall(data);
        vm.expectRevert();
        executor.onInstall(data);
    }

    function test_OnInstallWhenModuleIsNotInitailized() public {
        bytes memory data = abi.encodePacked($owners[0]);
        executor.onInstall(data);

        address[] memory owners = executor.getOwners(address(this));
        assertEq(owners.length, 1);
        assertEq(owners[0], $owners[0]);
        assertEq(executor.ownerCount(address(this)), 1);
    }

    function test_ExecuteOnOwnedAccountWhenMsgSenderIsAnOwner() public {
        address owner = $owners[0];
        bytes memory data = abi.encodePacked(owner);
        address ownedAccount = address(target);

        vm.prank(ownedAccount);
        executor.onInstall(data);

        address[] memory owners = executor.getOwners(ownedAccount);
        assertEq(owners.length, 1);
        assertEq(owners[0], owner);

        uint256 val = 24;
        vm.prank(address(owner));
        executor.executeOnOwnedAccount(ownedAccount, abi.encode(val));

        uint256 res = target.value();
        assertEq(res, val);
    }
}
