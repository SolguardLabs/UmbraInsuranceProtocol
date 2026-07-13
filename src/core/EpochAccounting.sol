// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IEpochAccounting } from "../interfaces/IEpochAccounting.sol";
import { IRiskPool } from "../interfaces/IRiskPool.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import { PoolSnapshot } from "../types/UmbraTypes.sol";

/// @title EpochAccounting
/// @notice Records daily pool snapshots for operations, reporting and invariant checks.
contract EpochAccounting is IEpochAccounting, ProtocolAccess {
    error InvalidPool();
    error InvalidEpoch();
    error EmptyInput();

    struct EpochDelta {
        int256 capitalDelta;
        int256 reserveDelta;
        int256 availableDelta;
        uint256 previousUtilizationBps;
        uint256 currentUtilizationBps;
    }

    IRiskPool public immutable riskPool;
    uint64 public immutable epochLength;

    mapping(uint256 => uint64) internal _latestEpoch;
    mapping(uint256 => mapping(uint64 => PoolSnapshot)) internal _snapshots;

    constructor(address riskPool_, uint64 epochLength_, address governor_, address guardian_)
        ProtocolAccess(governor_, guardian_)
    {
        if (riskPool_ == address(0) || epochLength_ == 0) revert InvalidPool();
        riskPool = IRiskPool(riskPool_);
        epochLength = epochLength_;
    }

    function checkpointPool(uint256 poolId)
        public
        override
        onlyGovernorOrKeeper
        returns (uint64 epoch)
    {
        if (poolId == 0) revert InvalidPool();
        epoch = currentEpoch();
        PoolSnapshot memory snapshot = riskPool.poolSnapshot(poolId);
        _snapshots[poolId][epoch] = snapshot;
        _latestEpoch[poolId] = epoch;
        emit EpochCheckpointed(
            poolId,
            epoch,
            snapshot.totalCapital,
            snapshot.reservedCapital,
            snapshot.availableCapital
        );
    }

    function checkpointPools(uint256[] calldata poolIds)
        external
        override
        onlyGovernorOrKeeper
        returns (uint64[] memory epochs)
    {
        if (poolIds.length == 0) revert EmptyInput();
        epochs = new uint64[](poolIds.length);
        for (uint256 i; i < poolIds.length; ++i) {
            epochs[i] = checkpointPool(poolIds[i]);
        }
    }

    function latestEpoch(uint256 poolId) external view override returns (uint64) {
        return _latestEpoch[poolId];
    }

    function snapshotAt(uint256 poolId, uint64 epoch)
        external
        view
        override
        returns (PoolSnapshot memory)
    {
        PoolSnapshot memory snapshot = _snapshots[poolId][epoch];
        if (snapshot.poolId == 0) revert InvalidEpoch();
        return snapshot;
    }

    function latestSnapshot(uint256 poolId) external view returns (PoolSnapshot memory) {
        uint64 epoch = _latestEpoch[poolId];
        if (epoch == 0) revert InvalidEpoch();
        return _snapshots[poolId][epoch];
    }

    function deltaBetween(uint256 poolId, uint64 previousEpoch, uint64 currentEpoch_)
        external
        view
        returns (EpochDelta memory delta)
    {
        PoolSnapshot memory previous = _snapshots[poolId][previousEpoch];
        PoolSnapshot memory current = _snapshots[poolId][currentEpoch_];
        if (previous.poolId == 0 || current.poolId == 0) revert InvalidEpoch();

        delta = EpochDelta({
            capitalDelta: _signedDiff(current.totalCapital, previous.totalCapital),
            reserveDelta: _signedDiff(current.reservedCapital, previous.reservedCapital),
            availableDelta: _signedDiff(current.availableCapital, previous.availableCapital),
            previousUtilizationBps: previous.utilizationBps,
            currentUtilizationBps: current.utilizationBps
        });
    }

    function currentEpoch() public view returns (uint64) {
        return MathLib.toUint64(block.timestamp / epochLength);
    }

    function projectedEpoch(uint256 timestamp) external view returns (uint64) {
        return MathLib.toUint64(timestamp / epochLength);
    }

    function _signedDiff(uint256 a, uint256 b) internal pure returns (int256) {
        if (a >= b) return int256(a - b);
        return -int256(b - a);
    }
}

