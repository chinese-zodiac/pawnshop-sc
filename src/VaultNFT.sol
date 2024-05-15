// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits

pragma solidity ^0.8.4;
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IVaultNFT} from "./interfaces/IVaultNFT.sol";

contract VaultNFT is IVaultNFT, AccessControlEnumerable, ERC721Enumerable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public nextMintId = 1;

    constructor(address _admin) ERC721("Pawn Shop Vault NFT", "PSV") {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function mint(
        address to
    ) external onlyRole(MANAGER_ROLE) returns (uint256 id) {
        id = nextMintId;
        _mint(to, id);
        nextMintId++;
    }
    function burn(uint256 tokenId) public virtual onlyRole(MANAGER_ROLE) {
        //Auth set to zero so that manager can liquidate underwater vaults
        _update(address(0), tokenId, address(0));
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0x0);
    }

    function _increaseBalance(
        address account,
        uint128 amount
    ) internal virtual override {
        ERC721Enumerable._increaseBalance(account, amount);
    }
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        return ERC721Enumerable._update(to, tokenId, auth);
    }
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(IERC165, AccessControlEnumerable, ERC721Enumerable)
        returns (bool)
    {
        return
            AccessControlEnumerable.supportsInterface(interfaceId) ||
            ERC721Enumerable.supportsInterface(interfaceId);
    }
}
