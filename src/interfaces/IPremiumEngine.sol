// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { PolicyQuote, ProductConfig } from "../types/UmbraTypes.sol";

interface IPremiumEngine {
    event ProductConfigured(
        bytes32 indexed productId, uint256 indexed poolId, uint256 minCoverage, uint256 maxCoverage
    );
    event ProductStatusUpdated(bytes32 indexed productId, bool enabled);

    function configureProduct(ProductConfig calldata config) external;
    function setProductStatus(bytes32 productId, bool enabled) external;
    function quotePolicy(bytes32 productId, uint256 coverageAmount, uint32 duration)
        external
        view
        returns (PolicyQuote memory);
    function product(bytes32 productId) external view returns (ProductConfig memory);
}

