// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IClaimReviewBoard {
    enum ReviewDecision {
        None,
        NeedsEvidence,
        RecommendApproval,
        RecommendRejection
    }

    event ReviewerUpdated(address indexed reviewer, bool enabled);
    event ReviewRecorded(
        uint256 indexed claimId,
        address indexed reviewer,
        ReviewDecision decision,
        uint16 confidenceBps,
        bytes32 notesHash
    );

    function setReviewer(address reviewer, bool enabled) external;
    function recordReview(
        uint256 claimId,
        ReviewDecision decision,
        uint16 confidenceBps,
        bytes32 notesHash
    ) external;
    function reviewCount(uint256 claimId) external view returns (uint256);
    function recommendation(uint256 claimId)
        external
        view
        returns (ReviewDecision decision, uint256 averageConfidenceBps);
}

