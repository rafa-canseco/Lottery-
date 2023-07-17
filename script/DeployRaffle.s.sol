// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";
import {CreateSubscription,FundSubscription,AddConsumer} from "./Interactions.s.sol";
contract DeployRaffle is Script {

    function run() external returns(Raffle, HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        (
        uint256 entraceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 suscriptionId,
        uint32 callbackGasLimit,
        address link,
        uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if(suscriptionId == 0){
            CreateSubscription createSubscription = new CreateSubscription();
            suscriptionId = createSubscription.createSubscription(
                vrfCoordinator,deployerKey);
        
        

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            vrfCoordinator, suscriptionId, link,deployerKey);
        }


    
    vm.startBroadcast();
    Raffle raffle = new Raffle(
        entraceFee,
        interval,
        vrfCoordinator,
        gasLane,
        suscriptionId,
        callbackGasLimit
    );
    vm.stopBroadcast();

    AddConsumer addConsumer = new AddConsumer();
    addConsumer.addConsumer(address(raffle),vrfCoordinator,suscriptionId,deployerKey);

    return (raffle,helperConfig);
    }
}