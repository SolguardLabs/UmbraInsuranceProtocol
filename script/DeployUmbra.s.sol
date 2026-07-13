// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";

import { ClaimProcessor } from "../src/core/ClaimProcessor.sol";
import { IncidentRegistry } from "../src/core/IncidentRegistry.sol";
import { PolicyRegistry } from "../src/core/PolicyRegistry.sol";
import { PremiumEngine } from "../src/core/PremiumEngine.sol";
import { RiskPool } from "../src/core/RiskPool.sol";
import { PoolConfig, ProductConfig } from "../src/types/UmbraTypes.sol";

contract DeployUmbra is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address asset = vm.envAddress("UMBRA_ASSET");
        address treasury = vm.envOr("UMBRA_TREASURY", msg.sender);
        address guardian = vm.envOr("UMBRA_GUARDIAN", msg.sender);

        vm.startBroadcast(privateKey);

        RiskPool riskPool = new RiskPool(asset, msg.sender, guardian, 1 days);
        PremiumEngine premiumEngine = new PremiumEngine(address(riskPool), msg.sender, guardian);
        PolicyRegistry policyRegistry = new PolicyRegistry(
            asset, address(riskPool), address(premiumEngine), treasury, msg.sender, guardian
        );
        IncidentRegistry incidentRegistry = new IncidentRegistry(msg.sender, guardian);
        ClaimProcessor claimProcessor = new ClaimProcessor(
            address(policyRegistry),
            address(incidentRegistry),
            address(riskPool),
            msg.sender,
            guardian
        );

        riskPool.setPolicyRegistry(address(policyRegistry));
        riskPool.setClaimProcessor(address(claimProcessor));
        policyRegistry.setClaimProcessor(address(claimProcessor));

        uint256 poolId = riskPool.createPool(
            PoolConfig({
                label: bytes32("VAULT_RISK"),
                minCapital: vm.envOr("UMBRA_MIN_CAPITAL", uint256(100_000e18)),
                maxUtilizationBps: uint16(vm.envOr("UMBRA_MAX_UTILIZATION_BPS", uint256(9000))),
                exitFeeBps: uint16(vm.envOr("UMBRA_EXIT_FEE_BPS", uint256(0))),
                acceptsPolicies: true,
                acceptsDeposits: true
            })
        );

        premiumEngine.configureProduct(
            ProductConfig({
                productId: vm.envOr("UMBRA_PRODUCT_ID", keccak256("STABLE_VAULT_COVER")),
                poolId: poolId,
                minCoverage: vm.envOr("UMBRA_MIN_COVERAGE", uint256(1000e18)),
                maxCoverage: vm.envOr("UMBRA_MAX_COVERAGE", uint256(1_000_000e18)),
                minDuration: uint32(vm.envOr("UMBRA_MIN_DURATION", uint256(7 days))),
                maxDuration: uint32(vm.envOr("UMBRA_MAX_DURATION", uint256(365 days))),
                baseRateBps: uint16(vm.envOr("UMBRA_BASE_RATE_BPS", uint256(300))),
                utilizationSlopeBps: uint16(vm.envOr("UMBRA_SLOPE_BPS", uint256(900))),
                deductibleBps: uint16(vm.envOr("UMBRA_DEDUCTIBLE_BPS", uint256(1000))),
                protocolFeeBps: uint16(vm.envOr("UMBRA_PROTOCOL_FEE_BPS", uint256(500))),
                waitingPeriod: uint32(vm.envOr("UMBRA_WAITING_PERIOD", uint256(0))),
                enabled: true
            })
        );

        vm.stopBroadcast();
    }
}

