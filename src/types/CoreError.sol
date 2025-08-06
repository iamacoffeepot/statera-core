pragma solidity 0.8.27;

error CoreError(CoreErrorType);

enum CoreErrorType {
    ILLEGAL_ARGUMENT,
    ILLEGAL_STATE,
    INSUFFICIENT_COLLATERAL,
    INSUFFICIENT_LIQUIDITY,
    TRANSFER_FAILED,
    UNREACHABLE
}