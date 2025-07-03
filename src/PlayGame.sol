//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// import {GameStructure} from "../src/Game.sol";
import {VRFCoordinatorV2Interface} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";


interface IErrors {
    error AlreadyInGame();
    error FeeNotPaid();
    error MustEnterGameFirst();
    error AlreadyPooledMoney();
    error PoolingWindowClosed();
    error OnlyCroupierCanCall();
    error GuessingWindowClosed();
    error GuessingWindowNotClosed();
}

interface IGameEvents {
    event PlayerEntered(address indexed player, uint256 time);
    event NewRoundStartingIn(uint256 roundNumber, uint256 timeInterval);
    event NewRoundStarted(uint256 roundNumber, uint256 remainingTime);
    event PlayerProposedGuess(address indexed player, uint256 guess, uint256 roundNumber);
}

contract NewGame is VRFConsumerBaseV2, IErrors, IGameEvents {

    address payable[] private s_players;
    uint256 private moneyPool;

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

    mapping (uint256 => uint256) private secretNumberOfRound;
    mapping (uint256 => bool) public secretNumberIsReady;
    mapping (uint8 => bool) private s_roundStarted;

    constructor(address _vrfCoordinator, bytes32 keyHash, uint64 subscriptionId) VRFConsumerBaseV2(_vrfCoordinator) {

        i_croupier = msg.sender;

        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    modifier onlyCroupier() {
        require(msg.sender == i_croupier, OnlyCroupierCanCall());
        _;
    }

    mapping (address => mapping(uint8 => uint256)) private s_playerGuessForRound;
    // player to round number to guess
    mapping (address => bool) private enteredGame;

    function enterGame() external payable {
        require(enteredGame[msg.sender] == false, AlreadyInGame());
        require(msg.value == FEE, FeeNotPaid());

        enteredGame[msg.sender] = true;
        s_players.push(payable(msg.sender));
        moneyPool += msg.value;

        emit PlayerEntered(msg.sender, block.timestamp);
    }

    function startRound(uint8 roundNumber) external onlyCroupier {
        require(block.timestamp == i_startTime + (roundNumber * i_interval), "Too early to start round");
        require(!s_roundStarted[roundNumber], "Round already started");

        require(msg.sender == i_croupier, "Only croupier can request random words");
        uint256 requestId = COORDINATOR.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, /* (blockConfirmations/ timeForOracleToRespond) */
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        s_roundStarted[roundNumber] = true;
    }
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
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


    function enterRoundproposeGuesses(uint8 round, uint256 guess) external payable{ 
        round = round - 1; // appropriate indexing for array
        GameRound memory gameRound = s_gameRounds[round];
        s_gameRounds[round].roundNumber = round +1;

        require(enteredGame[msg.sender], MustEnterGameFirst());
        require(s_roundStarted[0], "Round not started yet");

        require(block.timestamp < i_startTime + (gameRound[round]*i_interval) 
        && block.timestamp > i_startTime + ((gameRound[round]-1)*i_interval), GuessingWindowClosed());

        require(msg.value == gameRound.fees, FeeNotPaid());

        require(s_playerGuessForRound[msg.sender][round] == 0, "Already proposed a guess for this round");

        s_playerGuessForRound[msg.sender][round] = guess;
        emit PlayerProposedGuess(msg.sender, guess, round + 1);
    }
}