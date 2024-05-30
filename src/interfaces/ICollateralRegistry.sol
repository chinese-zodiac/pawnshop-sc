// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILiquidationController} from "../interfaces/ILiquidationController.sol";
import {IBorrowCalculator} from "../interfaces/IBorrowCalculator.sol";
import {IYieldController} from "../interfaces/IYieldController.sol";
import {CollateralRecord} from "../structs/CollateralRecord.sol";

interface ICollateralRegistry {
    function getAllIDs() external view returns (uint256[] memory allIDs_);
    function getIsIDInRegistry(
        uint256 collateralID
    ) external view returns (bool isInRegistry_);
    function getCount() external view returns (uint256 count_);
    function getIDAt(
        uint256 index
    ) external view returns (uint256 collateralId_);
    function getCollateralByID(
        uint256 collateralID
    ) external view returns (CollateralRecord memory collateralRecord);

    function addCollateralRecord(
        CollateralRecord memory collateralRecord
    ) external;
    function updateCollateralRecord(
        uint256 collateralID,
        CollateralRecord memory collateralRecord
    ) external;
    function removeCollateralRecord(uint256 collateralID) external;
}
