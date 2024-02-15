import sys
import json
from eth_abi import encode
from web3 import Web3, EthereumTesterProvider

w3 = Web3(EthereumTesterProvider())


def hash_node(left_hash, right_hash):
    return w3.to_hex(
        w3.solidity_keccak(["bytes32", "bytes32"], [left_hash, right_hash])
    )


def hash_leaf(address, reward, amount):
    address = w3.to_checksum_address(address)
    reward = w3.to_checksum_address(reward)
    encoded_args = encode(["address", "address", "uint256"], [address, reward, amount])
    first_hash = w3.solidity_keccak(
        ["bytes"],
        [encoded_args],
    )
    second_hash = w3.solidity_keccak(
        ["bytes"],
        [first_hash],
    )
    return w3.to_hex(second_hash)


certificate = {}
hash_to_address = {}
hash_to_reward = {}
hash_to_value = {}
left = {}
right = {}


def populate(addr, reward, amount, proof):
    computedHash = hash_leaf(addr, reward, amount)
    hash_to_address[computedHash] = addr.lower()
    hash_to_reward[computedHash] = reward.lower()
    hash_to_value[computedHash] = amount
    for proofElement in proof:
        [leftHash, rightHash] = (
            [computedHash, proofElement]
            if computedHash <= proofElement
            else [proofElement, computedHash]
        )
        computedHash = hash_node(leftHash, rightHash)
        left[computedHash] = leftHash
        right[computedHash] = rightHash


def walk(h):
    if h in left:
        walk(left[h])
        walk(right[h])
        certificate["node"].append(
            {
                "id": h,
                "left": left[h],
                "right": right[h],
            }
        )
    else:
        certificate["leaf"].append(
            {
                "addr": hash_to_address[h],
                "reward": hash_to_reward[h],
                "value": hash_to_value[h],
            }
        )


with open(sys.argv[1]) as input_file:
    proofs = json.load(input_file)
    rewards = proofs["rewards"]

    certificate["root"] = proofs["root"]
    certificate["leaf"] = []
    certificate["node"] = []

    for addr, rest in rewards.items():
        for reward, data in rest.items():
            amount = int(data["amount"])
            populate(addr, reward, amount, data["proof"])

    walk(proofs["root"])

    certificate["leafLength"] = len(certificate["leaf"])
    certificate["nodeLength"] = len(certificate["node"])

    json_output = json.dumps(certificate)

with open("certificate.json", "w") as output_file:
    output_file.write(json_output)
