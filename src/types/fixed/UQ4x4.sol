pragma solidity 0.8.27;

import {CoreError, CoreErrorType} from "../CoreError.sol";

/// @notice An unsigned binary fixed point number with 4 integer bits and 4 fraction bits.
type UQ4x4 is uint8;

/// @dev Alias of `type(uint8).max` for use in inline assembly.
uint256 constant UINT8_MAXIMUM = 0xff;

/// @custom:todo
uint8 constant UQ4X4_SCALING_FACTOR = 1 << 4;

/// @dev The numerical representation of one for a `Q4x4`.
UQ4x4 constant UQ4X4_ONE = UQ4x4.wrap(UQ4X4_SCALING_FACTOR);

using {
    UQ4x4IsEqualTo              as ==,
    UQ4x4IsGreaterThan          as >,
    UQ4x4IsGreaterThanOrEqualTo as >=,
    UQ4x4IsLessThan             as <,
    UQ4x4IsLessThanOrEqualTo    as <=,
    UQ4x4Subtract               as -
} for UQ4x4 global;

/// @notice Returns `true` if `x` is equal to `y`.
function UQ4x4IsEqualTo(UQ4x4 x, UQ4x4 y) pure returns (bool result) {
    assembly {
        result := eq(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y))
    }
}

/// @notice Returns `true` if `x` is greater than `y`.
function UQ4x4IsGreaterThan(UQ4x4 x, UQ4x4 y) pure returns (bool result) {
    assembly {
        result := gt(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y))
    }
}

/// @notice Returns `true` if `x` is greater than or equal to `y`.
function UQ4x4IsGreaterThanOrEqualTo(UQ4x4 x, UQ4x4 y) pure returns (bool result) {
    assembly {
        result := iszero(lt(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y)))
    }
}

/// @notice Returns `true` if `x` is less than `y`.
function UQ4x4IsLessThan(UQ4x4 x, UQ4x4 y) pure returns (bool result) {
    assembly {
        result := lt(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y))
    }
}

/// @notice Returns `true` if `x` is less than or equal to `y`.
function UQ4x4IsLessThanOrEqualTo(UQ4x4 x, UQ4x4 y) pure returns (bool result) {
    assembly {
        result := iszero(gt(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y)))
    }
}

/// @notice Returns `x - y`.
function UQ4x4Subtract(UQ4x4 x, UQ4x4 y) pure returns (UQ4x4 result) {
    uint256 u = UQ4x4.unwrap(x);
    uint256 v = UQ4x4.unwrap(y);

    require(v > u, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));

    assembly { result := sub(u, v) }
}