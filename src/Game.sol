//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract placementPackage{
    address public immutable croupier;

    struct Participant {
        address gambler;
        uint guess;
    }

    uint public constant FEE = 1 ether;
    uint public immutable multiplier;
    uint public immutable guessWindow;

    constructor(address _croupier, uint _multiplier){
        _croupier = msg.sender;
        croupier = _croupier;
        multiplier = _multiplier;
    }

    uint public constant r = 10;
    uint[] public rangesForSuccessiveRounds;
    function setRange() private returns (uint range){

    }

    struct Game {
        uint 
    }

    mapping (address => bool) canGamble;
    function startGambling() external payable {
        require(msg.value == FEE, 'must pay participating fee');

        canGamble[msg.sender] = true;
    }

    function proposeGuess(uint _guess) external {
        require(canGamble[msg.sender == true]);


    }

    }


}