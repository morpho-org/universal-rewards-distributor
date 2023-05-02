# Universal Rewards Distributor

A universal rewards distributor written in Solidity. It allows to distribute any reward token (different reward tokens is possible at the same time) based on a merkle tree distribution.

Based on [Morpho's rewards distributor](https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol), itself based on [Euler's rewards distributor](https://github.com/euler-xyz/euler-contracts/blob/master/contracts/mining/EulDistributor.sol).

Tests are using [Murky](https://github.com/dmfxyz/murky), to generate merkle trees in Solidity.

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
