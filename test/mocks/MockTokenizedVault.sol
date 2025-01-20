pragma solidity 0.8.27;

import {Token} from "../../src/interfaces/Token.sol";
import {TokenizedVault} from "../../src/interfaces/TokenizedVault.sol";

import {MockToken} from "./MockToken.sol";

contract MockTokenizedVault is MockToken, TokenizedVault {
    /// @inheritdoc TokenizedVault
    Token public immutable override asset;

    constructor(Token _asset_) {
        asset = _asset_;
    }

    /// @inheritdoc TokenizedVault
    function convertToAssets(uint256 shares) external view returns (uint256 assets) { }

    /// @inheritdoc TokenizedVault
    function convertToShares(uint256 assets) external view returns (uint256 shares) { }

    /// @inheritdoc TokenizedVault
    function maxDeposit(address receiver) external view returns (uint256 maxAssets) { }

    /// @inheritdoc TokenizedVault
    function previewDeposit(uint256 assets) external view returns (uint256 shares) { }

    /// @inheritdoc TokenizedVault
    function deposit(uint256 assets, address receiver) external { }

    /// @inheritdoc TokenizedVault
    function maxMint(address receiver) external view returns (uint256 maxShares) { }

    /// @inheritdoc TokenizedVault
    function previewMint(uint256 shares) external view returns (uint256 assets) { }

    /// @inheritdoc TokenizedVault
    function mint(uint256 shares, address receiver) external { }

    /// @inheritdoc TokenizedVault
    function maxWithdraw(address owner) external view returns (uint256 maxAssets) { }

    /// @inheritdoc TokenizedVault
    function previewWithdraw(uint256 assets) external view returns (uint256 shares) { }

    /// @inheritdoc TokenizedVault
    function withdraw(uint256 assets, address receiver, address owner) external { }

    /// @inheritdoc TokenizedVault
    function maxRedeem(address owner) external view returns (uint256 maxShares) { }

    /// @inheritdoc TokenizedVault
    function previewRedeem(uint256 shares) external view returns (uint256 assets) { }

    /// @inheritdoc TokenizedVault
    function redeem(uint256 shares, address receiver, address owner) external { }
}