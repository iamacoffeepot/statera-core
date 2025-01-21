pragma solidity 0.8.27;

struct Bucket {
    uint256 liquidityBorrowed;
    uint256 liquiditySupplied;
    uint256 liquidityWeighted;
    uint256 supplierProfitsRealized;
}