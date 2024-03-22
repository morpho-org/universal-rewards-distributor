This folder contains the verification of the universal rewards distribution mechanism using CVL, Certora's Verification Language.

# Folder and file structure

The [`certora/specs`](specs) folder contains the specification files.

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

The [`certora/helpers`](helpers) folder contains files that enable the verification of Morpho Blue.

# Overview of the verification

This work aims at providing a formally verified rewards checker.
The rewards checker is composed of the [Checker.sol](checker/Checker.sol) file, which takes a certificate as an input.
The certificate is assumed to contain the submitted root to verify and a Merkle tree, and it is checked that the Merkle tree is well-formed.

Those checks are done by only using "trusted" functions, namely `newLeaf` and `newInternalNode`, that have been formally verified to preserve those invariants:

- it is checked in [MerkleTree.spec](specs/MerkleTree.spec) that those functions lead to creating well-formed trees.
- it is checked in [UniversalRewardsDistributor.spec](specs/UniversalRewardsDistributor.spec) that the rewards distributor is correct, meaning that claimed rewards correspond exactly to the rewards contained in the corresponding Merkle tree.

# Getting started

## Verifying the rewards checker

Install `certora-cli` package with `pip install certora-cli`.
To verify specification files, pass to `certoraRun` the corresponding configuration file in the [`certora/confs`](confs) folder.
It requires having set the `CERTORAKEY` environment variable to a valid Certora key.
You can also pass additional arguments, notably to verify a specific rule.
For example, at the root of the repository:

```
certoraRun certora/confs/MerkleTrees.conf --rule wellFormed
```

## Running the rewards checker

To verify that a given list of proofs corresponds to a valid Merkle tree, you must generate a certificate from it.
This assumes that the list of proofs is in the expected JSON format.
For example, at the root of the repository, given a `proofs.json` file:

```
python certora/checker/create_certificate.py proofs.json
```

This requires installing the corresponding libraries first:

```
pip install web3 eth-tester py-evm
```

Then, check this certificate:

```
FOUNDRY_PROFILE=checker forge test
```
