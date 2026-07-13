// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BatchSettlement, ClaimData } from "../types/UmbraTypes.sol";

interface IClaimProcessor {
    event ClaimFiled(
        uint256 indexed claimId,
        uint256 indexed policyId,
        uint256 indexed incidentId,
        address claimant,
        uint256 requestedAmount
    );
    event ClaimRejected(uint256 indexed claimId, uint256 indexed policyId, bytes32 reason);
    event ClaimPaid(
        uint256 indexed claimId, uint256 indexed policyId, address indexed receiver, uint256 amount
    );
    event ClaimBatchProcessed(
        uint256 indexed poolId, uint256 claimsRead, uint256 claimsApproved, uint256 totalPayout
    );

    function fileClaim(
        uint256 policyId,
        uint256 incidentId,
        uint256 lossAmount,
        uint256 requestedAmount,
        address receiver,
        bytes32 evidenceHash
    ) external returns (uint256 claimId);
    function processClaimBatch(uint256 poolId, uint256[] calldata claimIds)
        external
        returns (BatchSettlement memory);
    function claim(uint256 claimId) external view returns (ClaimData memory);
    function claimCount() external view returns (uint256);
}

