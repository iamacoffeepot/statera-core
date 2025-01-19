pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {MathLibrary} from "../../src/libraries/MathLibrary.sol";

contract MathLibraryTest is Test {
    function test_fuzz_min(uint256 a, uint256 b) external {
        vm.assume(a < b);
        assertEq(MathLibrary.min(a, b), a);
    }
}