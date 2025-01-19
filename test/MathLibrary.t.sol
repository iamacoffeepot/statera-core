pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {MathLibrary} from "../src/libraries/MathLibrary.sol";

contract MathLibraryTest is Test {
    function test_min() external {
        assertEq(MathLibrary.min(0, 0), 0);
        assertEq(MathLibrary.min(0, 1), 0);
        assertEq(MathLibrary.min(1, 0), 0);
        assertEq(MathLibrary.min(0, type(uint256).max), 0);
        assertEq(MathLibrary.min(type(uint256).max, 0), 0);
    }

    function test_max() external {
        assertEq(MathLibrary.max(0, 0), 0);
        assertEq(MathLibrary.max(0, 1), 1);
        assertEq(MathLibrary.max(1, 0), 1);
        assertEq(MathLibrary.max(0, type(uint256).max), type(uint256).max);
        assertEq(MathLibrary.max(type(uint256).max, 0), type(uint256).max);
    }

    function test_fuzz_min(uint256 a, uint256 b) external {
        vm.assume(a < b);
        assertEq(MathLibrary.min(a, b), a);
    }

    function test_fuzz_max(uint256 a, uint256 b) external {
        vm.assume(a > b);
        assertEq(MathLibrary.max(a, b), a);
    }
}