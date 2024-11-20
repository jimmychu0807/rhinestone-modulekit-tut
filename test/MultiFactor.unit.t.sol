// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    MultiFactor,
    ERC7579ValidatorBase,
    Validator,
    ValidatorId
} from "src/MultiFactor.sol";
import { Test } from "forge-std/Test.sol";
import { IERC7579Module } from "modulekit/external/ERC7579.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp
} from "modulekit/ModuleKit.sol";
import {
    PackedUserOperation,
    getEmptyUserOperation,
    parseValidationData,
    ValidationData
} from "./utils/ERC4337.sol";

import { MockRegistry } from "test/utils/MockRegistry.sol";
import { MockValidator } from "test/utils/MockValidator.sol";

bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;

contract OwnableExecutorUnitTest is RhinestoneModuleKit, Test {
    // Contracts

    MultiFactor internal $$validator;
    MockRegistry internal $$registry;
    MockValidator internal $$subVal1;
    MockValidator internal $$subVal2;

    uint8 $threshold = 2;

    function setUp() public virtual {
        init();

        $$registry = new MockRegistry();
        $$validator = new MultiFactor($$registry);
        $$subVal1 = new MockValidator();
        $$subVal2 = new MockValidator();
    }

    function _getValidators() internal returns (Validator[] memory validators) {
        validators = new Validator[](2);
        validators[0] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(0), address($$subVal1))),
            data: hex"41414141"
        });

        validators[1] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(0), address($$subVal2))),
            data: hex"42424242"
        });
    }

    function test_OnInstallWhenAllValidatorsAreAttestedTo()
        public
    {
        Validator[] memory validators = _getValidators();
        bytes memory data = abi.encodePacked($threshold, abi.encode(validators));

        vm.expectEmit(true, true, true, true, address($$validator));
        emit MultiFactor.ValidatorAdd({
            account: address(this),
            valAddr: address($$subVal1),
            id: ValidatorId.wrap(bytes12(0)),
            iteration: 0
        });

        $$validator.onInstall(data);

        (uint8 threshold,, uint128 iteration) = $$validator.accountConfig(address(this));
        assertEq(threshold, $threshold);

        assertTrue(
            $$validator.isSubValidator(address(this), address($$subVal1), ValidatorId.wrap(bytes12(0)))
        );

        assertTrue(
            $$validator.isSubValidator(address(this), address($$subVal2), ValidatorId.wrap(bytes12(0)))
        );
    }

    function test_OnUninstall() public {
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        $$validator.onUninstall(hex"");
        (uint8 threshold,, uint64 iteration) = $$validator.accountConfig(address(this));

        assertEq(iteration, 1);
        assertEq(threshold, uint8(0));
    }

    function test_ValidateUserOpWhenValidSignaturesAreLessThanThreshold() public {
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        PackedUserOperation memory userOp = getEmptyUserOperation();

        Validator[] memory validators = _getValidators();
        validators[1].data = bytes("invalid");

        userOp.signature = abi.encode(validators);
        userOp.sender = address(this);

        bytes32 userOpHash = keccak256("userOpHash");

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(
                $$validator.validateUserOp(userOp, userOpHash)
            );
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenValidSignaturesAreGreaterThanThreshold()
        public
    {
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        PackedUserOperation memory userOp = getEmptyUserOperation();

        Validator[] memory validators = _getValidators();
        userOp.signature = abi.encode(validators);
        userOp.sender = address(this);

        bytes32 userOpHash = keccak256("userOpHash");

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(
                $$validator.validateUserOp(userOp, userOpHash)
            );
        assertEq(validationData, 0);
    }
}
