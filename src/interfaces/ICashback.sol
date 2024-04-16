// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

interface ICashback {
    function addCzusdToDistribute(address _to, uint256 _wad) external;
}
