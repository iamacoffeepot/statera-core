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
    KernelError,
    KernelErrorType,
    Position,
    Q4x4,
    Q4X4_ONE
} from "./types/Types.sol";

contract LibraPool is PermitsReadOnlyDelegateCall {
    using BitmapLibrary for BitmapX256;
    using BucketLibrary for Bucket;
    using FixedPointMathLibrary for uint256;
    using LendingTermsLibrary for LendingTerms;
    using LendingTermsLibrary for LendingTermsPacked;

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

    /// @notice The total amount of shares supplied as collateral to the pool.
    uint256 public totalSharesSupplied;

    /// @custom:todo
    mapping(LendingTermsPacked => Bucket) public buckets;

    /// @custom:todo
    mapping(address supplier => mapping(LendingTermsPacked => Commitment)) public commitments;

    /// @custom:todo
    mapping(address borrower => Position) public positions;

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

    /// @notice Returns the total amount of liquidity supplied by `supplier`.
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
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `sources.length` is equal to zero.
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `liquidity` is equal to zero.
    /// - Reverts with an `ILLEGAL_STATE` error if the pool has expired.
    /// - Reverts with an `ILLEGAL_STATE` error if the auction has started.
    /// @param sources TODO
    /// @param liquidity The amount of liquidity to borrow.
    function borrowLiquidity(LendingTerms[] calldata sources, uint256 liquidity) external {
        require(sources.length > 0, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));
        require(liquidity > 0, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

        require(getSecondsUntilExpiration() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));
        require(getSecondsUntilAuctionStart() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));
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

    /// @notice Supplies collateral to this pool.
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `shares` is equal to zero.
    /// - Reverts with an `ILLEGAL_STATE` error if the pool has expired.
    /// - Reverts with an `ILLEGAL_STATE` error if the auction has started.
    /// @param shares The amount of shares to supply.
    /// @param recipient The address to supply collateral to.
    function supplyCollateral(uint256 shares, address recipient) external {
        require(shares > 0, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));
        require(getSecondsUntilExpiration() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));
        require(getSecondsUntilAuctionStart() > 0, KernelError(KernelErrorType.ILLEGAL_STATE));

        Position storage position = positions[recipient];

        totalSharesSupplied += shares;
        unchecked {
            position.sharesSupplied += shares;
        }
    }

    /// @notice Withdraws collateral from this pool.
    /// @param shares The amount of shares to withdraw.
    function withdrawCollateral(uint256 shares) external { }
}