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

        (address owner, uint256 bountyAmount, string memory bountyDescription, MergeGain.BountyStatus status, address contributor, bytes32 proofHash) = mergeGain.bounties(0);

        assertEq(owner, address(this));
        assertEq(bountyAmount, amount);
        assertEq(bountyDescription, description);
        assertEq(uint(status), uint(MergeGain.BountyStatus.Open));
        assertEq(contributor, address(0));
        assertEq(proofHash, bytes32(0));
        assertEq(mergeGain.bountyCount(), 1);
    }
}
