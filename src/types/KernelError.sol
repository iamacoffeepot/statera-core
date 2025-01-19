pragma solidity 0.8.27;

error KernelError(KernelErrorType);

enum KernelErrorType {
    ILLEGAL_ARGUMENT,
    ILLEGAL_STATE,
    INSUFFICIENT_COLLATERAL,
    INSUFFICIENT_LIQUIDITY,
    TRANSFER_FAILED,
    UNREACHABLE
}