pragma solidity 0.8.27;

import {TokenizedVault} from "../interfaces/TokenizedVault.sol";

import {
    Bucket,
    KernelError,
    KernelErrorType
} from "../types/Types.sol";

/// @notice A collection of functions for performing operations on a `Bucket`.
library BucketLibrary {
    /// @custom:todo
    function getUnrealizedProfits(Bucket storage bucket, TokenizedVault vault) internal view returns (uint256 result) {
        // This computation assumes that TokenizedVault.convertToAssets(x) is additive:
        // f(x) + f(y) + f(z) + ... = f(x + y + z + ...)
        //
        // U_1 = V_1 - K_1
        // U_2 = V_2 - K_2
        // ...
        // U_i = V_i - K_i
        //
        // U_1 + U_2 + ... U_N = V_0 + V_1 + ... + V_2 - K_1 - K_2 - ... K_N
        //
        // ΣU = ΣV - ΣK
        return vault.convertToAssets(bucket.shares) - bucket.totalInitialValue;
    }

    /// @custom:todo
    function getExpectedShares(
        Bucket storage bucket,
        uint256 supplierWeightedLiquidity
    ) internal view returns (uint256 result) {
        return bucket.shares * supplierWeightedLiquidity / bucket.liquidityWeighted;
    }
}