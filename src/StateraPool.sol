pragma solidity 0.8.27;

import {StateraPoolFactory} from "./StateraPoolFactory.sol";
import {Token} from "./interfaces/Token.sol";
import {TokenizedVault} from "./interfaces/TokenizedVault.sol";
import {BitMathLibrary} from "./libraries/BitMathLibrary.sol";
import {FixedPointMathLibrary} from "./libraries/FixedPointMathLibrary.sol";
import {LendingTermsLibrary} from "./libraries/LendingTermsLibrary.sol";
import {MathLibrary} from "./libraries/MathLibrary.sol";
import {TokenTransferLibrary} from "./libraries/TokenTransferLibrary.sol";

import {
    Bucket,
    Commitment,
    LendingTerms,
    LendingTermsPacked,
    Loan,
    CoreError,
    CoreErrorType,
    UQ4x4,
    UQ4X4_ONE
} from "./types/Types.sol";

contract StateraPool {
    using FixedPointMathLibrary for uint256;
    using LendingTermsLibrary for LendingTerms;
    using LendingTermsLibrary for LendingTermsPacked;
    using TokenTransferLibrary for Token;
    using TokenTransferLibrary for TokenizedVault;

    // @custom:todo Are parameters properly indexed?
    event CommitLiquidity(
        address indexed sender,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity,
        address indexed recipient
    );

    /// @custom:todo Are parameters properly indexed?
    event SettleCommitment(
        address indexed sender,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor
    );

    /// @custom:todo Are parameters properly indexed?
    event StageLiquidity(
        address indexed sender,
        uint256 liquidity,
        address indexed recipient
    );

    /// @custom:todo Are parameters properly indexed?
    event StageCollateral(
        address indexed sender,
        uint256 shares,
        address indexed recipient
    );

    // @custom:todo Are parameters properly indexed?
    event SupplyLiquidity(
        address indexed sender,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity,
        address indexed recipient
    );

    /// @custom:todo Are parameters properly indexed?
    event WithdrawCollateral(
        address indexed sender,
        uint256 shares,
        address indexed recipient
    );

    /// @custom:todo Are parameters properly indexed?
    event WithdrawLiquidity(
        address indexed sender,
        uint256 liquidity,
        address indexed recipient
    );

    /// @notice The underlying token that `vault` uses for accounting, depositing, and withdrawing.
    Token immutable public asset;

    /// @notice The time at which the auction starts.
    /// @custom:invariant `timeAuction < timeExpires`
    uint256 immutable public timeAuction;

    /// @notice The time at which this pool expires.
    uint256 immutable public timeExpires;

    /// @notice The vault whose shares are accepted as collateral.
    TokenizedVault immutable public vault;

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
    uint256 public liquidityCommittedTotal;

    /// @custom:todo
    mapping(address supplier => uint256 liquidity) public liquidityStaged;

    /// @custom:todo
    uint256 public liquidityStagedTotal;

    /// @custom:todo
    mapping(uint256 id => Loan) public loans;

    /// @custom:todo
    mapping(uint256 id => mapping(LendingTermsPacked => uint256 liquidity)) public loanChunks;

    /// @custom:todo
    /// @custom:invariant `∀x(sharesStaged[x] > sharesUtilized[x])`
    mapping(address => uint256 shares) public sharesStaged;

    /// @custom:todo
    /// @custom:invariant `sharesStagedTotal >= sum(sharesStaged)`
    uint256 public sharesStagedTotal;

    /// @notice A bitmap for each address that specifies the buckets that they have supplied liquidity to.
    mapping(address supplier => uint256) public supplierBucketBitmap;

    constructor() {
        (timeAuction, timeExpires, vault) = StateraPoolFactory(msg.sender).parameters();

        asset = vault.asset();

        require(timeExpires > timeAuction, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));
    }

    /// @notice Returns the proportion of collateral that can be claimed from a borrower when closing a loan during
    /// the auction period respective to `timestamp`.
    function getLiquidationFactor(uint256 timestamp) public view returns (uint256 result) { }

    /// @notice Returns the proportion of collateral that can be claimed from a borrower when closing a loan.
    /// @notice This function returns `0` if the auction has not started.
    function getLiquidationFactor() public view returns (uint256 result) {
        return getLiquidationFactor(block.timestamp);
    }

    /// @custom:todo
    function getLiquidityWeighted(uint256 liquidity) public view returns (uint256 result) {
        return liquidity * getSecondsUntilAuction();
    }

    /// @notice Returns the number of seconds remaining until the auction starts respective to `timestamp`.
    function getSecondsUntilAuction(uint256 timestamp) public view returns (uint256) {
        if (timestamp >= timeAuction) {
            return 0;
        }

        unchecked {
            return timeAuction - timestamp;
        }
    }

    /// @notice Returns the number of seconds remaining until the auction starts.
    /// @notice This function returns `0` if the auction has already started.
    function getSecondsUntilAuction() public view returns (uint256) {
        return getSecondsUntilAuction(block.timestamp);
    }

    /// @notice Returns the number of seconds remaining until this pool expires respective to `timestamp`.
    function getSecondsUntilExpiration(uint256 timestamp) public view returns (uint256 result) {
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

    /// @notice Borrows liquidity from this pool.
    /// @notice
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `sources.length` is equal to zero.
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `liquidity` is equal to zero.
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `shares` is equal to zero.
    /// - Reverts with an `ILLEGAL_STATE` error if the pool has expired.
    /// - Reverts with an `ILLEGAL_STATE` error if the auction has started.
    /// - Reverts with an `TRANSFER_FAILED` error if the assets fail to transfer.
    /// - Reverts with an `INSUFFICIENT_LIQUIDITY` error if the specified buckets do not contain enough liquidity
    /// to fulfill the request.
    /// - Reverts with an `INSUFFICIENT_COLLATERAL` error if value of `shares` is not enough to collateralize the loan.
    /// @param sources TODO
    /// @param liquidity The amount of liquidity to borrow.
    /// @param shares The amount of shares to supply as collateral.
    /// @return loanId The identifier of the created loan.
    /// @custom:todo Assure that you cannot take liquidity from bucket more than once to prevent invalid loan count
    function borrowLiquidity(
        LendingTerms[] calldata sources,
        uint256 liquidity,
        uint256 shares
    ) external returns (uint256 loanId) {
        require(sources.length > 0, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));
        require(liquidity > 0, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));
        require(shares > 0, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));
        require(sharesStaged[msg.sender] >= shares, CoreError(CoreErrorType.INSUFFICIENT_COLLATERAL)); // TODO

        require(getSecondsUntilExpiration() > 0, CoreError(CoreErrorType.ILLEGAL_STATE));
        require(getSecondsUntilAuction() > 0, CoreError(CoreErrorType.ILLEGAL_STATE));

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
            require(i < sources.length, CoreError(CoreErrorType.INSUFFICIENT_LIQUIDITY));

            LendingTerms calldata source = sources[i];

            (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(source);
            require(success, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));

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
                bucket.loanCount++;
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

        uint256 liquidityBorrowable = FixedPointMathLibrary.multiplyByUQ4x4(loan.sharesValue, loan.borrowFactor);
        require(liquidityBorrowable >= loan.liquidityBorrowed, CoreError(CoreErrorType.INSUFFICIENT_COLLATERAL));

        unchecked {
            sharesStaged[msg.sender] -= shares;
            sharesStagedTotal -= shares;
        }

        loans[loanId] = loan;

        require(
            asset.tryTransferFrom(msg.sender, address(this), liquidity),
            CoreError(CoreErrorType.TRANSFER_FAILED)
        );
    }

    /// @custom:todo
    function commitLiquidity(
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external {
        require(liquidity > 0, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));
        require(getSecondsUntilExpiration() > 0, CoreError(CoreErrorType.ILLEGAL_STATE));
        require(getSecondsUntilAuction() > 0, CoreError(CoreErrorType.ILLEGAL_STATE));
        require(liquidityStaged[msg.sender] >= liquidity, CoreError(CoreErrorType.INSUFFICIENT_LIQUIDITY));

        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));

        Bucket storage bucket = buckets[terms];

        Commitment storage commit = commitments[recipient][terms];

        liquidityCommittedTotal += liquidity;
        unchecked {
            bucket.liquiditySupplied += liquidity;
            commit.liquiditySupplied += liquidity;
        }

        uint256 liquidityWeighted = getLiquidityWeighted(liquidity);

        bucket.liquidityWeighted += liquidityWeighted;
        unchecked {
            commit.liquidityWeighted += liquidityWeighted;
        }

        unchecked {
            liquidityStaged[msg.sender] -= liquidity;
            liquidityStagedTotal -= liquidity;
        }

        supplierBucketBitmap[recipient] |= 1 << terms.unwrap();

        emit CommitLiquidity(msg.sender, borrowFactor, profitFactor, liquidity, recipient);
    }

    /// @notice Repays liquidity to this pool.
    /// @notice
    /// - Reverts with an `ILLEGAL_STATE` error if the pool has expired.
    /// - Reverts with an `TRANSFER_FAILED` error if repaying the assets back into the pool fails.
    /// @param loanId The identifier of the loan to repay.
    function repayLiquidity(uint256 loanId) external {
        require(getSecondsUntilExpiration() > 0, CoreError(CoreErrorType.ILLEGAL_STATE));

        Loan storage loan = loans[loanId];

        require(loan.active, CoreError(CoreErrorType.ILLEGAL_STATE));
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
                (/* Q4x4 borrowFactor */, UQ4x4 profitFactor) = LendingTermsLibrary.unpack(terms);

                uint256 profitBucket = FixedPointMathLibrary.multiplyByUQ4x4(
                    MathLibrary.mulDiv(profitTotal, liquidityChunk, loan.liquidityBorrowed),
                    UQ4X4_ONE - profitFactor
                );

                buckets[terms].profitsRealized += profitBucket;
                buckets[terms].loanCount--;

                unchecked {
                    profitSuppliers += profitBucket;
                }
            }

            // Prevent overflow when index is 255, equivalent to: buckets >>= index + 1;
            bitmap >>= position;
            bitmap >>= 1;
        }

        require(
            asset.tryTransferFrom(msg.sender, address(this), loan.liquidityBorrowed + profitSuppliers),
            CoreError(CoreErrorType.TRANSFER_FAILED)
        );
    }

    /// @custom:todo
    function previewSettleCommitment(
        address supplier,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor
    ) public view returns (
        uint256 liquidity,
        uint256 profits,
        uint256 shares
    ) {
        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));
        return previewSettleCommitment(supplier, terms);
    }

    /// @custom:todo
    function previewSettleCommitment(
        address supplier,
        LendingTermsPacked terms
    ) internal view returns (
        uint256 liquidity,
        uint256 profits,
        uint256 shares
    ) {
        Bucket storage bucket = buckets[terms];

        uint256 liquidityAvailable;
        unchecked {
            liquidityAvailable = bucket.liquiditySupplied - bucket.liquidityBorrowed;
        }

        Commitment storage commit = commitments[supplier][terms];

        return (
            MathLibrary.mulDiv(liquidityAvailable, commit.liquiditySupplied, bucket.liquiditySupplied),
            MathLibrary.mulDiv(bucket.profitsRealized, commit.liquidityWeighted, bucket.liquidityWeighted),
            MathLibrary.mulDiv(bucket.shares, commit.liquiditySupplied, bucket.liquiditySupplied)
        );
    }

    /// @custom:todo
    /// @notice
    /// - Reverts with an `ILLEGAL_STATE` error if the auction has not started.
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `borrowFactor` or `profitFactor` are invalid.
    /// - Reverts with an `ILLEGAL_STATE` error if the commitment is empty.
    /// - Reverts with an `ILLEGAL_STATE` error if the associated bucket is unsettled.
    function settleCommitment(UQ4x4 borrowFactor, UQ4x4 profitFactor) external {
        require(getSecondsUntilAuction() == 0, CoreError(CoreErrorType.ILLEGAL_STATE));

        (LendingTermsPacked terms, bool success) = LendingTermsLibrary.tryPack(borrowFactor, profitFactor);
        require(success, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));

        Commitment storage commit = commitments[msg.sender][terms];
        require(commit.liquiditySupplied > 0, CoreError(CoreErrorType.ILLEGAL_STATE));

        Bucket storage bucket = buckets[terms];

        // Check that the bucket is settled. When the pool expires all loans are closed.
        uint256 loanCount = getSecondsUntilExpiration() > 0 ? bucket.loanCount : 0;
        require(loanCount == 0, CoreError(CoreErrorType.ILLEGAL_STATE));

        uint256 liquidityAvailable;
        unchecked {
            liquidityAvailable = bucket.liquiditySupplied - bucket.liquidityBorrowed;
        }

        uint256 liquidity = MathLibrary.mulDiv(liquidityAvailable,commit.liquiditySupplied,bucket.liquiditySupplied);
        unchecked {
            bucket.liquiditySupplied -= liquidity;
        }

        uint256 profits = MathLibrary.mulDiv(bucket.profitsRealized, commit.liquidityWeighted, bucket.liquidityWeighted);
        unchecked {
            bucket.profitsRealized -= profits;
        }

        uint256 shares = MathLibrary.mulDiv(bucket.shares, commit.liquiditySupplied, bucket.liquiditySupplied);
        unchecked {
            bucket.shares -= shares;
        }

        // TODO: Use calculated value or actual value
        liquidityCommittedTotal -= liquidity;

        liquidityStagedTotal += liquidity + profits;
        unchecked {
            liquidityStaged[msg.sender] += liquidity + profits;
        }

        sharesStagedTotal += shares;
        unchecked {
            sharesStaged[msg.sender] += shares;
        }

        delete commitments[msg.sender][terms];

        emit SettleCommitment(msg.sender, borrowFactor, profitFactor);
    }

    /// @notice Stages shares to `recipient` to be used for borrowing.
    /// @notice
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `shares` is equal to zero.
    /// - Reverts with an `TRANSFER_FAILED` error if transferring the shares to this pool fails.
    /// @param shares The amount of shares to stage.
    /// @param recipient The address to stage collateral to.
    function stageCollateral(uint256 shares, address recipient) external {
        require(shares > 0, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));

        sharesStagedTotal += shares;
        unchecked {
            sharesStaged[recipient] += shares;
        }

        require(
            vault.tryTransferFrom(msg.sender, address(this), shares),
            CoreError(CoreErrorType.TRANSFER_FAILED)
        );

        emit StageCollateral(msg.sender, shares, recipient);
    }

    /// @notice Stages liquidity to `recipient` to be used for lending.
    /// @notice
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `liquidity` is equal to zero.
    /// - Reverts with an `TRANSFER_FAILED` error if transferring the liquidity to this pool fails.
    /// @param liquidity The amount of liquidity to stage.
    /// @param recipient The address to stage liquidity to.
    function stageLiquidity(uint256 liquidity, address recipient) external {
        require(liquidity > 0, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));

        liquidityStagedTotal += liquidity;
        unchecked {
            liquidityStaged[recipient] += liquidity;
        }

        require(
            asset.tryTransferFrom(msg.sender, address(this), liquidity),
            CoreError(CoreErrorType.TRANSFER_FAILED)
        );

        emit StageLiquidity(msg.sender, liquidity, recipient);
    }

    /// @notice Withdraws collateral from this pool.
    /// @notice
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `shares` is equal to zero.
    /// - Reverts with an `TRANSFER_FAILED` error if transferring the shares to `recipient` fails.
    /// @param shares The amount of shares to withdraw.
    /// @param recipient The address to withdraw collateral to.
    function withdrawCollateral(uint256 shares, address recipient) external {
        require(shares > 0, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));
        require(sharesStaged[msg.sender] >= shares, CoreError(CoreErrorType.INSUFFICIENT_COLLATERAL)); // TODO

        unchecked {
            sharesStaged[msg.sender] -= shares;
            sharesStagedTotal -= shares;
        }

        require(vault.tryTransfer(recipient, shares), CoreError(CoreErrorType.TRANSFER_FAILED));

        emit WithdrawCollateral(msg.sender, shares, recipient);
    }

    /// @notice Withdraws liquidity to `recipient`.
    /// @notice
    /// - Reverts with an `ILLEGAL_ARGUMENT` error if `liquidity` is equal to zero.
    /// - Reverts with an `TRANSFER_FAILED` error if transferring the liquidity to `recipient` fails.
    /// @param liquidity The amount of liquidity to withdraw.
    /// @param recipient The address to withdraw liquidity to.
    function withdrawLiquidity(uint256 liquidity, address recipient) external {
        require(liquidity > 0, CoreError(CoreErrorType.ILLEGAL_ARGUMENT));
        require(liquidityStaged[msg.sender] >= liquidity, CoreError(CoreErrorType.INSUFFICIENT_LIQUIDITY));

        unchecked {
            liquidityStaged[msg.sender] -= liquidity;
            liquidityStagedTotal -= liquidity;
        }

        require(
            asset.tryTransfer(recipient, liquidity),
            CoreError(CoreErrorType.TRANSFER_FAILED)
        );

        emit WithdrawLiquidity(msg.sender, liquidity, recipient);
    }
}