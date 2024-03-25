import sys
import json
from eth_abi import encode
from web3 import Web3, EthereumTesterProvider

w3 = Web3(EthereumTesterProvider())


# Returns the hash of a node given the hashes of its children.
def hash_node(left_hash, right_hash):
    return w3.to_hex(
        w3.solidity_keccak(["bytes32", "bytes32"], [left_hash, right_hash])
    )


# Returns the hash of a leaf given the rewards details.
def hash_leaf(address, reward, amount):
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


# Returns the identifier of a leaf.
def hash_id(addr, reward):
    encoded_args = encode(["address", "address"], [addr, reward])
    return w3.to_hex(w3.solidity_keccak(["bytes"], [encoded_args]))


certificate = {}
hash_to_id = {}
hash_to_address = {}
hash_to_reward = {}
hash_to_value = {}
left = {}
right = {}


# Populates the fields of the tree along the path given by the proof.
def populate(addr, reward, amount, proof):
    computedHash = hash_leaf(addr, reward, amount)
    hash_to_id[computedHash] = hash_id(addr, reward)
    hash_to_address[computedHash] = addr
    hash_to_reward[computedHash] = reward
    hash_to_value[computedHash] = amount
    for proofElement in proof:
        [leftHash, rightHash] = (
            [computedHash, proofElement]
            if computedHash <= proofElement
            else [proofElement, computedHash]
        )
        computedHash = hash_node(leftHash, rightHash)
        hash_to_id[computedHash] = computedHash
        left[computedHash] = leftHash
        right[computedHash] = rightHash


# Traverse the tree and generate corresponding instruction for each internal node and each leaf.
def walk(node):
    if node in left:
        walk(left[node])
        walk(right[node])
        certificate["node"].append(
            {
                "id": node,
                "left": hash_to_id[left[node]],
                "right": hash_to_id[right[node]],
            }
        )
    else:
        certificate["leaf"].append(
            {
                "addr": hash_to_address[node],
                "reward": hash_to_reward[node],
                "value": hash_to_value[node],
            }
        )


with open(sys.argv[1]) as input_file:
    proofs = json.load(input_file)
    rewards = proofs["rewards"]

    certificate["root"] = proofs["root"]
    certificate["leaf"] = []
    certificate["node"] = []

    for addr, data in rewards.items():
        address = w3.to_checksum_address(addr)
        for reward, data in data.items():
            reward = w3.to_checksum_address(reward)
            amount = int(data["amount"])
            populate(addr, reward, amount, data["proof"])

    walk(proofs["root"])

    certificate["leafLength"] = len(certificate["leaf"])
    certificate["nodeLength"] = len(certificate["node"])

    json_output = json.dumps(certificate)

with open("certificate.json", "w") as output_file:
    output_file.write(json_output)
