// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MergeGain {
    enum BountyStatus {
        Open,
        PendingReview,
        Completed,
        Cancelled
    }

    struct Bounty {
        address owner;
        uint256 amount;
        string description;
        BountyStatus status;
        address contributor;
        bytes32 proofHash;
    }

    mapping(uint256 => Bounty) public bounties;
    uint256 public bountyCount;

    // Events
    event BountyCreated(uint256 indexed bountyId, address indexed owner, uint256 amount, string description);

    // Modifiers

    // Functions

    function createBounty(string memory _description) external payable {
        require(msg.value > 0, "Bounty amount must be greater than zero");
        bounties[bountyCount] = Bounty({
            owner: msg.sender,
            amount: msg.value,
            description: _description,
            status: BountyStatus.Open,
            contributor: address(0),
            proofHash: bytes32(0)
        });
        emit BountyCreated(bountyCount, msg.sender, msg.value, _description);
        bountyCount++;
    }
}
