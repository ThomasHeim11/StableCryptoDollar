// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockFailedMintSCD is ERC20Burnable, Ownable {
    error StableCryptoDollar_AmountMustBeMoreThanZero();
    error StableCryptoDollar__BurnAmountExceedsBalance();
    error StableCryptoDollar__NotZeroAddress();

    constructor() ERC20("StableCryptoDollar", "SCD") {}

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
