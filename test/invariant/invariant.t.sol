// SPDX-License-Identifier: MIT

import {Test, console, console2, StdUtils, StdInvariant} from "forge-std/Test.sol";
import {BlackJack} from "../../src/Blackjack.sol";
import {DeployScript} from "../../script/DeployScript.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {Handler} from "../invariant/Handler.t.sol";

pragma solidity 0.8.28;

contract Invariant is Test {
    ERC20Mock public BJT;
    BlackJack public BJ;
    VRFCoordinatorV2Mock public vrf;

    // Events
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
    Handler public handler;

    function setUp() public {
        // setting up contracts...
        vrf = new VRFCoordinatorV2Mock(100000000000000000, 1000000000);
        uint64 subId = vrf.createSubscription();
        vrf.fundSubscription(subId, 100000000000000000000);

        // Deploy the contracts

        BJT = new ERC20Mock();
        BJ = new BlackJack(BJT, subId, address(vrf), keyhash);
        handler = new Handler(BJ, BJT);

        BJT.mint(alice, 100 ether);
        deal(address(BJT), alice, 10 ether);
        deal(address(BJT), bob, 10 ether);
        BJT.mint(alice, 100 ether);

        BJT.mint(address(BJ), 100 ether);
        deal(address(BJT), address(BJ), 1000 ether);
        BJT.approve(address(this), type(uint256).max);

        BJT.mint(address(handler), 100 ether);
        deal(address(BJT), address(handler), 1000 ether);

        // Setup approvals
        vm.prank(address(handler));
        BJT.approve(address(BJ), type(uint256).max);

        vm.prank(alice);
        BJT.approve(address(BJ), type(uint256).max);

        vm.prank(bob);
        BJT.approve(address(BJ), type(uint256).max);

        BJ._shuffleDeck();

        vrf.addConsumer(subId, address(BJ));

        targetContract(address(handler));
    }

    function invariant_Player_Cannot_Change_During_The_Game() public {
        handler.play(10 ether);
        assertEq(address(handler), handler.getCurrentPlayer());
    }

    function invariant_bettingAmount_Cannot_Change_During_A_Game() public {
        handler.play(10 ether);
        assertEq(handler.getBettingAmount(), handler.ba());
    }
}
