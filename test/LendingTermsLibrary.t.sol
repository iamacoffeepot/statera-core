pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {LendingTermsLibrary} from "../src/libraries/LendingTermsLibrary.sol";
import {LendingTermsPacked, Q4x4} from "../src/types/Types.sol";

contract LendingTermsLibraryTest is Test {
    function test_is_valid_borrow_factor() external {
        for (
            Q4x4 borrowFactor = LendingTermsLibrary.BORROW_FACTOR_MINIMUM;
            borrowFactor <= LendingTermsLibrary.BORROW_FACTOR_MAXIMUM;
        ) {
            assertTrue(LendingTermsLibrary.isValidBorrowFactor(borrowFactor));
            unchecked { borrowFactor = Q4x4.wrap(Q4x4.unwrap(borrowFactor) + 1); }
        }
    }

    function test_is_valid_profit_factor() external {
        for (
            Q4x4 profitFactor = LendingTermsLibrary.PROFIT_FACTOR_MINIMUM;
            profitFactor <= LendingTermsLibrary.PROFIT_FACTOR_MAXIMUM;
        ) {
            assertTrue(LendingTermsLibrary.isValidProfitFactor(profitFactor));
            unchecked { profitFactor = Q4x4.wrap(Q4x4.unwrap(profitFactor) + 1); }
        }
    }

    function test_fuzz_try_pack_unpack(Q4x4 borrowFactor, Q4x4 profitFactor) external {
        vm.assume(LendingTermsLibrary.isValidBorrowFactor(borrowFactor));
        vm.assume(LendingTermsLibrary.isValidProfitFactor(profitFactor));

        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        assertTrue(success);

        (Q4x4 unpackedBorrowFactor, Q4x4 unpackedProfitFactor) = LendingTermsLibrary.unpack(terms);

        assertTrue(borrowFactor == unpackedBorrowFactor);
        assertTrue(profitFactor == unpackedProfitFactor);
    }
}