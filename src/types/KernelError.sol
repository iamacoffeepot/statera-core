pragma solidity 0.8.27;

error LibraKernelError(KernelErrorType);

enum KernelErrorType {
    ILLEGAL_ARGUMENT,
    ILLEGAL_STATE
}