// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7484 } from "modulekit/Interfaces.sol";

address constant REVERT_ADDR = address(0x420);

contract MockRegistry is IERC7484 {
    function check(address module) external view {
        if (module == REVERT_ADDR) revert();
    }

    function checkForAccount(address smartAcct, address module) external view {
        if (module == REVERT_ADDR) revert();
    }

    function check(address module, uint256 moduleType) external view {
        if (module == REVERT_ADDR) revert();
    }

    function checkForAccount(
        address smartAccount,
        address module,
        uint256 moduleType
    )
        external
        view
    {
        if (module == address(0x420)) {
            revert();
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              Check with external attester(s)               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function check(address module, address[] calldata attesters, uint256 threshold) external view {
        if (module == address(0x420)) {
            revert();
        }
    }

    function check(
        address module,
        uint256 moduleType,
        address[] calldata attesters,
        uint256 threshold
    )
        external
        view
    {
        if (module == address(0x420)) {
            revert();
        }
    }

    function trustAttesters(uint8 threshold, address[] calldata attesters) external { }
}
