// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {
    BuyPolicyParams,
    ClaimData,
    IncidentData,
    PolicyData,
    PolicyQuote,
    ProductConfig
} from "../types/UmbraTypes.sol";

library PolicyHashLib {
    bytes32 internal constant BUY_POLICY_TYPEHASH = keccak256(
        "BuyPolicy(bytes32 productId,address holder,address beneficiary,address coveredVault,uint256 coverageAmount,uint32 duration,uint256 maxPremium,bytes32 termsHash)"
    );
    bytes32 internal constant POLICY_TYPEHASH = keccak256(
        "Policy(uint256 id,uint256 poolId,bytes32 productId,address holder,address beneficiary,address coveredVault,uint256 coverageAmount,uint256 premiumPaid,uint16 deductibleBps,uint64 startsAt,uint64 expiresAt,bytes32 termsHash)"
    );
    bytes32 internal constant QUOTE_TYPEHASH = keccak256(
        "Quote(bytes32 productId,uint256 poolId,uint256 coverageAmount,uint256 grossPremium,uint256 protocolFee,uint256 reservePremium,uint16 deductibleBps,uint64 startsAt,uint64 expiresAt)"
    );
    bytes32 internal constant INCIDENT_TYPEHASH = keccak256(
        "Incident(uint256 id,bytes32 productId,address coveredVault,uint64 openedAt,uint64 occurredAt,uint64 resolvedAt,uint16 severityBps,bytes32 evidenceHash)"
    );
    bytes32 internal constant CLAIM_TYPEHASH = keccak256(
        "Claim(uint256 id,uint256 policyId,uint256 incidentId,address claimant,address receiver,uint256 lossAmount,uint256 requestedAmount,uint256 approvedAmount,uint64 filedAt,uint64 processedAt,bytes32 evidenceHash)"
    );
    bytes32 internal constant PRODUCT_TYPEHASH = keccak256(
        "Product(bytes32 productId,uint256 poolId,uint256 minCoverage,uint256 maxCoverage,uint32 minDuration,uint32 maxDuration,uint16 baseRateBps,uint16 utilizationSlopeBps,uint16 deductibleBps,uint16 protocolFeeBps,uint32 waitingPeriod,bool enabled)"
    );

    function hashBuyParams(BuyPolicyParams memory params) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                BUY_POLICY_TYPEHASH,
                params.productId,
                params.holder,
                params.beneficiary,
                params.coveredVault,
                params.coverageAmount,
                params.duration,
                params.maxPremium,
                params.termsHash
            )
        );
    }

    function hashPolicy(PolicyData memory policy) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                POLICY_TYPEHASH,
                policy.id,
                policy.poolId,
                policy.productId,
                policy.holder,
                policy.beneficiary,
                policy.coveredVault,
                policy.coverageAmount,
                policy.premiumPaid,
                policy.deductibleBps,
                policy.startsAt,
                policy.expiresAt,
                policy.termsHash
            )
        );
    }

    function hashQuote(PolicyQuote memory quote) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                QUOTE_TYPEHASH,
                quote.productId,
                quote.poolId,
                quote.coverageAmount,
                quote.grossPremium,
                quote.protocolFee,
                quote.reservePremium,
                quote.deductibleBps,
                quote.startsAt,
                quote.expiresAt
            )
        );
    }

    function hashIncident(IncidentData memory incident) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                INCIDENT_TYPEHASH,
                incident.id,
                incident.productId,
                incident.coveredVault,
                incident.openedAt,
                incident.occurredAt,
                incident.resolvedAt,
                incident.severityBps,
                incident.evidenceHash
            )
        );
    }

    function hashClaim(ClaimData memory claim) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                claim.id,
                claim.policyId,
                claim.incidentId,
                claim.claimant,
                claim.receiver,
                claim.lossAmount,
                claim.requestedAmount,
                claim.approvedAmount,
                claim.filedAt,
                claim.processedAt,
                claim.evidenceHash
            )
        );
    }

    function hashProduct(ProductConfig memory product) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                PRODUCT_TYPEHASH,
                product.productId,
                product.poolId,
                product.minCoverage,
                product.maxCoverage,
                product.minDuration,
                product.maxDuration,
                product.baseRateBps,
                product.utilizationSlopeBps,
                product.deductibleBps,
                product.protocolFeeBps,
                product.waitingPeriod,
                product.enabled
            )
        );
    }
}

