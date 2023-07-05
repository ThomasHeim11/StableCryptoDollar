// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
.

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockV3Aggregator} from "./MockV3Aggregator.sol";

/**
 * @title StableCryptoDollar
 * @dev This contract represents a decentralized stablecoin that is collateralized by crypto assets. It is an ERC20 token
 *      that can be minted and burned by the SCDEngine smart contract.
 */

contract MockMoreDebtSCD is ERC20Burnable, Ownable {
    error StableCryptoDollar__AmountMustBeMoreThanZero();
    error StableCryptoDollar__BurnAmountExceedsBalance();
    error StableCryptoDollar_NotZeroAddress();

    address mockAggregator;

    /**
     * @dev Initializes the StableCryptoDollar contract.
     * @param _mockAggregator The address of the mock aggregator contract.
     */
    constructor(address _mockAggregator) ERC20("StableCryptoDollar", "SCD") {
        mockAggregator = _mockAggregator;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param _amount The amount of tokens to be burned.
     * @notice The price is crashed by updating the answer in the mock aggregator.
     */
    function burn(uint256 _amount) public override onlyOwner {
        // We crash the price
        MockV3Aggregator(mockAggregator).updateAnswer(0);
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert StableCryptoDollar__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert StableCryptoDollar__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    /**
     * @dev Mints new tokens and assigns them to the specified address.
     * @param _to The address to which new tokens will be minted and assigned.
     * @param _amount The amount of tokens to be minted.
     * @return A boolean indicating whether the minting was successful.
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert StableCryptoDollar_NotZeroAddress();
        }
        if (_amount <= 0) {
            revert StableCryptoDollar__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
