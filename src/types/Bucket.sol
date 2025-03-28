pragma solidity 0.8.27;

struct Bucket {
    uint256 liquidityBorrowed;
    uint256 liquiditySupplied;
    uint256 liquidityWeighted;
    /// @dev This value is not finalized until after the pool expires or all open loans on a bucket are closed.
    /// @custom:todo The conditions of finalization will change as the design changes and the note should be updated.
    uint256 supplierProfitsRealized;
}