//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {NewGame} from "../src/PlayGame.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";


contract DeployGame is Script{
    function run() external {

    }

    function deployGameContract() external returns (NewGame, HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;

        config = helperConfig.getConfig();

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


        vm.stopBroadcast();

        VRFCoordinatorV2Mock(config.vrfCoordinator).addConsumer(config.subscriptionId, address(newGame));


        return (newGame, helperConfig);
    }
}