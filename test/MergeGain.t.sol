// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MergeGain} from "../src/MergeGain.sol";

// Contract that rejects all incoming ETH transfers.
// Used to force the .call() in approveWork/cancelBounty to fail.
contract RejectingReceiver {
    function createBountyOn(MergeGain target, string memory desc) external payable {
        target.createBounty{value: msg.value}(desc);
    }

    function submitWorkOn(MergeGain target, uint256 id, bytes32 proofHash) external {
        target.submitWork(id, proofHash);
    }

    function cancelBountyOn(MergeGain target, uint256 id) external {
        target.cancelBounty(id);
    }
    // No receive() or fallback() → any incoming ETH reverts
}

contract MergeGainTest is Test {
    MergeGain public mergeGain;

    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    address constant CAROL = address(0xCA801);

    function setUp() public {
        mergeGain = new MergeGain();
    }

    // Allow this contract to receive ETH refunds (e.g. from cancelBounty)
    receive() external payable {}

    // helpers

    function _createBounty(uint256 amount, string memory desc) internal returns (uint256 id) {
        id = mergeGain.bountyCount();
        mergeGain.createBounty{value: amount}(desc);
    }

    // createBounty

    function testCreateBounty() public {
        string memory description = "Fix bug in smart contract";
        uint256 amount = 1 ether;

        vm.expectEmit(true, true, false, true, address(mergeGain));
        emit MergeGain.BountyCreated(0, address(this), amount, description);

        _createBounty(amount, description);

        (
            address owner,
            uint256 bountyAmount,
            string memory bountyDescription,
            MergeGain.BountyStatus status,
            address contributor,
            bytes32 proofHash
        ) = mergeGain.bounties(0);

        assertEq(owner, address(this));
        assertEq(bountyAmount, amount);
        assertEq(bountyDescription, description);
        assertEq(uint256(status), uint256(MergeGain.BountyStatus.Open));
        assertEq(contributor, address(0));
        assertEq(proofHash, bytes32(0));
        assertEq(mergeGain.bountyCount(), 1);
    }

    function testCreateBountyWithZeroAmount() public {
        vm.expectRevert("Bounty amount must be greater than zero");
        mergeGain.createBounty{value: 0}("This should fail");
    }

    function testCreateBountyIncreasesContractBalance() public {
        uint256 amount = 2 ether;
        _createBounty(amount, "Increase balance");

        assertEq(address(mergeGain).balance, amount);
    }

    function testMultipleBountiesIncrementIds() public {
        uint256 id0 = _createBounty(1 ether, "First");
        uint256 id1 = _createBounty(0.5 ether, "Second");
        uint256 id2 = _createBounty(0.25 ether, "Third");

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(mergeGain.bountyCount(), 3);
        assertEq(address(mergeGain).balance, 1.75 ether);
    }

    // submitWork

    function testSubmitWork() public {
        string memory description = "Implement feature X";
        uint256 amount = 1 ether;
        _createBounty(amount, description);

        bytes32 proofHash = keccak256("Proof of work");

        vm.startPrank(ALICE);
        vm.expectEmit(true, true, false, true, address(mergeGain));
        emit MergeGain.WorkSubmitted(0, ALICE, proofHash);

        mergeGain.submitWork(0, proofHash);
        vm.stopPrank();

        (
            address owner,
            uint256 bountyAmount,
            string memory bountyDescription,
            MergeGain.BountyStatus status,
            address actualContributor,
            bytes32 actualProofHash
        ) = mergeGain.bounties(0);

        assertEq(owner, address(this));
        assertEq(bountyAmount, amount);
        assertEq(bountyDescription, description);
        assertEq(uint256(status), uint256(MergeGain.BountyStatus.PendingReview));
        assertEq(actualContributor, ALICE);
        assertEq(actualProofHash, proofHash);
    }

    function testSubmitWorkToNonExistentBounty() public {
        vm.expectRevert("Bounty does not exist");
        mergeGain.submitWork(999, keccak256("Proof of work"));
    }

    function testSubmitWorkToClosedBounty() public {
        _createBounty(1 ether, "Test bounty");

        // ALICE submits — bounty transitions to PendingReview (no longer Open)
        vm.prank(ALICE);
        mergeGain.submitWork(0, keccak256("First proof"));

        // BOB tries to submit work on a bounty that is no longer Open
        vm.prank(BOB);
        vm.expectRevert("Bounty is not open");
        mergeGain.submitWork(0, keccak256("New proof of work"));
    }

    function testOwnerCannotSubmitWork() public {
        _createBounty(1 ether, "Test bounty");

        // address(this) is the owner (created the bounty without prank);
        // without prank, msg.sender in submitWork is also address(this) → revert.
        vm.expectRevert("Owner cannot submit work");
        mergeGain.submitWork(0, keccak256("Owner's proof"));
    }

    function testApproveWork() public {
        _createBounty(1 ether, "Test bounty");

        // ALICE submits work
        vm.prank(ALICE);
        mergeGain.submitWork(0, keccak256("Proof of work"));

        // Owner (address(this)) approves ALICE's submission
        vm.expectEmit(true, true, false, true, address(mergeGain));
        emit MergeGain.BountyApproved(0, ALICE, 1 ether);

        mergeGain.approveWork(0);

        (
            ,
            ,
            ,
            MergeGain.BountyStatus status,
            address contributor,
            bytes32 proofHash
        ) = mergeGain.bounties(0);

        assertEq(uint256(status), uint256(MergeGain.BountyStatus.Completed));
        assertEq(contributor, ALICE);
        assertEq(proofHash, keccak256("Proof of work"));
    }

    function testApproveWorkByNonOwner() public {
        _createBounty(1 ether, "Test bounty");

        // ALICE submits work
        vm.prank(ALICE);
        mergeGain.submitWork(0, keccak256("Proof of work"));

        // BOB tries to approve ALICE's submission — should revert
        vm.prank(BOB);
        vm.expectRevert("Only bounty owner can perform this action");
        mergeGain.approveWork(0);
    }

    function testApproveWorkThatIsNotPending() public {
        _createBounty(1 ether, "Test bounty");

        // Owner tries to approve work before any submission — should revert
        vm.expectRevert("Bounty is not pending review");
        mergeGain.approveWork(0);
    }

    function testRejectWork() public {
        _createBounty(1 ether, "Test bounty");

        // ALICE submits work
        vm.prank(ALICE);
        mergeGain.submitWork(0, keccak256("Proof of work"));

        // Owner (address(this)) rejects ALICE's submission
        vm.expectEmit(true, true, false, true, address(mergeGain));
        emit MergeGain.WorkRejected(0, ALICE);

        mergeGain.rejectWork(0);
        (
            ,
            ,
            ,
            MergeGain.BountyStatus status,
            address contributor,
            bytes32 proofHash
        ) = mergeGain.bounties(0);

        assertEq(uint256(status), uint256(MergeGain.BountyStatus.Open));
        assertEq(contributor, address(0));
        assertEq(proofHash, bytes32(0));
    }

    function testRejectWorkThatIsNotPending() public {
        _createBounty(1 ether, "Test bounty");

        // Owner tries to reject work before any submission — should revert
        vm.expectRevert("Bounty is not pending review");
        mergeGain.rejectWork(0);
    }

    function testCancelBounty() public {
        _createBounty(1 ether, "Test bounty");

        uint256 ownerBalanceBefore = address(this).balance;

        // Owner cancels the bounty
        vm.expectEmit(true, true, false, true, address(mergeGain));
        emit MergeGain.BountyCancelled(0, address(this));

        mergeGain.cancelBounty(0);

        (
            address owner,
            uint256 bountyAmount,
            string memory bountyDescription,
            MergeGain.BountyStatus status,
            address contributor,
            bytes32 proofHash
        ) = mergeGain.bounties(0);

        assertEq(owner, address(this));
        assertEq(bountyAmount, 0); // Amount zeroed after refund
        assertEq(bountyDescription, "Test bounty");
        assertEq(uint256(status), uint256(MergeGain.BountyStatus.Cancelled));
        assertEq(contributor, address(0));
        assertEq(proofHash, bytes32(0));

        // Verify ETH was actually refunded
        assertEq(address(this).balance, ownerBalanceBefore + 1 ether);
        assertEq(address(mergeGain).balance, 0);
    }

    // Modifier branch coverage: bountyExists + onlyBountyOwner

    function testApproveWorkOnNonExistentBounty() public {
        vm.expectRevert("Bounty does not exist");
        mergeGain.approveWork(999);
    }

    function testRejectWorkOnNonExistentBounty() public {
        vm.expectRevert("Bounty does not exist");
        mergeGain.rejectWork(999);
    }

    function testCancelBountyOnNonExistentBounty() public {
        vm.expectRevert("Bounty does not exist");
        mergeGain.cancelBounty(999);
    }

    function testRejectWorkByNonOwner() public {
        _createBounty(1 ether, "Test bounty");

        vm.prank(ALICE);
        mergeGain.submitWork(0, keccak256("Proof of work"));

        // BOB (not the owner) tries to reject — should revert
        vm.prank(BOB);
        vm.expectRevert("Only bounty owner can perform this action");
        mergeGain.rejectWork(0);
    }

    function testCancelBountyByNonOwner() public {
        _createBounty(1 ether, "Test bounty");

        // BOB (not the owner) tries to cancel — should revert
        vm.prank(BOB);
        vm.expectRevert("Only bounty owner can perform this action");
        mergeGain.cancelBounty(0);
    }

    function testCancelBountyThatIsNotOpen() public {
        _createBounty(1 ether, "Test bounty");

        // ALICE submits — bounty status becomes PendingReview (no longer Open)
        vm.prank(ALICE);
        mergeGain.submitWork(0, keccak256("Proof of work"));

        // Owner tries to cancel — should revert because bounty is not Open
        vm.expectRevert("Bounty cannot be cancelled");
        mergeGain.cancelBounty(0);
    }

    // Failed ETH transfer branches (using RejectingReceiver)

    function testCancelBountyRevertsIfRefundFails() public {
        RejectingReceiver rejector = new RejectingReceiver();
        vm.deal(address(rejector), 1 ether);

        // rejector creates the bounty, so it is also the owner
        rejector.createBountyOn{value: 1 ether}(mergeGain, "Test");

        // rejector tries to cancel; the refund call will hit its missing receive() → revert
        vm.expectRevert("Refund failed");
        rejector.cancelBountyOn(mergeGain, 0);
    }

    function testApproveWorkRevertsIfTransferFails() public {
        RejectingReceiver rejector = new RejectingReceiver();
        _createBounty(1 ether, "Test bounty");

        // rejector submits work as the contributor
        rejector.submitWorkOn(mergeGain, 0, keccak256("Proof of work"));

        // Owner approves; transfer to rejector fails because it has no receive()
        vm.expectRevert("Transfer failed");
        mergeGain.approveWork(0);
    }
}
