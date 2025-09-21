# statera-core

## Overview

Statera is a decentralized finance protocol that provides users a means to originate fixed-term over-collateralized loans with yield bearing assets. Instead of charging interest during the life of a loan, Statera takes profits  when the loan is closed and distributes them at a prearranged proportion to the borrower and lenders.

## Organization

### Pool Factory

The Pool Factory is a singleton contract that specifies the liquidity pool for every tokenized vault contract. On each chain (e.g. Ethereum, Optimism, Arbitrum) there will only exist one official pool factory. The pool factory is responsible for ensuring that Pools associated with a deployment utilize the same code.

### Pool

Pools are instanced contracts created by the Pool Factory that provide the logic for supplying and borrowing liquidity for a tokenized vault.

### Solver

Solvers are external contracts that utilize data from a Pool to determine which buckets to borrow from when originating a loan. Solver contracts are granted read-only access to the storage of a pool via the read-only delegate call pattern. The effective functionality of a solver can be replaced by external code run by the user or through a centralized or decentralized network.

## Concepts

### Buckets

A Bucket is an aggregation of liquidity from lenders in a Pool who have an interest in lending liquidity a minimum set of lending terms. There are 225 Buckets in a pool; each Bucket corresponds to a permutation of lending terms  To borrow from a Bucket; an originated loan must exceed the Bucket's Borrow Factor and the loan's weighted Profit Factor must exceed the Bucket's Profit Factor.

### Auctions

The auction period begins when the current block timestamp exceeds the auction time. After this point all active loans are able to be closed by a third party. If a loan is closed by a third party during this period they will be able to seize a proportion of the borrower's collateral. The proportion of the collateral able to be seized starts at zero at the start of the auction period and linearly grows to the full amount when the pool expires. To conduct this action, the third party must pay all debts. The third party will receive the proportion of profits that would have been allocated to the borrower.

Borrowers can not originate loans during the auction period.

### Borrow Factor

When lenders commit liquidity to a pool they must specify the proportion of assets that borrowers are allowed to borrow per equivalent unit of collateral that they supply. This term is defined as the Borrow Factor. Borrowers are only permitted to originate loans from buckets whose Borrow Factor is greater than the minimum of all other Borrow Factors. 

A Borrow Factor is internally represented as a `UQ4x4` (an unsigned 8-bit  fixed point number with 4 fractional bits). The minimum accepted real value is 1/16 (`0.0625`). The maximum accepted real value is 15/16 (`0.9375`).

### Profit Factor

When lenders commit liquidity to a pool they must specify the proportion of profits that will be allocated to the borrower. This term is defined as the Profit Factor. Any profits not allocated to the borrower is distributed pro rata to lenders based upon how much liquidity they contributed for the loan. Regardless of who closes a loan, the payout of profits to lenders will occur unless there are no profits to distribute. The distribution of profits to the borrower will only occur if the borrower closes their loan. When a loan is closed by a third party during the auction period, they will receive the borrower's allocation of profits.


A Profit Factor is internally represented as a `UQ4x4` (an unsigned 8-bit  fixed point number with 4 fractional bits). The minimum accepted real value is 1/16 (`0.0625`). The maximum accepted real value is 15/16 (`0.9375`).

### Pool Lifecycle

A pool is considered active when it is deployed. A pool is active until the current block timestamp exceeds the expiration time.

When a Pool becomes inactive, all active loans are considered insolvent. The collateral of insolvent loans is seized from borrowers and distributed pro rata to lenders based upon how much liquidity they contributed to the loan.

### Authors

- [Ov3rKoalified](https://x.com/Ov3rKoalafied) - For our many conversations about the game theory of various mechanics and how to make the protocol applicable to the general public
