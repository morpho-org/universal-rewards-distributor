// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {UniversalRewardsDistributor} from "src/UniversalRewardsDistributor.sol";
import {IUniversalRewardsDistributor, Id} from "src/interfaces/IUniversalRewardsDistributor.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

import {Merkle} from "@murky/src/Merkle.sol";

import "@forge-std/Test.sol";

contract UniversalRouterDistributor is Test {
    uint256 internal constant MAX_RECEIVERS = 20;

    UniversalRewardsDistributor internal distributor;
    Merkle merkle = new Merkle();
    MockERC20 internal token1;
    MockERC20 internal token2;
    Id internal distributionWithoutTimeLock;
    Id internal distributionWithTimeLock;
    address owner = _addrFromHashedString("Owner");
    address updater = _addrFromHashedString("Updater");

    bytes32 DEFAULT_ROOT = bytes32(keccak256(bytes("DEFAULT_ROOT")));
    uint256 DEFAULT_TIMELOCK = 1 days;

    event RootUpdated(Id indexed distributionId, bytes32 newRoot);
    event RootSubmitted(Id indexed distributionId, bytes32 newRoot);
    event TreasuryUpdated(Id indexed distributionId, address newTreasury);
    event TreasurySuggested(Id indexed distributionId, address newTreasury);
    event Frozen(Id indexed distributionId, bool frozen);
    event TimelockUpdated(Id indexed distributionId, uint256 timelock);
    event DistributionCreated(Id indexed distributionId, address indexed owner, uint256 initialTimelock);
    event RootUpdaterUpdated(Id indexed distributionId, address indexed rootUpdater, bool active);
    event PendingRootRevoked(Id indexed distributionId);
    event RewardsClaimed(Id indexed distributionId, address indexed account, address indexed reward, uint256 amount);
    event DistributionOwnershipTransferred(
        Id indexed distributionId, address indexed previousOwner, address indexed newOwner
    );

    function _addrFromHashedString(string memory str) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(str)))));
    }

    function setUp() public {
        distributor = new UniversalRewardsDistributor();
        token1 = new MockERC20("Token1", "TKN1", 18);
        token2 = new MockERC20("Token2", "TKN2", 18);

        vm.prank(owner);
        distributionWithoutTimeLock = distributor.createDistribution(0, bytes32(0));
        vm.prank(owner);
        distributor.editRootUpdater(distributionWithoutTimeLock, updater, true);

        vm.warp(block.number + 12);
        vm.startPrank(owner);
        distributionWithTimeLock = distributor.createDistribution(1 days, bytes32(0));
        distributor.editRootUpdater(distributionWithTimeLock, updater, true);
        vm.stopPrank();
    }

    function testCreateDistributionSetupCorrectly(address randomCreator) public {
        Id distributionId = Id.wrap(keccak256(abi.encode(randomCreator, block.timestamp)));

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
        assertEq(distributor.treasuryOf(distributionId), address(0));
        assertEq(distributor.isFrozen(distributionId), false);
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
        distributor.confirmRootUpdate(distributionWithTimeLock);

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
        distributor.confirmRootUpdate(distributionWithTimeLock);
    }

    function testConfirmRootUpdateShouldRevertIfTimelockNotFinished(address randomCaller) public {

        vm.prank(updater);
        distributor.proposeRoot(distributionWithTimeLock, DEFAULT_ROOT);

        assert(distributor.rootOf(distributionWithTimeLock) != DEFAULT_ROOT);

        vm.warp(block.timestamp + 0.5 days);

        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: timelock not expired");
        distributor.confirmRootUpdate(distributionWithTimeLock);
    }

    function testConfirmRootUpdateShouldRevertIfNoPendingRoot(address randomCaller) public {
        vm.prank(randomCaller);
        vm.expectRevert("UniversalRewardsDistributor: no pending root");
        distributor.confirmRootUpdate(distributionWithTimeLock);
    }

    function testSuggestTreasuryShouldUpdatePendingTreasury(address newTreasury) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TreasurySuggested(distributionWithoutTimeLock, newTreasury);
        distributor.suggestTreasury(distributionWithoutTimeLock, newTreasury);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), newTreasury);
    }

    function testSuggestTreasuryShouldRevertIfNotOwner(address caller, address newTreasury) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.suggestTreasury(distributionWithoutTimeLock, newTreasury);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), address(0));
    }

    function testAcceptAsTreasuryShouldUpdateTreasury(address newTreasury) public {
        vm.prank(owner);
        distributor.suggestTreasury(distributionWithoutTimeLock, newTreasury);

        vm.prank(newTreasury);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.TreasuryUpdated(distributionWithoutTimeLock, newTreasury);
        distributor.acceptAsTreasury(distributionWithoutTimeLock);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), address(0));
        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), newTreasury);
    }

    function testAcceptAsTreasuryShouldRevertIfNotCalledByTreasury(address caller, address newTreasury) public {
        vm.assume(caller != newTreasury);

        vm.prank(owner);
        distributor.suggestTreasury(distributionWithoutTimeLock, newTreasury);

        vm.prank(caller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the pending treasury");
        distributor.acceptAsTreasury(distributionWithoutTimeLock);

        assertEq(distributor.treasuryOf(distributionWithoutTimeLock), newTreasury);
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
        distributor.confirmRootUpdate(distributionWithTimeLock);

        vm.warp(block.timestamp + 0.5 days);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdated(distributionWithTimeLock, DEFAULT_ROOT);
        distributor.confirmRootUpdate(distributionWithTimeLock);
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

    function testEditRootUpdaterShouldAddOrRemoveRootUpdater(address newUpdater, bool active) public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit IUniversalRewardsDistributor.RootUpdaterUpdated(distributionWithoutTimeLock, newUpdater, active);
        distributor.editRootUpdater(distributionWithoutTimeLock, newUpdater, active);

        assertEq(distributor.isUpdaterOf(distributionWithoutTimeLock, newUpdater), active);
    }

    function testEditRootUpdaterShouldRevertIfNotOwner(address caller, bool active) public {
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert("UniversalRewardsDistributor: caller is not the owner");
        distributor.editRootUpdater(distributionWithoutTimeLock, _addrFromHashedString("RANDOM_UPDATER"), active);
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

    //
    //    function testRewards(uint256 claimable, uint8 size) public {
    //        claimable = bound(claimable, 1 ether, type(uint256).max);
    //        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);
    //
    //        bytes32[] memory data = _setupRewards(claimable, boundedSize);
    //        _claimAndVerifyRewards(data, claimable);
    //    }
    //
    //    function testRewardsWithUpdate(uint256 claimable1, uint256 claimable2, uint8 size) public {
    //        claimable1 = bound(claimable1, 1 ether, type(uint128).max);
    //        claimable2 = bound(claimable2, claimable1 * 2, type(uint256).max);
    //        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);
    //
    //        bytes32[] memory data = _setupRewards(claimable1, boundedSize);
    //        _claimAndVerifyRewards(data, claimable1);
    //
    //        data = _setupRewards(claimable2, boundedSize);
    //        _claimAndVerifyRewards(data, claimable2);
    //    }
    //
    //    function testRewardsShouldRevertWhenAlreadyClaimed(uint256 claimable, uint8 size) public {
    //        claimable = bound(claimable, 1 ether, type(uint256).max);
    //        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);
    //
    //        bytes32[] memory data = _setupRewards(claimable, boundedSize);
    //
    //        bytes32[] memory proof = merkle.getProof(data, 0);
    //        deal(address(token1), address(distributor), claimable);
    //        distributor.claim(vm.addr(1), address(token1), claimable, proof);
    //
    //        vm.expectRevert(IUniversalRewardsDistributor.AlreadyClaimed.selector);
    //        distributor.claim(vm.addr(1), address(token1), claimable, proof);
    //    }
    //
    //    function testRewardsShouldRevertWhenInvalidProofAndCorrectInputs(
    //        bytes32[] memory proof,
    //        uint256 claimable,
    //        uint8 size
    //    ) public {
    //        claimable = bound(claimable, 1 ether, type(uint256).max);
    //        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);
    //
    //        _setupRewards(claimable, boundedSize);
    //
    //        deal(address(token1), address(distributor), claimable);
    //        vm.expectRevert(IUniversalRewardsDistributor.ProofInvalidOrExpired.selector);
    //        distributor.claim(vm.addr(1), address(token1), claimable, proof);
    //    }
    //
    //    function testRewardsShouldRevertWhenValidProofButIncorrectInputs(
    //        address account,
    //        address reward,
    //        uint256 amount,
    //        uint256 claimable,
    //        uint8 size
    //    ) public {
    //        claimable = bound(claimable, 1 ether, type(uint256).max);
    //        uint256 boundedSize = bound(size, 2, MAX_RECEIVERS);
    //
    //        bytes32[] memory data = _setupRewards(claimable, boundedSize);
    //
    //        bytes32[] memory proof = merkle.getProof(data, 0);
    //        deal(address(token1), address(distributor), claimable);
    //        vm.expectRevert(IUniversalRewardsDistributor.ProofInvalidOrExpired.selector);
    //        distributor.claim(account, reward, amount, proof);
    //    }
    //
    //    /// @dev In the implementation, claimed rewards are stored as a mapping.
    //    ///      The test function use vm.store to emulate assignations.
    //    ///      | Name    | Type                                            | Slot | Offset | Bytes |
    //    ///      |---------|-------------------------------------------------|------|--------|-------|
    //    ///      | _owner  | address                                         | 0    | 0      | 20    |
    //    ///      | root    | bytes32                                         | 1    | 0      | 32    |
    //    ///      | claimed | mapping(address => mapping(address => uint256)) | 2    | 0      | 32    |
    //    function testClaimedGetter(address token, address account, uint256 amount) public {
    //        vm.store(
    //            address(distributor),
    //            keccak256(abi.encode(address(token), keccak256(abi.encode(account, uint256(2))))),
    //            bytes32(amount)
    //        );
    //        assertEq(distributor.claimed(account, token), amount);
    //    }
    //
    //    function _setupRewards(uint256 claimable, uint256 size) internal returns (bytes32[] memory data) {
    //        data = new bytes32[](size);
    //
    //        uint256 i;
    //        while (i < size / 2) {
    //            uint256 index = i + 1;
    //            data[i] = keccak256(
    //                bytes.concat(keccak256(abi.encode(vm.addr(index), address(token1), uint256(claimable / index))))
    //            );
    //            data[i + 1] = keccak256(
    //                bytes.concat(keccak256(abi.encode(vm.addr(index), address(token2), uint256(claimable / index))))
    //            );
    //
    //            i += 2;
    //        }
    //
    //        bytes32 root = merkle.getRoot(data);
    //        distributor.updateRoot(root);
    //    }
    //
    //    function _claimAndVerifyRewards(bytes32[] memory data, uint256 claimable) internal {
    //        uint256 i;
    //        while (i < data.length / 2) {
    //            bytes32[] memory proof1 = merkle.getProof(data, i);
    //            bytes32[] memory proof2 = merkle.getProof(data, i + 1);
    //
    //            uint256 index = i + 1;
    //            uint256 claimableInput = claimable / index;
    //            uint256 claimableAdjusted1 = claimableInput - distributor.claimed(vm.addr(index), address(token1));
    //            uint256 claimableAdjusted2 = claimableInput - distributor.claimed(vm.addr(index), address(token2));
    //            deal(address(token1), address(distributor), claimableAdjusted1);
    //            deal(address(token2), address(distributor), claimableAdjusted2);
    //            uint256 balanceBefore1 = ERC20(address(token1)).balanceOf(vm.addr(index));
    //            uint256 balanceBefore2 = ERC20(address(token2)).balanceOf(vm.addr(index));
    //
    //            // Claim token1
    //            vm.expectEmit(true, true, true, true, address(distributor));
    //            emit RewardsClaimed(vm.addr(index), address(token1), claimableAdjusted1);
    //            distributor.claim(vm.addr(index), address(token1), claimableInput, proof1);
    //            // Claim token2
    //            vm.expectEmit(true, true, true, true, address(distributor));
    //            emit RewardsClaimed(vm.addr(index), address(token2), claimableAdjusted2);
    //            distributor.claim(vm.addr(index), address(token2), claimableInput, proof2);
    //
    //            uint256 balanceAfter1 = balanceBefore1 + claimableAdjusted1;
    //            uint256 balanceAfter2 = balanceBefore2 + claimableAdjusted2;
    //
    //            assertEq(ERC20(address(token1)).balanceOf(address(distributor)), 0);
    //            assertEq(ERC20(address(token1)).balanceOf(vm.addr(index)), balanceAfter1);
    //            assertEq(ERC20(address(token2)).balanceOf(address(distributor)), 0);
    //            assertEq(ERC20(address(token2)).balanceOf(vm.addr(index)), balanceAfter2);
    //            // Assert claimed getter
    //            assertEq(distributor.claimed(vm.addr(index), address(token1)), balanceAfter1);
    //            assertEq(distributor.claimed(vm.addr(index), address(token2)), balanceAfter2);
    //
    //            i += 2;
    //        }
    //    }
}
