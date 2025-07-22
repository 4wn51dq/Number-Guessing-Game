//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test /*, console*/} from "../../lib/forge-std/src/Test.sol";
import {DeployGame} from "../../script/DeployGame.s.sol";
import {NewGame} from "../../src/PlayGame.sol";
import {HelperConfig} from "../../script/DeployGame.s.sol";
import {Vm} from "";

contract UnitTest is Test {
    NewGame public newGame;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public PLAYER_INITIAL_BALANCE = 10 ether;
    uint256 public GUESS_ROUND1 = 4;
    uint8 public VALID_ROUNDNUMBER = 3;
    uint256 public VALID_GUESS_FOR_ROUND = 112;
    uint256 public VALID_FEE_FOR_ROUND;

    address vrfCoordinator;
    bytes32 keyHash; 
    uint64 subscriptionId;
    uint256 FEE;
    uint256 startTime;
    address croupier;

    function setUp() external {
        // croupier = makeAddr("croupier");
        // vm.startPrank(croupier);
        DeployGame deployer = new DeployGame();
        (newGame, helperConfig) = deployer.deployGameContract();
        // vm.stopPrank();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;
        FEE = config.FEE; 
        
        VALID_FEE_FOR_ROUND = FEE*(VALID_ROUNDNUMBER - 1);


        startTime = newGame.i_startTime();

        vm.deal(PLAYER, PLAYER_INITIAL_BALANCE);
    }

    modifier playerHasEntered() {
        vm.warp(startTime - 2 hours);
        vm.prank(PLAYER);
        newGame.enterGame{value: FEE}(GUESS_ROUND1);

        assertTrue(newGame.enteredGame(PLAYER));
        _;
    }

    modifier beforeStart() {
        vm.warp( startTime - 1 hours);
        _;
    }

    modifier submittedGuess(){
        vm.prank(PLAYER);
        newGame.submitGuess{value: VALID_FEE_FOR_ROUND}(VALID_ROUNDNUMBER, VALID_GUESS_FOR_ROUND);
        _;
    }

    function testPlayerEntersTheGame() external {
        vm.warp(startTime - 1 hours);
        vm.prank(PLAYER);
        newGame.enterGame{value: FEE}(GUESS_ROUND1);
    }
    function testPlayerCannotEnterGameAfterStart() external {
        vm.warp(startTime + 1 hours);
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.enterGame{value: FEE}(GUESS_ROUND1);
    }
    
    function testPlayerPaysCorrectFee() external {
        vm.warp(startTime - 1 hours);
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.enterGame{value: 2 ether}(GUESS_ROUND1);
    }

    function testPlayerGuessForFirstRoundIsValid() external {
        vm.warp(startTime - 1 hours);
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.enterGame{value: FEE}(12);
    }

    function testBoolIsUpdatedAfterTheyEnterGame() external playerHasEntered{
        assertTrue(newGame.enteredGame(PLAYER));
    }

    function testPlayerGuessIsRecordedForFirstRoundUponEntering() external playerHasEntered{
        assertEq(GUESS_ROUND1, newGame.getGuess(PLAYER, 1));
    }

    function testPlayerIsAddedToFirstRoundUponEnteringGame() external playerHasEntered {
        address payable [] memory round1players= newGame.getPlayersListOfRound(1);

        assertEq(PLAYER, round1players[round1players.length-1]);
    }

    function testEntryFeeWasAddedToMoneyPool() external {
        uint256 initialBalance = address(newGame).balance;

        vm.warp(startTime - 1 hours);
        vm.prank(PLAYER);
        newGame.enterGame{value: FEE}(GUESS_ROUND1);

        uint256 finalBalance = address(newGame).balance;

        assertEq(initialBalance + FEE, finalBalance);
    }

    function testPlayerIsInBeforeTheyCanSubmitGuess() external{
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.submitGuess(VALID_ROUNDNUMBER, VALID_GUESS_FOR_ROUND);
    }

    function testPlayerDoesNotReSubmitGuessForFirstRound() external playerHasEntered beforeStart{
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.submitGuess(1, GUESS_ROUND1);
    }

    function testPlayerDoesNotSubmitGuessForInvalidRound() external playerHasEntered beforeStart{
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.submitGuess(8, VALID_GUESS_FOR_ROUND);
    }

    function testPlayerStakesTheRightAmountOfMoneyForTheRound() external playerHasEntered beforeStart{
        vm.prank(PLAYER);
        newGame.submitGuess{value: FEE*2}(VALID_ROUNDNUMBER, VALID_GUESS_FOR_ROUND);

        assertEq(FEE*2, VALID_FEE_FOR_ROUND);
    }

    function testRevertIfPlayerStakesWrongFeeWhenSubmittingGuess() external playerHasEntered beforeStart{
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.submitGuess{value: 7 ether}(VALID_ROUNDNUMBER, VALID_GUESS_FOR_ROUND);
    }

    function testPlayerDoesNotSendInvalidGuessForRound() external playerHasEntered beforeStart {
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.submitGuess{value: VALID_FEE_FOR_ROUND}(VALID_ROUNDNUMBER, 1015);
    }

    function testGuessForTheRoundOfThePlayerIsRecorded() external playerHasEntered beforeStart submittedGuess {
        assertEq(VALID_GUESS_FOR_ROUND, newGame.getGuess(PLAYER, VALID_ROUNDNUMBER));
    }

    function testMoneyPoolIsUpdatedWithTheFees() external playerHasEntered beforeStart {
        uint256 initialBalance = address(newGame).balance;

        vm.prank(PLAYER);
        newGame.submitGuess{value: VALID_FEE_FOR_ROUND}(VALID_ROUNDNUMBER, VALID_GUESS_FOR_ROUND);

        uint256 finalBalance  = address(newGame).balance;

        assertEq(initialBalance +VALID_FEE_FOR_ROUND, finalBalance);
    }

    function testPlayerIsAddedToTheRoundUponSubmittingGuess() external playerHasEntered beforeStart submittedGuess {
        address payable [] memory roundPlayers= newGame.getPlayersListOfRound(VALID_ROUNDNUMBER);

        assertEq(PLAYER, roundPlayers[roundPlayers.length-1]);
    }

    function testOnlyCroupierCallRequestFunction() public {
        vm.prank(PLAYER);
        vm.expectRevert();
        newGame.startRound(VALID_ROUNDNUMBER);
    }

    function testCroupierStartsAValidRound() public {
        vm.prank(newGame.getCroupier());
        vm.expectRevert();
        newGame.startRound(8);
    }

    function testRoundIsStartedAtTheRightTime() public {
        uint256 someTimeInFuture = 4 hours;
        vm.warp(startTime + someTimeInFuture);
        vm.prank(newGame.getCroupier());
        vm.expectRevert();
        newGame.startRound(VALID_ROUNDNUMBER);
    }

    function testTheRoundHasNotAlreadyStarted() public {
        vm.warp(startTime- (VALID_ROUNDNUMBER* newGame.getInterval()));
        vm.prank(newGame.getCroupier());
        vm.expectRevert();

        newGame.startRound(VALID_ROUNDNUMBER);
    }

    function 
}