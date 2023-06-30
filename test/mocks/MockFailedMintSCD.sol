// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockFailedMintSCD
 * @dev This contract is a mock implementation of a StableCryptoDollar (SCD) token that can be burned and minted by the owner.
 */
contract MockFailedMintSCD is ERC20Burnable, Ownable {
    error StableCryptoDollar_AmountMustBeMoreThanZero();
    error StableCryptoDollar__BurnAmountExceedsBalance();
    error StableCryptoDollar__NotZeroAddress();

    /**
     * @dev Initializes the SCD token with the name "StableCryptoDollar" and the symbol "SCD".
     */
    constructor() ERC20("StableCryptoDollar", "SCD") {}

    /**
     * @dev Burns a specified amount of SCD tokens.
     * @param _amount The amount of SCD tokens to burn.
     * throws StableCryptoDollar_AmountMustBeMoreThanZero if the `_amount` parameter is less than or equal to zero.
     * throws StableCryptoDollar__BurnAmountExceedsBalance if the `_amount` parameter is greater than the balance of the caller.
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert StableCryptoDollar_AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert StableCryptoDollar__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    /**
     * @dev Mints a specified amount of SCD tokens to a specified address.
     * @param _to The address to mint the SCD tokens to.
     * @param _amount The amount of SCD tokens to mint.
     * @return false
     * throws StableCryptoDollar__NotZeroAddress if the `_to` parameter is the zero address.
     * throws StableCryptoDollar_AmountMustBeMoreThanZero if the `_amount` parameter is less than or equal to zero.
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert StableCryptoDollar__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert StableCryptoDollar_AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return false;
    }
}
