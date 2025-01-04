pragma solidity 0.8.27;

/// @notice A collection of functions for performing bitwise math.
library BitmathLibrary {
    /// @notice Returns the index of the least significant bit.
    /// @custom:todo
    function getIndexOfLsb(uint256 x) internal pure returns (uint8 result) {
        require(x > 0);
    }
}