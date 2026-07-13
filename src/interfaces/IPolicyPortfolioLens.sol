// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ClaimData, PolicyData } from "../types/UmbraTypes.sol";

interface IPolicyPortfolioLens {
    struct AccountPortfolio {
        address account;
        uint256 policyCount;
        uint256 activePolicies;
        uint256 totalCoverage;
        uint256 totalPremiumsPaid;
        uint256 expiringCoverage30d;
    }

    struct ProductExposure {
        bytes32 productId;
        uint256 policyCount;
        uint256 activePolicies;
        uint256 totalCoverage;
        uint256 expiredCoverage;
        uint256 claimedCoverage;
    }

    struct ClaimActivity {
        uint256 policyId;
        uint256 claimCount;
        uint256 filedClaims;
        uint256 paidClaims;
        uint256 rejectedClaims;
        uint256 requestedAmount;
        uint256 paidAmount;
    }

    function accountPortfolio(address account) external view returns (AccountPortfolio memory);
    function productExposure(bytes32 productId) external view returns (ProductExposure memory);
    function claimActivity(uint256 policyId) external view returns (ClaimActivity memory);
    function policiesOf(address account) external view returns (PolicyData[] memory);
    function claimsOfPolicy(uint256 policyId) external view returns (ClaimData[] memory);
}

