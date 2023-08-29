// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";
import {IUniversalRewardsDistributor} from "src/interfaces/IUniversalRewardsDistributor.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

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
    uint256 DEFAULT_TIMELOCK = 1 days;

    event RootUpdated(uint256 indexed distributionId, bytes32 newRoot);
    event RootSubmitted(uint256 indexed distributionId, bytes32 newRoot);
    event TreasuryUpdated(uint256 indexed distributionId, address newTreasury);
    event TreasurySuggested(uint256 indexed distributionId, address newTreasury);
    event Frozen(uint256 indexed distributionId, bool frozen);
    event TimelockUpdated(uint256 indexed distributionId, uint256 timelock);
    event DistributionCreated(uint256 indexed distributionId, address indexed owner, uint256 initialTimelock);
    event RootUpdaterUpdated(uint256 indexed distributionId, address indexed rootUpdater, bool active);
    event PendingRootRevoked(uint256 indexed distributionId);
    event RewardsClaimed(uint256 indexed distributionId, address indexed account, address indexed reward, uint256 amount);
    event DistributionOwnershipTransferred(
        uint256 indexed distributionId, address indexed previousOwner, address indexed newOwner
    );

    function setUp() public {
        distributor = new UniversalRewardsDistributor();
        token1 = new MockERC20("Token1", "TKN1", 18);
        token2 = new MockERC20("Token2", "TKN2", 18);

        vm.prank(owner);
        distributionWithoutTimeLock = distributor.createDistribution(0, bytes32(0));
        vm.prank(owner);
        distributor.updateRootUpdater(distributionWithoutTimeLock, updater, true);

        vm.warp(block.number + 12);
        vm.startPrank(owner);
        distributionWithTimeLock = distributor.createDistribution(1 days, bytes32(0));
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
        emit IUniversalRewardsDistributor.DistributionCreated(distributionId, randomCreator, DEFAULT_TIMELOCK);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionId, DEFAULT_ROOT);
        distributor.createDistribution(DEFAULT_TIMELOCK, DEFAULT_ROOT);

        assertEq(distributor.rootOf(distributionId), DEFAULT_ROOT);
        assertEq(distributor.timelockOf(distributionId), DEFAULT_TIMELOCK);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot = distributor.getPendingRoot(distributionId);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
        assertEq(distributor.ownerOf(distributionId), randomCreator);
        assertEq(distributor.treasuryOf(distributionId), randomCreator);
        assertEq(distributor.pendingTreasuryOf(distributionId), address(0));
        assertEq(distributor.isFrozen(distributionId), false);
        assertEq(distributor.nextDistributionId(), distributionId + 1);
    }

    function testUpdateRootWithoutTimelockAsOwner() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithoutTimeLock, DEFAULT_ROOT);
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT);

        assertEq(distributor.rootOf(distributionWithoutTimeLock), DEFAULT_ROOT);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot =
            distributor.getPendingRoot(distributionWithoutTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testUpdateRootWithoutTimelockAsUpdater() public {
        vm.prank(updater);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithoutTimeLock, DEFAULT_ROOT);
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT);

        assertEq(distributor.rootOf(distributionWithoutTimeLock), DEFAULT_ROOT);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot =
            distributor.getPendingRoot(distributionWithoutTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testUpdateRootWithoutTimelockAsRandomCallerShouldRevert(address randomCaller) public {
        vm.assume(!distributor.isUpdaterOf(distributionWithoutTimeLock, randomCaller) && randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the updater");
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT);
    }

    function testUpdateRootWithTimelockAsOwner() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootSubmitted(distributionWithTimeLock, DEFAULT_ROOT);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot =
            distributor.getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, DEFAULT_ROOT);
        assertEq(pendingRoot.submittedAt, block.timestamp);
    }

    function testUpdateRootWithTimelockAsUpdater() public {
        vm.prank(updater);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootSubmitted(distributionWithTimeLock, DEFAULT_ROOT);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot =
            distributor.getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, DEFAULT_ROOT);
        assertEq(pendingRoot.submittedAt, block.timestamp);
    }

    function testProposeRoottWithTimelockAsRandomCallerShouldRevert(address randomCaller) public {
        vm.assume(!distributor.isUpdaterOf(distributionWithoutTimeLock, randomCaller) && randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the updater");
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT);
    }

    function testProposeRootShouldRevertIfFrozenAsOwner() public {
        vm.startPrank(owner);
        distributor.freeze(distributionWithoutTimeLock, true);

        vm.expectRevert("UniversalRewardsDistributor: frozen");
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT);

        vm.stopPrank();
    }

    function testProposeRootShouldRevertIfFrozenAsUpdater() public {
        vm.prank(owner);
        distributor.freeze(distributionWithoutTimeLock, true);

        vm.prank(updater);
        vm.expectRevert("UniversalRewardsDistributor: frozen");
        distributor.proposeRoot(distributionWithoutTimeLock, DEFAULT_ROOT);
    }

    function testConfirmRootUpdateShouldUpdateMainRoot(address randomCaller) public {
        vm.prank(updater);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);
        vm.warp(block.timestamp + 1 days);

        vm.prank(randomCaller);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithTimeLock, DEFAULT_ROOT);
        distributor.acceptRootUpdate(distributionWithTimeLock);

        assertEq(distributor.rootOf(distributionWithTimeLock), DEFAULT_ROOT);
        IUniversalRewardsDistributor.PendingRoot memory pendingRoot =
            distributor.getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testConfirmRootUpdateShouldRevertIfFrozen(address randomCaller) public {
        vm.prank(updater);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);

        vm.prank(owner);
        distributor.freeze(distributionWithTimeLock, true);
        vm.warp(block.timestamp + 1 days);

        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: frozen");
        distributor.acceptRootUpdate(distributionWithTimeLock);
    }

    function testConfirmRootUpdateShouldRevertIfTimelockNotFinished(address randomCaller) public {
        vm.prank(updater);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);

        vm.warp(block.timestamp + 0.5 days);

        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: timelock not expired");
        distributor.acceptRootUpdate(distributionWithTimeLock);
    }

    function testConfirmRootUpdateShouldRevertIfNoPendingRoot(address randomCaller) public {
        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: no pending root");
        distributor.acceptRootUpdate(distributionWithTimeLock);
    }

    function testSuggestTreasuryShouldUpdatePendingTreasury(address newTreasury) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TreasurySuggested(distributionWithoutTimeLock, newTreasury);
        distributor.suggestTreasury(distributionWithoutTimeLock, newTreasury);

        assertEq(distributor.pendingTreasuryOf(distributionWithoutTimeLock), newTreasury);
    }

    function testSuggestTreasuryShouldRevertIfNotOwner(address caller, address newTreasury) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.suggestTreasury(distributionWithoutTimeLock, newTreasury);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), owner);
        assertEq(distributor.pendingTreasuryOf(distributionWithoutTimeLock), address(0));
    }

    function testAcceptAsTreasuryShouldUpdateTreasury(address newTreasury) public {
        vm.prank(owner);
        distributor.suggestTreasury(distributionWithoutTimeLock, newTreasury);

        vm.prank(newTreasury);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TreasuryUpdated(distributionWithoutTimeLock, newTreasury);
        distributor.acceptAsTreasury(distributionWithoutTimeLock);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), newTreasury);
    }

    function testAcceptAsTreasuryShouldRevertIfNotCalledByTreasury(address caller, address newTreasury) public {
        vm.assume(caller != newTreasury);

        vm.prank(owner);
        distributor.suggestTreasury(distributionWithoutTimeLock, newTreasury);

        vm.prank(caller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the pending treasury");
        distributor.acceptAsTreasury(distributionWithoutTimeLock);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), owner);
    }

    function testFreezeShouldFreezeTheDistribution() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.Frozen(distributionWithoutTimeLock, true);
        distributor.freeze(distributionWithoutTimeLock, true);

        assertEq(distributor.isFrozen(distributionWithoutTimeLock), true);
    }

    function testFreezeShouldRevertIfNotOwner(address randomCaller, bool isFrozen) public {
        vm.assume(randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.freeze(distributionWithoutTimeLock, isFrozen);
    }

    function testForceUpdateRootShouldForceNewRootWhenFrozen(bytes32 newRoot) public {
        vm.startPrank(owner);
        distributor.freeze(distributionWithoutTimeLock, true);

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithoutTimeLock, newRoot);
        distributor.forceUpdateRoot(distributionWithoutTimeLock, newRoot);
        vm.stopPrank();

        assertEq(distributor.rootOf(distributionWithoutTimeLock), newRoot);
        assertEq(distributor.isFrozen(distributionWithoutTimeLock), true);
    }

    function testForceUpdateRootShouldRevertIfNotOwner(bytes32 newRoot, address randomCaller) public {
        vm.assume(newRoot != bytes32(0) && randomCaller != owner);

        vm.prank(owner);
        distributor.freeze(distributionWithoutTimeLock, true);

        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.forceUpdateRoot(distributionWithoutTimeLock, newRoot);
    }

    function testForceUpdateRootShouldRevertIfNotFrozen(bytes32 newRoot) public {
        vm.prank(owner);
        vm.expectRevert("UniversalRewardsDistributor: not frozen");
        distributor.forceUpdateRoot(distributionWithoutTimeLock, newRoot);
    }

    function testUpdateTimelockShouldChangeTheDistributionTimelock(uint256 newTimelock) public {
        vm.assume(newTimelock != 0);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TimelockUpdated(distributionWithoutTimeLock, newTimelock);
        distributor.updateTimelock(distributionWithoutTimeLock, newTimelock);

        assertEq(distributor.timelockOf(distributionWithoutTimeLock), newTimelock);
    }

    function testUpdateTimelockShouldIncreaseTheQueueTimestamp() public {
        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        vm.warp(block.timestamp + 0.5 days);

        vm.prank(owner);
        distributor.updateTimelock(distributionWithTimeLock, 1.5 days);

        assertEq(distributor.timelockOf(distributionWithTimeLock), 1.5 days);

        vm.warp(block.timestamp + 0.5 days);
        vm.expectRevert("UniversalRewardsDistributor: timelock not expired");
        distributor.acceptRootUpdate(distributionWithTimeLock);

        vm.warp(block.timestamp + 0.5 days);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithTimeLock, DEFAULT_ROOT);
        distributor.acceptRootUpdate(distributionWithTimeLock);
    }

    function testUpdateTimelockShouldRevertIfNotOwner(uint256 newTimelock, address randomCaller) public {
        vm.assume(newTimelock != 0 && randomCaller != owner);

        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.updateTimelock(distributionWithoutTimeLock, newTimelock);
    }

    function testUpdatetimelockShouldRevertIfNewTimelockIsTooLow(bytes32 pendingRoot) public {
        vm.assume(pendingRoot != bytes32(0));

        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, pendingRoot);

        vm.warp(block.timestamp + 0.5 days);

        vm.prank(owner);
        vm.expectRevert("UniversalRewardsDistributor: timelock not expired");
        distributor.updateTimelock(distributionWithTimeLock, 0.7 days);
    }

    function testUpdateTimelockShouldWorkIfPendingRootIsUpdatableButNotYetUpdated() public {
        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        vm.warp(block.timestamp + 1 days);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TimelockUpdated(distributionWithTimeLock, 0.7 days);
        distributor.updateTimelock(distributionWithTimeLock, 0.7 days);

        assertEq(distributor.timelockOf(distributionWithTimeLock), 0.7 days);
    }

    function testupdateRootUpdaterShouldAddOrRemoveRootUpdater(address newUpdater, bool active) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdaterUpdated(distributionWithoutTimeLock, newUpdater, active);
        distributor.updateRootUpdater(distributionWithoutTimeLock, newUpdater, active);

        assertEq(distributor.isUpdaterOf(distributionWithoutTimeLock, newUpdater), active);
    }

    function testupdateRootUpdaterShouldRevertIfNotOwner(address caller, bool active) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.updateRootUpdater(distributionWithoutTimeLock, _addrFromHashedString("RANDOM_UPDATER"), active);
    }

    function testRevokePendingRootShouldRevokeWhenCalledWithOwner() public {
        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.PendingRootRevoked(distributionWithTimeLock);
        distributor.revokePendingRoot(distributionWithTimeLock);

        IUniversalRewardsDistributor.PendingRoot memory pendingRoot =
            distributor.getPendingRoot(distributionWithTimeLock);
        assertEq(pendingRoot.root, bytes32(0));
        assertEq(pendingRoot.submittedAt, 0);
    }

    function testRevokePendingRootShouldRevertIfNotOwner(bytes32 proposedRoot, address caller) public {
        vm.assume(proposedRoot != bytes32(0) && caller != owner);

        vm.prank(owner);
        distributor.proposeRoot(distributionWithTimeLock, proposedRoot);

        vm.prank(caller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.revokePendingRoot(distributionWithTimeLock);
    }

    function testRevokePendingRootShouldRevertWhenNoPendingRoot() public {
        vm.prank(owner);
        vm.expectRevert("UniversalRewardsDistributor: no pending root");
        distributor.revokePendingRoot(distributionWithTimeLock);
    }

    function testTransferDistributionOwnershipShouldWorkCorrectly(address newOwner) public {
        vm.assume(newOwner != owner);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.DistributionOwnershipTransferred(distributionWithTimeLock, owner, newOwner);
        distributor.transferDistributionOwnership(distributionWithTimeLock, newOwner);

        assertEq(distributor.ownerOf(distributionWithTimeLock), newOwner);
    }

    function testTransferDistributionOwnershipShouldRevertIfNotOwner(address newOwner, address caller) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.transferDistributionOwnership(distributionWithTimeLock, newOwner);
    }

    function testClaimRewardsShouldFollowTheMerkleDistribution(uint256 claimable, uint8 size) public {
        claimable = bound(claimable, 1 ether, 1000 ether);
        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, boundedSize);

        vm.prank(owner);
        distributor.proposeRoot(distributionWithoutTimeLock, root);

        assertEq(distributor.rootOf(distributionWithoutTimeLock), root);

        _claimAndVerifyRewards(distributionWithoutTimeLock, data, claimable);
    }

    function testClaimRewardsShouldRevertIfClaimedTwice(uint256 claimable) public {
        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, 2);

        vm.prank(owner);
        distributor.proposeRoot(distributionWithoutTimeLock, root);

        assertEq(distributor.rootOf(distributionWithoutTimeLock), root);
        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RewardsClaimed(
            distributionWithoutTimeLock, vm.addr(1), address(token1), claimable
        );
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);

        vm.expectRevert("UniversalRewardsDistributor: already claimed");
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);
    }

    function testClaimRewardsShouldRevertIfFrozen(uint256 claimable) public {
        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, 2);

        vm.startPrank(owner);
        distributor.proposeRoot(distributionWithoutTimeLock, root);
        distributor.freeze(distributionWithoutTimeLock, true);
        vm.stopPrank();

        assertEq(distributor.rootOf(distributionWithoutTimeLock), root);
        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectRevert("UniversalRewardsDistributor: frozen");
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);
    }

    function testClaimRewardsShouldRevertIfNoRoot(uint256 claimable) public {
        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data,) = _setupRewards(claimable, 2);

        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectRevert("UniversalRewardsDistributor: root is not set");
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);
    }

    function testClaimRewardsShouldRevertIfInvalidRoot(uint256 claimable, bytes32 invalidRoot) public {
        vm.assume(invalidRoot != bytes32(0));

        claimable = bound(claimable, 1 ether, 1000 ether);

        (bytes32[] memory data, bytes32 root) = _setupRewards(claimable, 2);

        vm.assume(root != invalidRoot);
        vm.prank(owner);
        distributor.proposeRoot(distributionWithoutTimeLock, invalidRoot);

        bytes32[] memory proof1 = merkle.getProof(data, 0);

        vm.expectRevert("UniversalRewardsDistributor: invalid proof or expired");
        distributor.claim(distributionWithoutTimeLock, vm.addr(1), address(token1), claimable, proof1);
    }

    function _setupRewards(uint256 claimable, uint256 size) internal view returns (bytes32[] memory data, bytes32 root) {
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

    function _claimAndVerifyRewards(uint256 distributionId, bytes32[] memory data, uint256 claimable) internal {
        uint256 i;
        while (i < data.length / 2) {
            bytes32[] memory proof1 = merkle.getProof(data, i);
            bytes32[] memory proof2 = merkle.getProof(data, i + 1);

            uint256 index = i + 1;
            uint256 claimableInput = claimable / index;
            uint256 claimableAdjusted1 =
                claimableInput - distributor.claimed(distributionId, vm.addr(index), address(token1));
            uint256 claimableAdjusted2 =
                claimableInput - distributor.claimed(distributionId, vm.addr(index), address(token2));
            uint256 balanceBefore1 = ERC20(address(token1)).balanceOf(vm.addr(index));
            uint256 balanceBefore2 = ERC20(address(token2)).balanceOf(vm.addr(index));
            uint256 treasuryBalanceBefore1 = ERC20(address(token1)).balanceOf(distributor.treasuryOf(distributionId));
            uint256 treasuryBalanceBefore2 = ERC20(address(token2)).balanceOf(distributor.treasuryOf(distributionId));

            console.log(claimableInput);
            // Claim token1
            vm.expectEmit(true, true, true, true, address(distributor));
            emit IUniversalRewardsDistributor.RewardsClaimed(
                distributionId, vm.addr(index), address(token1), claimableAdjusted1
            );
            distributor.claim(distributionId, vm.addr(index), address(token1), claimableInput, proof1);
            console.log(distributor.claimed(distributionId, vm.addr(index), address(token1)));
            // Claim token2
            vm.expectEmit(true, true, true, true, address(distributor));
            emit IUniversalRewardsDistributor.RewardsClaimed(
                distributionId, vm.addr(index), address(token2), claimableAdjusted2
            );
            distributor.claim(distributionId, vm.addr(index), address(token2), claimableInput, proof2);

            uint256 balanceAfter1 = balanceBefore1 + claimableAdjusted1;
            uint256 balanceAfter2 = balanceBefore2 + claimableAdjusted2;

            assertEq(ERC20(address(token1)).balanceOf(vm.addr(index)), balanceAfter1);
            assertEq(ERC20(address(token2)).balanceOf(vm.addr(index)), balanceAfter2);
            // Assert claimed getter
            assertEq(distributor.claimed(distributionId, vm.addr(index), address(token1)), balanceAfter1);
            assertEq(distributor.claimed(distributionId, vm.addr(index), address(token2)), balanceAfter2);

            assertEq(
                ERC20(address(token1)).balanceOf(distributor.treasuryOf(distributionId)),
                treasuryBalanceBefore1 - claimableAdjusted1
            );
            assertEq(
                ERC20(address(token2)).balanceOf(distributor.treasuryOf(distributionId)),
                treasuryBalanceBefore2 - claimableAdjusted2
            );

            i += 2;
        }
    }

    function _addrFromHashedString(string memory str) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(str)))));
    }
}
