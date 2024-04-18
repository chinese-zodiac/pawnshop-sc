// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits

pragma solidity ^0.8.4;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Wrapper} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PawnShopBankroll.sol";
import "./interfaces/IBlacklist.sol";
import "./interfaces/ICashback.sol";

//import "hardhat/console.sol";

contract PawnShopBankrollWrapperToken is
    AccessControlEnumerable,
    ERC20,
    ERC20Wrapper,
    IBlacklist
{
    using SafeERC20 for IERC20;

    IERC20 public czusd = IERC20(0xE68b79e51bf826534Ff37AA9CeE71a3842ee9c70);

    PawnShopBankroll public pool;

    IBlacklist public blacklist =
        IBlacklist(0x8D82235e48Eeb0c5Deb41988864d14928B485bac);

    ICashback public cashback =
        ICashback(0xe32a6BF04d6Aaf34F3c29af991a6584C5D8faB5C);

    uint16 public feeBpsDeposit = 49;
    uint16 public feeBpsWithdraw = 199;

    uint16 public feeToPoolPct = 80;
    uint16 public feeToCashPct = 20;

    constructor()
        ERC20("wCZUSD: Pawn Shop Bankroll", "wCZUSD-PSB")
        ERC20Wrapper(IERC20(czusd))
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        PawnShopBankroll newPool = new PawnShopBankroll();
        newPool.initialize(address(czusd), address(this), msg.sender);
        pool = newPool;
    }

    function decimals()
        public
        view
        override(ERC20, ERC20Wrapper)
        returns (uint8)
    {
        return ERC20Wrapper.decimals();
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._update(from, to, amount);
        if (amount > 0) {
            restake(from);
            restake(to);
            pool.withdraw(from, amount);
            pool.deposit(to, amount);
        }
    }

    function restake(address _account) public {
        if (pool.pendingReward(_account) == 0) return;
        uint256 initialCzusd = czusd.balanceOf(address(this));
        pool.claimFor(_account);
        uint256 claimedCzusd = czusd.balanceOf(address(this)) - initialCzusd;
        if (claimedCzusd > 0) {
            _mint(_account, claimedCzusd);
        }
    }

    function claim() external {
        uint256 initialBal = balanceOf(msg.sender);
        restake(msg.sender);
        uint256 amount = balanceOf(msg.sender) - initialBal;
        withdrawTo(msg.sender, amount);
    }

    function depositFor(
        address _account,
        uint256 _amount
    ) public override returns (bool) {
        restake(_account);
        uint256 totalFee = (feeBpsDeposit * _amount) / 10_000;
        if (totalFee > 0) {
            czusd.transferFrom(msg.sender, address(this), totalFee);
            _distributeFees(totalFee, _account);
        }

        super.depositFor(_account, _amount - totalFee);
        return true;
    }

    function withdrawTo(
        address _account,
        uint256 _amount
    ) public override returns (bool) {
        restake(_account);

        address receiver = isBlacklisted(msg.sender)
            ? getRoleMember(DEFAULT_ADMIN_ROLE, 0)
            : _account;

        uint256 totalFee = (feeBpsWithdraw * _amount) / 10_000;
        if (totalFee > 0) {
            _burn(msg.sender, totalFee);
            _distributeFees(totalFee, receiver);
        }

        super.withdrawTo(receiver, _amount - totalFee);
        return true;
    }

    function isBlacklisted(address _account) public returns (bool) {
        return blacklist.isBlacklisted(_account);
    }

    function setPool(PawnShopBankroll _to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        pool = _to;
    }

    function setFees(
        uint16 _feeBpsDeposit,
        uint16 _feeBpsWithdraw
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        feeBpsDeposit = _feeBpsDeposit;
        feeBpsWithdraw = _feeBpsWithdraw;
    }

    function recoverWrongTokens(
        address _tokenAddress,
        uint256 _tokenAmount,
        address _to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tokenAddress != address(czusd));

        IERC20(_tokenAddress).safeTransfer(_to, _tokenAmount);
    }

    function _distributeFees(uint256 _totalFees, address _account) internal {
        uint256 feeToPool = (feeToPoolPct * _totalFees) / 100;
        czusd.approve(address(pool), feeToPool);
        pool.addRewards(feeToPool);
        uint256 feeToCash = _totalFees - feeToPool;
        czusd.approve(address(cashback), feeToCash);
        cashback.addCzusdToDistribute(_account, feeToCash);
    }
}
