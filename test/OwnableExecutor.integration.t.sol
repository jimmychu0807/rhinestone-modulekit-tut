// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { SENTINEL } from "src/utils/SentinelList.sol";
import { OwnableExecutor } from "src/OwnableExecutor.sol";

contract OwnableExecutorUnitTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using LibSort for *;

    OwnableExecutor internal executor;
    AccountInstance internal smartAcct;
    address[] $owners;
    address target;

    function setUp() public {
        init();
        executor = new OwnableExecutor();
        target = makeAddr("target");

        address o1 = makeAddr("owner1");
        address o2 = makeAddr("owner2");
        $owners = [o1, o2];
        $owners.sort();

        smartAcct = makeAccountInstance("smartAcct");
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: abi.encodePacked($owners[0])
        });

        address[] memory owners = executor.getOwners(smartAcct.account);
        assertEq(owners[0], $owners[0]);
    }

    function test_AddOwner() public {

    }
}
