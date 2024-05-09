// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.4;
import {IPawnVault} from "./interfaces/IPawnVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAmmPair} from "./interfaces/IAmmPair.sol";
import {AmmLibrary} from "./libs/AmmLibrary.sol";

library PawnVaultRecord {
    struct VaultRecord {
        uint256 vaultERC721Id;
        IPawnVault vault;
        IERC20 collateral;
        uint256 creationEpoch;
        uint256 lastPaymentEpoch;
        uint256 missedPaymentsStreak;
        uint256 principalPaymentsStreak;
        uint256 principal;
        uint256 nextPaymentEpoch;
        uint256 nextPaymentInterestPayment;
        uint256 nextPaymentPrincipalPayment;
    }

    function availableCzusd(VaultRecord storage vRecord, IAmmPair ammCollCzusdPair, address lpLocker, uint256 pawnVaultsTotalColl, uint256 pawnVaultsCollReductionBps) internal view returns (uint256 availableCzusd_) {
        IERC20 collateral = vRecord.collateral;
        uint256 collateralQuantity = collateral.balanceOf(address(vRecord.vault));
        uint256 collateralTotalSupply = collateral.totalSupply();
        bool czusdIsToken0 = ammCollCzusdPair.token0() == address(czusd);
        (uint112 reserve0, uint112 reserve1, ) = ammCollCzusdPair.getReserves();
        uint256 lockedLP = ammCzusdPair.balanceOf(lpLocker);
        uint256 totalLP = ammCzusdPair.totalSupply();

        uint256 lockedLpCzusdBal = ((czusdIsToken0 ? reserve0 : reserve1) *
            lockedLP) / totalLP;
        uint256 lockedLpCollBal = ((czusdIsToken0 ? reserve1 : reserve0) *
            lockedLP) / totalLP;

        if (lockedLpCollBal == collateralTotalSupply) {
            availableCzusd_ = collateralQuantity * lockedLpCzusdBal / collateralTotalSupply;
        } else {
            availableCzusd_ =
                collateralQuantity * (lockedLpCzusdBal -
                (
                    AmmLibrary.getAmountOut(
                        collateralTotalSupply - lockedLpCollBal - (((10_000 - pawnVaultsCollReductionBps) * pawnVaultsTotalColl) / 10_000),
                        lockedLpCollBal,
                        lockedLpCzusdBal
                    )
                )) / collateralTotalSupply;
        }
    }

    function setNextPayment(uint256 apr, uint256 ) internal {

    }

    function isSeizable(VaultRecord vRecord, uint256 maxCzusdPerCollToken)

}
