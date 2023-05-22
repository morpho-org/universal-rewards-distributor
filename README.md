# Universal Rewards Distributor

A universal rewards distributor written in Solidity. It allows the distribution of any reward token (different reward tokens are possible simultaneously) based on a Merkle tree distribution.

Based on [Morpho's rewards distributor](https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol), itself based on [Euler's rewards distributor](https://github.com/euler-xyz/euler-contracts/blob/master/contracts/mining/EulDistributor.sol).

Tests are using [Murky](https://github.com/dmfxyz/murky), to generate Merkle trees in Solidity.

## Usage
Merkle trees should be generated with [Openzeppelin library](https://github.com/OpenZeppelin/merkle-tree).  
It will ensures trees will be secure for on-chain verification.

## Installation

Download foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
```

Install it:
```bash
foundryup
```

Install dependencies:
```bash
git submodule update --init --recursive
```

Now you can run tests, using forge:
```bash
forge test
```
