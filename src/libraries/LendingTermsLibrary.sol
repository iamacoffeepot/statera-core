pragma solidity 0.8.27;

import {
    BitmapX256,
    LendingTerms,
    LendingTermsPacked,
    Q4x4
} from "../types/Types.sol";

/// @notice TODO
library LendingTermsLibrary {
    /// @notice The minimum accepted borrow factor.
    Q4x4 public constant BORROW_FACTOR_MINIMUM = Q4x4.wrap(1);

    /// @notice The minimum accepted profit factor.
    Q4x4 public constant PROFIT_FACTOR_MINIMUM = Q4x4.wrap(1);

    /// @notice The maximum accepted borrow factor.
    Q4x4 public constant BORROW_FACTOR_MAXIMUM = Q4x4.wrap((1 << 4) - 1);

    /// @notice The maximum accepted profit factor.
    Q4x4 public constant PROFIT_FACTOR_MAXIMUM = Q4x4.wrap((1 << 4) - 1);

    /// @notice Returns `true` if `borrowFactor` is in the accepted range.
    function isValidBorrowFactor(Q4x4 borrowFactor) internal pure returns (bool valid) {
        valid = borrowFactor >= BORROW_FACTOR_MINIMUM && borrowFactor <= BORROW_FACTOR_MAXIMUM;
    }

    /// @notice Returns `true` if `profitFactor` is in the accepted range.
    function isValidProfitFactor(Q4x4 profitFactor) internal pure returns (bool valid) {
        valid = profitFactor >= PROFIT_FACTOR_MINIMUM && profitFactor <= PROFIT_FACTOR_MAXIMUM;
    }

    /// @notice Tries to pack lending terms into an integer.
    /// @notice `result` should be considered undefined when `success` is `false`.
    function tryPack(
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) internal pure returns (LendingTermsPacked result, bool success) {
        if (isValidBorrowFactor(borrowFactor)) success = false;
        if (isValidProfitFactor(profitFactor)) success = false;

        if (success) result = unsafePack(borrowFactor, profitFactor);
    }

    /// @notice Tries to pack `terms` into an integer.
    /// @notice `result` should be considered undefined when `success` is `false`,
    function tryPack(LendingTerms memory terms) internal pure returns (LendingTermsPacked result, bool success) {
        return tryPack(terms.borrowFactor, terms.profitFactor);
    }

    /// @notice Packs lending terms into an integer without checking if the terms are valid.
    function unsafePack(
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) internal pure returns (LendingTermsPacked result) {
        uint8 x = Q4x4.unwrap(borrowFactor);
        uint8 y = Q4x4.unwrap(profitFactor);

        result = LendingTermsPacked.wrap(x << 4 | y);
    }

    /// @notice Packs `terms` into an integer without checking if the terms are valid.
    function unsafePack(LendingTerms memory terms) internal pure returns (LendingTermsPacked result) {
        return unsafePack(terms.borrowFactor, terms.profitFactor);
    }

    /// @notice Unpacks `packed` into lending terms.
    function unpack(LendingTermsPacked packed) internal pure returns (Q4x4 borrowFactor, Q4x4 profitFactor) {
        uint8 unwrapped = LendingTermsPacked.unwrap(packed);

        borrowFactor = Q4x4.wrap(unwrapped >> 4);
        profitFactor = Q4x4.wrap(unwrapped & 0xf);
    }

    /// @custom:todo
    function unpackProfitFactor(LendingTermsPacked packed) internal pure returns (Q4x4 result) {
        uint8 unwrapped = LendingTermsPacked.unwrap(packed);
        result = Q4x4.wrap(unwrapped & 0xf);
    }

    /// @custom:todo
    function unwrap(LendingTermsPacked packed) internal pure returns (uint8 result) {
        return LendingTermsPacked.unwrap(packed);
    }
}