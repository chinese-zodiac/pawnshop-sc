// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultRegistry} from "../interfaces/IVaultRegistry.sol";
import {IVaultNFT} from "../interfaces/IVaultNFT.sol";
import {IVaultWallet} from "../interfaces/IVaultWallet.sol";
import {VaultRecord} from "../structs/VaultRecord.sol";
import {VaultWallet} from "../VaultWallet.sol";

contract VaultRegistry is IVaultRegistry, AccessControlEnumerable {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    IVaultNFT public immutable vaultNFT;
    mapping(uint256 vaultID => VaultRecord record) public vaultRecords;

    constructor(IVaultNFT _vaultNFT) {
        vaultNFT = _vaultNFT;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //WARNING: View only
    function getAllIDs() external view returns (uint256[] memory allIDs_) {
        uint256 count = getCount();
        allIDs_ = new uint256[](count);
        for (uint256 i; i < count; i++) {
            allIDs_[i] = getIDAt(i);
        }
    }

    function getIsIDInRegistry(
        uint256 vaultID
    ) external view returns (bool isInRegistry_) {
        return vaultNFT.exists(vaultID);
    }
    function getCount() public view returns (uint256 count_) {
        return vaultNFT.totalSupply();
    }
    function getIDAt(
        uint256 index
    ) public view returns (uint256 collateralId_) {
        return vaultNFT.tokenByIndex(index);
    }
    function getVaultByID(
        uint256 vaultID
    ) external view returns (VaultRecord memory vaultRecord) {
        return vaultRecords[vaultID];
    }

    function addVaultRecord(
        address owner,
        VaultRecord memory vaultRecord
    ) external onlyRole(REGISTRAR_ROLE) {
        uint256 vaultID = vaultNFT.mint(owner);
        vaultRecords[vaultID] = vaultRecord;
    }
    function updateVaultRecord(
        uint256 vaultID,
        VaultRecord memory vaultRecord
    ) external onlyRole(REGISTRAR_ROLE) {
        require(vaultNFT.exists(vaultID), "Vault ID not in registry");
        vaultRecords[vaultID] = vaultRecord;
    }
    function removeVaultRecord(
        uint256 vaultID
    ) external onlyRole(REGISTRAR_ROLE) {
        require(vaultNFT.exists(vaultID), "Vault ID not in registry");
        VaultRecord storage record = vaultRecords[vaultID];
        delete record.vaultWallet;
        delete record.collateralID;
        delete record.fullPaymentsStreak;
        delete record.principal;
        delete record.nextPaymentEpoch;
        delete record.nextPaymentInterest;
        delete record.collateralUnlockEpoch;
        delete vaultRecords[vaultID];
        vaultNFT.burn(vaultID);
    }
}
