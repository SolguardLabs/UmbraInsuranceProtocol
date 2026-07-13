// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IClaimProcessor } from "./interfaces/IClaimProcessor.sol";
import { IIncidentRegistry } from "./interfaces/IIncidentRegistry.sol";
import { IPolicyRegistry } from "./interfaces/IPolicyRegistry.sol";
import { IPremiumEngine } from "./interfaces/IPremiumEngine.sol";
import { IRiskPool } from "./interfaces/IRiskPool.sol";
import { SafeTransferLib } from "./libraries/SafeTransferLib.sol";
import { ProtocolAccess } from "./security/ProtocolAccess.sol";
import { ReentrancyGuard } from "./security/ReentrancyGuard.sol";
import {
    BatchSettlement,
    BuyPolicyParams,
    PolicyData,
    PolicyQuote,
    PoolSnapshot,
    ProductConfig
} from "./types/UmbraTypes.sol";

/// @title UmbraInsuranceProtocol
/// @notice User-facing coordinator for the Umbra coverage market modules.
contract UmbraInsuranceProtocol is ProtocolAccess, ReentrancyGuard {
    using SafeTransferLib for IERC20;

    error InvalidModule();
    error InvalidAmount();

    IERC20 public immutable asset;
    IRiskPool public immutable riskPool;
    IPremiumEngine public immutable premiumEngine;
    IPolicyRegistry public immutable policyRegistry;
    IIncidentRegistry public immutable incidentRegistry;
    IClaimProcessor public immutable claimProcessor;

    event ProtocolPolicyPurchased(
        uint256 indexed policyId,
        bytes32 indexed productId,
        address indexed holder,
        uint256 premiumPaid
    );
    event ProtocolCapitalDeposited(
        uint256 indexed poolId, address indexed owner, uint256 assets, uint256 shares
    );
    event ProtocolClaimBatch(uint256 indexed poolId, uint256 claimsApproved, uint256 totalPayout);

    constructor(
        address asset_,
        address riskPool_,
        address premiumEngine_,
        address policyRegistry_,
        address incidentRegistry_,
        address claimProcessor_,
        address governor_,
        address guardian_
    ) ProtocolAccess(governor_, guardian_) {
        if (
            asset_ == address(0) || riskPool_ == address(0) || premiumEngine_ == address(0)
                || policyRegistry_ == address(0) || incidentRegistry_ == address(0)
                || claimProcessor_ == address(0)
        ) revert InvalidModule();

        asset = IERC20(asset_);
        riskPool = IRiskPool(riskPool_);
        premiumEngine = IPremiumEngine(premiumEngine_);
        policyRegistry = IPolicyRegistry(policyRegistry_);
        incidentRegistry = IIncidentRegistry(incidentRegistry_);
        claimProcessor = IClaimProcessor(claimProcessor_);
    }

    function depositCapital(uint256 poolId, uint256 assets, address owner)
        external
        nonReentrant
        returns (uint256 shares)
    {
        if (assets == 0) revert InvalidAmount();
        asset.safeTransferFrom(msg.sender, address(this), assets);
        asset.forceApprove(address(riskPool), assets);
        shares = riskPool.deposit(poolId, assets, owner);
        emit ProtocolCapitalDeposited(poolId, owner, assets, shares);
    }

    function buyPolicy(BuyPolicyParams calldata params)
        external
        nonReentrant
        returns (uint256 policyId, PolicyQuote memory quote)
    {
        PolicyQuote memory preview = premiumEngine.quotePolicy(
            params.productId, params.coverageAmount, params.duration
        );
        asset.safeTransferFrom(msg.sender, address(this), preview.grossPremium);
        asset.forceApprove(address(policyRegistry), preview.grossPremium);
        (policyId, quote) = policyRegistry.buyPolicy(params);
        emit ProtocolPolicyPurchased(policyId, params.productId, params.holder, quote.grossPremium);
    }

    function processClaimBatch(uint256 poolId, uint256[] calldata claimIds)
        external
        onlyGovernorOrKeeper
        returns (BatchSettlement memory settlement)
    {
        settlement = claimProcessor.processClaimBatch(poolId, claimIds);
        emit ProtocolClaimBatch(poolId, settlement.claimsApproved, settlement.totalPayout);
    }

    function quotePolicy(bytes32 productId, uint256 coverageAmount, uint32 duration)
        external
        view
        returns (PolicyQuote memory)
    {
        return premiumEngine.quotePolicy(productId, coverageAmount, duration);
    }

    function poolSnapshot(uint256 poolId) external view returns (PoolSnapshot memory) {
        return riskPool.poolSnapshot(poolId);
    }

    function policy(uint256 policyId) external view returns (PolicyData memory) {
        return policyRegistry.policy(policyId);
    }

    function product(bytes32 productId) external view returns (ProductConfig memory) {
        return premiumEngine.product(productId);
    }
}

