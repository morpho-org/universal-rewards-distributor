// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    PendingRoot, IUniversalRewardsDistributor, IPendingRoot
} from "src/interfaces/IUniversalRewardsDistributor.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";
import {EventsLib} from "src/libraries/EventsLib.sol";

import {Merkle} from "@murky/src/Merkle.sol";

import "@forge-std/Test.sol";

contract UniversalRewardsDistributorTest is Test {
    uint256 internal constant MAX_RECEIVERS = 20;

    Merkle merkle = new Merkle();
    MockERC20 internal token1;
    MockERC20 internal token2;
    IUniversalRewardsDistributor internal distributionWithoutTimeLock;
    IUniversalRewardsDistributor internal distributionWithTimeLock;
    address owner = _addrFromHashedString("Owner");
    address updater = _addrFromHashedString("Updater");

    bytes32 DEFAULT_ROOT = bytes32(keccak256(bytes("DEFAULT_ROOT")));
    bytes32 DEFAULT_IPFS_HASH = bytes32(keccak256(bytes("DEFAULT_IPFS_HASH")));
    uint256 DEFAULT_TIMELOCK = 1 days;

    function setUp() public {
        distributionWithoutTimeLock = new UniversalRewardsDistributor(
            owner, 0, bytes32(0), bytes32(0)
        );
        token1 = new MockERC20("Token1", "TKN1", 18);
        token2 = new MockERC20("Token2", "TKN2", 18);

        vm.startPrank(owner);
        distributionWithoutTimeLock.setRootUpdater(updater, true);

        vm.warp(block.timestamp + 1);
        distributionWithTimeLock = new UniversalRewardsDistributor(
            owner, DEFAULT_TIMELOCK, bytes32(0), bytes32(0)
        );
        distributionWithTimeLock.setRootUpdater(updater, true);
        vm.stopPrank();

        token1.mint(owner, 1000 ether * 200);
        token2.mint(owner, 1000 ether * 200);

        token1.mint(address(distributionWithoutTimeLock), 1000 ether * 200);
        token2.mint(address(distributionWithoutTimeLock), 1000 ether * 200);
        token1.mint(address(distributionWithTimeLock), 1000 ether * 200);
        token2.mint(address(distributionWithTimeLock), 1000 ether * 200);
    }

    function testDistributionConstructor(address randomCreator) public {
        vm.prank(randomCreator);
        UniversalRewardsDistributor distributor = new UniversalRewardsDistributor(
            randomCreator, DEFAULT_TIMELOCK, DEFAULT_ROOT, DEFAULT_IPFS_HASH
        );

        PendingRoot memory pendingRoot = _getPendingRoot(distributor);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
        assertEq(distributor.owner(), randomCreator);
        assertEq(distributor.timelock(), DEFAULT_TIMELOCK);
        assertEq(distributor.root(), DEFAULT_ROOT);
        assertEq(distributor.ipfsHash(), DEFAULT_IPFS_HASH);
    }

    function testProposeRootWithoutTimelockAsOwner() public {
        vm.prank(owner);
        vm.expectEmit(address(distributionWithoutTimeLock));
        emit EventsLib.RootSet(DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributionWithoutTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assertEq(distributionWithoutTimeLock.root(), DEFAULT_ROOT);
        assertEq(distributionWithoutTimeLock.ipfsHash(), DEFAULT_IPFS_HASH);
        PendingRoot memory pendingRoot = _getPendingRoot(distributionWithoutTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
        assertEq(pendingRoot.ipfsHash, bytes32(0));
    }

    function testProposeRootWithoutTimelockAsUpdater() public {
        vm.prank(updater);
        vm.expectEmit(address(distributionWithoutTimeLock));
        emit EventsLib.RootSet(DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributionWithoutTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assertEq(distributionWithoutTimeLock.root(), DEFAULT_ROOT);
        assertEq(distributionWithoutTimeLock.ipfsHash(), DEFAULT_IPFS_HASH);
        PendingRoot memory pendingRoot = _getPendingRoot(distributionWithoutTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
        assertEq(pendingRoot.ipfsHash, bytes32(0));
    }

    function testProposeRootWithoutTimelockAsRandomCallerShouldRevert(address randomCaller) public {
        vm.assume(!distributionWithoutTimeLock.isUpdater(randomCaller) && randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER_OR_UPDATER));
        distributionWithoutTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);
    }

    function testProposeRootWithTimelockAsOwner() public {
        vm.prank(owner);
        vm.expectEmit(address(distributionWithTimeLock));
        emit EventsLib.RootProposed(DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assert(distributionWithTimeLock.root() != DEFAULT_ROOT);

        PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, DEFAULT_ROOT);
        assertEq(pendingRoot.ipfsHash, DEFAULT_IPFS_HASH);
        assertEq(pendingRoot.submittedAt, block.timestamp);
    }

    function testProposeRootWithTimelockAsUpdater() public {
        vm.prank(updater);
        vm.expectEmit(address(distributionWithTimeLock));
        emit EventsLib.RootProposed(DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assert(distributionWithTimeLock.root() != DEFAULT_ROOT);

        PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, DEFAULT_ROOT);
        assertEq(pendingRoot.ipfsHash, DEFAULT_IPFS_HASH);
        assertEq(pendingRoot.submittedAt, block.timestamp);
    }

    function testProposeRootWithTimelockAsRandomCallerShouldRevert(address randomCaller) public {
        vm.assume(!distributionWithTimeLock.isUpdater(randomCaller) && randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER_OR_UPDATER));
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);
    }

    function testAcceptRootShouldUpdateMainRoot(address randomCaller) public {
        vm.prank(updater);
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assert(distributionWithTimeLock.root() != DEFAULT_ROOT);
        vm.warp(block.timestamp + 1 days);

        vm.prank(randomCaller);
        vm.expectEmit(address(distributionWithTimeLock));
        emit EventsLib.RootSet(DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributionWithTimeLock.acceptRoot();

        assertEq(distributionWithTimeLock.root(), DEFAULT_ROOT);
        assertEq(distributionWithTimeLock.ipfsHash(), DEFAULT_IPFS_HASH);
        PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.ipfsHash, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testAcceptRootShouldRevertIfTimelockNotFinished(address randomCaller, uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, 0, distributionWithTimeLock.timelock() - 1);

        vm.prank(updater);
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assert(distributionWithTimeLock.root() != DEFAULT_ROOT);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_EXPIRED));
        distributionWithTimeLock.acceptRoot();
    }

    function testAcceptRootShouldRevertIfNoPendingRoot(address randomCaller) public {
        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.NO_PENDING_ROOT));
        distributionWithTimeLock.acceptRoot();
    }

    function testSetRootShouldRevertIfNotOwner(bytes32 newRoot, address randomCaller) public {
        vm.assume(randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributionWithoutTimeLock.setRoot(newRoot, DEFAULT_IPFS_HASH);
    }

    function testSetRootShouldUpdateTheCurrentRoot(bytes32 newRoot, bytes32 newIpfsHash) public {
        vm.prank(owner);
        vm.expectEmit(address(distributionWithTimeLock));
        emit EventsLib.RootSet(newRoot, newIpfsHash);
        distributionWithTimeLock.setRoot(newRoot, newIpfsHash);

        assertEq(distributionWithTimeLock.root(), newRoot);
        assertEq(distributionWithTimeLock.ipfsHash(), newIpfsHash);

        PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);

        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.ipfsHash, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testSetRootShouldRemovePendingRoot(bytes32 newRoot, address randomCaller) public {
        vm.assume(newRoot != DEFAULT_ROOT && randomCaller != owner);

        vm.startPrank(owner);
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assertEq(_getPendingRoot(distributionWithTimeLock).root, DEFAULT_ROOT);

        distributionWithTimeLock.setRoot(newRoot, DEFAULT_IPFS_HASH);
        vm.stopPrank();

        assertEq(_getPendingRoot(distributionWithTimeLock).root, bytes32(0));
    }

    function testSetTimelockShouldChangeTheDistributionTimelock(uint256 newTimelock) public {
        newTimelock = bound(newTimelock, 0, type(uint256).max);

        vm.prank(owner);
        vm.expectEmit(address(distributionWithoutTimeLock));
        emit EventsLib.TimelockSet(newTimelock);
        distributionWithoutTimeLock.setTimelock(newTimelock);

        assertEq(distributionWithoutTimeLock.timelock(), newTimelock);
    }

    function testSetTimelockShouldIncreaseTheQueueTimestamp(
        uint256 timeElapsed,
        uint256 newTimelock,
        uint256 beforeEndOfTimelock,
        uint256 afterEndOfTimelock
    ) public {
        vm.assume(newTimelock > 0);
        timeElapsed = bound(timeElapsed, 0, DEFAULT_TIMELOCK - 1);
        newTimelock = bound(newTimelock, DEFAULT_TIMELOCK + 1, type(uint128).max - 1);
        beforeEndOfTimelock = bound(beforeEndOfTimelock, 0, newTimelock - timeElapsed - 1);
        afterEndOfTimelock = bound(afterEndOfTimelock, newTimelock - beforeEndOfTimelock + 1, type(uint128).max);
        vm.prank(owner);
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(owner);
        distributionWithTimeLock.setTimelock(newTimelock);

        assertEq(distributionWithTimeLock.timelock(), newTimelock);

        vm.warp(block.timestamp + beforeEndOfTimelock);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_EXPIRED));
        distributionWithTimeLock.acceptRoot();

        vm.warp(block.timestamp + afterEndOfTimelock);
        vm.expectEmit(address(distributionWithTimeLock));
        emit EventsLib.RootSet(DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributionWithTimeLock.acceptRoot();
    }

    function testSetTimelockShouldRevertIfNotOwner(uint256 newTimelock, address randomCaller) public {
        vm.assume(randomCaller != owner);
        newTimelock = bound(newTimelock, 0, type(uint256).max);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributionWithoutTimeLock.setTimelock(newTimelock);
    }

    function testSetTimelockShouldRevertIfNewTimelockShorterThanCurrentTimelockAndTimelockNotExpired(
        bytes32 pendingRoot,
        uint256 newTimelock,
        uint256 timeElapsed
    ) public {
        newTimelock = bound(newTimelock, 0, DEFAULT_TIMELOCK - 1);
        timeElapsed = bound(timeElapsed, 0, DEFAULT_TIMELOCK - 1);

        vm.prank(owner);
        distributionWithTimeLock.proposeRoot(pendingRoot, DEFAULT_IPFS_HASH);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(owner);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_EXPIRED));
        distributionWithTimeLock.setTimelock(newTimelock);
    }

    function testSetTimelockShouldWorkIfPendingRootIsUpdatableButNotYetUpdated() public {
        vm.prank(owner);
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK);

        vm.prank(owner);
        vm.expectEmit(address(distributionWithTimeLock));
        emit EventsLib.TimelockSet(0.7 days);
        distributionWithTimeLock.setTimelock(0.7 days);

        assertEq(distributionWithTimeLock.timelock(), 0.7 days);
    }

    function testSetRootUpdaterShouldAddOrRemoveRootUpdater(address newUpdater, bool active) public {
        vm.prank(owner);
        vm.expectEmit(address(distributionWithoutTimeLock));
        emit EventsLib.RootUpdaterSet(newUpdater, active);
        distributionWithoutTimeLock.setRootUpdater(newUpdater, active);

        assertEq(distributionWithoutTimeLock.isUpdater(newUpdater), active);
    }

    function testSetRootUpdaterShouldRevertIfNotOwner(address caller, bool active) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributionWithoutTimeLock.setRootUpdater(_addrFromHashedString("RANDOM_UPDATER"), active);
    }

    function testRevokeRootShouldRevokeWhenCalledWithOwner() public {
        vm.prank(owner);
        distributionWithTimeLock.proposeRoot(DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        vm.prank(owner);
        vm.expectEmit(address(distributionWithTimeLock));
        emit EventsLib.RootRevoked();
        distributionWithTimeLock.revokeRoot();

        PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testRevokeRootShouldRevertIfNotOwner(bytes32 proposedRoot, address caller) public {
        vm.assume(proposedRoot != bytes32(0) && caller != owner);

        vm.prank(owner);
        distributionWithTimeLock.proposeRoot(proposedRoot, DEFAULT_IPFS_HASH);

        vm.prank(caller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributionWithTimeLock.revokeRoot();
    }

    function testRevokeRootShouldRevertWhenNoPendingRoot() public {
        vm.prank(owner);
        vm.expectRevert(bytes(ErrorsLib.NO_PENDING_ROOT));
        distributionWithTimeLock.revokeRoot();
    }

    function testSetOwner(address newOwner) public {
        vm.assume(newOwner != owner);

        vm.prank(owner);
        vm.expectEmit(address(distributionWithTimeLock));
        emit EventsLib.OwnerSet(owner, newOwner);
        distributionWithTimeLock.setOwner(newOwner);

        assertEq(distributionWithTimeLock.owner(), newOwner);
    }

    function testSetOwnerShouldRevertIfNotOwner(address newOwner, address caller) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributionWithTimeLock.setOwner(newOwner);
    }

    function testClaimShouldFollowTheMerkleDistribution(uint256 claimable, uint8 size) public {
        claimable = bound(claimable, 1 ether, 1000 ether);
        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, boundedSize);

        vm.prank(owner);
        distributionWithoutTimeLock.proposeRoot(root, DEFAULT_IPFS_HASH);

        assertEq(distributionWithoutTimeLock.root(), root);

        _claimAndVerifyRewards(distributionWithoutTimeLock, data, claimable);
    }

    function testClaimShouldRevertIfClaimedTwice(uint256 claimable) public {
        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, 2);

        vm.prank(owner);
        distributionWithoutTimeLock.proposeRoot(root, DEFAULT_IPFS_HASH);

        assertEq(distributionWithoutTimeLock.root(), root);
        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectEmit(address(distributionWithoutTimeLock));
        emit EventsLib.Claimed(vm.addr(1), address(token1), claimable);
        distributionWithoutTimeLock.claim(vm.addr(1), address(token1), claimable, proof1);

        vm.expectRevert(bytes(ErrorsLib.ALREADY_CLAIMED));
        distributionWithoutTimeLock.claim(vm.addr(1), address(token1), claimable, proof1);
    }

    function testClaimShouldReturnsTheAmountClaimed(uint256 claimable) public {
        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, 2);

        vm.prank(owner);
        distributionWithoutTimeLock.proposeRoot(root, DEFAULT_IPFS_HASH);

        assertEq(distributionWithoutTimeLock.root(), root);
        bytes32[] memory proof1 = merkle.getProof(data, 0);

        uint256 claimed = distributionWithoutTimeLock.claim(vm.addr(1), address(token1), claimable, proof1);

        assertEq(claimed, claimable);

        // now, we will check if the amount claimed is reduced with the already claimed amount

        (bytes32[] memory data2, bytes32 root2) = _setupRewards(claimable * 2, 2);

        vm.prank(owner);
        distributionWithoutTimeLock.proposeRoot(root2, DEFAULT_IPFS_HASH);

        assertEq(distributionWithoutTimeLock.root(), root2);
        bytes32[] memory proof2 = merkle.getProof(data2, 0);

        uint256 claimed2 = distributionWithoutTimeLock.claim(vm.addr(1), address(token1), claimable * 2, proof2);

        assertEq(claimed2, claimable);
    }

    function testClaimShouldRevertIfNoRoot(uint256 claimable) public {
        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data,) = _setupRewards(claimable, 2);

        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectRevert(bytes(ErrorsLib.ROOT_NOT_SET));
        distributionWithoutTimeLock.claim(vm.addr(1), address(token1), claimable, proof1);
    }

    function testClaimShouldRevertIfInvalidRoot(uint256 claimable, bytes32 invalidRoot) public {
        vm.assume(invalidRoot != bytes32(0));

        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, 2);

        vm.assume(root != invalidRoot);
        vm.prank(owner);
        distributionWithoutTimeLock.proposeRoot(invalidRoot, DEFAULT_IPFS_HASH);

        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectRevert(bytes(ErrorsLib.INVALID_PROOF_OR_EXPIRED));
        distributionWithoutTimeLock.claim(vm.addr(1), address(token1), claimable, proof1);
    }

    function _setupRewards(uint256 claimable, uint256 size)
        internal
        view
        returns (bytes32[] memory data, bytes32 root)
    {
        data = new bytes32[](size);

        uint256 i;
        while (i < size / 2) {
            uint256 index = i + 1;
            data[i] = keccak256(
                bytes.concat(keccak256(abi.encode(vm.addr(index), address(token1), uint256(claimable / index))))
            );
            data[i + 1] = keccak256(
                bytes.concat(keccak256(abi.encode(vm.addr(index), address(token2), uint256(claimable / index))))
            );

            i += 2;
        }

        root = merkle.getRoot(data);
    }

    struct Vars {
        uint256 i;
        uint256 index;
        uint256 claimableInput;
        uint256 claimableAdjusted1;
        uint256 claimableAdjusted2;
        uint256 balanceBefore1;
        uint256 balanceBefore2;
        uint256 UrdBalanceBefore1;
        uint256 UrdBalanceBefore2;
    }

    function _claimAndVerifyRewards(IUniversalRewardsDistributor distribution, bytes32[] memory data, uint256 claimable)
        internal
    {
        Vars memory vars;

        while (vars.i < data.length / 2) {
            bytes32[] memory proof1 = merkle.getProof(data, vars.i);
            bytes32[] memory proof2 = merkle.getProof(data, vars.i + 1);

            vars.index = vars.i + 1;
            vars.claimableInput = claimable / vars.index;
            vars.claimableAdjusted1 = vars.claimableInput - distribution.claimed(vm.addr(vars.index), address(token1));
            vars.claimableAdjusted2 = vars.claimableInput - distribution.claimed(vm.addr(vars.index), address(token2));
            vars.balanceBefore1 = token1.balanceOf(vm.addr(vars.index));
            vars.balanceBefore2 = token2.balanceOf(vm.addr(vars.index));
            vars.UrdBalanceBefore1 = token1.balanceOf(address(distribution));
            vars.UrdBalanceBefore2 = token2.balanceOf(address(distribution));

            // Claim token1
            vm.expectEmit(address(distribution));
            emit EventsLib.Claimed(vm.addr(vars.index), address(token1), vars.claimableAdjusted1);
            distribution.claim(vm.addr(vars.index), address(token1), vars.claimableInput, proof1);

            // Claim token2
            vm.expectEmit(address(distribution));
            emit EventsLib.Claimed(vm.addr(vars.index), address(token2), vars.claimableAdjusted2);
            distribution.claim(vm.addr(vars.index), address(token2), vars.claimableInput, proof2);

            uint256 balanceAfter1 = vars.balanceBefore1 + vars.claimableAdjusted1;
            uint256 balanceAfter2 = vars.balanceBefore2 + vars.claimableAdjusted2;

            assertEq(token1.balanceOf(vm.addr(vars.index)), balanceAfter1);
            assertEq(token2.balanceOf(vm.addr(vars.index)), balanceAfter2);
            // Assert claimed getter
            assertEq(distribution.claimed(vm.addr(vars.index), address(token1)), balanceAfter1);
            assertEq(distribution.claimed(vm.addr(vars.index), address(token2)), balanceAfter2);

            assertEq(token1.balanceOf(address(distribution)), vars.UrdBalanceBefore1 - vars.claimableAdjusted1);
            assertEq(token2.balanceOf(address(distribution)), vars.UrdBalanceBefore2 - vars.claimableAdjusted2);

            vars.i += 2;
        }
    }

    function _addrFromHashedString(string memory str) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(str)))));
    }

    function _getPendingRoot(IUniversalRewardsDistributor distribution) internal view returns (PendingRoot memory) {
        return IPendingRoot(address(distribution)).pendingRoot();
    }
}
