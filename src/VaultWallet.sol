// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits

pragma solidity ^0.8.4;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVaultWallet} from "./interfaces/IVaultWallet.sol";

contract VaultWallet is IVaultWallet, AccessControlEnumerable {
    using SafeERC20 for IERC20;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function transferERC20(
        IERC20 _asset,
        address _to,
        uint256 _value
    ) external onlyRole(MANAGER_ROLE) {
        _asset.transfer(_to, _value);
    }

    function transferERC721(
        IERC721 _asset,
        address _to,
        uint256 _id
    ) external onlyRole(MANAGER_ROLE) {
        _asset.transferFrom(address(this), _to, _id);
    }

    function execute(
        address _on,
        bytes memory _abiSignatureEncoded
    )
        external
        onlyRole(MANAGER_ROLE)
        returns (bool success, bytes memory returndata)
    {
        (success, returndata) = address(_on).call(_abiSignatureEncoded);
    }
}
