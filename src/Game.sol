//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract GameRules is VRFConsumerBaseV2{
    address public immutable croupier;

    struct Participant {
        address gambler;
        uint guess;
    }
    struct GameRound {
        uint guessingWindowTime;
        uint range;
        uint correct; 
        uint fees;
    }

    uint public constant FEE = 1 ether;

    GameRound[] public gameRounds;
    uint public roundNumber = 1;

    constructor(
    address _vrfCoordinator,
    bytes32 _keyHash,
    uint64 _subId ) VRFConsumerBaseV2(_vrfCoordinator) {

        croupier = msg.sender;

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subId;
    }

    //round number to secret number

    VRFCoordinatorV2Interface COORDINATOR;

    //below are the CHAINLINK VRF VARIABLES 
    bytes32 private keyHash; //max gas willing to pay for chainlink oracle's job
    uint64 private subscriptionId; // LINK-funded sub ID
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // wait time (usually 3 for testing)
    uint32 private constant CALLBACK_GAS_LIMIT = 100000; //max gas chainlink node can use while calling func
    uint32 private constant NUM_WORDS = 1; // number of random words to be generated

    mapping (uint => uint) secretNumberOfRound;
    mapping (uint => bool) secretNumberIsReady;


    //first we will send a request for generating random number;
    function requestRandomNumber() external {
        require(!secretNumberIsReady[roundNumber]);
        require(msg.sender == croupier);
        COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(uint256, uint256[] memory randomNumber) internal override {
        uint difficulty = 10**roundNumber;
        uint secret = (randomNumber[0] % difficulty);

        secretNumberOfRound[roundNumber] = secret;
        secretNumberIsReady[roundNumber] = true;


        GameRound memory gameRound = GameRound({
            guessingWindowTime: roundNumber*10,
            range: difficulty,
            correct: secret,
            fees: FEE*roundNumber
        });

        gameRounds.push(gameRound);
        roundNumber++;
    }
}