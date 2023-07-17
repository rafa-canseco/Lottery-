// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {VRFCoordinatorV2Interface} from  "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";


/**
*@title A sample raffle contract
*@author Rafa Canseco
*@notice this contract is for creating a sample raffle
*@dev implements Chainlink VRFv2
*/

contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughFee();
    error Raffle__TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPLayers,
        uint256 raffleState
        );

    /**Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**Constant */

    /**State Variables */

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS =1;
    uint256 private immutable i_entraceFee;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    address payable[] private s_players;
    uint256 private immutable i_interval;
    bytes32 private immutable i_gasLane;
    uint256 private s_lastTimeStamp;
    uint64  private immutable i_suscriptionId;
    uint32  private immutable i_callbackGasLimit;
    address private s_reccentWinner;
    RaffleState private s_raffleState;


    /**Events */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor (
        uint256 entraceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 suscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator){
        i_entraceFee = entraceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_suscriptionId = suscriptionId;
        s_raffleState = RaffleState.OPEN;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entraceFee){
            revert Raffle_NotEnoughFee();
        }
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle_RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    
    function checkUpkeep(
        bytes memory 
        ) public view returns ( bool upkeepNeeded, bytes memory){
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded =( timeHasPassed && isOpen && hasBalance &&hasPlayers);
        return(upkeepNeeded,"0x0");
        }
    

    function performUpkeep(bytes calldata) external {
        (bool upkeepNedeed,) = checkUpkeep("");
        if(!upkeepNedeed){
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState= RaffleState.CALCULATING;
        uint256 requestId=i_vrfCoordinator.requestRandomWords(
            i_gasLane, // GAS
            i_suscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }
        function fulfillRandomWords(
            uint256 /*requestId*/,
            uint256[] memory randomWords
        ) internal override {

        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_reccentWinner = winner;
        s_raffleState =RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);
        (bool success,) = winner.call{value:address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }


        }


    /**Getter function */
    function getEntraceFee() external view returns(uint256){
        return i_entraceFee;
    }
    
    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }
    function getPlayer (uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];

    }

    function getRecentWinner () external view returns(address){
       return s_reccentWinner;

    }

    function getLengthOfPlayers () external view returns (uint256){
        return s_players.length;
    }

    function getLastTimeStamp () external view returns (uint256){
        return s_lastTimeStamp;
    }
}