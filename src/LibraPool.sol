pragma solidity 0.8.27;

import {PermitsReadOnlyDelegateCall} from "./PermitsReadOnlyDelegateCall.sol";
import {Token} from "./interfaces/Token.sol";
import {TokenizedVault} from "./interfaces/TokenizedVault.sol";
import {BitmapLibrary} from "./libraries/BitmapLibrary.sol";
import {BitMathLibrary} from "./libraries/BitMathLibrary.sol";
import {BucketLibrary} from "./libraries/BucketLibrary.sol";
import {FixedPointMathLibrary} from "./libraries/FixedPointMathLibrary.sol";
import {LendingTermsLibrary} from "./libraries/LendingTermsLibrary.sol";
import {MathLibrary} from "./libraries/MathLibrary.sol";
import {TokenTransferLibrary} from "./libraries/TokenTransferLibrary.sol";

import {
    BitmapX256,
    Bucket,
    Commitment,
    LendingTerms,
    LendingTermsPacked,
    Loan,
    KernelError,
    KernelErrorType,
    Q4x4,
    Q4X4_ONE
} from "./types/Types.sol";

contract LibraPool is PermitsReadOnlyDelegateCall {
    using BitmapLibrary for BitmapX256;
    using BucketLibrary for Bucket;
    using FixedPointMathLibrary for uint256;
    using LendingTermsLibrary for LendingTerms;
    using LendingTermsLibrary for LendingTermsPacked;
    using TokenTransferLibrary for Token;
    using TokenTransferLibrary for TokenizedVault;

    // @custom:todo Are parameters properly indexed?
    event SupplyLiquidity(
        address indexed sender,
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
        uint256 liquidity,
        address indexed recipient
    );

    /// @notice The vault whose shares are accepted as collateral.
    TokenizedVault immutable public vault;

    /// @notice The underlying token that `vault` uses for accounting, depositing, and withdrawing.
    Token immutable public asset;

    /// @notice The time at which this pool expires.
    uint256 immutable public timeExpires;

    /// @notice The time at which the auction starts.
    /// @custom:invariant `timeAuctionStart < timeExpires`
    uint256 immutable public timeAuctionStarts;

    /// @notice The total amount of liquidity supplied to the pool.
    uint256 public totalLiquiditySupplied;

    /// @notice The total amount of liquidity borrowed from the pool.
    uint256 public totalLiquidityBorrowed;

    /// @custom:todo
    uint256 public totalLoans;

    /// @custom:todo
    mapping(LendingTermsPacked => Bucket) public buckets;

    /// @custom:todo
    mapping(address supplier => mapping(LendingTermsPacked => Commitment)) public commitments;

    /// @custom:todo
    mapping(uint256 id => Loan) public loans;

    /// @custom:todo
    mapping(uint256 id => mapping(LendingTermsPacked => uint256 liquidity)) public loanChunks;

    /// @notice A bitmap for each address that specifies the buckets that they have supplied liquidity to.
    mapping(address supplier => uint256) public supplierBucketBitmap;

    constructor() { }

    /// @notice Returns the number of seconds remaining until this pool expires respective to `timestamp`.
    /// @notice This function returns `0` if this pool has already expired.
    function getSecondsUntilExpiration(uint256 timestamp) public view returns (uint256) {
        if (timestamp >= timeExpires) {
            return 0;
        }

        unchecked {
            return timeExpires - timestamp;
        }
    }

    /// @notice Returns the number of seconds remaining until this pool expires.
    /// @notice This function returns `0` if this pool has already expired.
    function getSecondsUntilExpiration() public view returns (uint256) {
        return getSecondsUntilExpiration(block.timestamp);
    }

    /// @notice Returns the number of seconds remaining until the auction starts respective to `timestamp`.
    /// @notice This function returns `0` if the auction has already started.
    function getSecondsUntilAuctionStart(uint256 timestamp) public view returns (uint256) {
        if (timestamp >= timeAuctionStarts) {
            return 0;
        }

        unchecked {
            return timeAuctionStarts - timestamp;
        }
    }

    /// @notice Returns the number of seconds remaining until the auction starts.
    /// @notice This function returns `0` if the auction has already started.
    function getSecondsUntilAuctionStart() public view returns (uint256) {
        return getSecondsUntilAuctionStart(block.timestamp);
    }

    /// @custom:todo
    function getBucket(
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) public view returns (LendingTermsPacked terms, Bucket memory bucket) {
        (LendingTermsPacked terms, Bucket storage bucket) = getBucketPointer(borrowFactor, profitFactor);
        return (terms, bucket);
    }

    /// @notice Returns a storage pointer to the bucket associated with the given lending terms
    /// (`borrowFactor` and `profitFactor`).
    function getBucketPointer(
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) internal view returns (LendingTermsPacked terms, Bucket storage bucket) {
        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));
        return (terms, buckets[terms]);
    }

    /// @notice Returns the amount of profits that have are yet to be realized for a bucket associated with the
    /// given lending terms (`borrowFactor` and `profitFactor`).
    function getBucketProfitsUnrealized(Q4x4 borrowFactor, Q4x4 profitFactor) public view returns (uint256 result) {
        (/* LendingTermsPacked terms */, Bucket storage bucket) = getBucketPointer(borrowFactor, profitFactor);

        // All recorded profits are final when the pool expires.
        if (getSecondsUntilExpiration() == 0) return 0;

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
        uint256 currentValue = vault.convertToAssets(bucket.sharesSupplied);
        if (bucket.sharesValueInitial > currentValue) return 0;

        unchecked {
            return currentValue - bucket.sharesValueInitial;
        }
    }

    /// @notice Returns the amount of liquidity that is available to be borrowed from a bucket associated with
    /// the given lending terms (`borrowFactor` and `profitFactor`).
    function getBucketLiquidityAvailable(Q4x4 borrowFactor, Q4x4 profitFactor) public view returns (uint256 result) {
        (/* LendingTermsPacked terms */, Bucket storage bucket) = getBucketPointer(borrowFactor, profitFactor);
        return bucket.liquiditySupplied - bucket.liquidityBorrowed;
    }

    /// @custom:todo
    function getLoanProfits(uint256 loanId) public view returns (uint256 result) {
        Loan storage loan = loans[loanId];

        uint256 sharesValue = vault.convertToAssets(loan.sharesSupplied);
        if (sharesValue < loan.sharesValue) return 0;

        unchecked {
            return sharesValue - loan.sharesValue;
        }
    }

    /// @notice Returns the amount of liquidity that `supplier` should expect to receive back from a bucket
    /// associated with the given lending terms (`borrowFactor` and `profitFactor`).
    /// @notice This value must only be used as an estimate when `getSecondsUntilExpiration() > 0`.
    function getSupplierLiquidity(
        address supplier,
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) public view returns (uint256 result) {
        (LendingTermsPacked terms, Bucket storage bucket) = getBucketPointer(borrowFactor, profitFactor);

        Commitment storage commit = commitments[supplier][terms];
        if (commit.liquidityWeighted == 0) return 0;

        uint256 liquidityAvailable;
        unchecked {
            liquidityAvailable = bucket.liquiditySupplied - bucket.liquidityBorrowed;
        }

        return MathLibrary.mulDiv(liquidityAvailable, commit.liquiditySupplied, bucket.liquiditySupplied);
    }

    /// @notice Returns the amount of profits in `asset` that `supplier` should expect to receive from a bucket
    /// associated with the given lending terms (`borrowFactor` and `profitFactor`).
    /// @notice This value must only be used as an estimate when `getSecondsUntilExpiration() > 0`.
    function getSupplierProfits(
        address supplier,
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) public view returns (uint256 result) {
        (LendingTermsPacked terms, Bucket storage bucket) = getBucketPointer(borrowFactor, profitFactor);

        Commitment storage commit = commitments[supplier][terms];
        if (commit.liquidityWeighted == 0) return 0;

        uint256 supplierProfitsUnrealized = FixedPointMathLibrary.multiplyByQ4x4(
            getBucketProfitsUnrealized(borrowFactor, profitFactor),
            Q4X4_ONE - profitFactor
        );

        return MathLibrary.mulDiv(
            supplierProfitsUnrealized + bucket.supplierProfitsRealized,
            commit.liquidityWeighted,
            bucket.liquidityWeighted
        );
    }

    /// @notice Returns the number of shares of `vault` that `supplier` should expect to receive from the loans
    /// associated for a bucket with the given lending terms (`borrowFactor` and `profitFactor`) default.
    /// @notice This value must only be used as an estimate when `getSecondsUntilExpiration() > 0`.
    function getSupplierShares(
        address supplier,
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) public view returns (uint256 result) {
        (LendingTermsPacked terms, Bucket storage bucket) = getBucketPointer(borrowFactor, profitFactor);

        Commitment storage commit = commitments[supplier][terms];
        if (commit.liquidityWeighted == 0) return 0;

        return MathLibrary.mulDiv(bucket.sharesSupplied, commit.liquidityWeighted, bucket.liquidityWeighted);
    }

    /// @notice Returns the total amount of liquidity supplied by `supplier` across all buckets.
    function getSupplierTotalLiquidity(address supplier) public view returns (uint256 result) {
        uint256 bitmap = supplierBucketBitmap[supplier];
        while (bitmap != 0) {
            uint8 position = BitMathLibrary.ffs(bitmap);

            // Unchecked addition is safe here because the sum of liquidity supplied is less or equal to the total
            // which is of the same type.
            LendingTermsPacked terms = LendingTermsPacked.wrap(position);
            unchecked {
                result += commitments[supplier][terms].liquiditySupplied;
            }

            // Prevent overflow when index is 255, equivalent to: buckets >>= index + 1;
            bitmap >>= position;
            bitmap >>= 1;
        }
    }

    /// @notice Borrows liquidity from this pool.
    /// @notice
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `sources.length` is equal to zero or greater than 4.
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `liquidity` is equal to zero.
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `shares` is equal to zero.
    /// - Reverts with an `ILLEGAL_STATE` error if the pool has expired.
    /// - Reverts with an `ILLEGAL_STATE` error if the auction has started.
    /// - Reverts with a `TRANSFER_FAILED` error if the shares failed to transfer.
    /// - Reverts with an `INSUFFICIENT_LIQUIDITY` error if the specified buckets do not contain enough liquidity
    /// to fulfill the request.
    /// - Reverts with an `INSUFFICIENT_COLLATERAL` error if value of supplied shares is not enough to collateralize
    /// the loan.
    /// @param sources TODO
    /// @param liquidity The amount of liquidity to borrow.
    /// @param shares The amount of shares to supply as collateral.
    /// @return loanId The identifier of the created loan.
    function borrowLiquidity(
        LendingTerms[] calldata sources,
        uint256 liquidity,
        uint256 shares
    ) external returns (uint256 loanId) {
        require(sources.length > 0, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));
        require(liquidity > 0, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));
        require(shares > 0, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

        require(getSecondsUntilExpiration() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));
        require(getSecondsUntilAuctionStart() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));

        require(
            vault.trySafeTransferFrom(msg.sender, address(this), shares),
            KernelError(KernelErrorType.TRANSFER_FAILED)
        );

        unchecked { loanId = totalLoans++; }

        Loan memory loan;

        loan.active            = true;
        loan.borrowFactor      = LendingTermsLibrary.BORROW_FACTOR_MAXIMUM;
        loan.liquidityBorrowed = liquidity;
        loan.sharesSupplied    = shares;
        loan.sharesValue       = vault.convertToAssets(shares);

        uint256 liquidityRemaining = liquidity;
        uint256 i = 0;

        while (liquidityRemaining > 0) {
            require(i < sources.length, KernelError(KernelErrorType.INSUFFICIENT_LIQUIDITY));

            LendingTerms calldata source = sources[i];

            (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(source);
            require(success, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

            Bucket storage bucket = buckets[terms];

            uint256 liquidityAvailable;
            unchecked {
                liquidityAvailable = bucket.liquiditySupplied - bucket.liquidityBorrowed;
            }

            if (liquidityAvailable == 0) {
                continue;
            }

            uint256 liquidityBorrowed = MathLibrary.min(liquidityAvailable, liquidityRemaining);
            unchecked {
                bucket.liquidityBorrowed += liquidityBorrowed;
            }

            loanChunks[loanId][terms] = liquidityBorrowed;

            if (source.borrowFactor < loan.borrowFactor) {
                loan.borrowFactor = source.borrowFactor;
            }

            loan.bucketBitmap |= 1 << terms.unwrap();

            unchecked {
                liquidityRemaining -= liquidityBorrowed;
                i++;
            }
        }

        uint256 liquidityBorrowable = FixedPointMathLibrary.multiplyByQ4x4(loan.sharesValue, loan.borrowFactor);
        require(loan.liquidityBorrowed <= liquidityBorrowable, KernelError(KernelErrorType.INSUFFICIENT_COLLATERAL));

        loans[loanId] = loan;
    }

    /// @notice Repays liquidity to this pool.
    /// @notice
    /// - Reverts with an `ILLEGAL_STATE` error if the pool has expired.
    /// - Reverts with an `TRANSFER_FAILED` error if repaying the assets back into the pool fails.
    /// @param loanId The identifier of the loan to repay.
    function repayLiquidity(uint256 loanId) external {
        require(getSecondsUntilExpiration() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));

        Loan storage loan = loans[loanId];

        require(loan.active, KernelError(KernelErrorType.ILLEGAL_STATE));
        loan.active = false;

        uint256 profitTotal;
        {
            uint256 sharesValue = vault.convertToAssets(loan.sharesSupplied);
            if (sharesValue > loan.sharesValue) {
                unchecked {
                    profitTotal = sharesValue - loan.sharesValue;
                }
            }
        }

        uint256 profitSuppliers;

        uint256 bitmap = loan.bucketBitmap;
        while (bitmap != 0) {
            uint8 position = BitMathLibrary.ffs(bitmap);

            LendingTermsPacked terms = LendingTermsPacked.wrap(position);

            uint256 liquidityChunk = loanChunks[loanId][terms];
            unchecked {
                buckets[terms].liquidityBorrowed += liquidityChunk;
            }

            if (profitTotal > 0) {
                (/* Q4x4 borrowFactor */, Q4x4 profitFactor) = LendingTermsLibrary.unpack(terms);

                uint256 profitBucket = FixedPointMathLibrary.multiplyByQ4x4(
                    MathLibrary.mulDiv(profitTotal, liquidityChunk, loan.liquidityBorrowed),
                    Q4X4_ONE - profitFactor
                );

                buckets[terms].supplierProfitsRealized += profitBucket;

                unchecked {
                    profitSuppliers += profitBucket;
                }
            }

            // Prevent overflow when index is 255, equivalent to: buckets >>= index + 1;
            bitmap >>= position;
            bitmap >>= 1;
        }

        require(
            asset.trySafeTransferFrom(msg.sender, address(this), loan.liquidityBorrowed + profitSuppliers),
            KernelError(KernelErrorType.TRANSFER_FAILED)
        );
    }

    /// @notice Supplies liquidity to this pool.
    /// @notice Liquidity cannot be supplied if pool has expired or the auction has started.
    /// @notice
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `liquidity` is equal to zero.
    /// - Reverts with an `ILLEGAL_STATE` error if the pool has expired.
    /// - Reverts with an `ILLEGAL_STATE` error if the auction has started.
    /// @param borrowFactor TODO
    /// @param profitFactor The proportion of profits that will be allocated to the borrower.
    /// @param liquidity The amount of liquidity to supply.
    /// @param recipient The address to supply liquidity to.
    function supplyLiquidity(
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external {
        require(liquidity > 0, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));
        require(getSecondsUntilExpiration() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));
        require(getSecondsUntilAuctionStart() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));

        (LendingTermsPacked terms, Bucket storage bucket) = getBucketPointer(borrowFactor, profitFactor);

        Commitment memory commit = commitments[recipient][terms];

        totalLiquiditySupplied += liquidity;
        unchecked {
            bucket.liquiditySupplied += liquidity;
            commit.liquiditySupplied += liquidity;
        }

        uint256 liquidityWeighted = liquidity * getSecondsUntilAuctionStart();

        bucket.liquidityWeighted += liquidityWeighted;
        unchecked {
            commit.liquidityWeighted += liquidityWeighted;
        }

        supplierBucketBitmap[recipient] |= 1 << terms.unwrap();

        emit SupplyLiquidity(msg.sender, borrowFactor, profitFactor, liquidity, recipient);
    }

    /// @notice Withdraws shares from a loan.
    /// @notice
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `shares` is equal to zero.
    /// - Reverts with an `ILLEGAL_STATE` error if the loan is active.
    /// - Reverts with a `TRANSFER_FAILED` error if the shares were not successfully transferred.
    /// @param loanId The loan to withdraw shares from.
    /// @param shares The number of shares to withdraw.
    function withdrawShares(uint32 loanId, uint256 shares) external {
        require(shares > 0, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

        Loan storage loan = loans[loanId];
        require(!loan.active, KernelError(KernelErrorType.ILLEGAL_STATE));

        loan.sharesSupplied -= shares;

        require(vault.trySafeTransfer(msg.sender, shares), KernelError(KernelErrorType.TRANSFER_FAILED));
    }
}