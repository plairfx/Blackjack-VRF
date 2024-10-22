// SPDX-License-Identifier: MIT

import {Test, console, console2} from "forge-std/Test.sol";
import {BlackJack} from "../../src/Blackjack.sol";
import {DeployScript} from "../../script/DeployScript.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

pragma solidity 0.8.28;

contract BlackJackFuzz is Test {
    ERC20Mock public BJT;
    BlackJack public BJ;
    VRFCoordinatorV2Mock public vrf;

    event GameWon(address winner, uint256 amount);
    event GameLost(address winner, uint256 amount);
    event GameDraw(address winner, uint256 amount);
    event Blackjack(address winner, uint256 amount);
    event BlackjackHouse(uint256 amount);
    event playerBusted(uint8 value, uint256 amount);

    // Gameplay
    event CardDrawnPlayer(uint8 value, uint8 suit);
    event CardDrawnDealer(uint8 value, uint8 suit);

    address alice = makeAddr("user");
    address bob = makeAddr("user2");
    bytes32 keyhash = keccak256("ANY_RANDOM_STRING");

    function setUp() public {
        // address testie = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
        // Deploying contracts

        // setting up chainlink....
        vrf = new VRFCoordinatorV2Mock(100000000000000000, 1000000000);
        uint64 subId = vrf.createSubscription();
        vrf.fundSubscription(subId, 100000000000000000000);

        // Deploy the contracts

        BJT = new ERC20Mock();
        BJ = new BlackJack(BJT, subId, address(vrf), keyhash);

        vrf.addConsumer(subId, address(BJ));

        BJ._shuffleDeck();

        BJT.mint(alice, 100 ether);
        deal(address(BJT), alice, 10 ether);
        deal(address(BJT), bob, 10 ether);
        BJT.mint(alice, 100 ether);
        // BJT.mint(address(test), 100 ether);

        BJT.mint(address(BJ), 100 ether);
        deal(address(BJT), address(BJ), 1000 ether);
        BJT.approve(address(this), type(uint256).max);
    }

    function testFuzzPlay(uint256 amount) public {
        vm.assume(amount < BJT.balanceOf(address(alice)));
        vm.startPrank(alice);
        BJT.approve(address(BJ), amount);
        BJ.play(amount);
    }
}
