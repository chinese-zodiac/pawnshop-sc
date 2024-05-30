// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICollateralRegistry} from "../interfaces/ICollateralRegistry.sol";
import {ILiquidationController} from "../interfaces/ILiquidationController.sol";
import {IBorrowCalculator} from "../interfaces/IBorrowCalculator.sol";
import {IYieldController} from "../interfaces/IYieldController.sol";
import {CollateralRecord} from "../structs/CollateralRecord.sol";

contract CollateralRegistry is ICollateralRegistry, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.UintSet;
    EnumerableSet.UintSet internal collateralRegistry;
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    uint256 public nextId = 0;
    mapping(uint256 id => CollateralRecord record) public collateralRecords;

    error CollateralRegistryID404();

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //WARNING: View only
    function getAllIDs() external view returns (uint256[] memory allIDs_) {
        return collateralRegistry.values();
    }

    function getIsIDInRegistry(
        uint256 collateralID
    ) public view returns (bool isInRegistry_) {
        return collateralRegistry.contains(collateralID);
    }
    function getCount() external view returns (uint256 count_) {
        return collateralRegistry.length();
    }
    function getIDAt(
        uint256 index
    ) external view returns (uint256 collateralID_) {
        return collateralRegistry.at(index);
    }
    function getCollateralByID(
        uint256 collateralID
    ) external view returns (CollateralRecord memory collateralRecord) {
        if (!getIsIDInRegistry(collateralID)) revert CollateralRegistryID404();
        return collateralRecords[collateralID];
    }

    function addCollateralRecord(
        CollateralRecord memory collateralRecord
    ) external onlyRole(REGISTRAR_ROLE) {
        collateralRecords[nextId] = collateralRecord;
        collateralRegistry.add(nextId);
        nextId++;
    }
    function updateCollateralRecord(
        uint256 id,
        CollateralRecord memory collateralRecord
    ) external onlyRole(REGISTRAR_ROLE) {
        if (!getIsIDInRegistry(id)) revert CollateralRegistryID404();
        collateralRecords[id] = collateralRecord;
    }
    function removeCollateralRecord(
        uint256 id
    ) external onlyRole(REGISTRAR_ROLE) {
        if (!getIsIDInRegistry(id)) revert CollateralRegistryID404();
        delete collateralRecords[id].collateral;
        delete collateralRecords[id].borrowCalculator;
        delete collateralRecords[id].liquidationController;
        delete collateralRecords[id].yieldController;
        delete collateralRecords[id];
        collateralRegistry.remove(id);
    }
}
