pragma solidity 0.8.27;

import {Token} from "./interfaces/Token.sol";
import {TokenizedVault} from "./interfaces/TokenizedVault.sol";
import {BitmapLibrary} from "./libraries/BitmapLibrary.sol";
import {BitMathLibrary} from "./libraries/BitMathLibrary.sol";
import {BucketLibrary} from "./libraries/BucketLibrary.sol";
import {FixedPointMathLibrary} from "./libraries/FixedPointMathLibrary.sol";
import {LendingTermsLibrary} from "./libraries/LendingTermsLibrary.sol";
import {MathLibrary} from "./libraries/MathLibrary.sol";
import {TokenTransferLibrary} from "./libraries/TokenTransferLibrary.sol";
import {PermitsReadOnlyDelegateCall} from "./PermitsReadOnlyDelegateCall.sol";

import {
    BitmapX256,
    Bucket,
    Commitment,
    LendingTerms,
    LendingTermsPacked,
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

    // @custom:todo Are parameters properly indexed?
    event SupplyLiquidity(
        address indexed sender,
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
        uint256 liquidity,
        address indexed recipient
    );

    /// @notice TODO
    TokenizedVault immutable public vault;

    /// @notice TODO
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
    mapping(LendingTermsPacked => Bucket) public buckets;

    /// @custom:todo
    mapping(address supplier => mapping(LendingTermsPacked => Commitment)) public commitments;

    /// @notice A bitmap for each address that specifies the buckets that they have supplied liquidity to.
    mapping(address supplier => uint256) public supplierBuckets;

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

    /// @notice Returns the total amount of liquidity supplied by `supplier`.
    function getTotalLiquiditySupplied(address supplier) public view returns (uint256 result) {
        uint256 bitmap = supplierBuckets[supplier];
        while (bitmap != 0) {
            uint8 index = BitMathLibrary.ffs(bitmap);

            // Unchecked addition is safe here because the sum of liquidity supplied is less or equal to the total
            // which is of the same type.
            LendingTermsPacked terms = LendingTermsPacked.wrap(index);
            unchecked {
                result += commitments[supplier][terms].liquiditySupplied;
            }

            // Prevent overflow when index is 255, equivalent to: buckets >>= index + 1;
            bitmap >>= index;
            bitmap >>= 1;
        }
    }

    /// @notice Returns the amount of profits in `asset` that `supplier` can expect to receive when the pool expires.
    ///
    /// This value must only be used as an estimate when `getSecondsUntilExpiration() > 0`.
    function getExpectedProfits(
        address supplier,
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) public view returns (uint256 result) {
        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

        Commitment storage commitment = commitments[supplier][terms];
        if (commitment.liquidityWeighted == 0) return 0;

        Bucket storage bucket = buckets[terms];

        uint256 profitsGross = bucket.totalProfitsRealized;
        if (getSecondsUntilExpiration() > 0) {
            profitsGross += bucket.getUnrealizedProfits(vault);
        }

        uint256 profitsNet = profitsGross.multiplyByQ4x4(Q4X4_ONE - profitFactor);

        return MathLibrary.mulDiv(profitsNet, commitment.liquidityWeighted, bucket.liquidityWeighted);
    }

    /// @notice Returns the amount of profits that have are yet to be realized for a bucket associated with the
    /// given lending terms (`borrowFactor` and `profitFactor`).
    function getUnrealizedProfits(Q4x4 borrowFactor, Q4x4 profitFactor) public view returns (uint256 result) {
        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

        return buckets[terms].getUnrealizedProfits(vault);
    }

    /// @notice Returns the number of shares of `vault` that `supplier` can expect to receive if the loans
    /// associated with a bucket for the given lending terms (`borrowFactor` and `profitFactor`) default.
    ///
    /// This value must only be used as an estimate when `getSecondsUntilExpiration() > 0`.
    function getExpectedShares(
        address supplier,
        Q4x4 borrowFactor,
        Q4x4 profitFactor
    ) public view returns (uint256 result) {
        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

        Commitment storage commitment = commitments[supplier][terms];
        if (commitment.liquidityWeighted == 0) return 0;

        Bucket storage bucket = buckets[terms];

        return MathLibrary.mulDiv(bucket.shares, commitment.liquidityWeighted, bucket.liquidityWeighted);
    }

    /// @notice Supplies liquidity to this pool.
    ///
    /// Liquidity cannot be supplied if pool has expired or the auction has started.
    ///
    /// @param borrowFactor TODO
    /// @param profitFactor TODO
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

        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, KernelError(KernelErrorType.ILLEGAL_ARGUMENT));

        totalLiquiditySupplied += liquidity;

        commitments[recipient][terms].liquidityWeighted += liquidity * getSecondsUntilAuctionStart();

        // TODO: Specify conditions in which this is safe
        unchecked {
            commitments[recipient][terms].liquiditySupplied += liquidity;
        }

        // TODO: And this
        unchecked {
            buckets[terms].liquiditySupplied += liquidity;
            buckets[terms].liquidityWeighted += liquidity * getSecondsUntilAuctionStart();
        }

        supplierBuckets[recipient] |= 1 << terms.unwrap();

        emit SupplyLiquidity(msg.sender, borrowFactor, profitFactor, liquidity, recipient);
    }
}