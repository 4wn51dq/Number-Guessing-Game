//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// import {GameStructure} from "../src/Game.sol";
import {VRFCoordinatorV2Interface} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "../lib/chainlink-evm/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "../lib/chainlink-evm/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";


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
    error OutOfTimeBound();
    error RoundHasBegun();
    error TooEarlyToAnnounce();
    error RewardingFailed();
}

interface IGameEvents {
    event PlayerEntered(address indexed player, uint256 time);
    event NewRoundStartingIn(uint256 roundNumber, uint256 timeInterval);
    event NewRoundStarted(uint256 roundNumber, uint256 remainingTime);
    event PlayerProposedGuess(address indexed player, uint256 guess, uint256 roundNumber);
    event RequestedRandomness(uint256 requestId);
    event RequestFulfilled(uint256 round);
    event WinnersListed(uint8 roundNumber, address[] winners);
    event WinnerRewarded(uint8 roundNumber, address[] winners, uint256 reward);
}

contract NewGame is AutomationCompatibleInterface, VRFConsumerBaseV2, IErrors, IGameEvents {  

    address payable[] private s_players;

    address public immutable i_croupier;
    uint256 internal immutable FEE;
    uint256 internal immutable i_interval; // interval between rounds in seconds
    uint256 public immutable i_startTime; // whenever the game starts 
    uint256 private s_lastTimeStamp;
    uint256 public immutable i_announceTime;

    /* below are the CHAINLINK VRF VARIABLES */
    bytes32 private immutable i_keyHash;                    /* max gas willing to pay for chainlink oracle's job */
    uint64 private immutable i_subscriptionId;              /* LINK-funded sub ID */ 
    uint16 private constant REQUEST_CONFIRMATIONS = 3;      /* wait time (usually 3 for testing) */
    uint32 private constant CALLBACK_GAS_LIMIT = 100000;    /* max gas chainlink node can use while calling func */ 
    uint32 private constant NUM_WORDS = 1;                  /* number of random words to be generated */ 

    //we will be using the interface to implement the consumer base
    VRFCoordinatorV2Interface private COORDINATOR;

    mapping (uint8 => address payable[]) private s_playersInRound;
    mapping (uint256 => uint256) private secretNumberOfRound;
    mapping (uint256 => bool) public secretNumberIsReady;
    mapping (uint8 => bool) private s_roundStarted;
    mapping (uint8 => uint256) public moneyPoolForRound;
    mapping (uint8 => address[]) public winnersForRound; 
    mapping (uint256 => uint8) public requestIdForRound; 
    mapping (address => mapping(uint8 => uint256)) private s_playerGuessForRound;
    mapping (address => bool) public enteredGame;


    constructor( address _vrfCoordinator, 
        bytes32 keyHash, 
        uint64 subscriptionId,
        uint256 _FEE,
        uint256 startTime,
        uint256 announceTime,
        uint256 interval
        ) VRFConsumerBaseV2(_vrfCoordinator) {

        i_croupier = msg.sender;

        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);

        FEE= _FEE;
        i_startTime = startTime;
        i_announceTime = announceTime;
        i_interval = interval;
    }

    modifier onlyCroupier() {
        require(msg.sender == i_croupier, OnlyCroupierCanCall());
        _;
    }

    function checkUpkeep(bytes calldata /*checkData*/) external override view returns (bool upKeepNeeded, bytes memory returnInfo) {
        bool itsTime = (block.timestamp-s_lastTimeStamp) >= i_interval;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length >0;

        upKeepNeeded = itsTime && hasBalance && hasPlayers;
        
        uint8 _roundNumber = uint8((block.timestamp - s_lastTimeStamp)/i_interval);
        returnInfo = abi.encode(_roundNumber);
    } 

    function performUpkeep(bytes calldata returnInfo) public {
        uint8 _roundNumber = abi.decode(returnInfo, (uint8));

        require(block.timestamp >= i_startTime + (_roundNumber * i_interval), "Too early");
        s_lastTimeStamp = block.timestamp;

        startRound(_roundNumber);
    }

    function enterGame(uint256 guessForRound1) external payable {
        require(enteredGame[msg.sender] == false, AlreadyInGame());
        require(msg.value == FEE, FeeNotPaid());
        require(block.timestamp< i_startTime, WindowClosed());
        require(guessForRound1>0 && guessForRound1<10, InvalidProposal());

        s_playerGuessForRound[msg.sender][1] = guessForRound1;

        enteredGame[msg.sender] = true;
        s_players.push(payable(msg.sender));
        s_playersInRound[1].push(payable(msg.sender));
        moneyPoolForRound[1] += msg.value;

        emit PlayerEntered(msg.sender, block.timestamp);
    }

    function submitGuess(uint8 roundNumber, uint256 guess) external payable {
        require(enteredGame[msg.sender], MustEnterGameFirst());
        require(roundNumber>=1 && roundNumber<=6, InvalidProposal());
        require(msg.value == FEE* uint256(roundNumber-1), FeeNotPaid());

        require(block.timestamp< i_startTime, WindowClosed());

        require(guess>0 && guess<10*roundNumber, InvalidProposal());

        s_playerGuessForRound[msg.sender][roundNumber] = guess;
        moneyPoolForRound[roundNumber] += msg.value;

        s_playersInRound[roundNumber].push(payable(msg.sender));

        emit PlayerProposedGuess(msg.sender, guess, roundNumber);
    }

    function startRound(uint8 roundNumber) public onlyCroupier {
        require(block.timestamp == i_startTime + (roundNumber * i_interval), OutOfTimeBound());
        require(!s_roundStarted[roundNumber], RoundHasBegun());

        uint256 requestId = COORDINATOR.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, /* (blockConfirmations/ timeForOracleToRespond) */
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        requestIdForRound[requestId] = roundNumber;

        s_roundStarted[roundNumber] = true;
    }
    
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords) internal override {
        uint256 secretNumber;
        for(uint8 i=1; i<=6; i++){

            uint256 difficulty = 10**i;
            secretNumber = (randomWords[i-1] % difficulty) + 1; 

            secretNumberOfRound[i] = secretNumber;
            secretNumberIsReady[i] = true;

            s_playersInRound[i] = new address payable[](0);
        }
    }

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a > b) ? (a - b) : (b - a);
    }

    function announceWinners() external onlyCroupier {
        require(block.timestamp>= i_announceTime, TooEarlyToAnnounce());

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
        for (uint8 r=1; r<6; r++){
            uint256 fullReward = (moneyPoolForRound[r])/winnersForRound[r].length;
            uint256 halfReward = (moneyPoolForRound[r])/(winnersForRound[r].length*2);
            for(uint256 i=0; i<winnersForRound[r].length; i++){
                if(s_playerGuessForRound[winnersForRound[r][i]][r] == secretNumberOfRound[r]){
                    (bool rewarded, )= winnersForRound[r][i].call{value: fullReward}("");
                    require (rewarded, RewardingFailed());

                    emit WinnerRewarded(r, winnersForRound[r], fullReward);

                } else {
                    (bool rewarded, )= winnersForRound[r][i].call{value: halfReward}("");
                    require (rewarded, RewardingFailed());

                    emit WinnerRewarded(r, winnersForRound[r], halfReward);
                }
            }
        }
    }
}


// how can this game be destroyed? 
