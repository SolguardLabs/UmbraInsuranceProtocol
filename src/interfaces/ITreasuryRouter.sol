// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITreasuryRouter {
    event FeeNotified(bytes32 indexed category, address indexed payer, uint256 amount);
    event BudgetAssigned(bytes32 indexed category, address indexed receiver, uint256 amount);
    event BudgetClaimed(bytes32 indexed category, address indexed receiver, uint256 amount);
    event CategoryLimitUpdated(bytes32 indexed category, uint256 limit);

    function notifyFee(bytes32 category, address payer, uint256 amount) external;
    function assignBudget(bytes32 category, address receiver, uint256 amount) external;
    function claimBudget(bytes32 category) external returns (uint256 amount);
    function setCategoryLimit(bytes32 category, uint256 limit) external;
    function collected(bytes32 category) external view returns (uint256);
    function assigned(bytes32 category) external view returns (uint256);
    function claimable(bytes32 category, address receiver) external view returns (uint256);
}

