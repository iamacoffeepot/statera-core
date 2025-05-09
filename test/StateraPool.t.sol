pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {MockToken} from "./mocks/MockToken.sol";
import {MockTokenizedVault} from "./mocks/MockTokenizedVault.sol";

import {StateraPool} from "../src/StateraPool.sol";
import {StateraPoolFactory} from "../src/StateraPoolFactory.sol";
import {Token} from "../src/interfaces/Token.sol";
import {TokenizedVault} from "../src/interfaces/TokenizedVault.sol";
import {LendingTermsLibrary} from "../src/libraries/LendingTermsLibrary.sol";


import {
    Bucket,
    Commitment,
    KernelError,
    KernelErrorType,
    LendingTermsPacked,
UQ4x4
} from "../src/types/Types.sol";

contract LibraPoolTest is Test {
    using LendingTermsLibrary for LendingTermsPacked;

    StateraPool public pool;
    Token public asset;
    TokenizedVault public vault;

    modifier mintsAssetsTo(address owner, uint256 amount) {
        deal(address(asset), owner, amount);
        _;
    }

    modifier performsCallsAs(address caller) {
        vm.startPrank(caller);
        _;
        vm.stopPrank();
    }

    modifier validatesSupplyLiquidityArguments(
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity
    ) {
        vm.assume(LendingTermsLibrary.isValidBorrowFactor(borrowFactor));
        vm.assume(LendingTermsLibrary.isValidProfitFactor(profitFactor));
        vm.assume(liquidity > 0);

        // TODO: Gracefully prevent overflow when calculating weighted liquidity
        unchecked {
            uint256 secondsUntilAuction = pool.getSecondsUntilAuction();
            vm.assume(secondsUntilAuction == 0 || liquidity == liquidity * secondsUntilAuction / secondsUntilAuction);
        }
        _;
    }

    function setUp() external {
        vault = new MockTokenizedVault(asset = new MockToken());

        StateraPoolFactory poolFactory = new StateraPoolFactory({
            _timeAuction_: block.timestamp + 1 hours,
            _timeExpires_: block.timestamp + 2 hours
        });
        pool = poolFactory.createPool(vault);
    }

    function test_fuzz_supply_liquidity_increases_supplied_of_bucket(
        address caller,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external
        validatesSupplyLiquidityArguments(borrowFactor, profitFactor, liquidity)
        mintsAssetsTo(caller, liquidity)
        performsCallsAs(caller)
    {
        assertTrue(asset.approve(address(pool), liquidity));
        pool.supplyLiquidity(borrowFactor, profitFactor, liquidity, recipient);

        (
            /* uint256 liquidityBorrowed */,
            uint256 liquiditySupplied,
            /* uint256 liquidityWeighted */,
            /* uint256 supplierProfitsRealized */
        ) = pool.buckets(LendingTermsLibrary.unsafePack(borrowFactor, profitFactor));

        assertEq(liquiditySupplied, liquidity);
    }

    function test_fuzz_supply_liquidity_increases_supplied_of_recipient(
        address caller,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external
        validatesSupplyLiquidityArguments(borrowFactor, profitFactor, liquidity)
        mintsAssetsTo(caller, liquidity)
        performsCallsAs(caller)
    {
        assertTrue(asset.approve(address(pool), liquidity));
        pool.supplyLiquidity(borrowFactor, profitFactor, liquidity, recipient);

        (
            uint256 liquiditySupplied,
            /* uint256 liquidityWeighted */
        ) = pool.commitments(recipient, LendingTermsLibrary.unsafePack(borrowFactor, profitFactor));

        assertEq(liquiditySupplied, liquidity);
    }

    function test_fuzz_supply_liquidity_increases_total_liquidity_supplied(
        address caller,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external
        validatesSupplyLiquidityArguments(borrowFactor, profitFactor, liquidity)
        mintsAssetsTo(caller, liquidity)
        performsCallsAs(caller)
    {
        assertTrue(asset.approve(address(pool), liquidity));
        pool.supplyLiquidity(borrowFactor, profitFactor, liquidity, recipient);
        assertEq(pool.totalLiquiditySupplied(), liquidity);
    }

    function test_fuzz_supply_liquidity_transfers_assets_from_caller(
        address caller,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external
        validatesSupplyLiquidityArguments(borrowFactor, profitFactor, liquidity)
        mintsAssetsTo(caller, liquidity)
        performsCallsAs(caller)
    {
        assertTrue(asset.approve(address(pool), liquidity));
        pool.supplyLiquidity(borrowFactor, profitFactor, liquidity, recipient);
        assertEq(asset.balanceOf(address(pool)), liquidity);
        assertEq(asset.balanceOf(address(caller)), 0);
    }

    function test_fuzz_supply_liquidity_updates_recipient_bucket_bitmap(
        address caller,
        UQ4x4 borrowFactor,
        UQ4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external
        validatesSupplyLiquidityArguments(borrowFactor, profitFactor, liquidity)
        mintsAssetsTo(caller, liquidity)
        performsCallsAs(caller)
    {
        assertTrue(asset.approve(address(pool), liquidity));
        pool.supplyLiquidity(borrowFactor, profitFactor, liquidity, recipient);

        LendingTermsPacked terms = LendingTermsLibrary.unsafePack(borrowFactor, profitFactor);
        assertEq(pool.supplierBucketBitmap(recipient), 1 << terms.unwrap());
    }
    
    function test_get_seconds_until_auction() external {
        assertEq(pool.getSecondsUntilAuction(pool.timeAuction()), 0);
        assertEq(pool.getSecondsUntilAuction(pool.timeAuction() + 1), 0);
        assertEq(pool.getSecondsUntilAuction(pool.timeAuction() - 1), 1);
        assertEq(pool.getSecondsUntilAuction(0), pool.timeAuction());
    }

    function test_get_seconds_until_expiration() external {
        assertEq(pool.getSecondsUntilExpiration(pool.timeExpires()), 0);
        assertEq(pool.getSecondsUntilExpiration(pool.timeExpires() + 1), 0);
        assertEq(pool.getSecondsUntilExpiration(pool.timeExpires() - 1), 1);
        assertEq(pool.getSecondsUntilExpiration(0), pool.timeExpires());
    }

    function test_supply_liquidity_reverts_when_borrow_factor_is_invalid() external {
        vm.expectRevert(abi.encodeWithSelector(KernelError.selector, (KernelErrorType.ILLEGAL_ARGUMENT)));
        pool.supplyLiquidity(
            UQ4x4.wrap(type(uint8).max),
            LendingTermsLibrary.BORROW_FACTOR_MINIMUM,
            1,
            address(0xdead)
        );
    }

    function test_supply_liquidity_reverts_when_liquidity_is_zero() external {
        vm.expectRevert(abi.encodeWithSelector(KernelError.selector, (KernelErrorType.ILLEGAL_ARGUMENT)));
        pool.supplyLiquidity(
            LendingTermsLibrary.BORROW_FACTOR_MINIMUM,
            LendingTermsLibrary.BORROW_FACTOR_MINIMUM,
            0,
            address(0xdead)
        );
    }

    function test_supply_liquidity_reverts_when_profit_factor_is_invalid() external {
        vm.expectRevert(abi.encodeWithSelector(KernelError.selector, (KernelErrorType.ILLEGAL_ARGUMENT)));
        pool.supplyLiquidity(
            LendingTermsLibrary.BORROW_FACTOR_MINIMUM,
            UQ4x4.wrap(type(uint8).max),
            1,
            address(0xdead)
        );
    }

    function test_supply_liquidity_reverts_when_auction_active() external {
        vm.warp(pool.timeAuction());
        vm.expectRevert(abi.encodeWithSelector(KernelError.selector, (KernelErrorType.ILLEGAL_STATE)));
        pool.supplyLiquidity(
            LendingTermsLibrary.BORROW_FACTOR_MINIMUM,
            LendingTermsLibrary.PROFIT_FACTOR_MINIMUM,
            1,
            address(0xdead)
        );
    }

    function test_supply_liquidity_reverts_when_pool_expired() external {
        vm.warp(pool.timeExpires());
        vm.expectRevert(abi.encodeWithSelector(KernelError.selector, (KernelErrorType.ILLEGAL_STATE)));
        pool.supplyLiquidity(
            LendingTermsLibrary.BORROW_FACTOR_MINIMUM,
            LendingTermsLibrary.PROFIT_FACTOR_MINIMUM,
            1,
            address(0xdead)
        );
    }
}