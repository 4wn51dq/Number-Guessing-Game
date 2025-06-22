//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {GameRules} from "../src/Game.sol";

contract NewGame is GameRules {

    struct Participant {
        uint guess;
    }

    constructor(address _croupier) GameRules(_croupier){

    }

    enum Gamble {Out, In}
    //Gamble.In is stored as 1 and Gamble.Out is stored as 0 so Out is default!

    mapping (address=> mapping(uint => bool)) public isPlayingThisRound;
    // player to round number to playingornot
    mapping (address => Gamble) enteredGame;

    function enterGame() external payable {
        require(enteredGame[msg.sender] == Gamble.out, "already in game");
        require(msg.value == FEE, "must pay participating fee");

        enteredGame[msg.sender] = Gamble.In;
    }

    function startGambling(uint roundNumber, uint guess) external payable {
        require(enteredGame[msg.sender] == Gamble.In, "must enter game first");

        for(uint i=0; i< gameRounds.length; i++){
            roundNumber = i+1;
            require(!isPlayingThisRound[msg.sender][i+1], "already pooled money");
            require(block.timestamp<= gameRounds[i].guessingWindowTime, "Pooling windo closed!");

            (bool depositedToPool, ) = address(this).call{value: FEE*(i)}("");
            require( depositedToPool);
        }
        isPlayingThisRound[msg.sender][i+1] = true;

        address(this).balance += msg.value;


    }

    function proposeGuess(uint _guess) external {

    }
}