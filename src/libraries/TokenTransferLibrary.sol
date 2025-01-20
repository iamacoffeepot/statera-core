pragma solidity 0.8.27;

import {Token} from "../interfaces/Token.sol";

/// @dev Alias of `type(uint160).max` for use in inline assembly.
uint256 constant UINT160_MAXIMUM = 0xffffffffffffffffffffffffffffffffffffffff;

/// @notice A collection of functions to transfer tokens that may or may not conform to the ERC-20 standard.
library TokenTransferLibrary {
    /// @notice Transfers tokens to `recipient`.
    /// @param token The token to transfer.
    /// @param recipient The address to transfer the tokens to.
    /// @param amount The amount of tokens to transfer.
    /// @return success If the transfer was successful.
    function trySafeTransfer(Token token, address recipient, uint256 amount) internal returns (bool success) {
        return false;
    }

    /// @notice Transfers tokens from `owner` to `recipient`.
    /// @param token The token to transfer.
    /// @param owner The address to transfer the tokens from.
    /// @param recipient The address to transfer the tokens to.
    /// @param amount The amount of tokens to transfer.
    /// @return success If the transfer was successful.
    function trySafeTransferFrom(
        Token token,
        address owner,
        address recipient,
        uint256 amount
    ) internal returns (bool success) {
        assembly {
            let pointer := mload(0x40)

            // Encode the call into memory at the free memory pointer. Right pad the function signature with zeros
            // so that it occupies the first four bytes (memory[pointer:pointer+4]). Clean dirty bits from types
            // smaller than word size.
            mstore(pointer,            0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(pointer, 0x04), and(owner,     UINT160_MAXIMUM))
            mstore(add(pointer, 0x24), and(recipient, UINT160_MAXIMUM))
            mstore(add(pointer, 0x44), amount)

            // Input data starts at the free memory pointer address and is 100 bytes in length. Output data is written
            // to scratch space (0x00-0x3f). We only care about the first thirty two bytes which should be an ABI
            // encoded boolean indicating if the transfer succeeded (when any data is returned at all).
            success := call(
                gas(),        // gas
                token,        // address
                0,            // value
                pointer,      // input pointer
                0x64,         // input size
                0x00,         // output pointer
                0x20          // output size
            )

            // +---------+----------------+------------------+----------------+----------+
            // | success | returndatasize | memory[0x0:0x20] | extcodesize    | success' |
            // +---------+----------------+------------------+----------------+----------+
            // | 0       | *              | *                | *              | 0        |
            // | 1       | 0              | *                | 0              | 0        |
            // | 1       | 0              | *                | x > 0          | 1        |
            // | 1       | 0 < x < 32     | *                | *              | 0        |
            // | 1       | x >= 32        | ^1               | *              | 0        |
            // | 1       | x >= 32        | 1                | *              | 1        |
            // +---------+----------------+------------------+----------------+----------+
            //
            // Because call does not return false if the contract does not exist we must check that there exists a
            // response from the contract (which implies it exists) or check manually that the contract exists.
            // See https://github.com/ethereum/solidity/issues/4823 for more information.

            if success {
                switch returndatasize()
                case 0 {
                    success := gt(extcodesize(token), 0)
                }
                default {
                    success := and(gt(returndatasize(), 31), eq(mload(0), 1))
                }
            }
        }
    }
}