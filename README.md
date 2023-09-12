# Universal Permissionless Rewards Distributor

A universal permissionless rewards distributor written in Solidity. It allows the distribution of any reward token (different reward tokens are possible simultaneously) based on a Merkle tree distribution, and using ERC20 allowance of a treasury.

The singleton contract allows any treasury to distribute rewards to any address, based on a Merkle tree. The Merkle root is stored in the contract. The Merkle root can be updated by whitelisted users. The distribution owner can freeze, force update, or suggest a new treasury. The treasury must accept the role and set an allowance to distribute rewards.

Based on [Morpho's rewards distributor](https://github.com/morpho-dao/morpho-v1/blob/main/src/common/rewards-distribution/RewardsDistributor.sol), itself based on [Euler's rewards distributor](https://github.com/euler-xyz/euler-contracts/blob/master/contracts/mining/EulDistributor.sol).

Tests are using [Murky](https://github.com/dmfxyz/murky), to generate Merkle trees in Solidity.

## Usage

Merkle trees should be generated with [Openzeppelin library](https://github.com/OpenZeppelin/merkle-tree).
It will ensure that trees will be secure for on-chain verification.

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

## Limitations

### The pending root is not a queue

The pending root does not have a queue mechanism. Therefore, pushing a root to the pending root as a root updater in a distribution with a timelock will essentially erase the previous root. This means that a compromised root updater can always suggest a root and reset the timelock of the pending root.

Additionally, if the pending root is ready to be accepted but a root updater suggests a new root at the same time, the pending root will be erased and the timelock will restart.

This can lead to infinite loops of pending root if an automation mechanism suggests a root at an interval smaller than the timelock.

This behavior is acknowledged. When designing a strategy on top of the URD, you must ensure that the epoch interval at which you update the root is longer than the timelock. Define these parameters accordingly.

Additionally, you can build a queue mechanism on top of the URD with a 0 timelock distribution, where the root updater is a queue designed as the [Delay Modifier of Zodiac](https://github.com/gnosis/zodiac-modifier-delay/blob/36f56fd2e7a4aeb128971c5567fb8dffb6c6a21b/contracts/Delay.sol).
