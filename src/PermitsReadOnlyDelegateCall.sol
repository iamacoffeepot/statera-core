pragma solidity 0.8.27;

import {ReadOnlyDelegateCallSource} from "./interfaces/ReadOnlyDelegateCallSource.sol";

/// @notice Defines functions which allow for read-only delegate calls.
abstract contract PermitsReadOnlyDelegateCall {
    /// @notice Performs a read-only delegate call to `logic` with `data`. This function always reverts with the
    /// result of the delegate call operation to prevent state changes being committed to this contract. The returned
    /// data is an ABI encoded ordered pair of a boolean indicating if the delegate call reverted and the data bytes
    /// that were returned from the call (`abi.encode(success, data)`).
    /// @dev This function does not restrict `msg.sender`, as such it is possible for any EOA or external contract
    /// to call this function and access all data (private or public).
    function executeReadOnlyDelegateCall(address logic, bytes calldata data) external virtual {
        (bool success, bytes memory result) = logic.delegatecall(data);

        bytes memory packed = abi.encode(success, result);
        assembly { revert(add(packed, 0x20), mload(packed)) }
    }

    /// @notice Casts this contract to a wrapper interface which explicitly provides immutability guarantees for
    /// `executeReadOnlyDelegateCall`.
    /// @dev This performs an implicit cast. Any changes to the `executeReadOnlyDelegateCall` function signature
    /// **MUST** match the `ReadOnlyDelegateCallSource` interface.
    function asReadOnlyDelegateCallSource() internal view returns (ReadOnlyDelegateCallSource result) {
        result = ReadOnlyDelegateCallSource(address(this));
    }
}