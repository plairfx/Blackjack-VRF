// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {BlackJackToken} from "../src/BJT.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BlackJack} from "../src/Blackjack.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

pragma solidity 0.8.28;

contract DeployScript is Script {
    ERC20Mock public BJT;
    BlackJack public BJ;
    // VRFCoordinatorV2Mock public vrf;
    VRFCoordinatorV2_5Mock public vrf;
    BlackJackToken public BJT2;
    VRFConsumerBaseV2Plus public vrf2;

    bytes32 keyhash = keccak256("ANY_RANDOM_STRING");
    string anvil = "http://127.0.0.1:8545";

    // // Constants for Sepolia // V2
    // address constant COORDINATOR_ADDRESS = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    // bytes32 constant KEYHASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    // uint64 constant SUBSCRIPTION_ID = 12171; // Your existing subscription ID

    // Constants For sepolia VRF 2.5

    address constant VRF = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 constant keyhashie = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 subId = 86598933470644584028996293341249180815532749963224879926181176505211467024199;

    function run() external {
        if (block.chainid == 11155111) {
            vm.startBroadcast();

            BJT2 = new BlackJackToken(msg.sender);

            BJ = new BlackJack(BJT2, subId, VRF, keyhashie);

            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            // setting up chainlink....cl

            vrf = new VRFCoordinatorV2_5Mock(10, 10, 4701000330007423);

            vrf.createSubscription();

            vrf.fundSubscription(1, 100000000000000000000);

            // Deploy the contracts

            BJT = new ERC20Mock();
            BJ = new BlackJack(BJT, 1, address(vrf), keyhash);

            vrf.addConsumer(1, address(BJ));

            vm.stopBroadcast();
        }
    }
}
