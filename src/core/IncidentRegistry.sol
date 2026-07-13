// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IIncidentRegistry } from "../interfaces/IIncidentRegistry.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import {
    IncidentData,
    IncidentStatus,
    PolicyData,
    PolicyState,
    UmbraConstants
} from "../types/UmbraTypes.sol";

/// @title IncidentRegistry
/// @notice Maintains covered incident records approved by protocol operations.
contract IncidentRegistry is IIncidentRegistry, ProtocolAccess {
    error InvalidIncident();
    error InvalidSeverity();
    error InvalidVault();
    error InvalidTimestamp();
    error IncidentClosed();

    uint256 public incidentCount;
    mapping(uint256 => IncidentData) internal _incidents;
    mapping(bytes32 => uint256[]) internal _incidentsByProduct;
    mapping(address => uint256[]) internal _incidentsByVault;

    constructor(address governor_, address guardian_) ProtocolAccess(governor_, guardian_) { }

    function openIncident(
        bytes32 productId,
        address coveredVault,
        uint64 occurredAt,
        uint16 severityBps,
        bytes32 evidenceHash
    ) external override onlyGovernorOrKeeper returns (uint256 incidentId) {
        if (productId == bytes32(0)) revert InvalidIncident();
        if (coveredVault == address(0)) revert InvalidVault();
        if (occurredAt == 0 || occurredAt > block.timestamp) revert InvalidTimestamp();
        if (severityBps == 0 || severityBps > UmbraConstants.BPS) revert InvalidSeverity();

        incidentId = ++incidentCount;
        _incidents[incidentId] = IncidentData({
            id: incidentId,
            productId: productId,
            coveredVault: coveredVault,
            openedAt: MathLib.toUint64(block.timestamp),
            occurredAt: occurredAt,
            resolvedAt: 0,
            severityBps: severityBps,
            status: IncidentStatus.Active,
            evidenceHash: evidenceHash
        });
        _incidentsByProduct[productId].push(incidentId);
        _incidentsByVault[coveredVault].push(incidentId);

        emit IncidentOpened(incidentId, productId, coveredVault, occurredAt, severityBps);
    }

    function resolveIncident(uint256 incidentId, bytes32 resolutionHash)
        external
        override
        onlyGovernorOrKeeper
    {
        IncidentData storage data = _incidents[incidentId];
        if (data.id == 0) revert InvalidIncident();
        if (data.status != IncidentStatus.Active) revert IncidentClosed();
        data.status = IncidentStatus.Resolved;
        data.resolvedAt = MathLib.toUint64(block.timestamp);
        emit IncidentResolved(incidentId, resolutionHash);
    }

    function archiveIncident(uint256 incidentId) external override onlyGovernor {
        IncidentData storage data = _incidents[incidentId];
        if (data.id == 0) revert InvalidIncident();
        if (data.status == IncidentStatus.Archived) revert IncidentClosed();
        data.status = IncidentStatus.Archived;
        emit IncidentArchived(incidentId);
    }

    function incident(uint256 incidentId) external view override returns (IncidentData memory) {
        return _incidents[incidentId];
    }

    function matchesPolicy(uint256 incidentId, PolicyData calldata policyData)
        external
        view
        override
        returns (bool)
    {
        IncidentData memory data = _incidents[incidentId];
        if (data.id == 0 || data.status == IncidentStatus.Archived) return false;
        if (policyData.state != PolicyState.Active) return false;
        if (data.productId != policyData.productId) return false;
        if (data.coveredVault != policyData.coveredVault) return false;
        if (data.occurredAt < policyData.startsAt || data.occurredAt > policyData.expiresAt) {
            return false;
        }
        return true;
    }

    function incidentsByProduct(bytes32 productId) external view returns (uint256[] memory) {
        return _incidentsByProduct[productId];
    }

    function incidentsByVault(address vault) external view returns (uint256[] memory) {
        return _incidentsByVault[vault];
    }
}

