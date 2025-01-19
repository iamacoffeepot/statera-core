pragma solidity 0.8.27;

import {LibraPool} from "./LibraPool.sol";
import {Token} from "./interfaces/Token.sol";
import {TokenizedVault} from "./interfaces/TokenizedVault.sol";


import {
    KernelError,
    KernelErrorType
} from "./types/Types.sol";

contract LibraPoolFactory {
    /// @custom:todo
    mapping(TokenizedVault vault => LibraPool pool) public pools;

    struct ConstructorParameters {
        TokenizedVault vault;
        Token asset;
        uint256 timeExpires;
        uint256 timeAuctionStarts;
    }

    /// @custom:todo
    ConstructorParameters public constructorParameters;

    /// @notice Creates a pool for `vault`.
    /// @notice
    /// - Reverts with an `ILLEGAL_STATE` error if a pool already exists for `vault`.
    /// @param vault The vault to create a pool for.
    function createPool(TokenizedVault vault) external returns (LibraPool result) {
        require(pools[vault] == LibraPool(address(0)), KernelError(KernelErrorType.ILLEGAL_STATE));

        constructorParameters = ConstructorParameters({
            vault: vault,
            asset: vault.asset(),
            timeExpires : 0,
            timeAuctionStarts : 0
        });

        LibraPool pool = new LibraPool{salt: keccak256(abi.encode(vault))}();
        pools[vault] = pool;

        delete constructorParameters;

        return pool;
    }
}