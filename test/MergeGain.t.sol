// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MergeGain} from "../src/MergeGain.sol";

contract MergeGainTest is Test {
    MergeGain public mergeGain;

    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    address constant CAROL = address(0xCA801);

    function setUp() public {
        mergeGain = new MergeGain();
    }

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
}
