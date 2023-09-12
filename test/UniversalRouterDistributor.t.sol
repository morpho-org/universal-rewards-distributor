// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniversalRewardsDistributor, IPendingRoot} from "src/interfaces/IUniversalRewardsDistributor.sol";

import {ErrorsLib} from "src/libraries/ErrorsLib.sol";

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";

import {Merkle} from "@murky/src/Merkle.sol";

import "@forge-std/Test.sol";

contract UniversalRouterDistributor is Test {
    uint256 internal constant MAX_RECEIVERS = 20;

    UniversalRewardsDistributor internal distributor;
    Merkle merkle = new Merkle();
    MockERC20 internal token1;
    MockERC20 internal token2;
    uint256 internal distributionWithoutTimeLock;
    uint256 internal distributionWithTimeLock;
    address owner = _addrFromHashedString("Owner");
    address updater = _addrFromHashedString("Updater");

    bytes32 DEFAULT_ROOT = bytes32(keccak256(bytes("DEFAULT_ROOT")));
    bytes32 DEFAULT_IPFS_HASH = bytes32(keccak256(bytes("DEFAULT_IPFS_HASH")));
    uint256 DEFAULT_TIMELOCK = 1 days;

    event RootUpdated(uint256 indexed distributionId, bytes32 newRoot, bytes32 newIpfsHash);
    event RootProposed(uint256 indexed distributionId, bytes32 newRoot, bytes32 newIpfsHash);
    event TreasuryUpdated(uint256 indexed distributionId, address newTreasury);
    event TreasuryProposed(uint256 indexed distributionId, address newTreasury);
    event TimelockUpdated(uint256 indexed distributionId, uint256 timelock);
    event DistributionCreated(
        uint256 indexed distributionId, address indexed caller, address indexed owner, uint256 initialTimelock
    );
    event RootUpdaterUpdated(uint256 indexed distributionId, address indexed rootUpdater, bool active);
    event PendingRootRevoked(uint256 indexed distributionId);
    event RewardsClaimed(
        uint256 indexed distributionId, address indexed account, address indexed reward, uint256 amount
    );
    event DistributionOwnerSet(uint256 indexed distributionId, address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        distributor = new UniversalRewardsDistributor();
        token1 = new MockERC20("Token1", "TKN1", 18);
        token2 = new MockERC20("Token2", "TKN2", 18);

        vm.prank(owner);
        distributionWithoutTimeLock = distributor.createDistribution(0, bytes32(0), bytes32(0), address(0), address(0));
        vm.prank(owner);
        distributor.updateRootUpdater(distributionWithoutTimeLock, updater, true);

        vm.warp(block.timestamp + 1);
        vm.startPrank(owner);
        distributionWithTimeLock =
            distributor.createDistribution(DEFAULT_TIMELOCK, bytes32(0), bytes32(0), address(0), address(0));
        distributor.updateRootUpdater(distributionWithTimeLock, updater, true);
        vm.stopPrank();

        token1.mint(owner, 1000 ether * 200);
        token2.mint(owner, 1000 ether * 200);

        vm.startPrank(owner);
        token1.approve(address(distributor), 1000 ether * 200);
        token2.approve(address(distributor), 1000 ether * 200);
        vm.stopPrank();
    }

    function testCreateDistributionSetupCorrectly(address randomCreator) public {
        uint256 distributionId = distributor.nextDistributionId();

        vm.prank(randomCreator);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.DistributionCreated(
            distributionId, randomCreator, randomCreator, DEFAULT_TIMELOCK
        );
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionId, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributor.createDistribution(DEFAULT_TIMELOCK, DEFAULT_ROOT, DEFAULT_IPFS_HASH, address(0), address(0));

        assertEq(distributor.rootOf(distributionId), DEFAULT_ROOT);
        assertEq(distributor.timelockOf(distributionId), DEFAULT_TIMELOCK);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot = _getPendingRoot(distributionId);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
        assertEq(distributor.ownerOf(distributionId), randomCreator);
        assertEq(distributor.treasuryOf(distributionId), randomCreator);
        assertEq(distributor.pendingTreasuryOf(distributionId), address(0));
        assertEq(distributor.nextDistributionId(), distributionId + 1);
        assertEq(distributor.ipfsHashOf(distributionId), DEFAULT_IPFS_HASH);
    }

    function testCreateDistributionWithNewOwnerProvided(address newOwner) public {
        vm.assume(newOwner != address(0));

        uint256 distributionId = distributor.nextDistributionId();

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.DistributionCreated(distributionId, owner, newOwner, DEFAULT_TIMELOCK);
        distributionId =
            distributor.createDistribution(DEFAULT_TIMELOCK, DEFAULT_ROOT, DEFAULT_IPFS_HASH, newOwner, address(0));

        assertEq(distributor.ownerOf(distributionId), newOwner);
        assertEq(distributor.treasuryOf(distributionId), owner);
    }

    function testCreateDistributionWithNewPendingTreasuryProvided(address newPendingTreasury) public {
        vm.assume(newPendingTreasury != address(0));

        uint256 distributionId = distributor.nextDistributionId();
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TreasuryProposed(distributionId, newPendingTreasury);
        distributionId = distributor.createDistribution(
            DEFAULT_TIMELOCK, DEFAULT_ROOT, DEFAULT_IPFS_HASH, address(0), newPendingTreasury
        );

        assertEq(distributor.ownerOf(distributionId), owner);
        assertEq(distributor.treasuryOf(distributionId), owner);
        assertEq(distributor.pendingTreasuryOf(distributionId), newPendingTreasury);
    }

    function testCreateDistributionWithAnInitialRoot() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributor.nextDistributionId(), DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        uint256 distributionId =
            distributor.createDistribution(DEFAULT_TIMELOCK, DEFAULT_ROOT, DEFAULT_IPFS_HASH, address(0), address(0));

        assertEq(distributor.rootOf(distributionId), DEFAULT_ROOT);
        assertEq(distributor.ipfsHashOf(distributionId), DEFAULT_IPFS_HASH);
        assertEq(_getPendingRoot(distributionId).root, bytes32(0));
    }

    function testNextDistributionIdShouldBeIncrementedAfterDistributionCreation(
        uint256 timelock,
        bytes32 initialRoot,
        address newOwner,
        address newPendingTreasury
    ) public {
        uint256 initialRootId = distributor.nextDistributionId();
        vm.prank(owner);
        uint256 distributionId =
            distributor.createDistribution(timelock, initialRoot, DEFAULT_IPFS_HASH, newOwner, newPendingTreasury);

        assertEq(distributionId, initialRootId);
        assertEq(distributor.nextDistributionId(), initialRootId + 1);
    }

    function testUpdateRootWithoutTimelockAsOwner() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithoutTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assertEq(distributor.rootOf(distributionWithoutTimeLock), DEFAULT_ROOT);
        assertEq(distributor.ipfsHashOf(distributionWithoutTimeLock), DEFAULT_IPFS_HASH);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot = _getPendingRoot(distributionWithoutTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
        assertEq(pendingRoot.ipfsHash, bytes32(0));
    }

    function testUpdateRootWithoutTimelockAsUpdater() public {
        vm.prank(updater);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithoutTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assertEq(distributor.rootOf(distributionWithoutTimeLock), DEFAULT_ROOT);
        assertEq(distributor.ipfsHashOf(distributionWithoutTimeLock), DEFAULT_IPFS_HASH);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot = _getPendingRoot(distributionWithoutTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
        assertEq(pendingRoot.ipfsHash, bytes32(0));
    }

    function testUpdateRootWithoutTimelockAsRandomCallerShouldRevert(address randomCaller) public {
        vm.assume(!distributor.isUpdaterOf(distributionWithoutTimeLock, randomCaller) && randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER_OR_UPDATER));
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
    }

    function testUpdateRootWithTimelockAsOwner() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootProposed(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);

        IUniversalRewardsDistributor.PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, DEFAULT_ROOT);
        assertEq(pendingRoot.ipfsHash, DEFAULT_IPFS_HASH);
        assertEq(pendingRoot.submittedAt, block.timestamp);
    }

    function testUpdateRootWithTimelockAsUpdater() public {
        vm.prank(updater);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootProposed(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);

        IUniversalRewardsDistributor.PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, DEFAULT_ROOT);
        assertEq(pendingRoot.ipfsHash, DEFAULT_IPFS_HASH);
        assertEq(pendingRoot.submittedAt, block.timestamp);
    }

    function testProposeRootWithTimelockAsRandomCallerShouldRevert(address randomCaller) public {
        vm.assume(!distributor.isUpdaterOf(distributionWithoutTimeLock, randomCaller) && randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER_OR_UPDATER));
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
    }

    function testAcceptRootUpdateShouldUpdateMainRoot(address randomCaller) public {
        vm.prank(updater);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);
        vm.warp(block.timestamp + 1 days);

        vm.prank(randomCaller);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributor.acceptRootUpdate(distributionWithTimeLock);

        assertEq(distributor.rootOf(distributionWithTimeLock), DEFAULT_ROOT);
        assertEq(distributor.ipfsHashOf(distributionWithTimeLock), DEFAULT_IPFS_HASH);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testAcceptRootUpdateShouldRevertIfTimelockNotFinished(address randomCaller, uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, 0, distributor.timelockOf(distributionWithTimeLock) - 1);

        vm.prank(updater);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_EXPIRED));
        distributor.acceptRootUpdate(distributionWithTimeLock);
    }

    function testAcceptRootUpdateShouldRevertIfNoPendingRoot(address randomCaller) public {
        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.NO_PENDING_ROOT));
        distributor.acceptRootUpdate(distributionWithTimeLock);
    }

    function testProposeTreasuryShouldUpdatePendingTreasury(address newTreasury) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TreasuryProposed(distributionWithoutTimeLock, newTreasury);
        distributor.proposeTreasury(distributionWithoutTimeLock, newTreasury);

        assertEq(distributor.pendingTreasuryOf(distributionWithoutTimeLock), newTreasury);
    }

    function testProposeTreasuryShouldRevertIfNotOwner(address caller, address newTreasury) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributor.proposeTreasury(distributionWithoutTimeLock, newTreasury);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), owner);
        assertEq(distributor.pendingTreasuryOf(distributionWithoutTimeLock), address(0));
    }

    function testAcceptAsTreasuryShouldUpdateTreasury(address newTreasury) public {
        vm.prank(owner);
        distributor.proposeTreasury(distributionWithoutTimeLock, newTreasury);

        vm.prank(newTreasury);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TreasuryUpdated(distributionWithoutTimeLock, newTreasury);
        distributor.acceptAsTreasury(distributionWithoutTimeLock);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), newTreasury);
    }

    function testAcceptAsTreasuryShouldRevertIfNotCalledByTreasury(address caller, address newTreasury) public {
        vm.assume(caller != newTreasury);

        vm.prank(owner);
        distributor.proposeTreasury(distributionWithoutTimeLock, newTreasury);

        vm.prank(caller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_PENDING_TREASURY));
        distributor.acceptAsTreasury(distributionWithoutTimeLock);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), owner);
    }

    function testForceUpdateRootShouldRevertIfNotOwner(bytes32 newRoot, address randomCaller) public {
        vm.assume(newRoot != bytes32(0) && randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributor.forceUpdateRoot(distributionWithoutTimeLock, newRoot, DEFAULT_IPFS_HASH);
    }

    function testForceUpdateRootShouldUpdateTheCurrentRoot(bytes32 newRoot, bytes32 newIpfsHash) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithTimeLock, newRoot, newIpfsHash);
        distributor.forceUpdateRoot(distributionWithTimeLock, newRoot, newIpfsHash);

        assertEq(distributor.rootOf(distributionWithTimeLock), newRoot);
        assertEq(distributor.ipfsHashOf(distributionWithTimeLock), newIpfsHash);

        assertEq(_getPendingRoot(distributionWithTimeLock).root, bytes32(0));
        assertEq(_getPendingRoot(distributionWithTimeLock).ipfsHash, bytes32(0));
        assertEq(_getPendingRoot(distributionWithTimeLock).submittedAt, 0);
    }

    function testForceUpdateRootShouldRemovePendingRoot(bytes32 newRoot, address randomCaller) public {
        vm.assume(newRoot != DEFAULT_ROOT && randomCaller != owner);

        vm.startPrank(owner);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        assertEq(_getPendingRoot(distributionWithTimeLock).root, DEFAULT_ROOT);

        distributor.forceUpdateRoot(distributionWithTimeLock, newRoot, DEFAULT_IPFS_HASH);
        assertEq(_getPendingRoot(distributionWithTimeLock).root, bytes32(0));
        vm.stopPrank();
    }

    function testUpdateTimelockShouldChangeTheDistributionTimelock(uint256 newTimelock) public {
        newTimelock = bound(newTimelock, 0, type(uint256).max);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TimelockUpdated(distributionWithoutTimeLock, newTimelock);
        distributor.updateTimelock(distributionWithoutTimeLock, newTimelock);

        assertEq(distributor.timelockOf(distributionWithoutTimeLock), newTimelock);
    }

    function testUpdateTimelockShouldIncreaseTheQueueTimestamp(
        uint256 timeElapsed,
        uint256 newTimelock,
        uint256 beforeEndOfTimelock,
        uint256 afterEndOfTimelock
    ) public {
        timeElapsed = bound(timeElapsed, 0, DEFAULT_TIMELOCK - 1);
        newTimelock = bound(newTimelock, DEFAULT_TIMELOCK + 1, type(uint128).max - 1);
        beforeEndOfTimelock = bound(beforeEndOfTimelock, 0, newTimelock - timeElapsed - 1);
        afterEndOfTimelock = bound(afterEndOfTimelock, newTimelock - beforeEndOfTimelock + 1, type(uint128).max);
        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(owner);
        distributor.updateTimelock(distributionWithTimeLock, newTimelock);

        assertEq(distributor.timelockOf(distributionWithTimeLock), newTimelock);

        vm.warp(block.timestamp + beforeEndOfTimelock);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_EXPIRED));
        distributor.acceptRootUpdate(distributionWithTimeLock);

        vm.warp(block.timestamp + afterEndOfTimelock);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);
        distributor.acceptRootUpdate(distributionWithTimeLock);
    }

    function testUpdateTimelockShouldRevertIfNotOwner(uint256 newTimelock, address randomCaller) public {
        vm.assume(randomCaller != owner);
        newTimelock = bound(newTimelock, 0, type(uint256).max);

        vm.prank(randomCaller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributor.updateTimelock(distributionWithoutTimeLock, newTimelock);
    }

    function testUpdateTimelockShouldRevertIfNewTimelockShorterThanCurrentTimelockAndTimelockNotExpired(
        bytes32 pendingRoot,
        uint256 newTimelock,
        uint256 timeElapsed
    ) public {
        newTimelock = bound(newTimelock, 0, DEFAULT_TIMELOCK - 1);
        timeElapsed = bound(timeElapsed, 0, DEFAULT_TIMELOCK - 1);
        vm.assume(pendingRoot != bytes32(0));

        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, pendingRoot, DEFAULT_IPFS_HASH);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(owner);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_EXPIRED));
        distributor.updateTimelock(distributionWithTimeLock, newTimelock);
    }

    function testUpdateTimelockShouldWorkIfPendingRootIsUpdatableButNotYetUpdated() public {
        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        vm.warp(block.timestamp + DEFAULT_TIMELOCK);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TimelockUpdated(distributionWithTimeLock, 0.7 days);
        distributor.updateTimelock(distributionWithTimeLock, 0.7 days);

        assertEq(distributor.timelockOf(distributionWithTimeLock), 0.7 days);
    }

    function testUpdateRootUpdaterShouldAddOrRemoveRootUpdater(address newUpdater, bool active) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdaterUpdated(distributionWithoutTimeLock, newUpdater, active);
        distributor.updateRootUpdater(distributionWithoutTimeLock, newUpdater, active);

        assertEq(distributor.isUpdaterOf(distributionWithoutTimeLock, newUpdater), active);
    }

    function testUpdateRootUpdaterShouldRevertIfNotOwner(address caller, bool active) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributor.updateRootUpdater(distributionWithoutTimeLock, _addrFromHashedString("RANDOM_UPDATER"), active);
    }

    function testRevokePendingRootShouldRevokeWhenCalledWithOwner() public {
        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT, DEFAULT_IPFS_HASH);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.PendingRootRevoked(distributionWithTimeLock);
        distributor.revokePendingRoot(distributionWithTimeLock);

        IUniversalRewardsDistributor.PendingRoot memory pendingRoot = _getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testRevokePendingRootShouldRevertIfNotOwner(bytes32 proposedRoot, address caller) public {
        vm.assume(proposedRoot != bytes32(0) && caller != owner);

        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, proposedRoot, DEFAULT_IPFS_HASH);

        vm.prank(caller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributor.revokePendingRoot(distributionWithTimeLock);
    }

    function testRevokePendingRootShouldRevertWhenNoPendingRoot() public {
        vm.prank(owner);
        vm.expectRevert(bytes(ErrorsLib.NO_PENDING_ROOT));
        distributor.revokePendingRoot(distributionWithTimeLock);
    }

    function testSetDistributionOwner(address newOwner) public {
        vm.assume(newOwner != owner);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.DistributionOwnerSet(distributionWithTimeLock, owner, newOwner);
        distributor.setDistributionOwner(distributionWithTimeLock, newOwner);

        assertEq(distributor.ownerOf(distributionWithTimeLock), newOwner);
    }

    function testTransferDistributionOwnershipShouldRevertIfNotOwner(address newOwner, address caller) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert(bytes(ErrorsLib.CALLER_NOT_OWNER));
        distributor.setDistributionOwner(distributionWithTimeLock, newOwner);
    }

    function testClaimRewardsShouldFollowTheMerkleDistribution(uint256 claimable, uint8 size) public {
        claimable = bound(claimable, 1 ether, 1000 ether);
        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, boundedSize);

        vm.prank(owner);
        distributor.proposeRoot(distributionWithoutTimeLock, root, DEFAULT_IPFS_HASH);

        assertEq(distributor.rootOf(distributionWithoutTimeLock), root);

        _claimAndVerifyRewards(distributionWithoutTimeLock, data, claimable);
    }

    function testClaimRewardsShouldRevertIfClaimedTwice(uint256 claimable) public {
        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, 2);

        vm.prank(owner);
        distributor.proposeRoot(distributionWithoutTimeLock, root, DEFAULT_IPFS_HASH);

        assertEq(distributor.rootOf(distributionWithoutTimeLock), root);
        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RewardsClaimed(
            distributionWithoutTimeLock, vm.addr(1), address(token1), claimable
        );
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);

        vm.expectRevert(bytes(ErrorsLib.ALREADY_CLAIMED));
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);
    }

    function testClaimRewardsShouldRevertIfNoRoot(uint256 claimable) public {
        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data,) = _setupRewards(claimable, 2);

        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectRevert(bytes(ErrorsLib.ROOT_NOT_SET));
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);
    }

    function testClaimRewardsShouldRevertIfInvalidRoot(uint256 claimable, bytes32 invalidRoot) public {
        vm.assume(invalidRoot != bytes32(0));

        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, 2);

        vm.assume(root != invalidRoot);
        vm.prank(owner);
        distributor.proposeRoot(distributionWithoutTimeLock, invalidRoot, DEFAULT_IPFS_HASH);

        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectRevert(bytes(ErrorsLib.INVALID_PROOF_OR_EXPIRED));
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);
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
        uint256 treasuryBalanceBefore1;
        uint256 treasuryBalanceBefore2;
    }

    function _claimAndVerifyRewards(uint256 distributionId, bytes32[] memory data, uint256 claimable) internal {
        Vars memory vars;

        while (vars.i < data.length / 2) {
            bytes32[] memory proof1 = merkle.getProof(data, vars.i);
            bytes32[] memory proof2 = merkle.getProof(data, vars.i + 1);

            vars.index = vars.i + 1;
            vars.claimableInput = claimable / vars.index;
            vars.claimableAdjusted1 =
                vars.claimableInput - distributor.claimed(distributionId, vm.addr(vars.index), address(token1));
            vars.claimableAdjusted2 =
                vars.claimableInput - distributor.claimed(distributionId, vm.addr(vars.index), address(token2));
            vars.balanceBefore1 = ERC20(address(token1)).balanceOf(vm.addr(vars.index));
            vars.balanceBefore2 = ERC20(address(token2)).balanceOf(vm.addr(vars.index));
            vars.treasuryBalanceBefore1 = ERC20(address(token1)).balanceOf(distributor.treasuryOf(distributionId));
            vars.treasuryBalanceBefore2 = ERC20(address(token2)).balanceOf(distributor.treasuryOf(distributionId));

            // Claim token1
            vm.expectEmit(true, true, true, true, address(distributor));
            emit IUniversalRewardsDistributor.RewardsClaimed(
                distributionId, vm.addr(vars.index), address(token1), vars.claimableAdjusted1
            );
            distributor.claim(distributionId, vm.addr(vars.index), address(token1), vars.claimableInput, proof1);

            // Claim token2
            vm.expectEmit(true, true, true, true, address(distributor));
            emit IUniversalRewardsDistributor.RewardsClaimed(
                distributionId, vm.addr(vars.index), address(token2), vars.claimableAdjusted2
            );
            distributor.claim(distributionId, vm.addr(vars.index), address(token2), vars.claimableInput, proof2);

            uint256 balanceAfter1 = vars.balanceBefore1 + vars.claimableAdjusted1;
            uint256 balanceAfter2 = vars.balanceBefore2 + vars.claimableAdjusted2;

            assertEq(ERC20(address(token1)).balanceOf(vm.addr(vars.index)), balanceAfter1);
            assertEq(ERC20(address(token2)).balanceOf(vm.addr(vars.index)), balanceAfter2);
            // Assert claimed getter
            assertEq(distributor.claimed(distributionId, vm.addr(vars.index), address(token1)), balanceAfter1);
            assertEq(distributor.claimed(distributionId, vm.addr(vars.index), address(token2)), balanceAfter2);

            assertEq(
                ERC20(address(token1)).balanceOf(distributor.treasuryOf(distributionId)),
                vars.treasuryBalanceBefore1 - vars.claimableAdjusted1
            );
            assertEq(
                ERC20(address(token2)).balanceOf(distributor.treasuryOf(distributionId)),
                vars.treasuryBalanceBefore2 - vars.claimableAdjusted2
            );

            vars.i += 2;
        }
    }

    function _addrFromHashedString(string memory str) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(str)))));
    }

    function _getPendingRoot(uint256 distributionId)
        internal
        view
        returns (IUniversalRewardsDistributor.PendingRoot memory)
    {
        return IPendingRoot(address(distributor)).pendingRootOf(distributionId);
    }
}
