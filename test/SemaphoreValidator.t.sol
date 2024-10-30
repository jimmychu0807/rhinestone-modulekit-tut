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

import { Semaphore } from "@semaphore-protocol/Semaphore.sol";
import { ISemaphore } from "@semaphore-protocol/interfaces/ISemaphore.sol";
import { SemaphoreVerifier } from "@semaphore-protocol/base/SemaphoreVerifier.sol";
import { ISemaphoreVerifier } from "@semaphore-protocol/interfaces/ISemaphoreVerifier.sol";

import { SemaphoreValidator } from "src/SemaphoreValidator.sol";

contract SemaphoreValidatorTest is RhinestoneModuleKit, Test {
  using ModuleKitHelpers for *;
  using ModuleKitUserOp for *;

  AccountInstance internal smartAcct;
  SemaphoreValidator internal semaphoreValidator;

  Account user1;
  Account user2;
  Account admin;

  function setUp() public {
    init();

    // Deploy Semaphore
    SemaphoreVerifier semaphoreVerifier = new SemaphoreVerifier();
    vm.label(address(semaphoreVerifier), "SemaphoreVerifier");
    Semaphore semaphore = new Semaphore(ISemaphoreVerifier(address(semaphoreVerifier)));
    vm.label(address(semaphore), "Semaphore");
    // Create the validator
    semaphoreValidator = new SemaphoreValidator(semaphore);
    vm.label(address(semaphoreValidator), "SemaphoreValidator");

    console.log("semaphoreVerifier addr: %s", address(semaphoreVerifier));
    console.log("semaphore addr: %s", address(semaphore));
    console.log("semaphoreValidator addr: %s", address(semaphoreValidator));

    // Create some users
    user1 = makeAccount("user1");
    user2 = makeAccount("user2");
    admin = makeAccount("admin");
    vm.deal(user1.addr, 10 ether);
    vm.deal(user2.addr, 10 ether);
    vm.deal(admin.addr, 10 ether);

    // Create the acct and install the validator
    smartAcct = makeAccountInstance("Smart Acct");
    vm.deal(address(smartAcct.account), 10 ether);
  }

  function test_SemaphoreDeployProperly() public {
    ISemaphore semaphore = semaphoreValidator.semaphore();
    uint256 gId = semaphore.createGroup(admin.addr);
    console.log("gId: %d", gId);

    vm.prank(admin.addr);
    uint256[] memory members = new uint256[](3);
    members[0] = uint256(uint160(admin.addr));
    members[1] = uint256(2);
    members[2] = uint256(3);

    semaphore.addMembers(gId, members);
  }

  function test_InstallSemaphoreValidator() public {
    smartAcct.installModule({
      moduleTypeId: MODULE_TYPE_VALIDATOR,
      module: address(semaphoreValidator),
      data: abi.encode(admin.addr)
    });

    // uint256 groupCounter = semaphoreValidator.semaphore.groupCounter();
    // assertEq(groupCounter, 1);
  }

  function test_RevertWhen_InstallSemaphoreValidatorMultipleTimes() public {
    // vm.expectRevert(SemaphoreValidator.SemaphoreValidatorAlreadyInstalled.selector);

    // smartAcct.installModule({
    //   moduleTypeId: MODULE_TYPE_VALIDATOR,
    //   module: address(semaphoreValidator),
    //   data: abi.encode(admin.addr)
    // });
  }
}
