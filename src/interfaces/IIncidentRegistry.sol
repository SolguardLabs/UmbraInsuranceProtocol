// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IncidentData, PolicyData } from "../types/UmbraTypes.sol";

interface IIncidentRegistry {
    event IncidentOpened(
        uint256 indexed incidentId,
        bytes32 indexed productId,
        address indexed coveredVault,
        uint64 occurredAt,
        uint16 severityBps
    );
    event IncidentResolved(uint256 indexed incidentId, bytes32 resolutionHash);
    event IncidentArchived(uint256 indexed incidentId);

    function openIncident(
        bytes32 productId,
        address coveredVault,
        uint64 occurredAt,
        uint16 severityBps,
        bytes32 evidenceHash
    ) external returns (uint256 incidentId);
    function resolveIncident(uint256 incidentId, bytes32 resolutionHash) external;
    function archiveIncident(uint256 incidentId) external;
    function incident(uint256 incidentId) external view returns (IncidentData memory);
    function matchesPolicy(uint256 incidentId, PolicyData calldata policyData)
        external
        view
        returns (bool);
}

