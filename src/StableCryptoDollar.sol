// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/** 
 * @title DecentralizedStableCoin
 * @author Patrick Collins
 * @notice Collateral: Exogenous
 * @notice Minting (Stability Mechanism): Decentralized (Algorithmic)
 * @notice Value (Relative Stability): Anchored (Pegged to USD)
 * @notice Collateral Type: Crypto
 *
 * @dev This is the contract meant to be owned by DSCEngine. It is an ERC20 token that can be minted and burned by the DSCEngine smart contract.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") {}

    /**
     * @notice Burns a specific amount of tokens owned by the contract owner.
     * @param _amount The amount of tokens to be burned.
     * @dev Throws an error if `_amount` is less than or equal to zero or if the owner's balance is insufficient.
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    /**
     * @notice Mints new tokens and assigns them to a specific address.
     * @param _to The address to which the newly minted tokens will be assigned.
     * @param _amount The amount of tokens to be minted.
     * @return A boolean value indicating whether the minting was successful.
     * @dev Throws an error if `_to` address is zero or if `_amount` is less than or equal to zero.
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
