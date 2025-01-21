pragma solidity 0.8.27;

import {LibraPool} from "./LibraPool.sol";
import {Token} from "./interfaces/Token.sol";
import {TokenizedVault} from "./interfaces/TokenizedVault.sol";


import {
    KernelError,
    KernelErrorType
} from "./types/Types.sol";

contract LibraPoolFactory {
    /// @notice The time that all pool auctions start at.
    uint256 public immutable timeAuction;

    /// @notice The time that all pools expire at.
    uint256 public immutable timeExpires;

    /// @custom:todo
    mapping(TokenizedVault vault => LibraPool pool) public pools;

    struct Parameters {
        uint256 timeExpires;
        uint256 timeAuction;
        TokenizedVault vault;
    }

    /// @notice Transient parameters for newly created pools.
    Parameters public parameters;

    constructor(uint256 _timeAuction_, uint256 _timeExpires_) {
        timeAuction = _timeAuction_;
        timeExpires = _timeExpires_;
    }

    /// @notice Creates a pool for `vault`.
    /// @notice
    /// - Reverts with an `ILLEGAL_STATE` error if a pool already exists for `vault`.
    /// @param vault The vault to create a pool for.
    function createPool(TokenizedVault vault) external returns (LibraPool result) {
        require(pools[vault] == LibraPool(address(0)), KernelError(KernelErrorType.ILLEGAL_STATE));

        parameters = Parameters({timeAuction: timeAuction, timeExpires: timeExpires, vault: vault});
        LibraPool pool = new LibraPool{salt: keccak256(abi.encode(vault))}();
        pools[vault] = pool;

        delete parameters;

        return pool;
    }
}