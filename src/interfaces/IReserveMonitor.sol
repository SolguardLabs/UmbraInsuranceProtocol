// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IReserveMonitor {
    struct PoolHealth {
        uint256 poolId;
        uint256 totalCapital;
        uint256 reservedCapital;
        uint256 availableCapital;
        uint256 pendingWithdrawals;
        uint256 utilizationBps;
        uint256 solvencyBufferBps;
        bool acceptsPolicies;
        bool acceptsDeposits;
    }

    struct PolicyHealth {
        uint256 policyId;
        uint256 poolId;
        address holder;
        address beneficiary;
        address coveredVault;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 secondsRemaining;
        bool active;
    }

    struct ClaimQueueSummary {
        uint256 claimsRead;
        uint256 filedClaims;
        uint256 requestedAmount;
        uint256 estimatedPayout;
        uint256 policiesTouched;
    }

    function poolHealth(uint256 poolId) external view returns (PoolHealth memory);
    function policyHealth(uint256 policyId) external view returns (PolicyHealth memory);
    function summarizeClaims(uint256[] calldata claimIds)
        external
        view
        returns (ClaimQueueSummary memory);
    function poolNeedsCapital(uint256 poolId, uint256 targetBufferBps)
        external
        view
        returns (bool needsCapital, uint256 additionalCapital);
}

