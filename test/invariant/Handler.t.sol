//SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {Test, console} from "forge-std/Test.sol";
import {BlackJack} from "../../src/Blackjack.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    BlackJack private bj;
    ERC20Mock public BJT;

    bool public played;
    address public currentPlayer;
    uint256 public ba;

    constructor(BlackJack _BJ, ERC20Mock _token) {
        bj = _BJ;
        BJT = _token;
    }

    function play(uint256 amount) public {
        if (!played) {
            currentPlayer = address(this);

            amount = bound(amount, 0, BJT.balanceOf(address(this)));
            ba = amount;
            bj.play(amount);
            played = true;
        }
    }

    function drawCard() public {
        if (msg.sender == currentPlayer) {
            bj.drawCard();
        }
    }

    function stand() public {
        if (msg.sender == currentPlayer) {
            bj.stand();
        }
    }

    function getCurrentPlayer() public view returns (address) {
        return currentPlayer;
    }

    function getBettingAmount() public view returns (uint256) {
        uint256 bettingAmount = bj.getBettingAmount();

        return bettingAmount;
    }

    function getCard(uint8 index) public view returns (uint8, uint8) {
        bj.getCard(index);
    }

    function getPlayerCards() public view returns (uint8) {
        return bj.getPlayerCards();
    }

    function getHouseCards() public view returns (uint8) {
        return bj.getHouseCards();
    }
}
