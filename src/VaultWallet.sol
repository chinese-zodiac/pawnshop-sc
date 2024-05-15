// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits

pragma solidity ^0.8.4;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVaultWallet} from "./interfaces/IVaultWallet.sol";

contract VaultWallet is IVaultWallet, Ownable {
    using SafeERC20 for IERC20;
    constructor() Ownable(_msgSender()) {}

    function transferERC20(
        IERC20 _asset,
        address _to,
        uint256 _value
    ) external onlyOwner {
        _asset.transfer(_to, _value);
    }

    function transferERC721(
        IERC721 _asset,
        address _to,
        uint256 _id
    ) external onlyOwner {
        _asset.transferFrom(address(this), _to, _id);
    }

    function execute(
        address _on,
        bytes memory _abiSignatureEncoded
    ) external onlyOwner returns (bool success, bytes memory returndata) {
        (success, returndata) = address(_on).call(_abiSignatureEncoded);
    }
}
