pragma solidity 0.8.27;

interface ReadOnlyDelegateCallSource {
    function executeReadOnlyDelegateCall(address logic, bytes calldata data) external view;
}