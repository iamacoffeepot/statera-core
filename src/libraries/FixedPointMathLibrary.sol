pragma solidity 0.8.27;

import {
    KernelError,
    KernelErrorType,
    Q4x4
} from "../types/Types.sol";

/// @dev Alias of `type(uint8).max` for use in inline assembly.
uint256 constant UINT8_MAXIMUM = 0xff;

/// @notice A collection of functions for performing operations on fixed point numbers.
library FixedPointMathLibrary {
    /// @notice Multiplies an unsigned 256 bit integer by a binary fixed point number with 4 integer bits and 4 fraction bits.
    function multiplyByQ4x4(uint256 n, Q4x4 q) internal pure returns (uint256 result) {
        require(n < 2**248, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

        assembly {
            result := shr(4, mul(and(UINT8_MAXIMUM, q), n))
        }
    }
}