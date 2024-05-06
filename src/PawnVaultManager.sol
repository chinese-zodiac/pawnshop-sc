// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20MintableBurnable} from "./interfaces/IERC20MintableBurnable.sol";
import {PawnVaultERC721} from "./PawnVaultERC721.sol";

contract PawnVaultManager is AccessControlEnumerable {
    bytes32 public constant REPO_ROLE = keccak256("REPO_ROLE");

    PawnVaultERC721 public immutable VAULT_ERC721;
    IERC20MintableBurnable public immutable CZUSD;

    uint256 public aprDeltaPerDayBps = 20;
    uint256 public aprBase = 799;
    uint256 public aprAdd = 400;

    uint256 public originationFee = 199;
    uint256 public pawnCollReductionBps = 3000;
    uint256 public pawnLiqReductionBps = 1000;

    constructor(
        address _admin,
        PawnVaultERC721 _vaultErc721,
        IERC20MintableBurnable _czusd
    ) {
        VAULT_ERC721 = _vaultErc721;
        CZUSD = _czusd;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }
}
