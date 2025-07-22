//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "../lib/forge-std/src/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
// import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {

    function createSubscription(address _vrfCoordinator) public returns (uint64, address){
        // console.log("Creating Subscription ID on the the blockchain: ", block.chainId);
        vm.startBroadcast();
        uint64 subscriptionId = VRFCoordinatorV2Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        return (subscriptionId, _vrfCoordinator);
    }

    function createSubscriptionFromConfig() external returns (uint64, address) {
        HelperConfig helperConfig = new HelperConfig();

        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        return createSubscription(vrfCoordinator);
    }

    function run() external returns (uint64) {    }
}

contract FundSubscription is Script, CodeConstants{
    uint96 public constant FUND_AMOUNT = 3 ether;
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();

        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint64 subId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().linkTokenContractAddress;

        fundSubscription(vrfCoordinator, subId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint64 subscriptionId, address linkToken) public {
        if(block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encodePacked(subscriptionId));
            vm.stopBroadcast();
        }

    }

    function run() public {

    }
}

/** contract AddConsumer is Script {
    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("NewGame", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint64 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        addConsumer(vrfCoordinator, mostRecentlyDeployed, subId);
    }

    function addConsumer(address vrfCoordinator, address contractToAddToVRF, uint64 subId ) public {
        //vm.startBroadcast();
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, contractToAddToVRF);
        // vm.stopBroadcast();
    }
} 
*/