pragma solidity 0.8.27;

/// @notice A binary fixed point number with 4 integer bits and 4 fraction bits.
type Q4x4 is uint8;

/// @dev Alias of `type(uint8).max` for use in inline assembly.
uint256 constant UINT8_MAXIMUM = 0xff;

/// @dev The numerical representation of one for a `Q4x4`.
Q4x4 constant Q4X4_ONE = Q4x4.wrap(1 << 4);

using {
    Q4x4IsEqualTo              as ==,
    Q4x4IsGreaterThan          as >,
    Q4x4IsGreaterThanOrEqualTo as >=,
    Q4x4IsLessThan             as <,
    Q4x4IsLessThanOrEqualTo    as <=,
    Q4x4Subtract               as -
} for Q4x4 global;

/// @notice Returns `true` if `x` is equal to `y`.
function Q4x4IsEqualTo(Q4x4 x, Q4x4 y) pure returns (bool result) {
    assembly {
        result := eq(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y))
    }
}

/// @notice Returns `true` if `x` is greater than `y`.
function Q4x4IsGreaterThan(Q4x4 x, Q4x4 y) pure returns (bool result) {
    assembly {
        result := gt(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y))
    }
}

/// @notice Returns `true` if `x` is greater than or equal to `y`.
function Q4x4IsGreaterThanOrEqualTo(Q4x4 x, Q4x4 y) pure returns (bool result) {
    assembly {
        result := iszero(lt(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y)))
    }
}

/// @notice Returns `true` if `x` is less than `y`.
function Q4x4IsLessThan(Q4x4 x, Q4x4 y) pure returns (bool result) {
    assembly {
        result := lt(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y))
    }
}

/// @notice Returns `true` if `x` is less than or equal to `y`.
function Q4x4IsLessThanOrEqualTo(Q4x4 x, Q4x4 y) pure returns (bool result) {
    assembly {
        result := iszero(gt(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y)))
    }
}

/// @notice Returns `x - y`.
function Q4x4Subtract(Q4x4 x, Q4x4 y) pure returns (Q4x4 result) {
    // TODO: Revert if y > x
    assembly {
        result := sub(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y))
    }
}