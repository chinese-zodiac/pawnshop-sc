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
    mapping(uint256 vaultId => VaultRecord record) public vaultRecords;

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
        uint256 vaultId
    ) external view returns (bool isInRegistry_) {
        return vaultNFT.exists(vaultId);
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
        )
    {
        VaultRecord memory record = vaultRecords[vaultId];
        owner = vaultNFT.ownerOf(vaultId);
        vaultWallet = record.vaultWallet;
        collateralID = record.collateralID;
        principalPaymentsStreak = record.principalPaymentsStreak;
        principal = record.principal;
        nextPaymentEpoch = record.nextPaymentEpoch;
        nextPaymentInterest = record.nextPaymentInterest;
    }

    function addVaultRecord(
        address owner,
        IVaultWallet vaultWallet,
        uint256 collateralID,
        uint256 principalPaymentsStreak,
        uint256 principal,
        uint256 nextPaymentEpoch,
        uint256 nextPaymentInterest
    ) external onlyRole(REGISTRAR_ROLE) {
        uint256 vaultId = vaultNFT.mint(owner);
        VaultRecord storage record = vaultRecords[vaultId];
        record.vaultWallet = vaultWallet;
        record.collateralID = collateralID;
        record.principalPaymentsStreak = principalPaymentsStreak;
        record.principal = principal;
        record.nextPaymentEpoch = nextPaymentEpoch;
        record.nextPaymentInterest = nextPaymentInterest;
    }
    function updateVaultRecord(
        uint256 vaultId,
        IVaultWallet vaultWallet,
        uint256 collateralID,
        uint256 principalPaymentsStreak,
        uint256 principal,
        uint256 nextPaymentEpoch,
        uint256 nextPaymentInterest
    ) external onlyRole(REGISTRAR_ROLE) {
        require(vaultNFT.exists(vaultId), "Vault ID not in registry");
        VaultRecord storage record = vaultRecords[vaultId];
        record.vaultWallet = vaultWallet;
        record.collateralID = collateralID;
        record.principalPaymentsStreak = principalPaymentsStreak;
        record.principal = principal;
        record.nextPaymentEpoch = nextPaymentEpoch;
        record.nextPaymentInterest = nextPaymentInterest;
    }
    function removeVaultRecord(
        uint256 vaultId
    ) external onlyRole(REGISTRAR_ROLE) {
        require(vaultNFT.exists(vaultId), "Vault ID not in registry");
        VaultRecord storage record = vaultRecords[vaultId];
        delete record.vaultWallet;
        delete record.collateralID;
        delete record.principalPaymentsStreak;
        delete record.principal;
        delete record.nextPaymentEpoch;
        delete record.nextPaymentInterest;
        delete vaultRecords[vaultId];
        vaultNFT.burn(vaultId);
    }

    function addPrincipal(uint256 vaultId, uint256 wad) external onlyRole(REGISTRAR_ROLE) returns (uint256 newPrincipal) {
        vaultRecords[vaultId].principal += wad;
        return vaultRecords[vaultId].principal;
    }
    function subPrincipal(uint256 vaultId, uint256 wad) external onlyRole(REGISTRAR_ROLE) returns (uint256 newPrincipal) {
        vaultRecords[vaultId].principal -= wad;
        return vaultRecords[vaultId].principal;
    }
    function setNextPaymentEpoch(uint256 vaultId, uint256 to) external onlyRole(REGISTRAR_ROLE) {
        vaultRecords[vaultId].nextPaymentEpoch = to;
    }
    function setNextPaymentInterest(uint256 vaultId, uint256 to) external onlyRole(REGISTRAR_ROLE) {
        vaultRecords[vaultId].nextPaymentInterest = to;
    }
    function incrementPrincipalPaymentsStreak(uint256 vaultId) external onlyRole(REGISTRAR_ROLE) {
        vaultRecords[vaultId].principalPaymentsStreak++;
    }
    function resetPrincipalPaymentsStreak(uint256 vaultId) external onlyRole(REGISTRAR_ROLE) {
        vaultRecords[vaultId].principalPaymentsStreak = 0;
    }
