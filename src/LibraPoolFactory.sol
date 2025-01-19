pragma solidity 0.8.27;

import {LibraPool} from "./LibraPool.sol";
import {TokenizedVault} from "./interfaces/TokenizedVault.sol";


import {
    KernelError,
    KernelErrorType
} from "./types/Types.sol";

contract LibraPoolFactory {
    /// @custom:todo
    mapping(TokenizedVault vault => LibraPool pool) public pools;

    /// @notice Creates a pool for `vault`.
    /// @notice
    /// - Reverts with an `ILLEGAL_STATE` error if a pool already exists for `vault`.
    /// @param vault The vault to create a pool for.
    function createPool(TokenizedVault vault) external returns (LibraPool result) {
        require(pools[vault] == LibraPool(address(0)), KernelError(KernelErrorType.ILLEGAL_STATE));

        LibraPool pool = new LibraPool{salt: keccak256(abi.encode(vault))}();

        return pool;
    }
}