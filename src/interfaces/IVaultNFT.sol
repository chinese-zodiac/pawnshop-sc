// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

import {IERC721Enumerable} from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";

interface IVaultNFT is IERC721Enumerable {
    function mint(address to) external returns (uint256 id);
    function burn(uint256 tokenId) external;
    function exists(uint256 tokenId) external view returns (bool);
}
