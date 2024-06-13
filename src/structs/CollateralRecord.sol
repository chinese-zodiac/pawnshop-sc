// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILiquidationController} from "../interfaces/ILiquidationController.sol";
import {IBorrowCalculator} from "../interfaces/IBorrowCalculator.sol";
import {IYieldController} from "../interfaces/IYieldController.sol";

struct CollateralRecord {
    IERC20 collateral;
    IBorrowCalculator borrowCalculator;
    ILiquidationController liquidationController;
    IYieldController yieldController;
    uint256 currentBorrow;
    uint256 additionalGlobalBorrowCap;
}
