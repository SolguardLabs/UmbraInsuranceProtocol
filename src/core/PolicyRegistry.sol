// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "../interfaces/IERC20.sol";
import { IPremiumEngine } from "../interfaces/IPremiumEngine.sol";
import { IPolicyRegistry } from "../interfaces/IPolicyRegistry.sol";
import { IRiskPool } from "../interfaces/IRiskPool.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";
import { UmbraPolicyToken } from "../token/UmbraPolicyToken.sol";
import { BuyPolicyParams, PolicyData, PolicyQuote, PolicyState } from "../types/UmbraTypes.sol";

/// @title PolicyRegistry
/// @notice Owns the lifecycle and economic reserve binding of Umbra coverage policies.
contract PolicyRegistry is IPolicyRegistry, ProtocolAccess, ReentrancyGuard {
    using SafeTransferLib for IERC20;

    error InvalidPolicyAddress();
    error InvalidPolicy();
    error InvalidPremium();
    error PolicyNotActive();
    error PolicyNotExpired();
    error UnauthorizedModule();

    IERC20 public immutable asset;
    IRiskPool public immutable riskPool;
    IPremiumEngine public immutable premiumEngine;
    UmbraPolicyToken public immutable policyToken;
    address public treasury;
    address public claimProcessor;
    uint256 public override policyCount;

    mapping(uint256 => PolicyData) internal _policies;
    mapping(address => uint256[]) internal _policiesOf;
    mapping(bytes32 => uint256[]) internal _policiesByProduct;

    modifier onlyClaimProcessor() {
        if (msg.sender != claimProcessor) revert UnauthorizedModule();
        _;
    }

    constructor(
        address asset_,
        address riskPool_,
        address premiumEngine_,
        address treasury_,
        address governor_,
        address guardian_
    ) ProtocolAccess(governor_, guardian_) {
        if (
            asset_ == address(0) || riskPool_ == address(0) || premiumEngine_ == address(0)
                || treasury_ == address(0)
        ) revert InvalidPolicyAddress();
        asset = IERC20(asset_);
        riskPool = IRiskPool(riskPool_);
        premiumEngine = IPremiumEngine(premiumEngine_);
        treasury = treasury_;
        policyToken = new UmbraPolicyToken("Umbra Coverage Policy", "uPOLICY", address(this));
    }

    function setClaimProcessor(address processor) external onlyGovernor {
        if (processor == address(0)) revert InvalidPolicyAddress();
        claimProcessor = processor;
    }

    function setTreasury(address newTreasury) external onlyGovernor {
        if (newTreasury == address(0)) revert InvalidPolicyAddress();
        treasury = newTreasury;
    }

    function buyPolicy(BuyPolicyParams calldata params)
        external
        override
        nonReentrant
        returns (uint256 policyId, PolicyQuote memory quote)
    {
        if (
            params.holder == address(0) || params.beneficiary == address(0)
                || params.coveredVault == address(0)
        ) revert InvalidPolicyAddress();

        quote = premiumEngine.quotePolicy(params.productId, params.coverageAmount, params.duration);
        if (quote.grossPremium > params.maxPremium) revert InvalidPremium();

        asset.safeTransferFrom(msg.sender, address(riskPool), quote.reservePremium);
        if (quote.protocolFee != 0) {
            asset.safeTransferFrom(msg.sender, treasury, quote.protocolFee);
        }

        policyId = ++policyCount;
        riskPool.reserveForPolicy(
            quote.poolId, policyId, quote.coverageAmount, quote.reservePremium
        );

        _policies[policyId] = PolicyData({
            id: policyId,
            poolId: quote.poolId,
            productId: params.productId,
            holder: params.holder,
            beneficiary: params.beneficiary,
            coveredVault: params.coveredVault,
            coverageAmount: quote.coverageAmount,
            premiumPaid: quote.grossPremium,
            deductibleBps: quote.deductibleBps,
            startsAt: quote.startsAt,
            expiresAt: quote.expiresAt,
            createdAt: uint64(block.timestamp),
            state: PolicyState.Active,
            termsHash: params.termsHash
        });
        _policiesOf[params.holder].push(policyId);
        _policiesByProduct[params.productId].push(policyId);
        policyToken.mint(params.holder, policyId);

        emit PolicyPurchased(
            policyId,
            params.productId,
            quote.poolId,
            params.holder,
            params.beneficiary,
            quote.coverageAmount,
            quote.grossPremium
        );
    }

    function expirePolicy(uint256 policyId) external override nonReentrant {
        PolicyData storage data = _policies[policyId];
        if (data.id == 0) revert InvalidPolicy();
        if (data.state != PolicyState.Active) revert PolicyNotActive();
        if (block.timestamp <= data.expiresAt) revert PolicyNotExpired();

        data.state = PolicyState.Expired;
        riskPool.releasePolicyReserve(data.poolId, policyId, data.coverageAmount);
        policyToken.burn(policyId);
        emit PolicyExpired(policyId, data.poolId, data.coverageAmount);
    }

    function markClaimed(uint256 policyId, uint256 incidentId, uint256 payoutAmount)
        external
        override
        onlyClaimProcessor
        returns (uint256 reserveReleased)
    {
        PolicyData storage data = _policies[policyId];
        if (data.id == 0) revert InvalidPolicy();
        if (data.state != PolicyState.Active) revert PolicyNotActive();
        data.state = PolicyState.Claimed;
        reserveReleased = data.coverageAmount;
        policyToken.burn(policyId);
        emit PolicyClaimed(policyId, incidentId, payoutAmount, reserveReleased);
    }

    function policy(uint256 policyId) external view override returns (PolicyData memory) {
        return _policies[policyId];
    }

    function ownerOfPolicy(uint256 policyId) external view override returns (address) {
        return policyToken.ownerOf(policyId);
    }

    function isPolicyActive(uint256 policyId) external view override returns (bool) {
        PolicyData memory data = _policies[policyId];
        return data.state == PolicyState.Active && block.timestamp <= data.expiresAt
            && block.timestamp >= data.startsAt;
    }

    function policiesOf(address owner) external view returns (uint256[] memory) {
        return _policiesOf[owner];
    }

    function policiesByProduct(bytes32 productId) external view returns (uint256[] memory) {
        return _policiesByProduct[productId];
    }
}
