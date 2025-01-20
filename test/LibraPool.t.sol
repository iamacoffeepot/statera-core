pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {MockToken} from "./mocks/MockToken.sol";
import {MockTokenizedVault} from "./mocks/MockTokenizedVault.sol";

import {Token} from "../src/interfaces/Token.sol";
import {TokenizedVault} from "../src/interfaces/TokenizedVault.sol";
import {LendingTermsLibrary} from "../src/libraries/LendingTermsLibrary.sol";
import {Q4x4} from "../src/types/Types.sol";
import "../src/LibraPool.sol";

contract LibraPoolTest is Test {
    LibraPool public pool;
    Token public asset;
    TokenizedVault public vault;

    function setUp() external {
        vault = new MockTokenizedVault(asset = new MockToken());

        LibraPoolFactory poolFactory = new LibraPoolFactory();
        pool = poolFactory.createPool(vault);
    }

    function test_fuzz_supply_liquidity_increases_total_liquidity_supplied(
        Q4x4 borrowFactor,
        Q4x4 profitFactor,
        uint256 liquidity,
        address recipient
    ) external {
        vm.assume(LendingTermsLibrary.isValidBorrowFactor(borrowFactor));
        vm.assume(LendingTermsLibrary.isValidProfitFactor(profitFactor));
        vm.assume(liquidity > 0);

        deal(address(asset), address(this), liquidity);

        assertTrue(asset.approve(address(pool), liquidity));

        pool.supplyLiquidity(borrowFactor, profitFactor, liquidity, recipient);

        assertEq(pool.totalLiquiditySupplied(), liquidity);
    }
}