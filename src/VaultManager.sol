// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20MintableBurnable} from "./interfaces/IERC20MintableBurnable.sol";
import {IVaultNFT} from "./interfaces/IVaultNFT.sol";
import {IVaultRegistry} from "./interfaces/IVaultRegistry.sol";
import {ICollateralRegistry} from "./interfaces/ICollateralRegistry.sol";
import {ILiquidationController} from "./interfaces/ILiquidationController.sol";
import {IBorrowCalculator} from "./interfaces/IBorrowCalculator.sol";
import {IYieldController} from "./interfaces/IYieldController.sol";
import {IVaultWallet} from "./interfaces/IVaultWallet.sol";
import {VaultWallet} from "./VaultWallet.sol";

contract VaultManager is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    IVaultNFT public immutable VAULT_NFT;
    IVaultRegistry public immutable VAULT_REGISTRY;
    ICollateralRegistry public immutable COLLATERAL_REGISTRY;
    IERC20MintableBurnable public immutable CZUSD;

    uint256 public constant PAYMENT_PERIOD = 14 days;
    uint256 public constant LIQUIDATION_PERIOD = 90 days;
    uint256 public constant MAX_MISSED_PAYMENTS = 6;

    uint256 public aprDeltaPerDayBps = 20;
    uint256 public aprBase = 799;
    uint256 public aprAdd = 400;

    uint256 public originationFee = 199;
    uint256 public missedPaymentFeeBps = 399;
    uint256 public principalPaymentAprReductionBps = 100;
    uint256 public principalPaymentBps = 75;

    uint256 public pawnBorrowCollReductionBps = 3000;
    uint256 public pawnLiqCollReductionBps = 1000;

    error PawnVaultManagerUnauthorized();
    error PawnVaultManagerNotCollateralWhitelist();

    constructor(
        address _admin,
        IVaultNFT _vaultNft,
        IVaultRegistry _vaultRegistry,
        ICollateralRegistry _collateralRegistry,
        IERC20MintableBurnable _czusd
    ) {
        VAULT_NFT = _vaultNft;
        VAULT_REGISTRY = _vaultRegistry;
        COLLATERAL_REGISTRY = _collateralRegistry;
        CZUSD = _czusd;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    modifier onlyWhitelistCollateral(uint256 collateralId) {
        if (!COLLATERAL_REGISTRY.getIsIDInRegistry(collateralId)) {
            revert PawnVaultManagerNotCollateralWhitelist();
        }
        _;
    }

    modifier onlyVaultOwner(uint256 vaultId) {
        if (msg.sender != VAULT_NFT.ownerOf(vaultId)) {
            revert PawnVaultManagerUnauthorized();
        }
        _;
    }

    function spawnVault(
        address _to,
        uint256 collateralId
    ) public onlyWhitelistCollateral(collateralId) {
        VaultWallet vaultWallet = new VaultWallet();
        VAULT_REGISTRY.addVaultRecord(
            _to,
            vaultWallet,
            collateralId,
            0,
            0,
            0,
            0
        );
        (
            ,
            ,
            ILiquidationController liquidationController,
            IYieldController yieldController
        ) = COLLATERAL_REGISTRY.getCollateralByID(collateralId);
        vaultWallet.grantRole(vaultWallet.MANAGER_ROLE(), address(this));
        vaultWallet.grantRole(
            vaultWallet.MANAGER_ROLE(),
            address(liquidationController)
        );
        vaultWallet.grantRole(
            vaultWallet.MANAGER_ROLE(),
            address(yieldController)
        );
    }

    function _updateVault(
        uint256 vaultId,
        uint256 nextPaymentEpoch,
        uint256 principal
    ) internal returns (uint256 newPrincipal) {
        //Add penalties
        if (block.timestamp > nextPaymentEpoch) {
            principal = VAULT_REGISTRY.addPrincipal(
                vaultId,
                getPenalty(
                    block.timestamp - nextPaymentEpoch / PAYMENT_PERIOD,
                    principal
                )
            );
        }
        //Set liquidation status

        return newPrincipal;
    }

    //Must be only vault owner to prevent 3rd parties breaking streak
    function makeInterestPayment(
        uint256 vaultId
    ) external onlyVaultOwner(vaultId) {
        (
            ,
            ,
            ,
            uint256 principalPaymentsStreak,
            uint256 principal,
            uint256 nextPaymentEpoch,
            uint256 nextPaymentInterest
        ) = VAULT_REGISTRY.getVaultByID(vaultId);
        principal = _updateVault(vaultId, nextPaymentEpoch, principal);
        CZUSD.burnFrom(msg.sender, nextPaymentInterest);
        VAULT_REGISTRY.setNextPaymentEpoch(
            vaultId,
            nextPaymentEpoch + PAYMENT_PERIOD
        );
        VAULT_REGISTRY.setNextPaymentInterest(
            vaultId,
            getInterest(principal, 1, principalPaymentsStreak)
        );
        VAULT_REGISTRY.resetPrincipalPaymentsStreak(vaultId);
    }

    function makeFullPayment(uint256 vaultId) external {
        (
            ,
            ,
            ,
            uint256 principalPaymentsStreak,
            uint256 principal,
            uint256 nextPaymentEpoch,
            uint256 nextPaymentInterest
        ) = VAULT_REGISTRY.getVaultByID(vaultId);
        principal = _updateVault(vaultId, nextPaymentEpoch, principal);
        uint256 principalPayment = (principal *
            principalPaymentAprReductionBps) / 10_000;
        CZUSD.burnFrom(msg.sender, nextPaymentInterest + principalPayment);
        principal = VAULT_REGISTRY.subPrincipal(vaultId, principalPayment);
        VAULT_REGISTRY.incrementPrincipalPaymentsStreak(vaultId);
        VAULT_REGISTRY.setNextPaymentEpoch(
            vaultId,
            nextPaymentEpoch + PAYMENT_PERIOD
        );
        VAULT_REGISTRY.setNextPaymentInterest(
            vaultId,
            getInterest(principal, 1, principalPaymentsStreak)
        );
    }

    function getPenalty(
        uint256 missedPayments,
        uint256 principal
    ) public view returns (uint256 penalties) {
        if (missedPayments == 0) return 0;
        return
            ((principal * missedPaymentFeeBps * missedPayments) / 10_000) +
            getInterest(principal, missedPayments, 0);
    }

    function getInterest(
        uint256 principal,
        uint256 periods,
        uint256 principalPaymentsStreak
    ) public view returns (uint256 interest) {
        uint256 apr = aprBase;
        uint256 aprReduction = principalPaymentAprReductionBps *
            principalPaymentsStreak;
        if (aprReduction < aprAdd) apr -= aprReduction;
        return (principal * periods * PAYMENT_PERIOD * apr) / 10_000 / 365 days;
    }
    /*function getAvailableCzusd(
        PawnVaultRecord storage vRecord,
        IAmmPair ammCollCzusdPair,
        IERC20 czusd,
        address lpLocker,
        uint256 pawnVaultsTotalColl,
        uint256 pawnVaultsCollReductionBps
    ) internal view returns (uint256 availableCzusd_) {
        IERC20 collateral = vRecord.collateral;
        uint256 collateralQuantity = collateral.balanceOf(
            address(vRecord.vault)
        );
        uint256 collateralTotalSupply = collateral.totalSupply();
        bool czusdIsToken0 = ammCollCzusdPair.token0() == address(czusd);
        (uint112 reserve0, uint112 reserve1, ) = ammCollCzusdPair.getReserves();
        uint256 lockedLP = ammCollCzusdPair.balanceOf(lpLocker);
        uint256 totalLP = ammCollCzusdPair.totalSupply();

        uint256 lockedLpCzusdBal = ((czusdIsToken0 ? reserve0 : reserve1) *
            lockedLP) / totalLP;
        uint256 lockedLpCollBal = ((czusdIsToken0 ? reserve1 : reserve0) *
            lockedLP) / totalLP;

        if (lockedLpCollBal == collateralTotalSupply) {
            availableCzusd_ =
                (collateralQuantity * lockedLpCzusdBal) /
                collateralTotalSupply;
        } else {
            availableCzusd_ =
                (collateralQuantity *
                    (lockedLpCzusdBal -
                        (
                            AmmLibrary.getAmountOut(
                                collateralTotalSupply -
                                    lockedLpCollBal -
                                    (((10_000 - pawnVaultsCollReductionBps) *
                                        pawnVaultsTotalColl) / 10_000),
                                lockedLpCollBal,
                                lockedLpCzusdBal
                            )
                        ))) /
                collateralTotalSupply;
        }
    }
    */
}
