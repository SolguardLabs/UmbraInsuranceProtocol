// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { PoolSnapshot } from "../types/UmbraTypes.sol";

interface IEpochAccounting {
    event EpochCheckpointed(
        uint256 indexed poolId,
        uint64 indexed epoch,
        uint256 totalCapital,
        uint256 reservedCapital,
        uint256 availableCapital
    );

    function checkpointPool(uint256 poolId) external returns (uint64 epoch);
    function checkpointPools(uint256[] calldata poolIds) external returns (uint64[] memory epochs);
    function latestEpoch(uint256 poolId) external view returns (uint64);
    function snapshotAt(uint256 poolId, uint64 epoch) external view returns (PoolSnapshot memory);
}

