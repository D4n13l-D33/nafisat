// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract SoccerERC20 is ERC20 {
    constructor() ERC20("SoccerERC20", "SOC20"){
        _mint(msg.sender, 100000 * 10 ** 18);
    }
}
