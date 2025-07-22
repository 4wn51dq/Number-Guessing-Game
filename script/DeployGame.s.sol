//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "../lib/forge-std/src/Script.sol";
import {NewGame} from "../src/PlayGame.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription/** , AddConsumer*/} from "./Interactions.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";


contract DeployGame is Script{
    function run() external {
        deployGameContract();
    }

    function deployGameContract() public returns (NewGame, HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.linkTokenContractAddress);

            helperConfig.getConfig().subscriptionId = config.subscriptionId;
        }

        // config = helperConfig.getConfig();

        vm.startBroadcast();

        NewGame newGame = new NewGame(
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId,
            config.FEE,
            50 days,
            50 days,
            1 hours
        );

        /**
        @dev while deploying add the contract as consumer to the local subscription
        @dev the subId if looked into the forge test trace would be 1! what this means is 
        @dev its the first subscription ever created in the local test environment.
        @dev the mock assigns IDs automatically and increments them 
        @dev On the real Chainlink VRF Coordinator (like Sepolia), IDs also increment with each new subscription created — 
        @dev except they’re maintained across the network.
        */
        
        VRFCoordinatorV2Mock(config.vrfCoordinator).addConsumer(config.subscriptionId, address(newGame));

        vm.stopBroadcast();

        return (newGame, helperConfig);
    }
}