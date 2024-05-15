// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;
import {IPawnVault} from "./interfaces/IPawnVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAmmPair} from "./interfaces/IAmmPair.sol";
import {AmmLibrary} from "./lib/AmmLibrary.sol";
import {CollateralRegistry} from "./CollateralRegistry.sol";

library PawnVaultRecordLib {
    function makeInterestPayment(
        PawnVaultRecord storage vRecord,
        uint256 paymentPeriod,
        uint256 aprBase,
        uint256 aprAdd,
        uint256 principalPaymentAprReductionBps,
        uint256 missedPaymentFeeBps
    ) internal returns (uint256 requiredPayment) {
        updatePenalties(
            vRecord,
            paymentPeriod,
            missedPaymentFeeBps,
            aprBase + aprAdd
        );
        requiredPayment = vRecord.nextPaymentInterest;
        vRecord.prevPaymentEpoch = vRecord.nextPaymentEpoch;
        vRecord.nextPaymentEpoch += paymentPeriod;
        vRecord.nextPaymentInterest = getInterestPerPeriod(
            vRecord,
            paymentPeriod,
            getApr(
                vRecord,
                paymentPeriod,
                aprBase,
                aprAdd,
                principalPaymentAprReductionBps
            )
        );
    }

    function makeFullPayment(
        PawnVaultRecord storage vRecord,
        uint256 paymentPeriod,
        uint256 principalPaymentBps,
        uint256 aprBase,
        uint256 aprAdd,
        uint256 principalPaymentAprReductionBps,
        uint256 missedPaymentFeeBps
    ) internal returns (uint256 requiredPayment) {
        updatePenalties(
            vRecord,
            paymentPeriod,
            missedPaymentFeeBps,
            aprBase + aprAdd
        );
        uint256 principalPayment = getPrincipalPayment(
            vRecord,
            principalPaymentBps
        );
        vRecord.principalPaymentsStreak++;
        vRecord.principal -= principalPayment;
        requiredPayment =
            principalPayment +
            makeInterestPayment(
                vRecord,
                paymentPeriod,
                aprBase,
                aprAdd,
                principalPaymentAprReductionBps,
                missedPaymentFeeBps
            );
    }

    function updatePenalties(
        PawnVaultRecord storage vRecord,
        uint256 paymentPeriod,
        uint256 missedPaymentFeeBps,
        uint256 maxApr
    ) internal {
        vRecord.principal += getPenalty(
            vRecord,
            paymentPeriod,
            missedPaymentFeeBps,
            maxApr
        );
    }

    function getApr(
        PawnVaultRecord storage vRecord,
        uint256 paymentPeriod,
        uint256 aprBase,
        uint256 aprAdd,
        uint256 principalPaymentAprReductionBps
    ) internal view returns (uint256 apr) {
        uint256 streak = getPrincipalPaymentStreak(vRecord, paymentPeriod);
        if (streak == 0) return aprBase + aprAdd;
        uint256 reductionBps = principalPaymentAprReductionBps * streak;
        if (reductionBps >= aprAdd) return aprBase;
        return aprAdd - reductionBps;
    }

    function getPrincipalPayment(
        PawnVaultRecord storage vRecord,
        uint256 principalPaymentBps
    ) internal view returns (uint256 principalPayment) {
        return (vRecord.principal * principalPaymentBps) / 10_000;
    }

    function getInterestPerPeriod(
        PawnVaultRecord storage vRecord,
        uint256 paymentPeriod,
        uint256 apr
    ) internal view returns (uint256 interest) {
        return ((vRecord.principal) * apr * paymentPeriod) / 365 days / 10_000;
    }

    function getPenalty(
        PawnVaultRecord storage vRecord,
        uint256 paymentPeriod,
        uint256 missedPaymentFeeBps,
        uint256 maxApr
    ) internal view returns (uint256 penalties) {
        uint256 missedPayments = getMissedPayments(vRecord, paymentPeriod);
        if (missedPayments == 0) return 0;
        uint256 basePenalty = (vRecord.principal *
            missedPaymentFeeBps *
            missedPayments) / 10_000;
        uint256 aprPenalty = 0;
        if (missedPayments > 1) {
            aprPenalty =
                ((vRecord.principal + basePenalty) *
                    maxApr *
                    (missedPayments - 1) *
                    paymentPeriod) /
                365 days /
                10_000;
        }
        return basePenalty + aprPenalty;
    }

    function getPrincipalPaymentStreak(
        PawnVaultRecord storage vRecord,
        uint256 paymentPeriod
    ) internal view returns (uint256 principalPaymentStreak) {
        return
            getMissedPayments(vRecord, paymentPeriod) > 0
                ? 0
                : vRecord.principalPaymentsStreak;
    }

    function getMissedPayments(
        PawnVaultRecord storage vRecord,
        uint256 paymentPeriod
    ) internal view returns (uint256 missedPayments) {
        return block.timestamp - vRecord.prevPaymentEpoch / paymentPeriod;
    }

    function getAvailableCzusd(
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
}
