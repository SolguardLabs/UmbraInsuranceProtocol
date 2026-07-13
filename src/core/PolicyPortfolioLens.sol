// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IClaimProcessor } from "../interfaces/IClaimProcessor.sol";
import { IPolicyPortfolioLens } from "../interfaces/IPolicyPortfolioLens.sol";
import { IPolicyRegistry } from "../interfaces/IPolicyRegistry.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { ClaimData, ClaimStatus, PolicyData, PolicyState } from "../types/UmbraTypes.sol";

/// @title PolicyPortfolioLens
/// @notice Aggregates policy and claim state for dashboards and review tooling.
contract PolicyPortfolioLens is IPolicyPortfolioLens {
    IPolicyRegistry public immutable policyRegistry;
    IClaimProcessor public immutable claimProcessor;

    constructor(address policyRegistry_, address claimProcessor_) {
        policyRegistry = IPolicyRegistry(policyRegistry_);
        claimProcessor = IClaimProcessor(claimProcessor_);
    }

    function accountPortfolio(address account)
        external
        view
        override
        returns (AccountPortfolio memory portfolio)
    {
        uint256[] memory ids = policyRegistry.policiesOf(account);
        portfolio.account = account;
        portfolio.policyCount = ids.length;

        uint256 horizon = block.timestamp + 30 days;
        for (uint256 i; i < ids.length; ++i) {
            PolicyData memory data = policyRegistry.policy(ids[i]);
            portfolio.totalPremiumsPaid += data.premiumPaid;
            if (data.state == PolicyState.Active) {
                ++portfolio.activePolicies;
                portfolio.totalCoverage += data.coverageAmount;
                if (data.expiresAt <= horizon) {
                    portfolio.expiringCoverage30d += data.coverageAmount;
                }
            }
        }
    }

    function productExposure(bytes32 productId)
        external
        view
        override
        returns (ProductExposure memory exposure)
    {
        uint256[] memory ids = policyRegistry.policiesByProduct(productId);
        exposure.productId = productId;
        exposure.policyCount = ids.length;

        for (uint256 i; i < ids.length; ++i) {
            PolicyData memory data = policyRegistry.policy(ids[i]);
            if (data.state == PolicyState.Active) {
                ++exposure.activePolicies;
                exposure.totalCoverage += data.coverageAmount;
            } else if (data.state == PolicyState.Expired) {
                exposure.expiredCoverage += data.coverageAmount;
            } else if (data.state == PolicyState.Claimed) {
                exposure.claimedCoverage += data.coverageAmount;
            }
        }
    }

    function claimActivity(uint256 policyId)
        public
        view
        override
        returns (ClaimActivity memory activity)
    {
        activity.policyId = policyId;
        uint256 totalClaims = claimProcessor.claimCount();
        for (uint256 i = 1; i <= totalClaims; ++i) {
            ClaimData memory data = claimProcessor.claim(i);
            if (data.policyId != policyId) continue;

            ++activity.claimCount;
            activity.requestedAmount += data.requestedAmount;
            if (data.status == ClaimStatus.Filed) {
                ++activity.filedClaims;
            } else if (data.status == ClaimStatus.Paid) {
                ++activity.paidClaims;
                activity.paidAmount += data.approvedAmount;
            } else if (data.status == ClaimStatus.Rejected) {
                ++activity.rejectedClaims;
            }
        }
    }

    function policiesOf(address account)
        external
        view
        override
        returns (PolicyData[] memory policies)
    {
        uint256[] memory ids = policyRegistry.policiesOf(account);
        policies = new PolicyData[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            policies[i] = policyRegistry.policy(ids[i]);
        }
    }

    function claimsOfPolicy(uint256 policyId)
        external
        view
        override
        returns (ClaimData[] memory claims)
    {
        ClaimActivity memory activity = claimActivity(policyId);
        claims = new ClaimData[](activity.claimCount);
        uint256 cursor;
        uint256 totalClaims = claimProcessor.claimCount();
        for (uint256 i = 1; i <= totalClaims; ++i) {
            ClaimData memory data = claimProcessor.claim(i);
            if (data.policyId == policyId) {
                claims[cursor++] = data;
            }
        }
    }

    function nearestExpiry(address account)
        external
        view
        returns (uint256 policyId, uint64 expiresAt)
    {
        uint256[] memory ids = policyRegistry.policiesOf(account);
        uint64 best = type(uint64).max;
        for (uint256 i; i < ids.length; ++i) {
            PolicyData memory data = policyRegistry.policy(ids[i]);
            if (data.state == PolicyState.Active && data.expiresAt < best) {
                policyId = data.id;
                best = data.expiresAt;
            }
        }
        expiresAt = best == type(uint64).max ? 0 : best;
    }

    function activeCoverageRatio(address account, bytes32 productId)
        external
        view
        returns (uint256 ratioBps)
    {
        uint256[] memory accountIds = policyRegistry.policiesOf(account);
        uint256[] memory productIds = policyRegistry.policiesByProduct(productId);
        uint256 accountCoverage;
        uint256 productCoverage;

        for (uint256 i; i < accountIds.length; ++i) {
            PolicyData memory data = policyRegistry.policy(accountIds[i]);
            if (data.state == PolicyState.Active && data.productId == productId) {
                accountCoverage += data.coverageAmount;
            }
        }
        for (uint256 i; i < productIds.length; ++i) {
            PolicyData memory data = policyRegistry.policy(productIds[i]);
            if (data.state == PolicyState.Active) {
                productCoverage += data.coverageAmount;
            }
        }
        ratioBps = MathLib.bps(accountCoverage, productCoverage);
    }
}

