// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;
import {IVaultWallet} from "../interfaces/IVaultWallet.sol";

interface IVaultRegistry {
    function getVaultByID(
        uint256 vaultId
    )
        external
        view
        returns (
            address owner,
            IVaultWallet vaultWallet,
            uint256 collateralID,
            uint256 principalPaymentsStreak,
            uint256 principal,
            uint256 nextPaymentEpoch,
            uint256 nextPaymentInterest
        );

    function addVaultRecord(
        address owner,
        IVaultWallet vaultWallet,
        uint256 collateralID,
        uint256 principalPaymentsStreak,
        uint256 principal,
        uint256 nextPaymentEpoch,
        uint256 nextPaymentInterest
    ) external;
    function updateVaultRecord(
        uint256 vaultId,
        IVaultWallet vaultWallet,
        uint256 collateralID,
        uint256 principalPaymentsStreak,
        uint256 principal,
        uint256 nextPaymentEpoch,
        uint256 nextPaymentInterest
    ) external;
    function addPrincipal(
        uint256 vaultId,
        uint256 wad
    ) external returns (uint256 newPrincipal);
    function subPrincipal(
        uint256 vaultId,
        uint256 wad
    ) external returns (uint256 newPrincipal);
    function setNextPaymentEpoch(uint256 vaultId, uint256 to) external;
    function setNextPaymentInterest(uint256 vaultId, uint256 to) external;
    function incrementPrincipalPaymentsStreak(uint256 vaultId) external;
    function resetPrincipalPaymentsStreak(uint256 vaultId) external;
    function removeVaultRecord(uint256 vaultId) external;
}
