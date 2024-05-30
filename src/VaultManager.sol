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
import {VaultRecord} from "./structs/VaultRecord.sol";
import {CollateralRecord} from "./structs/CollateralRecord.sol";

contract VaultManager is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    IVaultNFT public immutable VAULT_NFT;
    IVaultRegistry public immutable VAULT_REGISTRY;
    ICollateralRegistry public immutable COLLATERAL_REGISTRY;
    IERC20MintableBurnable public immutable CZUSD;

    uint256 public constant PAYMENT_PERIOD = 14 days;
    uint256 public constant LIQUIDATION_PERIOD = 30 days;
    uint256 public constant UNLOCK_PERIOD = 60 days;
    uint256 public constant MAX_MISSED_PAYMENTS = 2;

    uint256 public constant MIN_PRINCIPAL = 10 ether;

    uint256 public aprDeltaPerDayBps = 20;
    uint256 public aprBase = 799;
    uint256 public aprAdd = 400;

    uint256 public originationFee = 199;
    uint256 public missedPaymentFeeBps = 399;
    uint256 public fullPaymentAprReductionBps = 100;
    uint256 public principalPaymentBps = 75;

    uint256 public pawnBorrowCollReductionBps = 3000;
    uint256 public pawnLiqCollReductionBps = 1000;

    error PawnVaultManagerUnauthorized();
    error PawnVaultManagerNotCollateralWhitelist();
    error PawnVaultManagerOverpayment();

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

    modifier onlyVaultOwner(uint256 vaultID) {
        if (msg.sender != VAULT_NFT.ownerOf(vaultID)) {
            revert PawnVaultManagerUnauthorized();
        }
        _;
    }

    function spawnVault(
        address _to,
        uint256 collateralID
    ) public onlyWhitelistCollateral(collateralID) {
        VaultWallet vaultWallet = new VaultWallet();
        VaultRecord memory vaultRecord;
        vaultRecord.vaultWallet = vaultWallet;
        vaultRecord.collateralID = collateralID;
        VAULT_REGISTRY.addVaultRecord(_to, vaultRecord);
        CollateralRecord memory collateralRecord = COLLATERAL_REGISTRY
            .getCollateralByID(collateralID);
        bytes32 managerRole = vaultWallet.MANAGER_ROLE();
        vaultWallet.grantRole(managerRole, address(this));
        vaultWallet.grantRole(
            managerRole,
            address(collateralRecord.liquidationController)
        );
        vaultWallet.grantRole(
            managerRole,
            address(collateralRecord.yieldController)
        );
    }

    //Must be only vault owner to prevent 3rd parties breaking streak
    function makePaymentInterest(
        uint256 vaultID
    ) external onlyVaultOwner(vaultID) {
        VaultRecord memory vaultRecord = (VAULT_REGISTRY.getVaultByID(vaultID));
        CollateralRecord memory collateralRecord = COLLATERAL_REGISTRY
            .getCollateralByID(vaultRecord.collateralID);
        if (vaultRecord.nextPaymentInterest == 0) {
            revert PawnVaultManagerOverpayment();
        }
        CZUSD.burnFrom(msg.sender, vaultRecord.nextPaymentInterest);
        vaultRecord.principal += getPenalty(
            vaultRecord.principal,
            vaultRecord.nextPaymentEpoch
        );
        vaultRecord.nextPaymentEpoch += PAYMENT_PERIOD;
        vaultRecord.nextPaymentInterest = getInterest(
            vaultRecord.principal,
            1,
            vaultRecord.fullPaymentsStreak
        );
        vaultRecord.fullPaymentsStreak = 0;
        VAULT_REGISTRY.updateVaultRecord(vaultID, vaultRecord);
    }

    function makePaymentFull(uint256 vaultID) external {
        VaultRecord memory vaultRecord = (VAULT_REGISTRY.getVaultByID(vaultID));
        CollateralRecord memory collateralRecord = COLLATERAL_REGISTRY
            .getCollateralByID(vaultRecord.collateralID);
        vaultRecord.principal += getPenalty(
            vaultRecord.principal,
            vaultRecord.nextPaymentEpoch
        );
        uint256 principalPayment;
        if (vaultRecord.principal < 10 ether) {
            principalPayment = vaultRecord.principal; //fully pay off debt
        } else {
            principalPayment =
                (vaultRecord.principal * principalPaymentBps) /
                10_000;
        }
        if (vaultRecord.nextPaymentInterest + principalPayment == 0) {
            revert PawnVaultManagerOverpayment();
        }
        CZUSD.burnFrom(
            msg.sender,
            vaultRecord.nextPaymentInterest + principalPayment
        );
        vaultRecord.principal -= principalPayment;
        vaultRecord.fullPaymentsStreak++;
        vaultRecord.nextPaymentEpoch += PAYMENT_PERIOD;
        vaultRecord.nextPaymentInterest += getInterest(
            vaultRecord.principal,
            1,
            vaultRecord.fullPaymentsStreak
        );
        VAULT_REGISTRY.updateVaultRecord(vaultID, vaultRecord);
    }

    //Must be only vault owner to prevent 3rd parties breaking streak
    function makePaymentPrincipal(
        uint256 vaultID,
        uint256 paymentWad
    ) external onlyVaultOwner(vaultID) {
        VaultRecord memory vaultRecord = (VAULT_REGISTRY.getVaultByID(vaultID));
        CollateralRecord memory collateralRecord = COLLATERAL_REGISTRY
            .getCollateralByID(vaultRecord.collateralID);
        vaultRecord.principal += getPenalty(
            vaultRecord.principal,
            vaultRecord.nextPaymentEpoch
        );
        if (
            vaultRecord.principal < 10 ether ||
            vaultRecord.principal < paymentWad
        ) {
            paymentWad = vaultRecord.principal; //fully pay off debt
        }
        CZUSD.burnFrom(msg.sender, paymentWad);
        vaultRecord.principal -= paymentWad;
        VAULT_REGISTRY.updateVaultRecord(vaultID, vaultRecord);
    }

    function deposit(uint256 vaultID, uint256 collateralWad) external {
        VaultRecord memory vaultRecord = (VAULT_REGISTRY.getVaultByID(vaultID));
        CollateralRecord memory collateralRecord = COLLATERAL_REGISTRY
            .getCollateralByID(vaultRecord.collateralID);
        (IERC20 collateral, , , ) = COLLATERAL_REGISTRY.getCollateralByID(
            collateralID
        );
        collateral.safeTransferFrom(
            msg.sender,
            address(vaultWallet),
            collateralWad
        );
    }

    function getPenalty(
        uint256 principal,
        uint256 nextPaymentEpoch
    ) public view returns (uint256 penalties) {
        if (block.timestamp <= nextPaymentEpoch) return 0;
        uint256 missedPayments = (block.timestamp - nextPaymentEpoch) /
            PAYMENT_PERIOD;
        if (missedPayments == 0) return 0;
        return
            ((principal * missedPaymentFeeBps * missedPayments) / 10_000) +
            getInterest(principal, missedPayments, 0);
    }

    function getInterest(
        uint256 principal,
        uint256 periods,
        uint256 fullPaymentsStreak
    ) public view returns (uint256 interest) {
        uint256 apr = aprBase;
        uint256 aprReduction = fullPaymentAprReductionBps * fullPaymentsStreak;
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
