//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test /*, console*/} from "../../lib/forge-std/src/Test.sol";
import {DeployGame} from "../../script/DeployGame.s.sol";
import {NewGame} from "../../src/PlayGame.sol";
import {HelperConfig} from "../../script/DeployGame.s.sol";

contract UnitTest is Test {
    NewGame public newGame;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public PLAYER_INITIAL_BALANCE = 10 ether;

    address vrfCoordinator;
    bytes32 keyHash; 
    uint64 subscriptionId;
    uint256 FEE;
    uint256 startTime;

    function setUp() external {
        DeployGame deployer = new DeployGame();
        (newGame, helperConfig) = deployer.deployGameContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;
        FEE = config.FEE;

        startTime = newGame.i_startTime();

        vm.deal(PLAYER, PLAYER_INITIAL_BALANCE);
    }

    function testPlayerEntersTheGame() external {
        vm.warp(startTime - 1 hours);
        vm.prank(PLAYER);
        newGame.enterGame{value: FEE}(4);
    }
    function testPlayerCannotEnterGameAfterStart() external {
        vm.warp(startTime + 1 hours);
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.enterGame{value: FEE}(4);
    }
    
}