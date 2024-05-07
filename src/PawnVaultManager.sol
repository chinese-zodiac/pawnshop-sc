// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20MintableBurnable} from "./interfaces/IERC20MintableBurnable.sol";
import {PawnVaultERC721} from "./PawnVaultERC721.sol";
import {IPawnVault} from "./interfaces/IPawnVault.sol";
import {PawnVault} from "./PawnVault.sol";

contract PawnVaultManager is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    bytes32 public constant REPO_ROLE = keccak256("REPO_ROLE");
    bytes32 public constant COLLATERAL_MANAGER_ROLE =
        keccak256("COLLATERAL_MANAGER_ROLE");
    bytes32 public constant EXECUTE_CUSTOM_ROLE =
        keccak256("EXECUTE_CUSTOM_ROLE");

    PawnVaultERC721 public immutable VAULT_ERC721;
    IERC20MintableBurnable public immutable CZUSD;

    uint256 public aprDeltaPerDayBps = 20;
    uint256 public aprBase = 799;
    uint256 public aprAdd = 400;

    uint256 public originationFee = 199;
    uint256 public pawnCollReductionBps = 3000;
    uint256 public pawnLiqReductionBps = 1000;

    mapping(IERC20 collateral => bool whitelisted) public collateralWhitelist;

    mapping(uint256 vaultERC721Id => IPawnVault vault) public vaults;
    mapping(uint256 vaultERC721Id => IERC20 collateral) public vaultCollateral;

    error PawnVaultManagerUnauthorized();
    error PawnVaultManagerNotCollateralWhitelist();

    constructor(
        address _admin,
        PawnVaultERC721 _vaultErc721,
        IERC20MintableBurnable _czusd
    ) {
        VAULT_ERC721 = _vaultErc721;
        CZUSD = _czusd;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function spawnVault(
        address _to,
        IERC20 _coll
    ) public onlyWhitelistCollateral(_coll) {
        uint256 id = VAULT_ERC721.mint(_to);
        vaults[id] = new PawnVault();
        vaultCollateral[id] = _coll;
    }

    modifier onlyWhitelistCollateral(IERC20 _coll) {
        if (!collateralWhitelist[_coll]) {
            revert PawnVaultManagerNotCollateralWhitelist();
        }
        _;
    }

    modifier onlyVaultOwner(uint256 _vaultERC721Id) {
        if (msg.sender != VAULT_ERC721.ownerOf(_vaultERC721Id)) {
            revert PawnVaultManagerUnauthorized();
        }
        _;
    }
}
