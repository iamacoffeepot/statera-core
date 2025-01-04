pragma solidity 0.8.27;

import {Q4x4} from "./fixed/Q4x4.sol";

/// @dev Alias of `type(uint8).max` for use in inline assembly.
uint256 constant UINT8_MAXIMUM = 0xff;

struct LendingTerms {
    Q4x4 borrowFactor;
    Q4x4 profitFactor;
}

/// @notice A compact representation of `LendingTerms`. The 4 least significant bits correspond to the fractional
/// bits of the profit factor. The 4 most significant bits correspond to the fractional bits of the borrow factor.
type LendingTermsPacked is uint8;

using {
    LendingTermsPackedIsEqual as ==
} for LendingTermsPacked global;

/// @notice Returns `true` if `x` is equal to `y`.
function LendingTermsPackedIsEqual(LendingTermsPacked x, LendingTermsPacked y) pure returns (bool result) {
    assembly {
        result := eq(and(UINT8_MAXIMUM, x), and(UINT8_MAXIMUM, y))
    }
}