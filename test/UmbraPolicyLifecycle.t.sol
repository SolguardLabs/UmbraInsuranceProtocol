// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { PolicyState, PoolSnapshot } from "../src/types/UmbraTypes.sol";
import { UmbraTestBase } from "./UmbraTestBase.sol";

contract UmbraPolicyLifecycleTest is UmbraTestBase {
    function testPolicyPurchaseReservesCapitalAndMintsPolicyToken() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);

        uint256 premium =
            premiumEngine.quotePolicy(PRODUCT, 100 * UNIT, uint32(30 days)).grossPremium;
        uint256 policyId = _buyPolicy(ALICE, ALICE, VAULT_A, 100 * UNIT);

        PoolSnapshot memory snapshot = riskPool.poolSnapshot(poolId);
        assertEq(policyRegistry.ownerOfPolicy(policyId), ALICE);
        assertEq(snapshot.reservedCapital, 100 * UNIT);
        assertEq(snapshot.totalCapital, 1000 * UNIT + premium - asset.balanceOf(TREASURY));
        assertGt(asset.balanceOf(TREASURY), 0);
    }

    function testPolicyExpirationReleasesReserveAndBurnsToken() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);
        uint256 policyId = _buyPolicy(ALICE, ALICE, VAULT_A, 100 * UNIT);

        vm.warp(policyRegistry.policy(policyId).expiresAt + 1);
        policyRegistry.expirePolicy(policyId);

        assertEq(uint256(policyRegistry.policy(policyId).state), uint256(PolicyState.Expired));
        assertEq(riskPool.poolSnapshot(poolId).reservedCapital, 0);
        vm.expectRevert();
        policyRegistry.ownerOfPolicy(policyId);
    }

    function testUnderwriterCanWithdrawAvailableCapitalAfterDelay() public {
        uint256 shares = _depositCapital(UNDERWRITER, 500 * UNIT);
        assertEq(shares, 500 * UNIT);

        vm.prank(UNDERWRITER);
        uint256 ticketId = riskPool.requestWithdrawal(poolId, 100 * UNIT, UNDERWRITER);

        vm.warp(block.timestamp + 1 days);
        uint256 assets = riskPool.executeWithdrawal(ticketId);

        assertEq(assets, 100 * UNIT);
        assertEq(asset.balanceOf(UNDERWRITER), 100 * UNIT);
        assertEq(riskPool.shareBalanceOf(poolId, UNDERWRITER), 400 * UNIT);
    }
}

