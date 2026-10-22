// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ProductRiskLens } from "../src/core/ProductRiskLens.sol";
import { UmbraTestBase } from "./UmbraTestBase.sol";

contract UmbraProductRiskLensTest is UmbraTestBase {
    function testProjectsQuoteIntoReserveAndCapital() public {
        _depositCapital(UNDERWRITER, 1000 * UNIT);
        ProductRiskLens lens = new ProductRiskLens(address(premiumEngine), address(riskPool));
        ProductRiskLens.ProjectedQuote memory projected = lens.project(PRODUCT, 100 * UNIT, 30 days);

        assertEq(projected.quote.coverageAmount, 100 * UNIT);
        assertEq(projected.capitalBefore, 1000 * UNIT);
        assertEq(projected.reservedBefore, 0);
        assertEq(projected.pendingWithdrawals, 0);
        assertEq(projected.capitalAfterPremium, 1000 * UNIT + projected.quote.reservePremium);
        assertEq(projected.reservedAfterPurchase, 100 * UNIT);
        assertEq(
            projected.availableAfterPurchase,
            projected.capitalAfterPremium - projected.reservedAfterPurchase
        );
        assertGt(projected.utilizationAfterPurchaseBps, 0);
    }

    function testRejectsInvalidModulesAndInvalidCoverage() public {
        vm.expectRevert(ProductRiskLens.InvalidModule.selector);
        new ProductRiskLens(address(0), address(riskPool));

        ProductRiskLens lens = new ProductRiskLens(address(premiumEngine), address(riskPool));
        vm.expectRevert();
        lens.project(PRODUCT, 1 * UNIT, 30 days);
    }
}
