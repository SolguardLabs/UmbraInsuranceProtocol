// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {
    BatchSettlement,
    ClaimStatus,
    PolicyState,
    PoolSnapshot
} from "../src/types/UmbraTypes.sol";
import { UmbraTestBase } from "./UmbraTestBase.sol";

contract UmbraClaimsTest is UmbraTestBase {
    function testIncidentCanBeOpenedForCoveredVault() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);
        _buyPolicy(ALICE, ALICE, VAULT_A, 100 * UNIT);

        uint256 incidentId = _openIncident(VAULT_A);

        assertEq(incidentRegistry.incident(incidentId).coveredVault, VAULT_A);
        assertEq(incidentRegistry.incident(incidentId).severityBps, 8000);
    }

    function testSingleClaimPaysBeneficiaryAndClosesPolicy() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);
        uint256 policyId = _buyPolicy(ALICE, CAROL, VAULT_A, 100 * UNIT);
        uint256 incidentId = _openIncident(VAULT_A);
        uint256 claimId = _fileClaim(ALICE, policyId, incidentId, 100 * UNIT, CAROL);

        uint256[] memory ids = new uint256[](1);
        ids[0] = claimId;
        vm.prank(KEEPER);
        BatchSettlement memory settlement = claimProcessor.processClaimBatch(poolId, ids);

        assertEq(settlement.claimsApproved, 1);
        assertEq(settlement.totalPayout, 90 * UNIT);
        assertEq(asset.balanceOf(CAROL), 90 * UNIT);
        assertEq(uint256(policyRegistry.policy(policyId).state), uint256(PolicyState.Claimed));
        assertEq(uint256(claimProcessor.claim(claimId).status), uint256(ClaimStatus.Paid));
    }

    function testBatchClaimsAcrossIndependentPolicies() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);
        uint256 firstPolicy = _buyPolicy(ALICE, ALICE, VAULT_A, 100 * UNIT);
        uint256 secondPolicy = _buyPolicy(BOB, BOB, VAULT_A, 200 * UNIT);
        uint256 incidentId = _openIncident(VAULT_A);

        uint256[] memory ids = new uint256[](2);
        ids[0] = _fileClaim(ALICE, firstPolicy, incidentId, 100 * UNIT, ALICE);
        ids[1] = _fileClaim(BOB, secondPolicy, incidentId, 200 * UNIT, BOB);

        vm.prank(KEEPER);
        BatchSettlement memory settlement = claimProcessor.processClaimBatch(poolId, ids);

        assertEq(settlement.claimsRead, 2);
        assertEq(settlement.claimsApproved, 2);
        assertEq(settlement.totalPayout, 270 * UNIT);
        assertEq(asset.balanceOf(ALICE), 90 * UNIT);
        assertEq(asset.balanceOf(BOB), 180 * UNIT);

        PoolSnapshot memory snapshot = riskPool.poolSnapshot(poolId);
        assertEq(snapshot.reservedCapital, 0);
        assertGt(snapshot.availableCapital, 0);
    }

    function testClaimForDifferentVaultIsRejectedDuringFiling() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);
        uint256 policyId = _buyPolicy(ALICE, ALICE, VAULT_A, 100 * UNIT);
        uint256 incidentId = _openIncident(VAULT_B);

        vm.prank(ALICE);
        vm.expectRevert();
        claimProcessor.fileClaim(
            policyId, incidentId, 100 * UNIT, 100 * UNIT, ALICE, keccak256("claim-evidence")
        );
    }
}

