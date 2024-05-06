// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20MintableBurnable is IERC20 {

    function mint(address to, uint256 amount) external;
    function burn(uint256 value) external;
    function burnFrom(address account, uint256 value) external;

}
