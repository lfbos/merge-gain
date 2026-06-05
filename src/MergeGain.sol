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
    event WorkSubmitted(uint256 indexed bountyId, address indexed contributor, bytes32 proofHash);

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

    function submitWork(uint256 _bountyId, bytes32 _proofHash) external {
        require(_bountyId < bountyCount, "Bounty does not exist");

        Bounty storage bounty = bounties[_bountyId];
        require(bounty.status == BountyStatus.Open, "Bounty is not open");
        require(bounty.owner != msg.sender, "Owner cannot submit work");

        bounty.contributor = msg.sender;
        bounty.proofHash = _proofHash;
        bounty.status = BountyStatus.PendingReview;

        emit WorkSubmitted(_bountyId, msg.sender, _proofHash);
    }
}
