// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IYieldController {
    function getAvailableYield(
        uint256 vaultId,
        IERC20 yieldToken
    ) external view returns (uint256 availableYield_);
    function isValidVault(
        uint256 vaultId
    ) external view returns (bool isValidVault_);

    function claimYield(
        uint256 vaultId,
        IERC20 yieldToken,
        address to
    ) external;
}
