// SPDX-License-Identifier: MIT

import {Test, console, console2} from "forge-std/Test.sol";
import {BlackJack} from "../../src/Blackjack.sol";
import {DeployScript} from "../../script/DeployScript.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

pragma solidity 0.8.28;

contract BlackJackTest is Test {
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

    function testIfEveryoneCanCallSetSubId() public {
        vm.prank(alice);
        vm.expectRevert();
        BJ.setSubscriptionId(1);
    }

    function testCanEveryoneSetOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        BJ.transferOwners(alice);
    }

    function test_DoesDrawingCardWork() public {
        console.log(vrf.consumerIsAdded(1, address(BJ)));

        vm.prank(alice);
        BJ.play(0);

        vm.prank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));
    }

    function test_drawcardAfterPlay() public {
        uint256 houseCardsBefore = BJ.getPlayerCards();
        uint256 playerCardsBefore = BJ.getHouseCards();
        vm.prank(alice);
        BJ.play(0);

        vm.prank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));

        vm.prank(alice);
        BJ.drawCard();

        vm.prank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        assert(houseCardsBefore < BJ.getHouseCards());
        assert(playerCardsBefore < BJ.getPlayerCards());
    }

    modifier playerDrawnCard() {
        vm.prank(alice);
        BJ.play(0);

        // shuffle...

        vm.prank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));

        vm.prank(alice);
        BJ.drawCard();

        vm.prank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));
        _;
    }

    modifier playerDrawnCards() {
        uint256 bettingAmount = 10 ether;
        vm.startPrank(alice);
        console.log("Balance Player Before Betting", BJT.balanceOf(alice));
        console.log(address(alice));

        BJT.approve(address(BJ), bettingAmount);
        BJ.play(1 ether);
        vm.stopPrank();
        vm.prank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));

        console.log("AFTER PLAY: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER PLAY: HOUSE_CARDS = ", BJ.getHouseCards());
        console.log("Balance Player After Betting", BJT.balanceOf(alice));

        vm.startPrank(alice);
        BJ.drawCard();
        vm.stopPrank();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        console.log("AFTER FIRST DRAW: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER FIRST DRAW: HOUSE_CARDS = ", BJ.getHouseCards());

        vm.startPrank(alice);

        BJ.drawCard();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(3, address(BJ));

        console.log("AFTER ADDING CARD HOUSE_CARDS = ", BJ.getHouseCards());
        _;
    }

    // Game State Tests

    function test_OtherPlayerCannotJoinWhileGameHasStarted() public playerDrawnCard {
        vm.prank(bob);
        vm.expectRevert();
        BJ.play(0);
    }

    function test_OtherPlayCannotDrawCardWhileGameIsInProgess() public playerDrawnCard {
        vm.prank(bob);
        vm.expectRevert();
        BJ.drawCard();
    }

    function test_playerBustsWhenAbove21() public {
        uint256 balanceHouseBefore = BJT.balanceOf(address(BJ));
        uint256 balancePlayerBefore = BJT.balanceOf(alice);
        uint256 bettingAmount = 10 ether;

        console.log("PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("HOUSE_CARDS = ", BJ.getHouseCards());

        vm.startPrank(alice);
        BJT.approve(address(BJ), type(uint256).max);
        BJ.play(bettingAmount);

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));

        console.log("AFTER PLAY: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER PLAY: HOUSE_CARDS = ", BJ.getHouseCards());

        vm.startPrank(alice);
        BJ.drawCard();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        console.log("AFTER FIRST DRAW: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER FIRST DRAW: HOUSE_CARDS = ", BJ.getHouseCards());

        vm.startPrank(alice);
        BJ.drawCard();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(3, address(BJ));

        console.log("AFTER SECOND DRAW: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER SECOND DRAW: HOUSE_CARDS = ", BJ.getHouseCards());

        vm.startPrank(alice);
        BJ.drawCard();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(4, address(BJ));

        console.log("AFTER THIRD DRAW: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER THIRD DRAW: HOUSE_CARDS = ", BJ.getHouseCards());

        assertEq(BJ.getPlayerCards(), 0);
        assertEq(BJ.getHouseCards(), 0);
        assertEq(balanceHouseBefore + 10 ether, BJT.balanceOf(address(BJ)));
        assertEq(balancePlayerBefore - 10 ether, BJT.balanceOf(alice));
    }

    function test_DealerBustsWhenAbove21() public {
        uint256 balanceHouseBefore = BJT.balanceOf(address(BJ));
        uint256 balancePlayerBefore = BJT.balanceOf(alice);
        uint256 bettingAmount = 10 ether;

        console.log("Balance player Before", BJT.balanceOf(alice));
        console.log("Balance House Before", BJT.balanceOf(address(BJ)));

        vm.startPrank(alice);
        BJT.approve(address(BJ), type(uint256).max);
        BJ.play(bettingAmount);

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));

        vm.startPrank(alice);
        BJ.drawCard();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        vm.startPrank(alice);

        BJ.drawCard();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(3, address(BJ));

        BJ.addCardDealer(9); // we will add a dealer's card... to  make sure the dealer busts...
        console.log("AFTER ADDING CARD HOUSE_CARDS = ", BJ.getHouseCards());
        console.log("PLAYER_CARDS = ", BJ.getPlayerCards());

        vm.startPrank(alice);
        BJ.stand();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(4, address(BJ));

        console.log("Balance player after", BJT.balanceOf(alice));
        console.log("Balance House after", BJT.balanceOf(address(BJ)));

        // Asserts
        assertEq(BJ.getPlayerCards(), 0);
        assertEq(BJ.getHouseCards(), 0);
        assertEq(balancePlayerBefore + bettingAmount, BJT.balanceOf(address(alice)));
        assertEq(balanceHouseBefore - bettingAmount, BJT.balanceOf(address(BJ)));
    }

    /////////////////////////////////////////////////////////
    ////////////// PLAYER WINS /////////////////////////////
    ////////////////////////////////////////////////////////

    function test_PlayerWinsAndReceivesRewards() public {
        uint256 bettingAmount = 10 ether;
        vm.startPrank(alice);
        console.log("Balance Player Before Betting", BJT.balanceOf(alice));
        console.log(address(alice));

        BJT.approve(address(BJ), bettingAmount);
        BJ.play(1 ether);
        vm.stopPrank();
        vm.prank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));

        console.log("AFTER PLAY: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER PLAY: HOUSE_CARDS = ", BJ.getHouseCards());
        console.log("Balance Player After Betting", BJT.balanceOf(alice));

        vm.startPrank(alice);
        BJ.drawCard();
        vm.stopPrank();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        console.log("AFTER FIRST DRAW: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER FIRST DRAW: HOUSE_CARDS = ", BJ.getHouseCards());

        vm.startPrank(alice);

        BJ.drawCard();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(3, address(BJ));

        console.log("AFTER ADDING CARD HOUSE_CARDS = ", BJ.getHouseCards());

        vm.startPrank(alice);

        BJ.stand();

        vm.startPrank(address(vrf));

        vrf.fulfillRandomWords(4, address(BJ));
    }

    /////////////////////////////////////////////////////////
    ////////////// BLACKJACK PLAYER/DEALER //////////////////
    ////////////////////////////////////////////////////////

    function test_DealerHasBlackJackandDealerWins() public {
        uint256 bettingAmount = 10 ether;
        vm.startPrank(alice);
        console.log("Balance Player Before Betting", BJT.balanceOf(alice));
        console.log(address(alice));

        BJT.approve(address(BJ), bettingAmount);
        BJ.play(bettingAmount);
        vm.stopPrank();
        vm.prank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));

        console.log("AFTER PLAY: PLAYER_CARDS = ", BJ.getPlayerCards());
        console.log("AFTER PLAY: HOUSE_CARDS = ", BJ.getHouseCards());
        console.log("Balance Player After Betting", BJT.balanceOf(alice));

        vm.startPrank(alice);
        BJ.drawCard();
        vm.stopPrank();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        BJ.addCardDealer(14);

        console.log("AFTER ADDING CARD HOUSE_CARDS = ", BJ.getHouseCards());
        console.log("AFTER PLAY: PLAYER_CARDS = ", BJ.getPlayerCards());

        vm.startPrank(alice);

        BJ.stand();

        vm.startPrank(address(vrf));
        vm.expectEmit(true, true, false, false);
        emit BlackjackHouse(bettingAmount);
        vm.expectEmit(true, true, true, true);
        emit GameLost(address(alice), bettingAmount);

        vrf.fulfillRandomWords(3, address(BJ));
    }

    function test_PlayerHasBlackJackandPlayerWins() public {
        BJ.addPlayer(alice);
        BJ.addCardPlayer(21);
        console.log("Before Player Cards:", BJ.getPlayerCards());
        console.log("Before House Cards:", BJ.getHouseCards());

        vm.startPrank(alice);

        BJ.stand();

        vm.startPrank(address(vrf));
        vm.expectEmit(true, true, true, true);
        emit Blackjack(address(alice), 0);

        vrf.fulfillRandomWords(1, address(BJ));

        console.log("Player Cards:", BJ.getPlayerCards());
        console.log("House Cards:", BJ.getHouseCards());
    }

    /////////////////////////////////////////////////////////////////
    ////////////// KING/QUEEN/ACE CARDS /////////////////////////////
    /////////////////////////////////////////////////////////////////

    function test_WhenDealerHasAnotherAce_PlayerShouldGet12Instead() public {
        BJ.addPlayer(alice);
        BJ.addCardPlayer(11);
        BJ.addCardDealer(11);

        vm.startPrank(alice);

        BJ.stand();

        vm.stopPrank();
        vm.prank(address(vrf));

        // player should have.. 11 and stand afterwards.
        // dealer will get 21, 11+2+8
        // player will have 11..

        // testing...
        uint256[] memory randomWords = new uint256[](5);
        randomWords[0] = 12;
        randomWords[1] = 25;
        randomWords[2] = 33;
        randomWords[3] = 44;
        randomWords[4] = 55;
        console.log(BJ.getPlayerCards());

        // checking to see if the expected events and values emit...
        vm.expectEmit(true, true, true, true);
        emit CardDrawnDealer(13, 1);
        vm.expectEmit(true, true, true, true);
        emit CardDrawnDealer(8, 2);
        vm.expectEmit(true, true, true, true);
        emit GameLost(address(alice), 0);

        BJ.testFulfillRandomWords(0, randomWords);
    }

    function test_WhenPlayerHasAnotherAce_PlayerShouldGet12Instead() public {
        BJ.addPlayer(alice);
        BJ.addCardPlayer(11);
        BJ.addCardDealer(11);

        uint8 beforeDraw = BJ.getPlayerCards();

        vm.startPrank(alice);

        BJ.drawCard();

        vm.stopPrank();
        vm.prank(address(vrf));

        // testing...w
        uint256[] memory randomWords = new uint256[](5);
        randomWords[0] = 12;
        randomWords[1] = 22;
        randomWords[2] = 33;
        randomWords[3] = 44;
        randomWords[4] = 55;

        vm.expectEmit(true, true, true, true);
        emit CardDrawnPlayer(13, 0);

        BJ.testFulfillRandomWords(0, randomWords);

        assertEq((BJ.getPlayerCards() - beforeDraw), 1);
        assertEq(BJ.getCardsRemaining(), 51);
    }

    function test_CardsKingShouldBe10AndNot12() public {
        BJ.addPlayer(alice);
        BJ.addCardPlayer(11);
        BJ.addCardDealer(11);

        uint8 beforeDraw = BJ.getPlayerCards();

        vm.startPrank(alice);

        BJ.drawCard();

        vm.stopPrank();
        vm.prank(address(vrf));

        // testing...
        uint256 requestId = 11;
        uint256[] memory randomWords = new uint256[](5);
        randomWords[0] = 11;
        randomWords[1] = 22;
        randomWords[2] = 33;
        randomWords[3] = 44;
        randomWords[4] = 55;
        console.log(BJ.getPlayerCards());

        BJ.testFulfillRandomWords(0, randomWords);

        console.log(BJ.getPlayerCards());

        assertEq((BJ.getPlayerCards() - beforeDraw), 10);
        assertEq(BJ.getCardsRemaining(), 51);
    }

    function test_CardsQueenShouldBe10AndNot12() public {
        BJ.addPlayer(alice);
        BJ.addCardPlayer(11);
        BJ.addCardDealer(11);

        uint8 beforeDraw = BJ.getPlayerCards();

        vm.startPrank(alice);

        BJ.drawCard();

        vm.stopPrank();
        vm.prank(address(vrf));

        // testing...
        uint256 requestId = 11;
        uint256[] memory randomWords = new uint256[](5);
        randomWords[0] = 10;
        randomWords[1] = 22;
        randomWords[2] = 33;
        randomWords[3] = 44;
        randomWords[4] = 55;
        console.log(BJ.getPlayerCards());

        BJ.testFulfillRandomWords(0, randomWords);

        console.log(BJ.getPlayerCards());

        assertEq((BJ.getPlayerCards() - beforeDraw), 10);
        assertEq(BJ.getCardsRemaining(), 51);
    }

    function test_WhenAceIsAddedUnder10ItWillEqual11() public {
        BJ.addPlayer(alice);
        BJ.addCardPlayer(9);
        BJ.addCardDealer(11);

        uint8 beforeDraw = BJ.getPlayerCards();

        vm.startPrank(alice);

        BJ.drawCard();

        vm.stopPrank();
        vm.prank(address(vrf));

        // testing...
        uint256 requestId = 11;
        uint256[] memory randomWords = new uint256[](5);
        randomWords[0] = 11;
        randomWords[1] = 22;
        randomWords[2] = 33;
        randomWords[3] = 44;
        randomWords[4] = 55;
        console.log(BJ.getPlayerCards());

        BJ.testFulfillRandomWords(0, randomWords);

        console.log(BJ.getPlayerCards());

        assertEq((BJ.getPlayerCards() - beforeDraw), 10);
        assertEq(BJ.getCardsRemaining(), 51);
    }

    /////////////////////////////////////////////////////////
    ////////////// REMOVE CARD/S /////////////////////////////
    ////////////////////////////////////////////////////////

    function test_CardsRemovedWhenDrawingACard() public {
        BJ.addPlayer(alice);
        BJ.addCardPlayer(9);
        BJ.addCardDealer(11);

        (uint8 value, uint8 suit) = BJ.getCard(12);
        uint8 beforeDraw = BJ.getPlayerCards();

        vm.startPrank(alice);

        BJ.drawCard();

        vm.stopPrank();
        vm.prank(address(vrf));

        // testing...
        uint256 requestId = 11;
        uint256[] memory randomWords = new uint256[](5);
        randomWords[0] = 12;
        randomWords[1] = 22;
        randomWords[2] = 33;
        randomWords[3] = 44;
        randomWords[4] = 55;
        console.log(BJ.getPlayerCards());

        BJ.testFulfillRandomWords(0, randomWords);

        assertEq(BJ.getCardsRemaining(), 51);
        assert(value == 13 && suit == 0);

        (uint8 value1, uint8 suit1) = BJ.getCard(12);

        assert(value1 == 13 && suit1 != 0);

        vm.expectRevert();
        BJ.getCard(51);
    }

    function test_CardsRemovedWhenFinshingTheGame() public {
        BJ.addPlayer(alice);
        BJ.addCardPlayer(9);
        BJ.addCardDealer(10);

        (uint8 value, uint8 suit) = BJ.getCard(25);
        uint8 beforeDraw = BJ.getPlayerCards();

        vm.startPrank(alice);

        BJ.stand();

        vm.stopPrank();
        vm.prank(address(vrf));

        // testing...
        uint256 requestId = 11;
        uint256[] memory randomWords = new uint256[](5);
        randomWords[0] = 12;
        randomWords[1] = 25;
        randomWords[2] = 33;
        randomWords[3] = 44;
        randomWords[4] = 55;
        console.log(BJ.getPlayerCards());

        BJ.testFulfillRandomWords(0, randomWords);

        assertEq(BJ.getCardsRemaining(), 51);
        assert(value == 13 && suit == 1);

        (uint8 value1, uint8 suit1) = BJ.getCard(25);

        assert(value1 == 13 && suit1 != 0);

        vm.expectRevert();
        BJ.getCard(51);
    }

    function test_drawCardShouldRemoveCardandRemainingCards() public {
        uint256 bettingAmount = 10 ether;
        vm.startPrank(alice);

        BJT.approve(address(BJ), bettingAmount);
        BJ.play(bettingAmount);
        vm.stopPrank();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));
        assertEq(BJ.getCardsRemaining(), 49);

        vm.startPrank(alice);
        BJ.drawCard();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        assertEq(BJ.getCardsRemaining(), 48);
        assertEq(BJ.getDeck().length, 48);
    }

    /////////////////////////////////////////////////////
    ////////////// HELPER/GET FUNCTIONS//////////////////
    /////////////////////////////////////////////////////

    function test_getDeck() public {
        // dekc already shuffled in setup-.
        assertEq(BJ.getDeck().length, 52);
    }

    function test_getPlayerCards() public {
        BJ.addCardPlayer(21);

        assertEq(BJ.getPlayerCards(), 21);
    }

    function test_getHouseCards() public {
        BJ.addCardDealer(17);

        assertEq(BJ.getHouseCards(), 17);
    }

    function test_getGameState() public {
        uint256 bettingAmount = 10 ether;
        vm.startPrank(alice);

        BJT.approve(address(BJ), bettingAmount);
        BJ.play(1 ether);
        vm.stopPrank();
        vm.prank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));

        vm.startPrank(alice);
        BJ.drawCard();
        vm.stopPrank();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        vm.startPrank(bob);
        vm.expectRevert();
        BJ.play(bettingAmount);

        assertEq(BJ.getGameState(), true);
    }

    function test_getCardsRemaining() public {
        // it should
        uint8 cardsRemaining = BJ.getCardsRemaining();

        assertEq(cardsRemaining, 52);
    }

    function test_getDeckTestFunction() public {
        (uint8 value, uint8 suit) = BJ.getCard(12);

        assert(value == 13 && suit == 0);
    }

    ///////////////////////////////////////////////
    ////////////// TEST FUNCTIONS//////////////////
    ///////////////////////////////////////////////

    function test_addDealerCardTestFunction() public {
        BJ.addCardDealer(1);

        assertEq(1, BJ.getHouseCards());
    }

    function test_addCardToPlayerTestFunction() public {
        BJ.addCardPlayer(1);

        assertEq(1, BJ.getPlayerCards());
    }

    function test_fixIssueWeirdAddy() public {
        deal(address(BJT), bob, 100 ether);
        uint256 bettingAmount = 10 ether;
        vm.startPrank(bob);
        console.log("Balance Player Before Betting", BJT.balanceOf(bob));
        BJT.approve(address(BJ), bettingAmount);
        console.log(address(BJ), address(BJT), address(bob));
        console.log(address(bob));

        BJ.play(1 ether);
        vm.stopPrank();
        vm.prank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));
    }

    function test_addPlayerTestFunction() public {
        vm.startPrank(alice);
        BJ.addPlayer(alice);

        assertEq(BJ.getPlayer(), address(alice));
    }

    function test_setGameStandTestFunction() public {
        vm.startPrank(alice);
        BJ.setGameStand(true);

        assertEq(BJ.getGameStand(), true);
    }

    function test_getBettingAmountTestFunction() public {
        uint256 bettingAmount = 10 ether;
        vm.startPrank(alice);

        BJT.approve(address(BJ), bettingAmount);
        BJ.play(bettingAmount);
        vm.stopPrank();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(1, address(BJ));
        assertEq(BJ.getCardsRemaining(), 49);

        vm.startPrank(alice);
        BJ.drawCard();

        vm.startPrank(address(vrf));
        vrf.fulfillRandomWords(2, address(BJ));

        uint256 amount = BJ.getBettingAmount();

        assertEq(bettingAmount, amount);
    }
}
