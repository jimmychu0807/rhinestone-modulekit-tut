// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { console } from "forge-std/console.sol";

import { ERC7579ValidatorBase, ERC7484RegistryAdapter } from "modulekit/Modules.sol";
import { IStatelessValidator, IERC7484 } from "modulekit/Interfaces.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { FlatBytesLib } from "./utils/Flatbytes.sol";
import { MultiFactorLib } from "./utils/MultiFactorLib.sol";

type ValidatorId is bytes12;

struct Validator {
    bytes32 packedValidatorAndId;
    bytes data;
}

struct SubValidatorConfig {
    bytes data;
}

struct IterativeSubvalidatorRecord {
    mapping(ValidatorId id => mapping(address account => FlatBytesLib.Bytes config)) subValidators;
}

struct MFAConfig {
    uint8 threshold;
    uint8 validationLength;
    uint64 iteration;
}

contract MultiFactor is ERC7579ValidatorBase, ERC7484RegistryAdapter {
    using FlatBytesLib for *;

    // errors
    error ZeroThreshold();
    error InvalidThreshold(uint256 length, uint8 threshold);
    error InvalidValidatorData();

    // events
    event ThresholdSet(address account, uint8 threshold);
    event ValidatorAdd(address account, address valAddr, ValidatorId id, uint256 iteration);

    // The storage
    mapping(address account => MFAConfig config) public accountConfig;
    mapping(uint256 iteration => mapping(address subValidator => IterativeSubvalidatorRecord)) internal iterationToSubValidator;

    constructor(IERC7484 _registry) ERC7484RegistryAdapter(_registry) {}

    function onInstall(bytes calldata data) external virtual {
        address account = msg.sender;

        if (isInitialized(account)) revert AlreadyInitialized(account);

        uint8 threshold = uint8(bytes1(data[:1]));
        if (threshold == 0) revert ZeroThreshold();

        Validator[] calldata validators = MultiFactorLib.decode(data[1:]);
        uint256 length = validators.length;

        if (length < threshold) revert InvalidThreshold(length, threshold);
        if (length > type(uint8).max) revert InvalidValidatorData();

        MFAConfig storage $config = accountConfig[account];
        uint256 iteration = $config.iteration;
        $config.threshold = threshold;

        emit ThresholdSet(account, threshold);

        uint8 _valLen;

        for (uint256 i; i < length; i++) {
            Validator calldata _validator = validators[i];

            // unpack
            (address valAddr, ValidatorId id) =
                MultiFactorLib.unpack(_validator.packedValidatorAndId);

            // retrieve the storage pointer
            FlatBytesLib.Bytes storage $validator = $subValidatorData({
                account: account,
                iteration: iteration,
                valAddr: valAddr,
                id: id
            });

            // check if the subValidator is an attested validator and revert if not.
            REGISTRY.checkForAccount({
                smartAccount: account,
                module: valAddr,
                moduleType: MODULE_TYPE_VALIDATOR
            });

            $validator.store(_validator.data);

            if (_validator.data.length != 0) _valLen += 1;

            emit ValidatorAdd(account, valAddr, id, iteration);
        }

        $config.validationLength = _valLen;
    }

    function onUninstall(bytes calldata data) external virtual view {

    }

    function isInitialized(address account) public virtual view returns (bool) {
        MFAConfig storage $config = accountConfig[account];
        return $config.threshold > 0;
    }

    function isModuleType(uint256 moduleTypeId) external view returns (bool) {
        return moduleTypeId == TYPE_VALIDATOR;
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        return VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        virtual
        override
        returns (bytes4 sigValidationResult)
    {
        return EIP1271_FAILED;
    }

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
        return false;
    }

    // Internal helpers
    function $subValidatorData(
        address account,
        uint256 iteration,
        address valAddr,
        ValidatorId id
    )
        internal
        view
        returns (FlatBytesLib.Bytes storage $validatorData)
    {
        return iterationToSubValidator[iteration][valAddr].subValidators[id][account];
    }

}
