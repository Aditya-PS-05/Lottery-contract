// SPDX-License-Identifer: MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();

            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, linkToken);
        }

        vm.startBroadcast();

        Raffle raffle = new Raffle(
            config.entraceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );

        vm.stopBroadcast();

        return (raffle, helperConfig);
    }

    function run() public {
        deployRaffle();
    }
}
