// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

interface ICzusdGate {
    function usdtIn(uint256 _wad, address _to) external;

    function usdtOut(uint256 _wad, address _to) external;
}
