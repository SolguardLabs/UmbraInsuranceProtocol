// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { MathLib } from "./MathLib.sol";
import { UmbraConstants } from "../types/UmbraTypes.sol";

library ClaimMath {
    using MathLib for uint256;

    function severityAdjustedLoss(
        uint256 reportedLoss,
        uint256 policyCoverage,
        uint256 incidentSeverityBps
    ) internal pure returns (uint256) {
        uint256 boundedLoss = MathLib.min(reportedLoss, policyCoverage);
        return MathLib.bpsMulDown(boundedLoss, incidentSeverityBps);
    }

    function confidenceWeightedLoss(
        uint256 reportedLoss,
        uint256 confidenceBps,
        uint256 minimumLoss
    ) internal pure returns (uint256) {
        uint256 weighted = MathLib.bpsMulDown(reportedLoss, confidenceBps);
        if (weighted < minimumLoss && reportedLoss != 0) return minimumLoss;
        return weighted;
    }

    function applyReviewHaircut(uint256 amount, uint256 age, uint256 reviewWindow)
        internal
        pure
        returns (uint256)
    {
        if (reviewWindow == 0 || age >= reviewWindow) return amount;
        uint256 maturity = MathLib.mulDivDown(age, UmbraConstants.BPS, reviewWindow);
        uint256 haircut = UmbraConstants.BPS.saturatingSub(maturity);
        return amount.saturatingSub(MathLib.bpsMulDown(amount, haircut / 2));
    }

    function aggregateLossRatio(uint256 totalRequested, uint256 totalCoverage)
        internal
        pure
        returns (uint256)
    {
        if (totalCoverage == 0) return 0;
        return MathLib.min(MathLib.bps(totalRequested, totalCoverage), UmbraConstants.BPS);
    }

    function batchConfidence(uint256 claimsApproved, uint256 claimsRead, uint256 baseConfidenceBps)
        internal
        pure
        returns (uint256)
    {
        if (claimsRead == 0) return 0;
        uint256 approvalRatio = MathLib.bps(claimsApproved, claimsRead);
        return MathLib.mulDivDown(baseConfidenceBps, approvalRatio, UmbraConstants.BPS);
    }

    function cappedPayout(uint256 requested, uint256 coverage, uint256 available)
        internal
        pure
        returns (uint256)
    {
        return MathLib.min(MathLib.min(requested, coverage), available);
    }
}

