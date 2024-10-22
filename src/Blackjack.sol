// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract BlackJack is VRFConsumerBaseV2Plus {
    IERC20 public BJT;

    // Errors
    error GameHasAlreadyStarted();
    error CardsAmountIs21OrAbove();
    error NotThePlayer();

    struct Cards {
        uint8 value;
        uint8 suit;
    }

    // Chainlink presets..
    bytes32 public keyHash;
    uint64 private subId;
    uint32 public callbackGasLimit = 100000000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 21;
    uint64 s_subscriptionId;
    VRFCoordinatorV2Interface private immutable CoordinatorInterface;

    // Player, House & Owner
    address house;
    address player;
    address owners;

    // Cards
    Cards[] private deck;
    uint8 immutable DECK_SIZE_LIMIT = 52;
    uint8 cardsRemaining;

    // Card Counts
    uint8 playerCards;
    uint8 houseCards;
    uint256 bettingAmount;

    // Game State
    bool gameStarted;
    bool gameStand;
    bool playerBust;
    bool dealerBust;

    // Game Results
    event GameWon(address winner, uint256 amount);
    event GameLost(address winner, uint256 amount);
    event GameDraw(address winner, uint256 amount);
    event Blackjack(address winner, uint256 amount);
    event BlackjackHouse(uint256 amount);
    event playerBusted(uint8 value, uint256 amount);

    // Gameplay
    event CardDrawnPlayer(uint8 value, uint8 suit);
    event CardDrawnDealer(uint8 value, uint8 suit);

    modifier onlyOwners() {
        require(msg.sender == owners);
        _;
    }

    constructor(IERC20 token, uint64 subscriptionId, address _vrfCoordinator, bytes32 KEY_HASH)
        VRFConsumerBaseV2Plus(_vrfCoordinator)
    {
        BJT = IERC20(token);
        s_subscriptionId = subscriptionId;
        keyHash = KEY_HASH;
        owners = msg.sender;
        CoordinatorInterface = VRFCoordinatorV2Interface(_vrfCoordinator);
        BJT.approve(address(this), type(uint256).max);
    }

    /**
     * @dev This function will start the blackjack-game,
     *  this will set the:
     * 1. player
     * 2. bettingAmount
     * 3. change gameStarted to true.
     * Dealer will receive 1 cards,( SecondCard will be finalised after the player does a second action)
     * Player will receive 2 cards.
     */
    function play(uint256 amount) public {
        require(BJT.balanceOf(msg.sender) >= amount, "You do not have enough Balance");
        require(!gameStarted, GameHasAlreadyStarted());

        if (cardsRemaining < 24) {
            _shuffleDeck();
        }

        BJT.transferFrom(msg.sender, address(this), amount);

        gameStarted = true;
        player = msg.sender;
        bettingAmount = amount;

        _requestRandomWords();
        cardsRemaining -= 3;
    }

    /**
     * @dev this is the function lets the user draw a card,
     * only the player who used the _play function can call this function.
     */
    function drawCard() public {
        require(player == msg.sender, NotThePlayer());

        _requestRandomWords();

        cardsRemaining -= 1;
    }

    /**
     * @dev  when a user stand it will stop the game and let the
     * dealer draw and compare the results between the player and the dealer
     */
    function stand() public {
        require(player == msg.sender, NotThePlayer());

        gameStand = true;

        _requestRandomWords();
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) internal override {
        if (gameStand == true) {
            _finishGame(_randomWords);
        } else if (playerCards == 0 && houseCards == 0) {
            _play(_randomWords);
        } else if (playerCards > 0 && houseCards > 0) {
            _drawCard(_randomWords);
        }
    }

    function _requestRandomWords() internal returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = CoordinatorInterface.requestRandomWords(
            keyHash, s_subscriptionId, requestConfirmations, callbackGasLimit, numWords
        );
        return requestId;
    }
    /**
     * @dev this function will be called whne the player goes above 21.
     */

    function _playerBusted(uint256[] memory randomWords) internal {
        // this will finish the game...
        gameStand = true;
        playerBust = true;

        _finishGame(randomWords);
    }

    /**
     * @dev for every card-draw the card will removed from the deck.
     * the removed card will switched with the last card and removed from the array.
     */
    function _removeCard(uint8 value, uint8 suit) internal {
        uint8 index;
        for (index = 0; index < 52; index++) {
            if (deck[index].value == value && deck[index].suit == suit) {
                break;
            }
        }

        require(index < 52, "Card not found in the deck");

        // Swap the card at the found index with the last card
        Cards storage lastCard = deck[deck.length - 1];
        deck[index] = lastCard;

        // Remove the last card
        deck.pop();
    }

    /**
     * @dev this is the function play depends upon, it will use the random value from _fulfillRandomWords (chainlink VRF),
     * and draw unique numbers of the cards and suits.
     * the logic of the queen&king&ace will also depend on this function, read the readMe/docs for more information.
     */
    function _play(uint256[] memory randomWords) internal {
        (uint8 card1, uint8 suit1) = (deck[randomWords[0] % 52].value, deck[randomWords[0] % 52].suit);
        (uint8 card2, uint8 suit2) = (deck[randomWords[1] % 52].value, deck[randomWords[1] % 52].suit);
        (uint8 card3, uint8 suit3) = (deck[randomWords[2] % 52].value, deck[randomWords[2] % 52].suit);

        // Events are emitted before the cards are added, because of the values of K-Q-A are: 11-12-13.
        emit CardDrawnPlayer(card1, suit1);
        emit CardDrawnDealer(card2, suit2);
        emit CardDrawnPlayer(card3, suit3);

        // removing cards...
        _removeCard(card1, suit1);
        _removeCard(card2, suit2);
        _removeCard(card3, suit3);

        // Kings and Queens will always be set to 10, as the cards are added to.
        if (card1 == 11 || card1 == 12) {
            card1 = 10;
        }
        if (card3 == 11 || card3 == 12) {
            card3 = 10;
        }

        // Effects
        playerCards += card1;
        houseCards += card2;

        // Double Ace check card...
        if (card3 == 13 && playerCards == 11) {
            card3 = 1;
        }

        playerCards += card3;

        if (playerCards == 21 && houseCards < 21) {
            _finishGame(randomWords);

            emit Blackjack(player, bettingAmount * 3);
        }
    }

    /**
     * @dev this is the function the drawCards depends on, when requestRandomWOrds is called fulfillRandomWords will call this function, and draw the card.
     */
    function _drawCard(uint256[] memory randomWords) internal {
        (uint8 value, uint8 suit) = (deck[randomWords[0] % 52].value, deck[randomWords[0] % 52].suit);

        emit CardDrawnPlayer(value, suit);
        // removing card...
        _removeCard(value, suit);

        if (value == 11 || value == 12) {
            value = 10;
        }
        if (value == 13) {
            if (playerCards <= 10) {
                value = 11;
            } else if (playerCards >= 11) {
                value = 1;
            }
        }

        playerCards += value;

        if (playerCards > 21) {
            _playerBusted(randomWords);
        }
    }

    /*
     * @dev this begins at the second array  value instead of the first, this is because
     * a situation can arise when a player draws and busts, this will make sure a different randomNumber is being used for drawing the Dealer's cards.
     */

    function _finishGame(uint256[] memory randomWords) internal {
        /// Drawing cards for dealer...

        if (houseCards < 17) {
            (uint8 value, uint8 suit) = (deck[randomWords[1] % 52].value, deck[randomWords[1] % 52].suit);
            emit CardDrawnDealer(value, suit);

            // removing card...
            _removeCard(value, suit);

            if (value == 11 || value == 12) {
                value = 10;
            }
            if (value == 13) {
                if (houseCards <= 10) {
                    value = 11;
                } else if (houseCards >= 11) {
                    value = 1;
                }
            }

            // Effects
            houseCards += value;
            cardsRemaining -= 1;
            if (houseCards > 21) {}
        }
        if (houseCards < 17) {
            (uint8 value, uint8 suit) = (deck[randomWords[2] % 52].value, deck[randomWords[2] % 52].suit);

            emit CardDrawnDealer(value, suit);
            // removing card...
            _removeCard(value, suit);
            if (value == 11 || value == 12) {
                value = 10;
            }
            if (value == 13) {
                if (houseCards <= 10) {
                    value = 11;
                } else if (houseCards >= 11) {
                    value = 1;
                }
            }
            // Effects
            houseCards += value;
            cardsRemaining -= 1;
        }
        if (houseCards < 17) {
            (uint8 value, uint8 suit) = (deck[randomWords[3] % 52].value, deck[randomWords[3] % 52].suit);

            emit CardDrawnDealer(value, suit);
            // removing card...
            _removeCard(value, suit);

            if (value == 11 || value == 12) {
                value = 10;
            }
            if (value == 13) {
                if (houseCards <= 10) {
                    value = 11;
                } else if (houseCards >= 11) {
                    value = 1;
                }
            }

            // Effects
            houseCards += value;
            cardsRemaining -= 1;
        }
        if (houseCards < 17) {
            (uint8 value, uint8 suit) = (deck[randomWords[4] % 52].value, deck[randomWords[4] % 52].suit);

            emit CardDrawnDealer(value, suit);
            // removing card...
            _removeCard(value, suit);

            if (value == 11 || value == 12) {
                value = 10;
            }
            if (value == 13) {
                if (houseCards <= 10) {
                    value = 11;
                } else if (houseCards >= 11) {
                    value = 1;
                }
            }

            houseCards += value;
            cardsRemaining -= 1;
        }
        if (houseCards < 17) {
            (uint8 value, uint8 suit) = (deck[randomWords[5] % 52].value, deck[randomWords[5] % 52].suit);

            emit CardDrawnDealer(value, suit);
            // removing card...
            _removeCard(value, suit);

            if (value == 11 || value == 12) {
                value = 10;
            }
            if (value == 13) {
                if (houseCards <= 10) {
                    value = 11;
                } else if (houseCards >= 11) {
                    value = 1;
                }
            }

            houseCards += value;
            cardsRemaining -= 1;

            emit CardDrawnDealer(value, suit);
        }

        // Finishing the game...

        // Blackjacks checks...

        if (playerCards == 21 && houseCards < 21) {
            BJT.transferFrom(address(this), player, bettingAmount * 3);
            emit Blackjack(player, bettingAmount * 3);
        }

        if (houseCards == 21 && playerCards < 21) {
            emit BlackjackHouse(bettingAmount);
        }

        if (playerBust == true) {
            emit GameLost(player, bettingAmount);
        } else if (playerCards < 22 && houseCards > 21) {
            BJT.transferFrom(address(this), player, bettingAmount * 2);
            emit GameWon(player, bettingAmount * 2);
        } else if (playerCards > houseCards && playerCards < 21) {
            BJT.transferFrom(address(this), player, bettingAmount * 2);

            emit GameWon(player, bettingAmount * 2);

            // When player Draws
        } else if (playerCards == houseCards) {
            BJT.transferFrom(address(this), player, bettingAmount);
            emit GameDraw(player, bettingAmount);

            // When player Loses
        } else if (houseCards > playerCards) {
            emit GameLost(player, bettingAmount);
        }

        // Resetting  to values...
        playerCards = 0;
        houseCards = 0;
        gameStarted = false;
        gameStand = false;
        bettingAmount = 0;
        playerBust = false;
    }

    /**
     * @dev when the cards are less than <24 , it will call shuffle deck,
     * which will delete the current deck and intialize a new one,
     * 0-10 are 1 -> B , 11 = King 12= Queen 13= Ace.
     */
    function _shuffleDeck() public {
        require(cardsRemaining < 24);
        // removing the deck...
        delete deck;
        deck = new Cards[](52);
        // Intializing deck to suit all the cards we need...
        for (uint8 i = 0; i < 52; i++) {
            deck[i] = Cards({value: (i % 13) + 1, suit: (i / 13)});
        }
        cardsRemaining = 52;
    }

    /////////////////////////////////////////////////////
    ////////////// OWNER FUNCTIONS//////////////////
    /////////////////////////////////////////////////////

    function setSubscriptionId(uint64 sub_id) public onlyOwners {
        s_subscriptionId = sub_id;
    }

    function transferOwners(address _owner) public onlyOwners {
        owners = _owner;
    }

    function getOwners() public view returns (address _owner) {
        return owners;
    }

    function getDeck() public view returns (Cards[] memory) {
        return deck;
    }

    function getCard(uint256 index) public view returns (uint8, uint8) {
        Cards memory cards = deck[index];
        return (cards.value, cards.suit);
    }

    function getPlayerCards() public view returns (uint8) {
        return playerCards;
    }

    function getHouseCards() public view returns (uint8) {
        return houseCards;
    }

    function getGameState() public view returns (bool) {
        return gameStarted;
    }

    function getGameStand() public view returns (bool) {
        return gameStand;
    }

    function getSubId() public view returns (uint64) {
        return s_subscriptionId;
    }

    function getPlayer() public view returns (address) {
        return player;
    }

    function getCardsRemaining() public view returns (uint8) {
        return cardsRemaining;
    }

    function getBettingAmount() public view returns (uint256) {
        return bettingAmount;
    }

/**
 * these functions are used for the testing enviorment inside the unit test.
 * these functions below will never get deployed.
 */
    function addCardPlayer(uint8 number) external {
        playerCards += number;
    }

    function addCardDealer(uint8 number) external {
        houseCards += number;
    }

    function setGameStand(bool state) external {
        gameStand = state;
    }

    function addPlayer(address Player) external {
        player = Player;
    }

    function testFulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) external {
        fulfillRandomWords(_requestId, _randomWords);
    }
}
