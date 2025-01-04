pragma solidity 0.8.27;

import {Token} from "./interfaces/Token.sol";
import {TokenizedVault} from "./interfaces/TokenizedVault.sol";
import {BitmapLibrary} from "./libraries/BitmapLibrary.sol";
import {BitmathLibrary} from "./libraries/BitmathLibrary.sol";
import {LendingTermsLibrary} from "./libraries/LendingTermsLibrary.sol";
import {TokenTransferLibrary} from "./libraries/TokenTransferLibrary.sol";
import {PermitsReadOnlyDelegateCall} from "./PermitsReadOnlyDelegateCall.sol";

import {
    BitmapX256,
    LendingTerms,
    LendingTermsPacked,
    LibraKernelError,
    Q4x4
} from "./types/Types.sol";

contract LibraKernel is PermitsReadOnlyDelegateCall {
    using BitmapLibrary for BitmapX256;
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

    /// @notice The amount of liquidity that has been supplied to a bucket.
    mapping(LendingTermsPacked => uint256) public bucketLiquiditySupplied;

    /// @custom:todo
    mapping(LendingTermsPacked => uint256) public bucketConviction;

    /// @custom:todo
    mapping(LendingTermsPacked => uint256) public bucketShares;

    /// @custom:todo
    mapping(address supplier => mapping(LendingTermsPacked => uint256)) public supplierLiquidity;

    /// @custom:todo
    mapping(address supplier => mapping(LendingTermsPacked => uint256)) public supplierConviction;

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
        uint256 buckets = supplierBuckets[supplier];
        while (buckets != 0) {
            uint8 index = BitmathLibrary.getIndexOfLsb(buckets);

            // Unchecked addition is safe here because the sum of liquidity supplied is less or equal to the total
            // which is of the same type.
            LendingTermsPacked terms = LendingTermsPacked.wrap(index);
            unchecked {
                result += supplierLiquidity[supplier][terms];
            }

            // Prevent overflow when index is 255, equivalent to: buckets >>= index + 1;
            buckets >>= index;
            buckets >>= 1;
        }
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
        require(liquidity > 0, LibraKernelError());
        require(getSecondsUntilExpiration() > 0, LibraKernelError());
        require(getSecondsUntilAuctionStart() > 0, LibraKernelError());

        // IMPORTANT: Packing the terms will check if they are within the accepted ranges.
        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, LibraKernelError());

        totalLiquiditySupplied += liquidity;

        supplierConviction[recipient][terms] += liquidity * getSecondsUntilAuctionStart();

        // TODO: Specify conditions in which this is safe
        unchecked {
            supplierLiquidity[recipient][terms] += liquidity;
        }

        // TODO: And this
        unchecked {
            bucketLiquiditySupplied[terms] += liquidity;
            bucketConviction[terms] += liquidity * getSecondsUntilAuctionStart();
        }

        supplierBuckets[recipient] |= 1 << terms.unwrap();

        emit SupplyLiquidity(msg.sender, borrowFactor, profitFactor, liquidity, recipient);
    }
}