// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "../interfaces/IERC20.sol";
import { IRiskPool } from "../interfaces/IRiskPool.sol";
import { InsuranceMath } from "../libraries/InsuranceMath.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";
import { UmbraRiskShare } from "../token/UmbraRiskShare.sol";
import {
    ClaimPayment,
    PoolAccounting,
    PoolConfig,
    PoolSnapshot,
    UmbraConstants,
    WithdrawalStatus,
    WithdrawalTicket
} from "../types/UmbraTypes.sol";

/// @title RiskPool
/// @notice Holds underwriter capital, policy reserves, premiums and claim payouts.
contract RiskPool is IRiskPool, ProtocolAccess, ReentrancyGuard {
    using SafeTransferLib for IERC20;
    using MathLib for uint256;

    error InvalidPool();
    error InvalidAmount();
    error InvalidReceiver();
    error PoolPaused();
    error DepositsClosed();
    error PoliciesClosed();
    error InsufficientPoolCapital(uint256 available, uint256 required);
    error InsufficientShares(uint256 available, uint256 required);
    error WithdrawalNotReady(uint256 executableAt);
    error InvalidTicket();
    error InvalidModule();

    IERC20 public immutable asset;
    UmbraRiskShare public immutable receiptToken;
    uint64 public immutable withdrawalDelay;

    uint256 public poolCount;
    uint256 public nextTicketId = 1;
    address public policyRegistry;
    address public claimProcessor;

    mapping(uint256 => PoolConfig) internal _poolConfig;
    mapping(uint256 => PoolAccounting) internal _poolAccounting;
    mapping(uint256 => mapping(address => uint256)) internal _poolShares;
    mapping(uint256 => WithdrawalTicket) internal _tickets;

    modifier onlyPolicyRegistry() {
        if (msg.sender != policyRegistry) revert InvalidModule();
        _;
    }

    modifier onlyClaimProcessor() {
        if (msg.sender != claimProcessor) revert InvalidModule();
        _;
    }

    constructor(address asset_, address governor_, address guardian_, uint64 withdrawalDelay_)
        ProtocolAccess(governor_, guardian_)
    {
        if (asset_ == address(0)) revert InvalidModule();
        asset = IERC20(asset_);
        withdrawalDelay = withdrawalDelay_;
        receiptToken = new UmbraRiskShare(
            "Umbra Risk Share", "uRISK", IERC20(asset_).decimals(), address(this)
        );
    }

    function createPool(PoolConfig calldata config)
        external
        override
        onlyGovernor
        returns (uint256 poolId)
    {
        if (
            config.maxUtilizationBps == 0
                || config.maxUtilizationBps > UmbraConstants.MAX_UTILIZATION_BPS
        ) {
            revert InvalidAmount();
        }
        if (config.exitFeeBps > 1000) revert InvalidAmount();

        poolId = ++poolCount;
        _poolConfig[poolId] = config;
        emit PoolCreated(poolId, config.label);
    }

    function setPolicyRegistry(address registry) external override onlyGovernor {
        if (registry == address(0)) revert InvalidModule();
        policyRegistry = registry;
    }

    function setClaimProcessor(address processor) external override onlyGovernor {
        if (processor == address(0)) revert InvalidModule();
        claimProcessor = processor;
    }

    function setPoolStatus(uint256 poolId, bool acceptsDeposits, bool acceptsPolicies)
        external
        onlyGovernorOrGuardian
    {
        _assertPool(poolId);
        if (msg.sender == guardian && (acceptsDeposits || acceptsPolicies)) {
            revert PoolPaused();
        }
        _poolConfig[poolId].acceptsDeposits = acceptsDeposits;
        _poolConfig[poolId].acceptsPolicies = acceptsPolicies;
    }

    function deposit(uint256 poolId, uint256 assets, address owner)
        external
        override
        nonReentrant
        returns (uint256 shares)
    {
        if (owner == address(0)) revert InvalidReceiver();
        if (assets == 0) revert InvalidAmount();
        _assertPool(poolId);
        PoolConfig memory config = _poolConfig[poolId];
        if (!config.acceptsDeposits) revert DepositsClosed();

        PoolAccounting storage accounting = _poolAccounting[poolId];
        shares = InsuranceMath.sharesForDeposit(
            assets, accounting.totalShares, accounting.totalCapital
        );
        if (shares == 0) revert InvalidAmount();

        asset.safeTransferFrom(msg.sender, address(this), assets);
        accounting.totalCapital += assets;
        accounting.totalShares += shares;
        _poolShares[poolId][owner] += shares;
        receiptToken.mint(owner, shares);

        emit CapitalDeposited(poolId, msg.sender, owner, assets, shares);
    }

    function requestWithdrawal(uint256 poolId, uint256 shares, address receiver)
        external
        override
        nonReentrant
        returns (uint256 ticketId)
    {
        if (receiver == address(0)) revert InvalidReceiver();
        if (shares == 0) revert InvalidAmount();
        _assertPool(poolId);

        PoolAccounting storage accounting = _poolAccounting[poolId];
        uint256 balance = _poolShares[poolId][msg.sender];
        if (balance < shares) revert InsufficientShares(balance, shares);

        uint256 assets = InsuranceMath.assetsForShares(
            shares, accounting.totalShares, accounting.totalCapital
        );
        uint256 fee = MathLib.bpsMulUp(assets, _poolConfig[poolId].exitFeeBps);
        uint256 netAssets = assets.saturatingSub(fee);
        uint256 available = _availableCapital(accounting);
        if (available < assets) revert InsufficientPoolCapital(available, assets);

        unchecked {
            _poolShares[poolId][msg.sender] = balance - shares;
            accounting.totalShares -= shares;
        }
        accounting.pendingWithdrawals += netAssets;
        accounting.cumulativeFees += fee;
        receiptToken.burn(msg.sender, shares);

        ticketId = nextTicketId++;
        _tickets[ticketId] = WithdrawalTicket({
            id: ticketId,
            poolId: poolId,
            owner: msg.sender,
            receiver: receiver,
            shares: shares,
            assets: netAssets,
            requestedAt: MathLib.toUint64(block.timestamp),
            executableAt: MathLib.toUint64(block.timestamp + withdrawalDelay),
            status: WithdrawalStatus.Pending
        });

        emit WithdrawalRequested(ticketId, poolId, msg.sender, receiver, shares, netAssets);
    }

    function executeWithdrawal(uint256 ticketId)
        external
        override
        nonReentrant
        returns (uint256 assets)
    {
        WithdrawalTicket storage ticket = _tickets[ticketId];
        if (ticket.status != WithdrawalStatus.Pending) revert InvalidTicket();
        if (block.timestamp < ticket.executableAt) revert WithdrawalNotReady(ticket.executableAt);

        PoolAccounting storage accounting = _poolAccounting[ticket.poolId];
        assets = ticket.assets;
        ticket.status = WithdrawalStatus.Executed;
        accounting.pendingWithdrawals = accounting.pendingWithdrawals.saturatingSub(assets);
        accounting.totalCapital = accounting.totalCapital.saturatingSub(assets);

        asset.safeTransfer(ticket.receiver, assets);
        emit WithdrawalExecuted(ticketId, ticket.poolId, ticket.owner, ticket.receiver, assets);
    }

    function cancelWithdrawal(uint256 ticketId) external nonReentrant {
        WithdrawalTicket storage ticket = _tickets[ticketId];
        if (ticket.status != WithdrawalStatus.Pending || ticket.owner != msg.sender) {
            revert InvalidTicket();
        }

        PoolAccounting storage accounting = _poolAccounting[ticket.poolId];
        uint256 restoredShares = ticket.shares;
        ticket.status = WithdrawalStatus.Cancelled;
        accounting.pendingWithdrawals = accounting.pendingWithdrawals.saturatingSub(ticket.assets);
        accounting.totalShares += restoredShares;
        _poolShares[ticket.poolId][msg.sender] += restoredShares;
        receiptToken.mint(msg.sender, restoredShares);
    }

    function reserveForPolicy(
        uint256 poolId,
        uint256 policyId,
        uint256 coverageAmount,
        uint256 premiumAmount
    ) external override onlyPolicyRegistry {
        if (coverageAmount == 0) revert InvalidAmount();
        _assertPool(poolId);
        PoolConfig memory config = _poolConfig[poolId];
        if (!config.acceptsPolicies) revert PoliciesClosed();

        PoolAccounting storage accounting = _poolAccounting[poolId];
        uint256 available = _availableCapital(accounting);
        if (available < coverageAmount) {
            revert InsufficientPoolCapital(available, coverageAmount);
        }

        accounting.totalCapital += premiumAmount;
        accounting.reservedCapital += coverageAmount;
        accounting.cumulativePremiums += premiumAmount;

        uint256 utilization =
            InsuranceMath.utilizationBps(accounting.reservedCapital, accounting.totalCapital);
        if (utilization > config.maxUtilizationBps) {
            revert InsufficientPoolCapital(config.maxUtilizationBps, utilization);
        }

        emit PolicyReserveAdded(poolId, policyId, coverageAmount, premiumAmount);
    }

    function releasePolicyReserve(uint256 poolId, uint256 policyId, uint256 coverageAmount)
        external
        override
        onlyPolicyRegistry
    {
        _releasePolicyReserve(poolId, policyId, coverageAmount);
    }

    function settleClaimBatch(
        uint256 poolId,
        ClaimPayment[] calldata payments,
        uint256 totalPayout,
        uint256 totalReserveReleased
    ) external override onlyClaimProcessor nonReentrant {
        _assertPool(poolId);
        PoolAccounting storage accounting = _poolAccounting[poolId];
        uint256 paid;
        uint256 released;
        uint256 claimsPaid;

        for (uint256 i; i < payments.length; ++i) {
            ClaimPayment calldata payment = payments[i];
            if (payment.amount == 0) continue;
            paid += payment.amount;
            released += payment.reserveRelease;
            ++claimsPaid;
            asset.safeTransfer(payment.receiver, payment.amount);
        }

        if (paid != totalPayout || released != totalReserveReleased) revert InvalidAmount();
        accounting.totalCapital = accounting.totalCapital.saturatingSub(totalPayout);
        accounting.reservedCapital = accounting.reservedCapital.saturatingSub(totalReserveReleased);
        accounting.cumulativePayouts += totalPayout;

        emit ClaimBatchPaid(poolId, claimsPaid, totalPayout, totalReserveReleased);
    }

    function poolSnapshot(uint256 poolId)
        external
        view
        override
        returns (PoolSnapshot memory snapshot)
    {
        _assertPool(poolId);
        PoolConfig memory config = _poolConfig[poolId];
        PoolAccounting memory accounting = _poolAccounting[poolId];
        uint256 available = _availableCapital(accounting);
        snapshot = PoolSnapshot({
            poolId: poolId,
            label: config.label,
            totalCapital: accounting.totalCapital,
            reservedCapital: accounting.reservedCapital,
            availableCapital: available,
            pendingWithdrawals: accounting.pendingWithdrawals,
            totalShares: accounting.totalShares,
            utilizationBps: InsuranceMath.utilizationBps(
                accounting.reservedCapital, accounting.totalCapital
            ),
            acceptsPolicies: config.acceptsPolicies,
            acceptsDeposits: config.acceptsDeposits
        });
    }

    function availableCapital(uint256 poolId) external view override returns (uint256) {
        _assertPool(poolId);
        return _availableCapital(_poolAccounting[poolId]);
    }

    function shareBalanceOf(uint256 poolId, address owner)
        external
        view
        override
        returns (uint256)
    {
        return _poolShares[poolId][owner];
    }

    function poolConfig(uint256 poolId) external view returns (PoolConfig memory) {
        _assertPool(poolId);
        return _poolConfig[poolId];
    }

    function poolAccounting(uint256 poolId) external view returns (PoolAccounting memory) {
        _assertPool(poolId);
        return _poolAccounting[poolId];
    }

    function withdrawalTicket(uint256 ticketId)
        external
        view
        override
        returns (WithdrawalTicket memory)
    {
        return _tickets[ticketId];
    }

    function _releasePolicyReserve(uint256 poolId, uint256 policyId, uint256 coverageAmount)
        internal
    {
        _assertPool(poolId);
        PoolAccounting storage accounting = _poolAccounting[poolId];
        accounting.reservedCapital = accounting.reservedCapital.saturatingSub(coverageAmount);
        emit PolicyReserveReleased(poolId, policyId, coverageAmount);
    }

    function _availableCapital(PoolAccounting memory accounting) internal pure returns (uint256) {
        return InsuranceMath.availableCapital(
            accounting.totalCapital, accounting.reservedCapital, accounting.pendingWithdrawals
        );
    }

    function _assertPool(uint256 poolId) internal view {
        if (poolId == 0 || poolId > poolCount) revert InvalidPool();
    }
}

