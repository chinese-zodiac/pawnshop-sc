// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ERC20BurnableMock is ERC20Mock, ERC20Burnable {}
