pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {BitMathLibrary} from "../../src/libraries/BitMathLibrary.sol";

contract BitMathLibraryTest is Test {
    function test_find_first_set() external {
        for (uint256 i = 0; i < 256; i++) {
            assertEq(BitMathLibrary.ffs(1 << i), i);
        }
    }

    function test_fuzz_find_first_set(uint8 n, uint256 jitter) external {
        // Construct a random-ish input which always has the nth bit set with randomly set bits after those.
        // If the nth bit is the most significant bit then we do nothing as there are no bits to set after.
        uint256 x = 1 << n | (n < 255 ? jitter << n + 1 : 0);
        assertEq(BitMathLibrary.ffs(x), n);
    }
}