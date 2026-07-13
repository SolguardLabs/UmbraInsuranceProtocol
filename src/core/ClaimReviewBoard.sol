// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IClaimReviewBoard } from "../interfaces/IClaimReviewBoard.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import { UmbraConstants } from "../types/UmbraTypes.sol";

/// @title ClaimReviewBoard
/// @notice Optional reviewer coordination layer for off-chain evidence workflows.
contract ClaimReviewBoard is IClaimReviewBoard, ProtocolAccess {
    error InvalidReviewer();
    error InvalidClaim();
    error InvalidDecision();
    error ReviewerDisabled();

    struct Review {
        address reviewer;
        ReviewDecision decision;
        uint16 confidenceBps;
        uint64 reviewedAt;
        bytes32 notesHash;
    }

    mapping(address => bool) public isReviewer;
    mapping(uint256 => Review[]) internal _reviews;
    mapping(uint256 => mapping(address => uint256)) internal _reviewIndexPlusOne;

    constructor(address governor_, address guardian_) ProtocolAccess(governor_, guardian_) { }

    function setReviewer(address reviewer, bool enabled) external override onlyGovernorOrKeeper {
        if (reviewer == address(0)) revert InvalidReviewer();
        isReviewer[reviewer] = enabled;
        emit ReviewerUpdated(reviewer, enabled);
    }

    function recordReview(
        uint256 claimId,
        ReviewDecision decision,
        uint16 confidenceBps,
        bytes32 notesHash
    ) external override {
        if (!isReviewer[msg.sender]) revert ReviewerDisabled();
        if (claimId == 0) revert InvalidClaim();
        if (decision == ReviewDecision.None) revert InvalidDecision();
        if (confidenceBps == 0 || confidenceBps > UmbraConstants.BPS) revert InvalidDecision();
        if (notesHash == bytes32(0)) revert InvalidDecision();

        uint256 indexPlusOne = _reviewIndexPlusOne[claimId][msg.sender];
        if (indexPlusOne == 0) {
            _reviews[claimId].push(
                Review({
                    reviewer: msg.sender,
                    decision: decision,
                    confidenceBps: confidenceBps,
                    reviewedAt: MathLib.toUint64(block.timestamp),
                    notesHash: notesHash
                })
            );
            _reviewIndexPlusOne[claimId][msg.sender] = _reviews[claimId].length;
        } else {
            Review storage existing = _reviews[claimId][indexPlusOne - 1];
            existing.decision = decision;
            existing.confidenceBps = confidenceBps;
            existing.reviewedAt = MathLib.toUint64(block.timestamp);
            existing.notesHash = notesHash;
        }

        emit ReviewRecorded(claimId, msg.sender, decision, confidenceBps, notesHash);
    }

    function reviewCount(uint256 claimId) external view override returns (uint256) {
        return _reviews[claimId].length;
    }

    function reviewAt(uint256 claimId, uint256 index) external view returns (Review memory) {
        return _reviews[claimId][index];
    }

    function recommendation(uint256 claimId)
        external
        view
        override
        returns (ReviewDecision decision, uint256 averageConfidenceBps)
    {
        Review[] storage reviews = _reviews[claimId];
        if (reviews.length == 0) return (ReviewDecision.None, 0);

        uint256 approvalWeight;
        uint256 rejectionWeight;
        uint256 evidenceWeight;
        uint256 confidenceTotal;
        for (uint256 i; i < reviews.length; ++i) {
            Review storage item = reviews[i];
            confidenceTotal += item.confidenceBps;
            if (item.decision == ReviewDecision.RecommendApproval) {
                approvalWeight += item.confidenceBps;
            } else if (item.decision == ReviewDecision.RecommendRejection) {
                rejectionWeight += item.confidenceBps;
            } else if (item.decision == ReviewDecision.NeedsEvidence) {
                evidenceWeight += item.confidenceBps;
            }
        }

        averageConfidenceBps = confidenceTotal / reviews.length;
        if (approvalWeight >= rejectionWeight && approvalWeight >= evidenceWeight) {
            decision = ReviewDecision.RecommendApproval;
        } else if (rejectionWeight >= evidenceWeight) {
            decision = ReviewDecision.RecommendRejection;
        } else {
            decision = ReviewDecision.NeedsEvidence;
        }
    }
}

