// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IRiskOracle } from "../interfaces/IRiskOracle.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import { UmbraConstants } from "../types/UmbraTypes.sol";

/// @title RiskOracle
/// @notice Stores governance-approved risk signals used by off-chain quoting and monitoring.
contract RiskOracle is IRiskOracle, ProtocolAccess {
    error InvalidProduct();
    error InvalidVault();
    error InvalidSignal();
    error SignalExpired();

    struct ProductRisk {
        uint16 baseSeverityBps;
        uint16 maxAggregateLossBps;
        uint16 premiumAdjustmentBps;
        uint64 updatedAt;
        bool configured;
    }

    struct VaultSignal {
        uint16 riskScoreBps;
        uint16 liquidityScoreBps;
        uint64 updatedAt;
        uint64 validUntil;
        bytes32 signalHash;
    }

    mapping(bytes32 => ProductRisk) internal _productRisk;
    mapping(bytes32 => mapping(address => VaultSignal)) internal _vaultSignals;
    bytes32[] internal _products;

    constructor(address governor_, address guardian_) ProtocolAccess(governor_, guardian_) { }

    function setProductRisk(
        bytes32 productId,
        uint16 baseSeverityBps,
        uint16 maxAggregateLossBps,
        uint16 premiumAdjustmentBps_
    ) external override onlyGovernorOrKeeper {
        if (productId == bytes32(0)) revert InvalidProduct();
        if (
            baseSeverityBps == 0 || baseSeverityBps > UmbraConstants.BPS || maxAggregateLossBps == 0
                || maxAggregateLossBps > UmbraConstants.BPS
                || premiumAdjustmentBps_ > UmbraConstants.BPS
        ) revert InvalidSignal();

        if (!_productRisk[productId].configured) _products.push(productId);
        _productRisk[productId] = ProductRisk({
            baseSeverityBps: baseSeverityBps,
            maxAggregateLossBps: maxAggregateLossBps,
            premiumAdjustmentBps: premiumAdjustmentBps_,
            updatedAt: MathLib.toUint64(block.timestamp),
            configured: true
        });

        emit ProductRiskUpdated(
            productId, baseSeverityBps, maxAggregateLossBps, premiumAdjustmentBps_
        );
    }

    function updateVaultSignal(
        bytes32 productId,
        address coveredVault,
        uint16 riskScoreBps,
        uint16 liquidityScoreBps,
        uint64 validUntil,
        bytes32 signalHash_
    ) external override onlyGovernorOrKeeper {
        if (!_productRisk[productId].configured) revert InvalidProduct();
        if (coveredVault == address(0)) revert InvalidVault();
        if (
            riskScoreBps == 0 || riskScoreBps > UmbraConstants.BPS || liquidityScoreBps == 0
                || liquidityScoreBps > UmbraConstants.BPS || validUntil <= block.timestamp
                || signalHash_ == bytes32(0)
        ) revert InvalidSignal();

        _vaultSignals[productId][coveredVault] = VaultSignal({
            riskScoreBps: riskScoreBps,
            liquidityScoreBps: liquidityScoreBps,
            updatedAt: MathLib.toUint64(block.timestamp),
            validUntil: validUntil,
            signalHash: signalHash_
        });

        emit VaultSignalUpdated(
            productId, coveredVault, riskScoreBps, liquidityScoreBps, validUntil
        );
    }

    function riskWeightBps(bytes32 productId, address coveredVault)
        external
        view
        override
        returns (uint256)
    {
        ProductRisk memory product = _requireProduct(productId);
        VaultSignal memory signal = _vaultSignals[productId][coveredVault];
        if (signal.validUntil != 0 && signal.validUntil < block.timestamp) revert SignalExpired();

        if (signal.updatedAt == 0) return product.baseSeverityBps;
        uint256 riskWeight = MathLib.average(product.baseSeverityBps, signal.riskScoreBps);
        uint256 liquidityDiscount =
            MathLib.bpsMulDown(riskWeight, UmbraConstants.BPS - signal.liquidityScoreBps);
        return MathLib.min(riskWeight + liquidityDiscount, UmbraConstants.BPS);
    }

    function premiumAdjustmentBps(bytes32 productId) external view override returns (uint256) {
        return _requireProduct(productId).premiumAdjustmentBps;
    }

    function signalHash(bytes32 productId, address coveredVault)
        external
        view
        override
        returns (bytes32)
    {
        return _vaultSignals[productId][coveredVault].signalHash;
    }

    function productRisk(bytes32 productId) external view returns (ProductRisk memory) {
        return _requireProduct(productId);
    }

    function vaultSignal(bytes32 productId, address coveredVault)
        external
        view
        returns (VaultSignal memory)
    {
        return _vaultSignals[productId][coveredVault];
    }

    function productCount() external view returns (uint256) {
        return _products.length;
    }

    function productAt(uint256 index) external view returns (bytes32) {
        return _products[index];
    }

    function _requireProduct(bytes32 productId) internal view returns (ProductRisk memory product) {
        product = _productRisk[productId];
        if (!product.configured) revert InvalidProduct();
    }
}
