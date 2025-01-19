pragma solidity 0.8.27;

import {LendingTermsPacked} from "./LendingTerms.sol";
import {Q4x4} from "./fixed/Q4x4.sol";

struct Loan {
    uint256 bucketBitmap;
    uint256 sharesSupplied;
    uint256 sharesValue;
    uint256 liquidityBorrowed;
    Q4x4 borrowFactor;
}