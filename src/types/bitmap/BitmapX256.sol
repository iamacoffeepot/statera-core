pragma solidity 0.8.27;

/// @notice A bitmap that supports up to 256 boolean elements.
type BitmapX256 is uint256;

using {
    BitmapX256IsEqual    as ==,
    BitmapX256BitwiseAnd as &,
    BitmapX256BitwiseOr  as |,
    BitmapX256BitwiseXor as ^
} for BitmapX256 global;

/// @notice Returns `true` if `x` is equal to `y`.
function BitmapX256IsEqual(BitmapX256 x, BitmapX256 y) pure returns (bool result) {
    assembly { result := eq(x, y) }
}

/// @notice Returns `x & y`.
function BitmapX256BitwiseAnd(BitmapX256 x, BitmapX256 y) pure returns (BitmapX256 result) {
    assembly { result := and(x, y) }
}

/// @notice Returns `x | y`.
function BitmapX256BitwiseOr(BitmapX256 x, BitmapX256 y) pure returns (BitmapX256 result) {
    assembly { result := or(x, y) }
}

/// @notice Returns `x ^ y`.
function BitmapX256BitwiseXor(BitmapX256 x, BitmapX256 y) pure returns (BitmapX256 result) {
    assembly { result := xor(x, y) }
}