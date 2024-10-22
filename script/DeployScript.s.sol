// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {BlackJackToken} from "../src/BJT.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BlackJack} from "../src/Blackjack.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

pragma solidity 0.8.28;

contract DeployScript is Script {
    ERC20Mock public BJT;
    BlackJack public BJ;
    VRFCoordinatorV2Mock public vrf;
    bytes32 keyhash = keccak256("ANY_RANDOM_STRING");

    function run() external {
        vm.startBroadcast();

        // setting up chainlink....
        vrf = new VRFCoordinatorV2Mock(10, 10);
        uint64 subId = vrf.createSubscription();

        vrf.fundSubscription(subId, 100000000000000000000);

        // Deploy the contracts

        BJT = new ERC20Mock();
        BJ = new BlackJack(BJT, 1, address(vrf), keyhash);

        vrf.addConsumer(subId, address(BJ));

        vm.stopBroadcast();
    }
}
