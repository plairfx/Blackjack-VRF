// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BlackJackToken is ERC20, Ownable {
    constructor(address initialOwner) ERC20("BlackJackToken", "BJT") Ownable(initialOwner) {}
}

// lets setup this later.
