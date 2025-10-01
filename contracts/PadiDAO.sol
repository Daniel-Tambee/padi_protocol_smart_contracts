// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CustomDAO is ReentrancyGuard, Pausable, Ownable {
    ERC20Votes public immutable governanceToken;
    address    public immutable guardian;

    uint256 public immutable votingDelay;       // in blocks
    uint256 public immutable votingPeriod;      // in blocks
    uint256 public immutable proposalThreshold; // min votes to propose
    uint256 public immutable quorumVotes;       // min forVotes to succeed

    uint256 public immutable timelockDelay;     // seconds before execution
    uint256 public immutable gracePeriod;       // seconds after eta to expire
    uint256 public immutable maxActions;        // cap on proposal “targets”

    uint256 private _proposalCount;

    struct Receipt {
        bool    hasVoted;
        bool    support;
        uint256 votes;
    }

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 eta;          // timestamp when execution unlocked
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        string  description;
        uint256 forVotes;
        uint256 againstVotes;
        bool    canceled;
        bool    executed;
        mapping(address => Receipt) receipts;
    }

    mapping(uint256 => Proposal) private _proposals;

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votes);
    event ProposalQueued(uint256 indexed id, uint256 eta);
    event ProposalExecuted(uint256 indexed id);
    event ProposalCanceled(uint256 indexed id);

    constructor(
        ERC20Votes _token,
        address    _guardian,
        uint256    _votingDelay,
        uint256    _votingPeriod,
        uint256    _proposalThreshold,
        uint256    _quorumVotes,
        uint256    _timelockDelay,
        uint256    _gracePeriod,
        uint256    _maxActions
    )Ownable(msg.sender) {
        governanceToken   = _token;
        guardian          = _guardian;
        votingDelay       = _votingDelay;
        votingPeriod      = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumVotes       = _quorumVotes;
        timelockDelay     = _timelockDelay;
        gracePeriod       = _gracePeriod;
        maxActions        = _maxActions;
    }

    /*** OWNER CONTROLS ***/
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    /*** PROPOSAL WORKFLOW ***/
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[]   memory calldatas,
        string    memory description
    ) external returns (uint256) {
        require(
            governanceToken.getPastVotes(msg.sender, block.number - 1) >= proposalThreshold,
            "CustomDAO: proposer votes below threshold"
        );
        require(
            targets.length > 0 && 
            targets.length == values.length && 
            targets.length == calldatas.length,
            "CustomDAO: invalid proposal parameters"
        );
        require(
            targets.length <= maxActions,
            "CustomDAO: too many actions"
        );

        _proposalCount++;
        uint256 pid = _proposalCount;

        Proposal storage prop = _proposals[pid];
        prop.id          = pid;
        prop.proposer    = msg.sender;
        prop.targets     = targets;
        prop.values      = values;
        prop.calldatas   = calldatas;
        prop.startBlock  = block.number + votingDelay;
        prop.endBlock    = prop.startBlock + votingPeriod;
        prop.description = description;

        emit ProposalCreated(
            pid,
            msg.sender,
            targets,
            values,
            calldatas,
            prop.startBlock,
            prop.endBlock,
            description
        );

        return pid;
    }

    function castVote(uint256 proposalId, bool support) external nonReentrant {
        Proposal storage prop = _proposals[proposalId];
        require(state(proposalId) == ProposalState.Active, "CustomDAO: voting closed");

        Receipt storage rcpt = prop.receipts[msg.sender];
        require(!rcpt.hasVoted, "CustomDAO: already voted");

        uint256 votes = governanceToken.getPastVotes(msg.sender, prop.startBlock);
        require(votes > 0, "CustomDAO: no voting power");

        if (support) {
            prop.forVotes += votes;
        } else {
            prop.againstVotes += votes;
        }

        rcpt.hasVoted = true;
        rcpt.support  = support;
        rcpt.votes    = votes;

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    function queue(uint256 proposalId) external whenNotPaused {
        require(state(proposalId) == ProposalState.Succeeded, "CustomDAO: not succeeded");
        Proposal storage prop = _proposals[proposalId];
        prop.eta = block.timestamp + timelockDelay;
        emit ProposalQueued(proposalId, prop.eta);
    }

    function execute(uint256 proposalId) external payable nonReentrant whenNotPaused {
        require(state(proposalId) == ProposalState.Queued, "CustomDAO: not ready");
        Proposal storage prop = _proposals[proposalId];
        prop.executed = true;

        for (uint256 i = 0; i < prop.targets.length; i++) {
            (bool ok, ) = prop.targets[i].call{value: prop.values[i]}(prop.calldatas[i]);
            require(ok, "CustomDAO: action failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external whenNotPaused {
        Proposal storage prop = _proposals[proposalId];
        ProposalState ps = state(proposalId);

        require(
            msg.sender == guardian ||
            (msg.sender == prop.proposer && (ps == ProposalState.Pending || ps == ProposalState.Active)),
            "CustomDAO: not authorized"
        );

        prop.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /*** VIEWS ***/
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId > 0 && proposalId <= _proposalCount, "CustomDAO: invalid id");
        Proposal storage prop = _proposals[proposalId];

        if (prop.canceled) {
            return ProposalState.Canceled;
        }
        if (prop.executed) {
            return ProposalState.Executed;
        }
        if (block.number <= prop.startBlock) {
            return ProposalState.Pending;
        }
        if (block.number <= prop.endBlock) {
            return ProposalState.Active;
        }
        if (prop.forVotes < quorumVotes || prop.forVotes <= prop.againstVotes) {
            return ProposalState.Defeated;
        }
        if (prop.eta == 0) {
            return ProposalState.Succeeded;
        }
        if (block.timestamp < prop.eta) {
            return ProposalState.Queued;
        }
        if (block.timestamp >= prop.eta + gracePeriod) {
            return ProposalState.Expired;
        }
        return ProposalState.Queued;
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return _proposals[proposalId].receipts[voter];
    }

    function proposalCount() external view returns (uint256) {
        return _proposalCount;
    }
}
