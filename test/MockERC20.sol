// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
  
  uint8 internal _decimals;

  constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
      _decimals = decimals_;
    }
    
  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }
}