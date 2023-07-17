// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test,console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Test.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test{
    /*events*/

    event EnteredRaffle(address indexed player);
    Raffle raffle;
    HelperConfig helperConfig;

        uint256 entraceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 suscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external{
        DeployRaffle deploy = new DeployRaffle();
        (raffle,helperConfig) = deploy.run();
             (
         entraceFee,
         interval,
         vrfCoordinator,
         gasLane,
         suscriptionId,
         callbackGasLimit,
         link,
         deployerKey
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER,STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
    //////////////////////////
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughFee.selector);
        raffle.enterRaffle();
    }
    function testRaffleRecordsPLayerEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entraceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert (playerRecorded == PLAYER);
    }
    function testEmmitsEventsOnEntrance () public{
        vm.prank(PLAYER);
        vm.expectEmit(true,false,false,false,address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value:entraceFee}();
    }
    function testEnterWhenRaffleCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entraceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number +1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entraceFee}();

    }

    //////
    function testCheckUpkeepReturnsIfHasNoBalance ()public{
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert((!upkeepNeeded));
    }
    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entraceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue () public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entraceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);

        raffle.performUpkeep("");
    }

    function terPerformUpkeepRevertIfCheckUpkeepIsFalse() public {
       uint256 currentBalance = 0;
       uint256 numPlayers = 0;
       uint256 raffleState = 0;
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector,currentBalance,numPlayers,raffleState));


        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed () {
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entraceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number+1);
        _;

    }

    function testPerformUpkeepRaffleStateANDEmitsrequestId ()
     public
        raffleEnteredAndTimePassed 
        {
            vm.recordLogs();
            raffle.performUpkeep("");
            Vm.Log[] memory entries = vm.getRecordedLogs();
            bytes32 requestId = entries[1].topics[1];

            Raffle.RaffleState rState = raffle.getRaffleState();

            assert(uint256(requestId)>0);
            assert(uint256(rState) ==1);
        }

        modifier skipFork(){
            if(block.chainid != 31337){
                return;
            }
            else{
                _;
            }

        }
    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256  randomRequestId
    )public raffleEnteredAndTimePassed skipFork{
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            0,address(raffle)
            );
    }
    function testFullFILLrandomWordsPicksAWinnerResetsAndSendMoney () raffleEnteredAndTimePassed skipFork public{
            uint256 additionalEntrants = 5;
            uint256 startingIndex = 1;
            for(uint256 i = startingIndex; i< startingIndex + additionalEntrants; i++){
                address player = address(uint160(i));
                hoax(player,STARTING_USER_BALANCE);
                raffle.enterRaffle{value:entraceFee}();
            }

            uint256 prize = entraceFee *(additionalEntrants *1);            

            vm.recordLogs();
            raffle.performUpkeep("");
            Vm.Log[] memory entries = vm.getRecordedLogs();
            bytes32 requestId = entries[1].topics[1];

            uint256 previousTimeStamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
            );

            assert(uint256(raffle.getRaffleState()) == 0);
            assert(raffle.getRecentWinner() != address(0));
            assert(raffle.getLengthOfPlayers() == 0);
            assert(previousTimeStamp < raffle.getLastTimeStamp());
            console.log(raffle.getRecentWinner().balance);
            console.log(prize+ STARTING_USER_BALANCE);
            assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE +prize);

    }
    }
