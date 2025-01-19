pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {LendingTermsLibrary} from "../src/libraries/LendingTermsLibrary.sol";
import {LendingTermsPacked, Q4x4} from "../src/types/Types.sol";

contract LendingTermsLibraryTest is Test {
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