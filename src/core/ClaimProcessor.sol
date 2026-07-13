// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IClaimProcessor } from "../interfaces/IClaimProcessor.sol";
import { IIncidentRegistry } from "../interfaces/IIncidentRegistry.sol";
import { IPolicyRegistry } from "../interfaces/IPolicyRegistry.sol";
import { IRiskPool } from "../interfaces/IRiskPool.sol";
import { InsuranceMath } from "../libraries/InsuranceMath.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";
import {
    BatchSettlement,
    ClaimAssessment,
    ClaimData,
    ClaimPayment,
    ClaimStatus,
    PolicyData,
    PolicyState,
    UmbraConstants
} from "../types/UmbraTypes.sol";

/// @title ClaimProcessor
/// @notice Reviews filed claims and coordinates claim disbursements with the risk pool.
contract ClaimProcessor is IClaimProcessor, ProtocolAccess, ReentrancyGuard {
    using MathLib for uint256;

    error InvalidClaim();
    error InvalidBatch();
    error InvalidReceiver();
    error InvalidPolicy();
    error InvalidIncident();
    error UnauthorizedClaimant();
    error BatchTooLarge();

    IPolicyRegistry public immutable policyRegistry;
    IIncidentRegistry public immutable incidentRegistry;
    IRiskPool public immutable riskPool;
    uint256 public override claimCount;

    mapping(uint256 => ClaimData) internal _claims;
    mapping(uint256 => uint256[]) internal _claimsByPolicy;
    mapping(uint256 => uint256[]) internal _claimsByIncident;

    bytes32 internal constant REASON_POLICY = keccak256("POLICY");
    bytes32 internal constant REASON_INCIDENT = keccak256("INCIDENT");
    bytes32 internal constant REASON_AMOUNT = keccak256("AMOUNT");
    bytes32 internal constant REASON_POOL = keccak256("POOL");

    constructor(
        address policyRegistry_,
        address incidentRegistry_,
        address riskPool_,
        address governor_,
        address guardian_
    ) ProtocolAccess(governor_, guardian_) {
        if (
            policyRegistry_ == address(0) || incidentRegistry_ == address(0)
                || riskPool_ == address(0)
        ) revert InvalidPolicy();
        policyRegistry = IPolicyRegistry(policyRegistry_);
        incidentRegistry = IIncidentRegistry(incidentRegistry_);
        riskPool = IRiskPool(riskPool_);
    }

    function fileClaim(
        uint256 policyId,
        uint256 incidentId,
        uint256 lossAmount,
        uint256 requestedAmount,
        address receiver,
        bytes32 evidenceHash
    ) external override nonReentrant returns (uint256 claimId) {
        if (receiver == address(0)) revert InvalidReceiver();
        if (lossAmount == 0 || requestedAmount == 0) revert InvalidClaim();

        PolicyData memory policyData = policyRegistry.policy(policyId);
        if (policyData.id == 0 || policyData.state != PolicyState.Active) {
            revert InvalidPolicy();
        }
        address currentOwner = policyRegistry.ownerOfPolicy(policyId);
        if (
            msg.sender != currentOwner && msg.sender != policyData.holder
                && msg.sender != policyData.beneficiary
        ) revert UnauthorizedClaimant();
        if (!incidentRegistry.matchesPolicy(incidentId, policyData)) revert InvalidIncident();

        claimId = ++claimCount;
        _claims[claimId] = ClaimData({
            id: claimId,
            policyId: policyId,
            incidentId: incidentId,
            claimant: msg.sender,
            receiver: receiver,
            lossAmount: lossAmount,
            requestedAmount: requestedAmount,
            approvedAmount: 0,
            filedAt: MathLib.toUint64(block.timestamp),
            processedAt: 0,
            status: ClaimStatus.Filed,
            evidenceHash: evidenceHash
        });
        _claimsByPolicy[policyId].push(claimId);
        _claimsByIncident[incidentId].push(claimId);

        emit ClaimFiled(claimId, policyId, incidentId, msg.sender, requestedAmount);
    }

    function processClaimBatch(uint256 poolId, uint256[] calldata claimIds)
        external
        override
        onlyGovernorOrKeeper
        nonReentrant
        returns (BatchSettlement memory settlement)
    {
        if (poolId == 0 || claimIds.length == 0) revert InvalidBatch();
        if (claimIds.length > UmbraConstants.MAX_BATCH_SIZE) revert BatchTooLarge();

        uint256 openingAvailable = riskPool.availableCapital(poolId);
        ClaimPayment[] memory payments = new ClaimPayment[](claimIds.length);
        uint256 approved;
        uint256 totalPayout;
        uint256 totalReserveReleased;

        for (uint256 i; i < claimIds.length; ++i) {
            ClaimData storage data = _claims[claimIds[i]];
            if (data.id == 0 || data.status != ClaimStatus.Filed) revert InvalidClaim();

            (ClaimPayment memory payment, bool accepted) =
                _processFiledClaim(data, poolId, openingAvailable);
            if (!accepted) continue;

            payments[i] = payment;
            ++approved;
            totalPayout += payment.amount;
            totalReserveReleased += payment.reserveRelease;
        }

        if (approved != 0) {
            riskPool.settleClaimBatch(poolId, payments, totalPayout, totalReserveReleased);
        }

        settlement = BatchSettlement({
            poolId: poolId,
            openingAvailableCapital: openingAvailable,
            claimsRead: claimIds.length,
            claimsApproved: approved,
            totalPayout: totalPayout,
            totalReserveReleased: totalReserveReleased
        });
        emit ClaimBatchProcessed(poolId, claimIds.length, approved, totalPayout);
    }

    function claim(uint256 claimId) external view override returns (ClaimData memory) {
        return _claims[claimId];
    }

    function claimsByPolicy(uint256 policyId) external view returns (uint256[] memory) {
        return _claimsByPolicy[policyId];
    }

    function claimsByIncident(uint256 incidentId) external view returns (uint256[] memory) {
        return _claimsByIncident[incidentId];
    }

    function previewClaim(uint256 claimId, uint256 poolId)
        external
        view
        returns (ClaimAssessment memory)
    {
        ClaimData memory data = _claims[claimId];
        return _assessClaim(data, poolId, riskPool.availableCapital(poolId));
    }

    function _processFiledClaim(ClaimData storage data, uint256 poolId, uint256 openingAvailable)
        internal
        returns (ClaimPayment memory payment, bool accepted)
    {
        ClaimAssessment memory assessment = _assessClaim(data, poolId, openingAvailable);
        if (!assessment.accepted || assessment.payout == 0) {
            data.status = ClaimStatus.Rejected;
            data.processedAt = MathLib.toUint64(block.timestamp);
            emit ClaimRejected(data.id, data.policyId, _reasonFor(data, poolId));
            return (payment, false);
        }

        uint256 reserveReleased =
            policyRegistry.markClaimed(data.policyId, data.incidentId, assessment.payout);
        data.approvedAmount = assessment.payout;
        data.processedAt = MathLib.toUint64(block.timestamp);
        data.status = ClaimStatus.Paid;

        payment = ClaimPayment({
            claimId: data.id,
            policyId: data.policyId,
            receiver: data.receiver,
            amount: assessment.payout,
            reserveRelease: reserveReleased
        });
        emit ClaimPaid(data.id, data.policyId, data.receiver, assessment.payout);
        accepted = true;
    }

    function _assessClaim(ClaimData memory data, uint256 poolId, uint256 openingAvailable)
        internal
        view
        returns (ClaimAssessment memory assessment)
    {
        PolicyData memory policyData = policyRegistry.policy(data.policyId);
        if (
            data.id == 0 || data.status != ClaimStatus.Filed
                || policyData.state != PolicyState.Active || policyData.poolId != poolId
        ) {
            return assessment;
        }
        if (!incidentRegistry.matchesPolicy(data.incidentId, policyData)) return assessment;

        (uint256 coveredLoss, uint256 deductible, uint256 payout) = InsuranceMath.payoutForLoss(
            policyData.coverageAmount,
            MathLib.min(data.lossAmount, data.requestedAmount),
            policyData.deductibleBps
        );
        payout = MathLib.min(payout, openingAvailable);

        assessment = ClaimAssessment({
            claimId: data.id,
            policyId: data.policyId,
            poolId: policyData.poolId,
            receiver: data.receiver,
            coveredLoss: coveredLoss,
            deductible: deductible,
            payout: payout,
            reserveRelease: policyData.coverageAmount,
            accepted: payout != 0
        });
    }

    function _reasonFor(ClaimData storage data, uint256 poolId) internal view returns (bytes32) {
        PolicyData memory policyData = policyRegistry.policy(data.policyId);
        if (policyData.id == 0 || policyData.state != PolicyState.Active) return REASON_POLICY;
        if (policyData.poolId != poolId) return REASON_POOL;
        if (!incidentRegistry.matchesPolicy(data.incidentId, policyData)) return REASON_INCIDENT;
        return REASON_AMOUNT;
    }
}
