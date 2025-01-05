pragma solidity 0.8.27;

/// @notice A collection of functions for performing bitwise math.
library BitMathLibrary {
    /// @notice Returns the position of the first set bit.
    function ffs(uint256 x) internal pure returns (uint8 result) {
        require(x > 0);

        unchecked {
            if ((x & 0xffffffffffffffffffffffffffffffff) == 0) {
                result += 128;
                x >>= 128;
            }

            if ((x & 0xffffffffffffffff) == 0) {
                result += 64;
                x >>= 64;
            }

            if ((x & 0xffffffff) == 0) {
                result += 32;
                x >>= 32;
            }

            if ((x & 0xffff) == 0) {
                result += 16;
                x >>= 16;
            }

            if ((x & 0xff) == 0) {
                result += 8;
                x >>= 8;
            }

            if ((x & 0xf) == 0) {
                result += 4;
                x >>= 4;
            }

            if ((x & 0x3) == 0) {
                result += 2;
                x >>= 2;
            }

            result += 1;
        }
    }
}