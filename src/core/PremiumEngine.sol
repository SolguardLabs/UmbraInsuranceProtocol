// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IPremiumEngine } from "../interfaces/IPremiumEngine.sol";
import { IRiskPool } from "../interfaces/IRiskPool.sol";
import { InsuranceMath } from "../libraries/InsuranceMath.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import { PolicyQuote, PoolSnapshot, ProductConfig, UmbraConstants } from "../types/UmbraTypes.sol";

/// @title PremiumEngine
/// @notice Prices coverage products from pool utilization, duration and product risk terms.
contract PremiumEngine is IPremiumEngine, ProtocolAccess {
    error InvalidProduct();
    error InvalidCoverage();
    error InvalidDuration();
    error InvalidRate();

    IRiskPool public immutable riskPool;
    mapping(bytes32 => ProductConfig) internal _products;
    bytes32[] internal _productIds;

    constructor(address riskPool_, address governor_, address guardian_)
        ProtocolAccess(governor_, guardian_)
    {
        if (riskPool_ == address(0)) revert InvalidProduct();
        riskPool = IRiskPool(riskPool_);
    }

    function configureProduct(ProductConfig calldata config) external override onlyGovernor {
        if (config.productId == bytes32(0) || config.poolId == 0) revert InvalidProduct();
        if (config.minCoverage == 0 || config.maxCoverage < config.minCoverage) {
            revert InvalidCoverage();
        }
        if (config.minDuration == 0 || config.maxDuration < config.minDuration) {
            revert InvalidDuration();
        }
        if (
            config.baseRateBps > UmbraConstants.MAX_RATE_BPS
                || config.utilizationSlopeBps > UmbraConstants.MAX_RATE_BPS
                || config.deductibleBps > UmbraConstants.MAX_DEDUCTIBLE_BPS
                || config.protocolFeeBps > 2000
        ) revert InvalidRate();

        if (_products[config.productId].productId == bytes32(0)) {
            _productIds.push(config.productId);
        }
        _products[config.productId] = config;
        emit ProductConfigured(
            config.productId, config.poolId, config.minCoverage, config.maxCoverage
        );
    }

    function setProductStatus(bytes32 productId, bool enabled)
        external
        override
        onlyGovernorOrGuardian
    {
        ProductConfig storage config = _products[productId];
        if (config.productId == bytes32(0)) revert InvalidProduct();
        if (msg.sender == guardian && enabled) revert InvalidProduct();
        config.enabled = enabled;
        emit ProductStatusUpdated(productId, enabled);
    }

    function quotePolicy(bytes32 productId, uint256 coverageAmount, uint32 duration)
        external
        view
        override
        returns (PolicyQuote memory quote)
    {
        ProductConfig memory config = _products[productId];
        if (config.productId == bytes32(0)) revert InvalidProduct();
        if (!InsuranceMath.validatePolicyTerms(config, coverageAmount, duration)) {
            revert InvalidCoverage();
        }

        PoolSnapshot memory pool = riskPool.poolSnapshot(config.poolId);
        if (!pool.acceptsPolicies) revert InvalidProduct();
        uint256 projectedUtilization =
            InsuranceMath.projectedUtilization(config, pool, coverageAmount);
        if (projectedUtilization > UmbraConstants.MAX_UTILIZATION_BPS) {
            revert InvalidCoverage();
        }

        (uint256 grossPremium, uint256 protocolFee, uint256 reservePremium) =
            InsuranceMath.quote(config, pool, coverageAmount, duration);

        uint64 start = uint64(block.timestamp + uint256(config.waitingPeriod));
        uint64 expiry = uint64(uint256(start) + duration);
        quote = PolicyQuote({
            productId: productId,
            poolId: config.poolId,
            coverageAmount: coverageAmount,
            grossPremium: grossPremium,
            protocolFee: protocolFee,
            reservePremium: reservePremium,
            deductibleBps: config.deductibleBps,
            startsAt: start,
            expiresAt: expiry
        });
    }

    function product(bytes32 productId) external view override returns (ProductConfig memory) {
        return _products[productId];
    }

    function productCount() external view returns (uint256) {
        return _productIds.length;
    }

    function productAt(uint256 index) external view returns (ProductConfig memory) {
        return _products[_productIds[index]];
    }
}

