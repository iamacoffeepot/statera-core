pragma solidity 0.8.27;

import {Token} from "../interfaces/Token.sol";

/// @notice A collection of functions to transfer tokens that may or may not conform to the ERC-20 standard.
library TokenTransferLibrary {
    /// @notice TODO
    /// @param token The token to transfer.
    /// @param recipient The address to transfer the tokens to.
    /// @param amount The amount of tokens to transfer.
    /// @return success If the transfer was successful.
    /// @custom:todo
    function trySafeTransfer(Token token, address recipient, uint256 amount) internal returns (bool success) {
        return false;
    }

    /// @notice TODO
    /// @param token The token to transfer.
    /// @param owner TODO
    /// @param recipient The address to transfer the tokens to.
    /// @param amount The amount of tokens to transfer.
    /// @return success If the transfer was successful.
    /// @custom:todo
    function trySafeTransferFrom(Token token, address owner, address recipient, uint256 amount) internal returns (bool success) {
        return false;
    }
}