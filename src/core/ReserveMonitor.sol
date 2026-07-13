// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IClaimProcessor } from "../interfaces/IClaimProcessor.sol";
import { IPolicyRegistry } from "../interfaces/IPolicyRegistry.sol";
import { IRiskPool } from "../interfaces/IRiskPool.sol";
import { MathLib } from "../libraries/MathLib.sol";
import {
    ClaimData,
    ClaimStatus,
    PolicyData,
    PoolSnapshot,
    UmbraConstants
} from "../types/UmbraTypes.sol";

/// @title ReserveMonitor
/// @notice Read-only analytics for pool solvency, active exposure and filed claim pressure.
contract ReserveMonitor {
    IRiskPool public immutable riskPool;
    IPolicyRegistry public immutable policyRegistry;
    IClaimProcessor public immutable claimProcessor;

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

    constructor(address riskPool_, address policyRegistry_, address claimProcessor_) {
        riskPool = IRiskPool(riskPool_);
        policyRegistry = IPolicyRegistry(policyRegistry_);
        claimProcessor = IClaimProcessor(claimProcessor_);
    }

    function poolHealth(uint256 poolId) public view returns (PoolHealth memory health) {
        PoolSnapshot memory snapshot = riskPool.poolSnapshot(poolId);
        uint256 solvencyBufferBps;
        if (snapshot.reservedCapital == 0) {
            solvencyBufferBps = type(uint256).max;
        } else {
            solvencyBufferBps = MathLib.bps(snapshot.totalCapital, snapshot.reservedCapital);
        }
        health = PoolHealth({
            poolId: poolId,
            totalCapital: snapshot.totalCapital,
            reservedCapital: snapshot.reservedCapital,
            availableCapital: snapshot.availableCapital,
            pendingWithdrawals: snapshot.pendingWithdrawals,
            utilizationBps: snapshot.utilizationBps,
            solvencyBufferBps: solvencyBufferBps,
            acceptsPolicies: snapshot.acceptsPolicies,
            acceptsDeposits: snapshot.acceptsDeposits
        });
    }

    function policyHealth(uint256 policyId) public view returns (PolicyHealth memory health) {
        PolicyData memory data = policyRegistry.policy(policyId);
        uint256 remaining;
        if (block.timestamp < data.expiresAt) {
            remaining = uint256(data.expiresAt) - block.timestamp;
        }
        health = PolicyHealth({
            policyId: policyId,
            poolId: data.poolId,
            holder: data.holder,
            beneficiary: data.beneficiary,
            coveredVault: data.coveredVault,
            coverageAmount: data.coverageAmount,
            premiumPaid: data.premiumPaid,
            secondsRemaining: remaining,
            active: policyRegistry.isPolicyActive(policyId)
        });
    }

    function summarizeClaims(uint256[] calldata claimIds)
        external
        view
        returns (ClaimQueueSummary memory summary)
    {
        summary.claimsRead = claimIds.length;
        uint256[] memory touched = new uint256[](claimIds.length);
        uint256 touchedCount;

        for (uint256 i; i < claimIds.length; ++i) {
            ClaimData memory data = claimProcessor.claim(claimIds[i]);
            if (data.status != ClaimStatus.Filed) continue;

            ++summary.filedClaims;
            summary.requestedAmount += data.requestedAmount;
            PolicyData memory policyData = policyRegistry.policy(data.policyId);
            uint256 payout = MathLib.min(data.requestedAmount, policyData.coverageAmount);
            summary.estimatedPayout += payout;

            bool known;
            for (uint256 j; j < touchedCount; ++j) {
                if (touched[j] == data.policyId) {
                    known = true;
                    break;
                }
            }
            if (!known) {
                touched[touchedCount++] = data.policyId;
            }
        }
        summary.policiesTouched = touchedCount;
    }

    function poolNeedsCapital(uint256 poolId, uint256 targetBufferBps)
        external
        view
        returns (bool needsCapital, uint256 additionalCapital)
    {
        PoolSnapshot memory snapshot = riskPool.poolSnapshot(poolId);
        if (snapshot.reservedCapital == 0) return (false, 0);
        uint256 targetCapital =
            MathLib.mulDivUp(snapshot.reservedCapital, targetBufferBps, UmbraConstants.BPS);
        if (snapshot.totalCapital >= targetCapital) return (false, 0);
        return (true, targetCapital - snapshot.totalCapital);
    }
}

