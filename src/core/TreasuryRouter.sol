// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "../interfaces/IERC20.sol";
import { ITreasuryRouter } from "../interfaces/ITreasuryRouter.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";

/// @title TreasuryRouter
/// @notice Receives protocol fees and assigns category budgets for operations.
contract TreasuryRouter is ITreasuryRouter, ProtocolAccess, ReentrancyGuard {
    using SafeTransferLib for IERC20;
    using MathLib for uint256;

    error InvalidCategory();
    error InvalidReceiver();
    error InvalidAmount();
    error CategoryLimitExceeded(uint256 limit, uint256 attempted);

    IERC20 public immutable asset;

    mapping(bytes32 => uint256) public override collected;
    mapping(bytes32 => uint256) public override assigned;
    mapping(bytes32 => uint256) public categoryLimit;
    mapping(bytes32 => mapping(address => uint256)) public override claimable;
    mapping(bytes32 => address[]) internal _receiversByCategory;
    mapping(bytes32 => mapping(address => bool)) internal _knownReceiver;

    constructor(address asset_, address governor_, address guardian_)
        ProtocolAccess(governor_, guardian_)
    {
        if (asset_ == address(0)) revert InvalidReceiver();
        asset = IERC20(asset_);
    }

    function notifyFee(bytes32 category, address payer, uint256 amount)
        external
        override
        nonReentrant
    {
        if (category == bytes32(0)) revert InvalidCategory();
        if (payer == address(0)) revert InvalidReceiver();
        if (amount == 0) revert InvalidAmount();

        uint256 limit = categoryLimit[category];
        uint256 nextCollected = collected[category] + amount;
        if (limit != 0 && nextCollected > limit) {
            revert CategoryLimitExceeded(limit, nextCollected);
        }

        asset.safeTransferFrom(msg.sender, address(this), amount);
        collected[category] = nextCollected;
        emit FeeNotified(category, payer, amount);
    }

    function assignBudget(bytes32 category, address receiver, uint256 amount)
        external
        override
        onlyGovernorOrKeeper
    {
        if (category == bytes32(0)) revert InvalidCategory();
        if (receiver == address(0)) revert InvalidReceiver();
        if (amount == 0) revert InvalidAmount();
        uint256 availableBudget = collected[category].saturatingSub(assigned[category]);
        if (availableBudget < amount) revert InvalidAmount();

        assigned[category] += amount;
        claimable[category][receiver] += amount;
        if (!_knownReceiver[category][receiver]) {
            _knownReceiver[category][receiver] = true;
            _receiversByCategory[category].push(receiver);
        }
        emit BudgetAssigned(category, receiver, amount);
    }

    function claimBudget(bytes32 category) external override nonReentrant returns (uint256 amount) {
        amount = claimable[category][msg.sender];
        if (amount == 0) revert InvalidAmount();
        claimable[category][msg.sender] = 0;
        asset.safeTransfer(msg.sender, amount);
        emit BudgetClaimed(category, msg.sender, amount);
    }

    function setCategoryLimit(bytes32 category, uint256 limit) external override onlyGovernor {
        if (category == bytes32(0)) revert InvalidCategory();
        categoryLimit[category] = limit;
        emit CategoryLimitUpdated(category, limit);
    }

    function unassigned(bytes32 category) external view returns (uint256) {
        return collected[category].saturatingSub(assigned[category]);
    }

    function receiversByCategory(bytes32 category) external view returns (address[] memory) {
        return _receiversByCategory[category];
    }

    function sweepUncategorized(address receiver, uint256 amount) external onlyGovernor {
        if (receiver == address(0)) revert InvalidReceiver();
        if (amount == 0) revert InvalidAmount();
        asset.safeTransfer(receiver, amount);
    }
}
