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
    error WindowClosed();
    error GuessingWindowNotClosed();
    error InvalidProposal();
}

interface IGameEvents {
    event PlayerEntered(address indexed player, uint256 time);
    event NewRoundStartingIn(uint256 roundNumber, uint256 timeInterval);
    event NewRoundStarted(uint256 roundNumber, uint256 remainingTime);
    event PlayerProposedGuess(address indexed player, uint256 guess, uint256 roundNumber);
    event RequestedRandomness(uint256 requestId);
    event RequestFulfilled(uint256 round);
    event WinnersListed(uint8 roundNumber, address[] winners);
}

contract NewGame is VRFConsumerBaseV2, IErrors, IGameEvents {

    address payable[] private s_players;

    address public immutable i_croupier;
    uint256 internal constant FEE = 1 ether;
    uint256 internal immutable i_interval; // interval between rounds in seconds
    uint256 public immutable i_startTime; // whenever the game starts 
    uint256 public immutable i_announceTime;

    //below are the CHAINLINK VRF VARIABLES 
    bytes32 private immutable i_keyHash; //max gas willing to pay for chainlink oracle's job
    uint64 private immutable i_subscriptionId; // LINK-funded sub ID
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // wait time (usually 3 for testing)
    uint32 private constant CALLBACK_GAS_LIMIT = 100000; //max gas chainlink node can use while calling func
    uint32 private constant NUM_WORDS = 1; // number of random words to be generated

    //we will be using the interface to implement the consumer base
    VRFCoordinatorV2Interface private COORDINATOR;

    mapping (uint256 => uint256) private secretNumberOfRound;
    mapping (uint256 => bool) public secretNumberIsReady;
    mapping (uint8 => bool) private s_roundStarted;
    mapping (uint8 => uint256) public moneyPoolForRound;

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
        require(block.timestamp< i_startTime, WindowClosed());

        enteredGame[msg.sender] = true;
        s_players.push(payable(msg.sender));
        moneyPoolForRound[1] += msg.value;

        emit PlayerEntered(msg.sender, block.timestamp);
    }

    function submitGuess(uint8 roundNumber, uint256 guess) external payable {
        require(enteredGame[msg.sender], MustEnterGameFirst());
        require(roundNumber>=1 && roundNumber<=6, "valid Round Number required");
        require(msg.value == FEE* uint256(roundNumber-1), FeeNotPaid());

        require(block.timestamp< i_startTime, WindowClosed());

        require(guess>0 && guess<10*roundNumber, InvalidProposal());

        s_playerGuessForRound[msg.sender][roundNumber] = guess;
        moneyPoolForRound[roundNumber] += msg.value;

        emit PlayerProposedGuess(msg.sender, guess, roundNumber);
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

    mapping (uint8 => address[]) public winnersForRound; // round to winners list
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 secretNumber;
        for(uint8 i=1; i<=6; i++){

            uint256 difficulty = 10**i;
            secretNumber = (randomWords[i-1] % difficulty) + 1; 

            secretNumberOfRound[i] = secretNumber;
            secretNumberIsReady[i] = true;
        }
    }

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a > b) ? (a - b) : (b - a);
    }

    function announceWinners() external onlyCroupier {
        require(block.timestamp>= i_announceTime);

        for(uint8 r=1; r<=6; r++){
            bool roundHasExactGuess = false;
            uint256 smallestDiff = type(uint256).max; 

            //the first loop will check if someone has the exact guess and announce accordingly

            for (uint256 i=0; i<s_players.length; i++) {
                if(s_playerGuessForRound[s_players[i]][r] == secretNumberOfRound[r]){
                    roundHasExactGuess = true;
                    winnersForRound[r].push(s_players[i]);
                }
            }
            // Now if no one has exact guess then only the below logic will execute in this round.
            if (!roundHasExactGuess){
                // first generate the smallest diff to exist, and from the bool logic diff cannot be 0.
                for (uint256 i=0; i<s_players.length; i++){
                    uint256 diff = _absDiff(s_playerGuessForRound[s_players[i]][r], secretNumberOfRound[r]);
                    if(diff< smallestDiff){
                        smallestDiff = diff;
                    }
                }
                for (uint256 i=0; i<s_players.length; i++){
                    uint256 diff = _absDiff(s_playerGuessForRound[s_players[i]][r], secretNumberOfRound[r]);
                    if (diff == smallestDiff){
                        winnersForRound[r].push(s_players[i]);
                    }
                }
            }
            emit WinnersListed(r, winnersForRound[r]);
        }
    }

    function rewardWinners() private {
        // for each round r, 
        // and for i in each winner in winnersForRound[r]
        // winnersForRound[r][i].call{value: (moneyPoolForRound[r] - GasCostForUsingVRF)/winnersForRound[r].length}(""); 

        for (uint8 r=1; r<6; r++){
            for(uint256 i=0; i<winnersForRound[r].length; i++){
                (bool rewarded, )= winnersForRound[r][i].call{value: (moneyPoolForRound[r])/winnersForRound[r].length}("");
                require (rewarded, "Rewarding Failed");
            }
        }
    }
}


// how can this game be destroyed? 
