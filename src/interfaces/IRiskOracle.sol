// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IRiskOracle {
    event VaultSignalUpdated(
        bytes32 indexed productId,
        address indexed coveredVault,
        uint16 riskScoreBps,
        uint16 liquidityScoreBps,
        uint64 validUntil
    );
    event ProductRiskUpdated(
        bytes32 indexed productId,
        uint16 baseSeverityBps,
        uint16 maxAggregateLossBps,
        uint16 premiumAdjustmentBps
    );

    function setProductRisk(
        bytes32 productId,
        uint16 baseSeverityBps,
        uint16 maxAggregateLossBps,
        uint16 premiumAdjustmentBps
    ) external;
    function updateVaultSignal(
        bytes32 productId,
        address coveredVault,
        uint16 riskScoreBps,
        uint16 liquidityScoreBps,
        uint64 validUntil,
        bytes32 signalHash
    ) external;
    function riskWeightBps(bytes32 productId, address coveredVault) external view returns (uint256);
    function premiumAdjustmentBps(bytes32 productId) external view returns (uint256);
    function signalHash(bytes32 productId, address coveredVault) external view returns (bytes32);
}

