pragma solidity 0.8.27;

import {LendingTermsPacked} from "./LendingTerms.sol";
import {UQ4x4} from "./fixed/UQ4x4.sol";

struct Loan {
    bool active;
    UQ4x4 borrowFactor;
    uint256 bucketBitmap;
    uint256 liquidityBorrowed;
    uint256 sharesSupplied;
    uint256 sharesValue;
}