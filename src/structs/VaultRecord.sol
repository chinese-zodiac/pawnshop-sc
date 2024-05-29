// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;
import {IVaultWallet} from "../interfaces/IVaultWallet.sol";

struct VaultRecord {
    IVaultWallet vaultWallet;
    uint256 collateralID;
    uint256 principalPaymentsStreak;
    uint256 principal;
    uint256 nextPaymentEpoch;
    uint256 nextPaymentInterest;
}
