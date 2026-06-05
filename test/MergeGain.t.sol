// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MergeGain} from "../src/MergeGain.sol";

contract MergeGainTest is Test {
    MergeGain public mergeGain;

    function setUp() public {
        mergeGain = new MergeGain();
    }

    function testCreateBounty() public {
        string memory description = "Fix bug in smart contract";
        uint256 amount = 1 ether;

        vm.expectEmit(true, true, false, true, address(mergeGain));
        emit MergeGain.BountyCreated(0, address(this), amount, description);

        mergeGain.createBounty{value: amount}(description);

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
        string memory description = "This should fail";

        vm.expectRevert("Bounty amount must be greater than zero");
        mergeGain.createBounty{value: 0}(description);
    }

    function testSubmitWork() public {
        // Create a bounty first
        string memory description = "Implement feature X";
        uint256 amount = 1 ether;
        mergeGain.createBounty{value: amount}(description);

        // Simulate a contributor submitting work
        address contributor = address(0x123);
        bytes32 proofHash = keccak256("Proof of work");

        vm.startPrank(contributor);
        vm.expectEmit(true, true, false, true, address(mergeGain));
        emit MergeGain.WorkSubmitted(0, contributor, proofHash);

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
        assertEq(actualContributor, contributor);
        assertEq(actualProofHash, proofHash);
    }

    function testSubmitWorkToNonExistentBounty() public {
        bytes32 proofHash = keccak256("Proof of work");

        vm.expectRevert("Bounty does not exist");
        mergeGain.submitWork(999, proofHash);
    }

    function testSubmitWorkToClosedBounty() public {
        string memory description = "Test bounty";
        uint256 amount = 1 ether;
        mergeGain.createBounty{value: amount}(description);

        // First contributor submits — bounty status pasa a PendingReview (ya no Open)
        address firstContributor = address(0xBEEF);
        vm.prank(firstContributor);
        mergeGain.submitWork(0, keccak256("First proof"));

        // Second contributor intenta enviar trabajo sobre una bounty que ya no está Open
        address secondContributor = address(0xCAFE);
        vm.prank(secondContributor);
        vm.expectRevert("Bounty is not open");
        mergeGain.submitWork(0, keccak256("New proof of work"));
    }

    function testOwnerCannotSubmitWork() public {
        string memory description = "Test bounty";
        uint256 amount = 1 ether;
        mergeGain.createBounty{value: amount}(description);

        bytes32 proofHash = keccak256("Owner's proof");

        vm.expectRevert("Owner cannot submit work");
        mergeGain.submitWork(0, proofHash);
    }
}
