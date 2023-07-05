// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockFailedTransfer
 * @dev This contract is a mock implementation of a decentralized stable coin that fails transfers.
 */
contract MockFailedTransfer is ERC20Burnable, Ownable {
    error StableCryptoDollar___AmountMustBeMoreThanZero();
    error StableCryptoDollar___BurnAmountExceedsBalance();
    error StableCryptoDollar___NotZeroAddress();

    /**
     * @dev Constructor that sets the name and symbol of the token.
     */
    constructor() ERC20("StableCryptoDollar", "SCD") {}

    /**
     * @dev Burns a specific amount of tokens.
     * @param _amount The amount of token to be burned.
     * @notice Only the owner of the contract can call this function.
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert StableCryptoDollar___AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert StableCryptoDollar___BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    /**
     * @dev Creates `amount` new tokens for `account`.
     * @param account The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     * @notice This function can be called by anyone.
     */
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    /**
     * @dev Overrides the transfer function to always fail.
     * @return A boolean value indicating whether the transfer was successful or not.
     */
    function transfer(address, /*recipient*/ uint256 /*amount*/ ) public pure override returns (bool) {
        return false;
    }
}
