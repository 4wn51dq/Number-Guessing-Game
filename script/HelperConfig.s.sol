//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

abstract contract CodeConstants {
    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant LOCAL_CHAIN_ID = 31337;

    /** VRF Mock Values */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
}

contract HelperConfig is Script, CodeConstants{

    error HelperConfifg__InvalidChainId();
    
    address public subscriptionOwner;

    struct NetworkConfig {
        address vrfCoordinator;
        bytes32 keyHash; 
        uint64 subscriptionId;
        uint256 FEE;
    }

    NetworkConfig public localNetworkConfig;
    mapping (uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaETHConfig();
    }

    function getNetworkConfigByChainId(uint256 chainId) internal returns (NetworkConfig memory){
        if (networkConfigs[chainId].vrfCoordinator != address(0)){
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfifg__InvalidChainId();
        }
    }

    function getSepoliaETHConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            vrfCoordinator: 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61,
            keyHash: 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be,
            subscriptionId: 0,
            FEE: 0.01 ether
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();

        VRFCoordinatorV2Mock mockCoordinator = new VRFCoordinatorV2Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK);

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            vrfCoordinator: address(mockCoordinator),
            keyHash: 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be,
            subscriptionId: 0,
            FEE: 0.01 ether
        });

        (,,address subscriptionOwner,) = mockCoordinator.getSubscription(localNetworkConfig.subscriptionId);


        return localNetworkConfig;
    }

    function getConfig() public returns (NetworkConfig memory){
        return getNetworkConfigByChainId(block.chainid);
    }

    function getSubscriptionOwner() external view returns (address) {
        return subscriptionOwner;
    }
    
}