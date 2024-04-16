// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../../src/interfaces/ICzusdGate.sol";

contract CzusdGateMock is ICzusdGate {
    using SafeERC20 for ERC20Mock;

    ERC20Mock public immutable czusd;
    ERC20Mock public immutable usdt;

    uint256 public sellFeeBasis = 3000;

    constructor(ERC20Mock _czusd, ERC20Mock _usdt) {
        czusd = _czusd;
        usdt = _usdt;
    }

    function usdtIn(uint256 _wad, address _to) external {
        usdt.safeTransferFrom(msg.sender, address(this), _wad);
        czusd.mint(_to, _wad);
    }

    function usdtOut(uint256 _wad, address _to) external {
        czusd.transferFrom(msg.sender, address(this), _wad);
        uint256 fee = (_wad * sellFeeBasis) / 10000;
        usdt.transfer(_to, _wad - fee);
    }

    function setSellFeeBasis(uint256 to) external {
        sellFeeBasis = to;
    }
}
