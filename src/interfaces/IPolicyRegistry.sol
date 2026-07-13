// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { BuyPolicyParams, PolicyData, PolicyQuote } from "../types/UmbraTypes.sol";

interface IPolicyRegistry {
    event PolicyPurchased(
        uint256 indexed policyId,
        bytes32 indexed productId,
        uint256 indexed poolId,
        address holder,
        address beneficiary,
        uint256 coverageAmount,
        uint256 premiumPaid
    );
    event PolicyExpired(uint256 indexed policyId, uint256 indexed poolId, uint256 coverageAmount);
    event PolicyCancelled(uint256 indexed policyId, uint256 refundAmount);
    event PolicyClaimed(
        uint256 indexed policyId,
        uint256 indexed incidentId,
        uint256 payoutAmount,
        uint256 reserveReleased
    );

    function buyPolicy(BuyPolicyParams calldata params)
        external
        returns (uint256 policyId, PolicyQuote memory quote);
    function expirePolicy(uint256 policyId) external;
    function markClaimed(uint256 policyId, uint256 incidentId, uint256 payoutAmount)
        external
        returns (uint256 reserveReleased);
    function policy(uint256 policyId) external view returns (PolicyData memory);
    function ownerOfPolicy(uint256 policyId) external view returns (address);
    function isPolicyActive(uint256 policyId) external view returns (bool);
    function policiesOf(address owner) external view returns (uint256[] memory);
    function policiesByProduct(bytes32 productId) external view returns (uint256[] memory);
    function policyCount() external view returns (uint256);
}
