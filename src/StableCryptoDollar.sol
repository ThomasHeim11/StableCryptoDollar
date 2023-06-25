// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title StableCryptoDollar
 * @author Thomas Heim
 * Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 * This is the contract meant to be owned by DSCEngine. It is a ERC20 token that can be minted and burned by the DSCEngine smart contract.
 */

contract StableCryptoDollar is ERC20Burnable, Ownable {
    error StableCryptoDollar__MustBeMoreThanZero();
    error StableCryptoDollar__BurnAmountExeedsBalance();


    constructor() ERC20("StableCryptoDollar", "SCD") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert StableCryptoDollar__MustBeMoreThanZero();
        }
        else if (_amount > balance) {
            revert StableCryptoDollar__BurnAmountExeedsBalance();
        }
        else {
            super.burn(_amount);
        }
    }
}
