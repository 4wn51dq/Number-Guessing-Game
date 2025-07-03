//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFCoordinatorV2Interface} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";


contract GameStructure is VRFConsumerBaseV2{
    event RequestedRandomness(uint256 requestId);
    event RequestFulfilled(uint256 round);

    address public immutable i_croupier;
    uint256 internal constant FEE = 1 ether;
    uint256 internal immutable i_interval; // interval between rounds in seconds
    uint256 public immutable i_startTime; // whenever the game starts 

    //below are the CHAINLINK VRF VARIABLES 
    bytes32 private immutable i_keyHash; //max gas willing to pay for chainlink oracle's job
    uint64 private immutable i_subscriptionId; // LINK-funded sub ID
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // wait time (usually 3 for testing)
    uint32 private constant CALLBACK_GAS_LIMIT = 100000; //max gas chainlink node can use while calling func
    uint32 private constant NUM_WORDS = 1; // number of random words to be generated

    //we will be using the interface to implement the consumer base
    VRFCoordinatorV2Interface private COORDINATOR;


    struct GameRound {
        uint8 roundNumber;
        uint256 guessingWindowTime;
        uint256 range;
        uint256 fees; 
    }

    GameRound[6] public s_gameRounds;

    constructor(address _vrfCoordinator, bytes32 keyHash, uint64 subscriptionId) VRFConsumerBaseV2(_vrfCoordinator) {

        i_croupier = msg.sender;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);

    }

    //round number to secret number
    
    mapping (uint256 => uint256) private secretNumberOfRound;
    mapping (uint256 => bool) public secretNumberIsReady;
    // mapping () private s_roundInitialised;


    //first we will send a request for generating random number;
    // calling this external function via the interface
    function requestRandomWords() external {
        // require(!secretNumberIsReady[roundNumber], "Secret number already generated for this round");
        require(msg.sender == i_croupier, "Only croupier can request random words");
        COORDINATOR.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, /* (blockConfirmations/ timeForOracleToRespond) */
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(uint256, uint256[] memory randomNumber) internal override {
        
        uint256 secretNumber;
        for(uint8 i=1; i<=s_gameRounds.length; i++){

            uint256 difficulty = 10**i;
            uint256 secretNumber = (randomNumber[0] % difficulty);

            secretNumberOfRound[i] = secretNumber;
            secretNumberIsReady[i] = true;

            s_gameRounds[i] = GameRound({
                roundNumber: i+1,
                guessingWindowTime: i*10,
                range: difficulty,
                fees: FEE*i
            });
        }
    }
}

