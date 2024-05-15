// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVaultWallet {
    function transferERC20(IERC20 _asset, address _to, uint256 _value) external;
    function transferERC721(IERC721 _asset, address _to, uint256 _id) external;
    function execute(
        address _on,
        bytes memory _abiSignatureEncoded
    ) external returns (bool success, bytes memory returndata);
}
