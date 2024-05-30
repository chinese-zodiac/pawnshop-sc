// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

interface IBorrowCalculator {
    function getMaxBorrow(
        uint256 vaultID
    ) external view returns (int256 maxBorrow_);
    function getAvailableBorrow(
        uint256 vaultID
    ) external view returns (uint256 availableBorrow_);
    function isValidVault(
        uint256 vaultID
    ) external view returns (bool isValidVault_);
}
