// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;
import {IVaultWallet} from "../interfaces/IVaultWallet.sol";
import {VaultRecord} from "../structs/VaultRecord.sol";

interface IVaultRegistry {
    function getVaultByID(
        uint256 vaultID
    ) external view returns (VaultRecord memory vaultRecord);

    function addVaultRecord(
        address owner,
        VaultRecord memory vaultRecord
    ) external;
    function updateVaultRecord(
        uint256 vaultID,
        VaultRecord memory vaultRecord
    ) external;
    function removeVaultRecord(uint256 vaultID) external;
}
