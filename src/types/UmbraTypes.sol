// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library UmbraConstants {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant YEAR = 365 days;
    uint256 internal constant MAX_BATCH_SIZE = 64;
    uint256 internal constant MAX_DEDUCTIBLE_BPS = 8000;
    uint256 internal constant MAX_RATE_BPS = 5000;
    uint256 internal constant MAX_UTILIZATION_BPS = 9500;
}

enum PolicyState {
    None,
    Active,
    Expired,
    Cancelled,
    Claimed
}

enum IncidentStatus {
    None,
    Active,
    Resolved,
    Archived
}

enum ClaimStatus {
    None,
    Filed,
    Approved,
    Rejected,
    Paid
}

enum WithdrawalStatus {
    None,
    Pending,
    Executed,
    Cancelled
}

struct PoolConfig {
    bytes32 label;
    uint256 minCapital;
    uint16 maxUtilizationBps;
    uint16 exitFeeBps;
    bool acceptsPolicies;
    bool acceptsDeposits;
}

struct PoolAccounting {
    uint256 totalCapital;
    uint256 reservedCapital;
    uint256 pendingWithdrawals;
    uint256 totalShares;
    uint256 cumulativePremiums;
    uint256 cumulativePayouts;
    uint256 cumulativeFees;
}

struct PoolSnapshot {
    uint256 poolId;
    bytes32 label;
    uint256 totalCapital;
    uint256 reservedCapital;
    uint256 availableCapital;
    uint256 pendingWithdrawals;
    uint256 totalShares;
    uint256 utilizationBps;
    bool acceptsPolicies;
    bool acceptsDeposits;
}

struct ProductConfig {
    bytes32 productId;
    uint256 poolId;
    uint256 minCoverage;
    uint256 maxCoverage;
    uint32 minDuration;
    uint32 maxDuration;
    uint16 baseRateBps;
    uint16 utilizationSlopeBps;
    uint16 deductibleBps;
    uint16 protocolFeeBps;
    uint32 waitingPeriod;
    bool enabled;
}

struct PolicyData {
    uint256 id;
    uint256 poolId;
    bytes32 productId;
    address holder;
    address beneficiary;
    address coveredVault;
    uint256 coverageAmount;
    uint256 premiumPaid;
    uint16 deductibleBps;
    uint64 startsAt;
    uint64 expiresAt;
    uint64 createdAt;
    PolicyState state;
    bytes32 termsHash;
}

struct BuyPolicyParams {
    bytes32 productId;
    address holder;
    address beneficiary;
    address coveredVault;
    uint256 coverageAmount;
    uint32 duration;
    uint256 maxPremium;
    bytes32 termsHash;
}

struct PolicyQuote {
    bytes32 productId;
    uint256 poolId;
    uint256 coverageAmount;
    uint256 grossPremium;
    uint256 protocolFee;
    uint256 reservePremium;
    uint16 deductibleBps;
    uint64 startsAt;
    uint64 expiresAt;
}

struct IncidentData {
    uint256 id;
    bytes32 productId;
    address coveredVault;
    uint64 openedAt;
    uint64 occurredAt;
    uint64 resolvedAt;
    uint16 severityBps;
    IncidentStatus status;
    bytes32 evidenceHash;
}

struct ClaimData {
    uint256 id;
    uint256 policyId;
    uint256 incidentId;
    address claimant;
    address receiver;
    uint256 lossAmount;
    uint256 requestedAmount;
    uint256 approvedAmount;
    uint64 filedAt;
    uint64 processedAt;
    ClaimStatus status;
    bytes32 evidenceHash;
}

struct ClaimAssessment {
    uint256 claimId;
    uint256 policyId;
    uint256 poolId;
    address receiver;
    uint256 coveredLoss;
    uint256 deductible;
    uint256 payout;
    uint256 reserveRelease;
    bool accepted;
}

struct ClaimPayment {
    uint256 claimId;
    uint256 policyId;
    address receiver;
    uint256 amount;
    uint256 reserveRelease;
}

struct BatchSettlement {
    uint256 poolId;
    uint256 openingAvailableCapital;
    uint256 claimsRead;
    uint256 claimsApproved;
    uint256 totalPayout;
    uint256 totalReserveReleased;
}

struct WithdrawalTicket {
    uint256 id;
    uint256 poolId;
    address owner;
    address receiver;
    uint256 shares;
    uint256 assets;
    uint64 requestedAt;
    uint64 executableAt;
    WithdrawalStatus status;
}

