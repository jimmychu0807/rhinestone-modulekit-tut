// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance,
    UserOpData
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import {
    Semaphore,
    ISemaphore,
    ISemaphoreGroups,
    ISemaphoreVerifier,
    SemaphoreVerifier
} from "src/utils/semaphore.sol";

import { SemaphoreMSAValidator, ERC7579ValidatorBase } from "src/SemaphoreMSAValidator.sol";
import { LibSort } from "solady/utils/LibSort.sol";

contract SemaphoreValidatorIntegrationTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using LibSort for *;

    SemaphoreMSAValidator internal semaphoreValidator;

    /*//////////
       VARIABLES
    //////////*/

    AccountInstance internal smartAcct;
    uint256 _threshold = 2;
    address[] $owners;
    uint256[] $ownerSks;

    function setUp() public virtual
    {
        init();
        smartAcct = makeAccountInstance("smartAcct");
        vm.deal(address(smartAcct.account), 10 ether);

        SemaphoreVerifier semaphoreVerifier = new SemaphoreVerifier();
        vm.label(address(semaphoreVerifier), "SemaphoreVerifier");
        Semaphore semaphore = new Semaphore(ISemaphoreVerifier(address(semaphoreVerifier)));
        vm.label(address(semaphore), "Semaphore");
        // Create the validator
        semaphoreValidator = new SemaphoreMSAValidator(semaphore);
        vm.label(address(semaphoreValidator), "SemaphoreMSAValidator");

        $owners = new address[](2);
        $ownerSks = new uint256[](2);

        (address o1, uint256 os1) = makeAddrAndKey("owner1");
        $owners[0] = o1;
        $ownerSks[0] = os1;

        (address o2, uint256 os2) = makeAddrAndKey("owner2");
        uint256 cnt = 0;
        while (uint160(o2) <= uint160(o1)) {
            (o2, os2) = makeAddrAndKey(vm.toString(cnt));
            cnt += 1;
        }
        $owners[1] = o2;
        $ownerSks[1] = os2;

        // It is in integration that you install the module in an acct
        smartAcct.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(semaphoreValidator),
            data: abi.encode(_threshold, $owners)
        });
    }

    function test_OnInstallSetOwnersAndThreshold() public {
        assertEq(semaphoreValidator.threshold(smartAcct.account), _threshold);
        assertEq(semaphoreValidator.ownerCount(smartAcct.account), $owners.length);

        address[] memory res = semaphoreValidator.getOwners(smartAcct.account);
        res.sort();
        assertEq(res, $owners);
    }

    function test_ValidateUserOp() public {
        address target = makeAddr("target");

        UserOpData memory userOpData = smartAcct.getExecOps({
            target: target,
            value: 1,
            callData: "",
            txValidator: address(semaphoreValidator)
        });

        bytes memory sign1 = signHash($ownerSks[0], userOpData.userOpHash);
        bytes memory sign2 = signHash($ownerSks[1], userOpData.userOpHash);
        userOpData.userOp.signature = abi.encodePacked(sign1, sign2);
        userOpData.execUserOps();

        assertEq(target.balance, 1);
    }

    function test_ERC1271() public {

    }
}
