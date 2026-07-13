// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ClaimPayment, PoolConfig, PoolSnapshot, WithdrawalTicket } from "../types/UmbraTypes.sol";

interface IRiskPool {
    event PoolCreated(uint256 indexed poolId, bytes32 indexed label);
    event CapitalDeposited(
        uint256 indexed poolId,
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event WithdrawalRequested(
        uint256 indexed ticketId,
        uint256 indexed poolId,
        address indexed owner,
        address receiver,
        uint256 shares,
        uint256 assets
    );
    event WithdrawalExecuted(
        uint256 indexed ticketId,
        uint256 indexed poolId,
        address indexed owner,
        address receiver,
        uint256 assets
    );
    event PolicyReserveAdded(
        uint256 indexed poolId,
        uint256 indexed policyId,
        uint256 coverageAmount,
        uint256 premiumAmount
    );
    event PolicyReserveReleased(
        uint256 indexed poolId, uint256 indexed policyId, uint256 coverageAmount
    );
    event ClaimBatchPaid(
        uint256 indexed poolId, uint256 claimsPaid, uint256 totalPayout, uint256 reserveReleased
    );

    function createPool(PoolConfig calldata config) external returns (uint256 poolId);
    function setPolicyRegistry(address registry) external;
    function setClaimProcessor(address processor) external;
    function deposit(uint256 poolId, uint256 assets, address owner) external returns (uint256);
    function requestWithdrawal(uint256 poolId, uint256 shares, address receiver)
        external
        returns (uint256);
    function executeWithdrawal(uint256 ticketId) external returns (uint256 assets);
    function reserveForPolicy(
        uint256 poolId,
        uint256 policyId,
        uint256 coverageAmount,
        uint256 premiumAmount
    ) external;
    function releasePolicyReserve(uint256 poolId, uint256 policyId, uint256 coverageAmount) external;
    function settleClaimBatch(
        uint256 poolId,
        ClaimPayment[] calldata payments,
        uint256 totalPayout,
        uint256 totalReserveReleased
    ) external;
    function poolSnapshot(uint256 poolId) external view returns (PoolSnapshot memory);
    function availableCapital(uint256 poolId) external view returns (uint256);
    function shareBalanceOf(uint256 poolId, address owner) external view returns (uint256);
    function withdrawalTicket(uint256 ticketId) external view returns (WithdrawalTicket memory);
}

