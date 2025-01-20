pragma solidity 0.8.27;

/// @notice An interface that defines the functions and events that a contract must implement to adhere to the ERC-20 Token Standard.
interface Token {
    /// @notice Emitted when `owner` approves `spender` to spend `value` tokens on their behalf.
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Emitted when `amount` tokens are transferred from `owner` to `recipient`.
    event Transfer(address indexed owner, address indexed recipient, uint256 amount);

    /// @notice The name of the token.
    /// @dev At the time that the ERC-20 specification was written this function was considered optional. However,
    /// in practice it is considered unusual for a contract implementing the ERC-20 specification to not include this
    /// function.
    function name() external view returns (string memory);

    /// @notice The symbol of the token.
    /// @dev At the time that the ERC-20 specification was written this function was considered optional. However,
    /// in practice it is considered unusual for a contract implementing the ERC-20 specification to not include this
    /// function.
    function symbol() external view returns (string memory);

    /// @notice The number of digits that describe the fractional quantity.
    /// @dev At the time that the ERC-20 specification was written this function was considered optional. However,
    /// in practice it is considered unusual for a contract implementing the ERC-20 specification to not include this
    /// function.
    function decimals() external view returns (uint8);

    /// @notice Returns remaining number of tokens that `spender` can transfer on behalf of `owner`.
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    /// @notice Returns the number of tokens that `owner` holds.
    function balanceOf(address owner) external view returns (uint256 balance);

    /// @notice Returns the number of tokens in circulation.
    function totalSupply() external view returns (uint256);

    /// @notice Approves `spender` to transfer `amount` of tokens. Overrides any existing approval.
    /// @dev Reverting or returning `false` indicates that the approval failed.
    /// @return success `true` if the approval succeeded.
    function approve(address spender, uint256 amount) external returns (bool success);

    /// @notice Transfers `amount` of tokens to `recipient`.
    /// @dev Reverting or returning `false` indicates that the transfer failed.
    /// @return success `true` if the transfer succeeded.
    function transfer(address recipient, uint256 amount) external returns (bool success);

    /// @notice Transfers `amount` of tokens to `recipient` on behalf of `owner`. The caller (the spender) of this
    /// function must have an allowance of at least `amount` tokens.
    /// @dev Reverting or returning `false` indicates that the transfer failed.
    /// @return success `true` if the transfer succeeded.
    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool success);
}