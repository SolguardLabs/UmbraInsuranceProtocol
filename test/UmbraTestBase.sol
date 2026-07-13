// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Test } from "forge-std/Test.sol";

import { ClaimProcessor } from "../src/core/ClaimProcessor.sol";
import { IncidentRegistry } from "../src/core/IncidentRegistry.sol";
import { PolicyRegistry } from "../src/core/PolicyRegistry.sol";
import { PremiumEngine } from "../src/core/PremiumEngine.sol";
import { ReserveMonitor } from "../src/core/ReserveMonitor.sol";
import { RiskPool } from "../src/core/RiskPool.sol";
import { BuyPolicyParams, PoolConfig, ProductConfig } from "../src/types/UmbraTypes.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";

abstract contract UmbraTestBase is Test {
    uint256 internal constant UNIT = 1e18;
    bytes32 internal constant PRODUCT = keccak256("STABLE_VAULT_COVER");
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address internal constant CAROL = address(0xCA401);
    address internal constant UNDERWRITER = address(0xA11D);
    address internal constant SECOND_UNDERWRITER = address(0xBEEF);
    address internal constant VAULT_A = address(0x1001);
    address internal constant VAULT_B = address(0x1002);
    address internal constant GUARDIAN = address(0x600D);
    address internal constant KEEPER = address(0x5100);
    address internal constant TREASURY = address(0x7EA5);

    MockERC20 internal asset;
    RiskPool internal riskPool;
    PremiumEngine internal premiumEngine;
    PolicyRegistry internal policyRegistry;
    IncidentRegistry internal incidentRegistry;
    ClaimProcessor internal claimProcessor;
    ReserveMonitor internal reserveMonitor;

    uint256 internal poolId;

    function setUp() public virtual {
        vm.warp(1_700_000_000);

        asset = new MockERC20("Mock USD", "mUSD", 18);
        riskPool = new RiskPool(address(asset), address(this), GUARDIAN, 1 days);
        premiumEngine = new PremiumEngine(address(riskPool), address(this), GUARDIAN);
        policyRegistry = new PolicyRegistry(
            address(asset),
            address(riskPool),
            address(premiumEngine),
            TREASURY,
            address(this),
            GUARDIAN
        );
        incidentRegistry = new IncidentRegistry(address(this), GUARDIAN);
        claimProcessor = new ClaimProcessor(
            address(policyRegistry),
            address(incidentRegistry),
            address(riskPool),
            address(this),
            GUARDIAN
        );
        reserveMonitor = new ReserveMonitor(
            address(riskPool), address(policyRegistry), address(claimProcessor)
        );

        riskPool.setPolicyRegistry(address(policyRegistry));
        riskPool.setClaimProcessor(address(claimProcessor));
        policyRegistry.setClaimProcessor(address(claimProcessor));
        riskPool.setKeeper(KEEPER, true);
        premiumEngine.setKeeper(KEEPER, true);
        incidentRegistry.setKeeper(KEEPER, true);
        claimProcessor.setKeeper(KEEPER, true);

        poolId = riskPool.createPool(
            PoolConfig({
                label: bytes32("VAULT_RISK"),
                minCapital: 100 * UNIT,
                maxUtilizationBps: 9000,
                exitFeeBps: 0,
                acceptsPolicies: true,
                acceptsDeposits: true
            })
        );

        premiumEngine.configureProduct(
            ProductConfig({
                productId: PRODUCT,
                poolId: poolId,
                minCoverage: 10 * UNIT,
                maxCoverage: 10_000 * UNIT,
                minDuration: 7 days,
                maxDuration: 365 days,
                baseRateBps: 300,
                utilizationSlopeBps: 900,
                deductibleBps: 1000,
                protocolFeeBps: 500,
                waitingPeriod: 0,
                enabled: true
            })
        );
    }

    function _depositCapital(address underwriter, uint256 assets)
        internal
        returns (uint256 shares)
    {
        asset.mint(underwriter, assets);
        vm.startPrank(underwriter);
        asset.approve(address(riskPool), assets);
        shares = riskPool.deposit(poolId, assets, underwriter);
        vm.stopPrank();
    }

    function _buyPolicy(address buyer, address beneficiary, address coveredVault, uint256 coverage)
        internal
        returns (uint256 policyId)
    {
        uint256 duration = 30 days;
        uint256 premium =
            premiumEngine.quotePolicy(PRODUCT, coverage, uint32(duration)).grossPremium;
        asset.mint(buyer, premium);
        vm.startPrank(buyer);
        asset.approve(address(policyRegistry), premium);
        (policyId,) = policyRegistry.buyPolicy(
            BuyPolicyParams({
                productId: PRODUCT,
                holder: buyer,
                beneficiary: beneficiary,
                coveredVault: coveredVault,
                coverageAmount: coverage,
                duration: uint32(duration),
                maxPremium: premium,
                termsHash: keccak256("terms-v1")
            })
        );
        vm.stopPrank();
    }

    function _openIncident(address coveredVault) internal returns (uint256 incidentId) {
        incidentId = incidentRegistry.openIncident(
            PRODUCT, coveredVault, uint64(block.timestamp), 8000, keccak256("incident-evidence")
        );
    }

    function _fileClaim(
        address claimant,
        uint256 policyId,
        uint256 incidentId,
        uint256 lossAmount,
        address receiver
    ) internal returns (uint256 claimId) {
        vm.prank(claimant);
        claimId = claimProcessor.fileClaim(
            policyId, incidentId, lossAmount, lossAmount, receiver, keccak256("claim-evidence")
        );
    }
}

