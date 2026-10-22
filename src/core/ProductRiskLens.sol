// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPremiumEngine } from "../interfaces/IPremiumEngine.sol";
import { IRiskPool } from "../interfaces/IRiskPool.sol";
import { InsuranceMath } from "../libraries/InsuranceMath.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { PolicyQuote, PoolSnapshot } from "../types/UmbraTypes.sol";

/// @title ProductRiskLens
/// @notice Read-only projection of the capital and reserve effect of one policy quote.
contract ProductRiskLens {
    error InvalidModule();

    IPremiumEngine public immutable premiumEngine;
    IRiskPool public immutable riskPool;

    struct ProjectedQuote {
        PolicyQuote quote;
        uint256 capitalBefore;
        uint256 reservedBefore;
        uint256 pendingWithdrawals;
        uint256 capitalAfterPremium;
        uint256 reservedAfterPurchase;
        uint256 availableAfterPurchase;
        uint256 utilizationAfterPurchaseBps;
    }

    constructor(address premiumEngine_, address riskPool_) {
        if (premiumEngine_ == address(0) || riskPool_ == address(0)) revert InvalidModule();
        premiumEngine = IPremiumEngine(premiumEngine_);
        riskPool = IRiskPool(riskPool_);
    }

    function project(bytes32 productId, uint256 coverageAmount, uint32 duration)
        external
        view
        returns (ProjectedQuote memory result)
    {
        PolicyQuote memory quote = premiumEngine.quotePolicy(productId, coverageAmount, duration);
        PoolSnapshot memory pool = riskPool.poolSnapshot(quote.poolId);
        uint256 capitalAfterPremium = pool.totalCapital + quote.reservePremium;
        uint256 reservedAfterPurchase = pool.reservedCapital + quote.coverageAmount;
        result = ProjectedQuote({
            quote: quote,
            capitalBefore: pool.totalCapital,
            reservedBefore: pool.reservedCapital,
            pendingWithdrawals: pool.pendingWithdrawals,
            capitalAfterPremium: capitalAfterPremium,
            reservedAfterPurchase: reservedAfterPurchase,
            availableAfterPurchase: InsuranceMath.availableCapital(
                capitalAfterPremium, reservedAfterPurchase, pool.pendingWithdrawals
            ),
            utilizationAfterPurchaseBps: MathLib.bps(reservedAfterPurchase, capitalAfterPremium)
        });
    }
}
