// SPDX-License-Identifer: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract HelperConfigConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 1115511;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 4e15;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 1e9;
}

contract HelperConfig is HelperConfigConstants, Script {
    // errors
    error Helper__InvalidChainId();

    struct NetworkConfig {
        uint256 entraceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entraceFee: 0.001 ether,
            interval: 30,
            vrfCoordinator: 0xd691f04bc0C9a24Edb78af9E005Cf85768F694C9,
            gasLane: 0x130dba50ad435d4ecc214aad0d5820474137bd68e7e77724144f27c3c377d3d4,
            subscriptionId: 24231130315547724191821596450727177418118307832442970098794396957239277776165,
            callbackGasLimit: 500000
        });
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            // setup the anvil deployment
            return getOrCreateAnvilEthConfig();
        } else {
            revert Helper__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainId);
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vRFCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT_LINK);
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entraceFee: 0.001 ether,
            interval: 30,
            vrfCoordinator: address(vRFCoordinatorV2_5Mock),
            gasLane: 0x130dba50ad435d4ecc214aad0d5820474137bd68e7e77724144f27c3c377d3d4,
            subscriptionId: 0,
            callbackGasLimit: 500000
        });

        return localNetworkConfig;
    }
}
