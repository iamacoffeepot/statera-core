pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {MockToken} from "./mocks/MockToken.sol";
import {MockTokenizedVault} from "./mocks/MockTokenizedVault.sol";

import {LibraPool} from "../src/LibraPool.sol";
import {LibraPoolFactory} from "../src/LibraPoolFactory.sol";
import {Token} from "../src/interfaces/Token.sol";
import {TokenizedVault} from "../src/interfaces/TokenizedVault.sol";
import {LendingTermsLibrary} from "../src/libraries/LendingTermsLibrary.sol";


import {
    Bucket,
    Commitment,
    LendingTermsPacked,
    Q4x4
} from "../src/types/Types.sol";

contract LibraPoolTest is Test {
    LibraPool public pool;
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
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
        uint256 liquidity
    ) {
        vm.assume(LendingTermsLibrary.isValidBorrowFactor(borrowFactor));
        vm.assume(LendingTermsLibrary.isValidProfitFactor(profitFactor));
        vm.assume(liquidity > 0);
        _;
    }

    function setUp() external {
        vault = new MockTokenizedVault(asset = new MockToken());

        LibraPoolFactory poolFactory = new LibraPoolFactory();
        pool = poolFactory.createPool(vault);
    }

    function test_fuzz_supply_liquidity_increases_supplied_of_bucket(
        address caller,
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external
        validatesSupplyLiquidityArguments(borrowFactor, profitFactor, liquidity)
        mintsAssetsTo(caller, liquidity)
        performsCallsAs(caller)
    {
        assertTrue(asset.approve(address(pool), liquidity));
        pool.supplyLiquidity(borrowFactor, profitFactor, liquidity, recipient);

        (LendingTermsPacked terms, Bucket memory bucket) = pool.getBucket(borrowFactor, profitFactor);

        assertEq(bucket.liquiditySupplied, liquidity);
    }

    function test_fuzz_supply_liquidity_increases_supplied_of_recipient(
        address caller,
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external
        validatesSupplyLiquidityArguments(borrowFactor, profitFactor, liquidity)
        mintsAssetsTo(caller, liquidity)
        performsCallsAs(caller)
    {
        assertTrue(asset.approve(address(pool), liquidity));
        pool.supplyLiquidity(borrowFactor, profitFactor, liquidity, recipient);

        (LendingTermsPacked terms, Commitment memory commitment) = pool.getCommitment(
            recipient, borrowFactor, profitFactor
        );

        assertEq(commitment.liquiditySupplied, liquidity);
    }

    function test_fuzz_supply_liquidity_increases_total_liquidity_supplied(
        address caller,
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
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
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
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
}