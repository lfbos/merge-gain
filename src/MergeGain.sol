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
    // Bounty Events
    event BountyCreated(uint256 indexed bountyId, address indexed owner, uint256 amount, string description);
    event BountyApproved(uint256 indexed bountyId, address indexed contributor, uint256 amount);
    event BountyCancelled(uint256 indexed bountyId, address indexed owner);

    // Work Events
    event WorkSubmitted(uint256 indexed bountyId, address indexed contributor, bytes32 proofHash);
    event WorkRejected(uint256 indexed bountyId, address indexed contributor);

    // Modifiers
    modifier bountyExists(uint256 _bountyId) {
        require(_bountyId < bountyCount, "Bounty does not exist");
        _;
    }

    modifier onlyBountyOwner(uint256 _bountyId) {
        require(bounties[_bountyId].owner == msg.sender, "Only bounty owner can perform this action");
        _;
    }

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

    function submitWork(uint256 _bountyId, bytes32 _proofHash) external bountyExists(_bountyId) {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.status == BountyStatus.Open, "Bounty is not open");
        require(bounty.owner != msg.sender, "Owner cannot submit work");

        bounty.contributor = msg.sender;
        bounty.proofHash = _proofHash;
        bounty.status = BountyStatus.PendingReview;

        emit WorkSubmitted(_bountyId, msg.sender, _proofHash);
    }

    function approveWork(uint256 _bountyId) external bountyExists(_bountyId) onlyBountyOwner(_bountyId) {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.status == BountyStatus.PendingReview, "Bounty is not pending review");

        // 1. Update state
        bounty.status = BountyStatus.Completed;

        // 2. Transfer funds to contributor
        (bool success,) = bounty.contributor.call{value: bounty.amount}("");
        require(success, "Transfer failed");

        // 3. Emit event
        emit BountyApproved(_bountyId, bounty.contributor, bounty.amount);
    }

    function rejectWork(uint256 _bountyId) external bountyExists(_bountyId) onlyBountyOwner(_bountyId) {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.status == BountyStatus.PendingReview, "Bounty is not pending review");

        address rejectedContributor = bounty.contributor;

        // Reset contributor and proof hash
        bounty.contributor = address(0);
        bounty.proofHash = bytes32(0);
        bounty.status = BountyStatus.Open;

        // Emit event
        emit WorkRejected(_bountyId, rejectedContributor);
    }

    function cancelBounty(uint256 _bountyId) external bountyExists(_bountyId) onlyBountyOwner(_bountyId) {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.status == BountyStatus.Open, "Bounty cannot be cancelled");

        // 1. Update state
        uint256 refundAmount = bounty.amount;
        bounty.status = BountyStatus.Cancelled;
        bounty.amount = 0;

        // 2. Refund the owner
        (bool success,) = bounty.owner.call{value: refundAmount}("");
        require(success, "Refund failed");

        // 3. Emit event
        emit BountyCancelled(_bountyId, msg.sender);
    }
}
