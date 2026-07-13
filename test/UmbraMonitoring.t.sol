// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ReserveMonitor } from "../src/core/ReserveMonitor.sol";
import { UmbraTestBase } from "./UmbraTestBase.sol";

contract UmbraMonitoringTest is UmbraTestBase {
    function testReserveMonitorReportsPoolHealth() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);
        uint256 policyId = _buyPolicy(ALICE, ALICE, VAULT_A, 100 * UNIT);

        ReserveMonitor.PoolHealth memory health = reserveMonitor.poolHealth(poolId);
        ReserveMonitor.PolicyHealth memory policyHealth = reserveMonitor.policyHealth(policyId);

        assertEq(health.poolId, poolId);
        assertEq(health.reservedCapital, 100 * UNIT);
        assertTrue(health.acceptsPolicies);
        assertEq(policyHealth.policyId, policyId);
        assertEq(policyHealth.coverageAmount, 100 * UNIT);
        assertTrue(policyHealth.active);
    }

    function testReserveMonitorSummarizesFiledClaims() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);
        uint256 policyId = _buyPolicy(ALICE, ALICE, VAULT_A, 100 * UNIT);
        uint256 incidentId = _openIncident(VAULT_A);
        uint256 claimId = _fileClaim(ALICE, policyId, incidentId, 60 * UNIT, ALICE);

        uint256[] memory ids = new uint256[](1);
        ids[0] = claimId;
        ReserveMonitor.ClaimQueueSummary memory summary = reserveMonitor.summarizeClaims(ids);

        assertEq(summary.claimsRead, 1);
        assertEq(summary.filedClaims, 1);
        assertEq(summary.requestedAmount, 60 * UNIT);
        assertEq(summary.policiesTouched, 1);
    }
}

