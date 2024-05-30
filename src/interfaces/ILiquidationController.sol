// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

interface ILiquidationController {
    function getLiquidationLimit(
        uint256 vaultID
    ) external view returns (uint256 liquidationLimit_);
    function getCanScheduleLiquidation(
        uint256 vaultID
    ) external view returns (bool canLiquidate_);
    function getIsLiquidationScheduled(
        uint256 vaultID
    ) external view returns (bool isLiquidationScheduled);
    function getCanLiquidate(
        uint256 vaultID
    ) external view returns (bool canLiquidate_);
    function getIsValidVault(
        uint256 vaultID
    ) external view returns (bool isValidVault_);

    function scheduleLiquidation(uint256 vaultID) external;
    function cancelLiquidation(uint256 vaultID) external;
    function executeLiquidation(uint256 vaultID) external;
}
