// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { MathLib } from "./MathLib.sol";
import { PoolSnapshot, ProductConfig, UmbraConstants } from "../types/UmbraTypes.sol";

library InsuranceMath {
    using MathLib for uint256;

    function utilizationBps(uint256 reservedCapital, uint256 totalCapital)
        internal
        pure
        returns (uint256)
    {
        if (totalCapital == 0) return 0;
        return MathLib.bps(reservedCapital, totalCapital);
    }

    function availableCapital(uint256 totalCapital, uint256 reservedCapital, uint256 pending)
        internal
        pure
        returns (uint256)
    {
        return totalCapital.saturatingSub(reservedCapital).saturatingSub(pending);
    }

    function quote(
        ProductConfig memory product,
        PoolSnapshot memory pool,
        uint256 coverageAmount,
        uint32 duration
    ) internal pure returns (uint256 grossPremium, uint256 fee, uint256 reservePremium) {
        uint256 utilization = projectedUtilization(product, pool, coverageAmount);
        uint256 variableRate = MathLib.mulDivUp(
            uint256(product.utilizationSlopeBps), utilization, UmbraConstants.BPS
        );
        uint256 annualRate = uint256(product.baseRateBps) + variableRate;
        uint256 timePremium = MathLib.mulDivUp(
            coverageAmount, annualRate * uint256(duration), UmbraConstants.BPS * UmbraConstants.YEAR
        );
        uint256 floorPremium = MathLib.bpsMulUp(coverageAmount, product.baseRateBps / 4 + 1);
        reservePremium = MathLib.max(timePremium, floorPremium);
        fee = MathLib.bpsMulUp(reservePremium, product.protocolFeeBps);
        grossPremium = reservePremium + fee;
    }

    function projectedUtilization(
        ProductConfig memory,
        PoolSnapshot memory pool,
        uint256 coverageAmount
    ) internal pure returns (uint256) {
        if (pool.totalCapital == 0) return UmbraConstants.BPS;
        uint256 projectedReserved = pool.reservedCapital + coverageAmount;
        return MathLib.min(MathLib.bps(projectedReserved, pool.totalCapital), UmbraConstants.BPS);
    }

    function payoutForLoss(uint256 coverageAmount, uint256 lossAmount, uint256 deductibleBps)
        internal
        pure
        returns (uint256 coveredLoss, uint256 deductible, uint256 payout)
    {
        coveredLoss = MathLib.min(coverageAmount, lossAmount);
        deductible = MathLib.bpsMulUp(coveredLoss, deductibleBps);
        payout = coveredLoss.saturatingSub(deductible);
    }

    function sharesForDeposit(uint256 assets, uint256 totalShares, uint256 totalCapital)
        internal
        pure
        returns (uint256)
    {
        if (assets == 0) return 0;
        if (totalShares == 0 || totalCapital == 0) return assets;
        return MathLib.mulDivDown(assets, totalShares, totalCapital);
    }

    function assetsForShares(uint256 shares, uint256 totalShares, uint256 totalCapital)
        internal
        pure
        returns (uint256)
    {
        if (shares == 0 || totalShares == 0) return 0;
        return MathLib.mulDivDown(shares, totalCapital, totalShares);
    }

    function validatePolicyTerms(ProductConfig memory product, uint256 coverage, uint32 duration)
        internal
        pure
        returns (bool)
    {
        if (!product.enabled) return false;
        if (coverage < product.minCoverage || coverage > product.maxCoverage) return false;
        if (duration < product.minDuration || duration > product.maxDuration) return false;
        if (product.deductibleBps > UmbraConstants.MAX_DEDUCTIBLE_BPS) return false;
        if (product.baseRateBps > UmbraConstants.MAX_RATE_BPS) return false;
        return true;
    }
}

