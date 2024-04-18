// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
//Fund the Pawn Shop's Bankroll to earn CZUSD every second from the Pawn Shop's interest and fees.
pragma solidity ^0.8.4;
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/IterableArrayWithoutDuplicateKeys.sol";

//import "hardhat/console.sol";

contract PawnShopBankroll is AccessControlEnumerable {
    using IterableArrayWithoutDuplicateKeys for IterableArrayWithoutDuplicateKeys.Map;

    using SafeERC20 for IERC20;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The timestamp of the last pool update
    uint256 public timestampLast;

    // The timestamp when REWARD mining ends.
    uint256 public timestampEnd;

    // REWARD tokens created per second.
    uint256 public rewardPerSecond;

    //Total wad staked;
    uint256 public totalStaked;

    uint256 public globalRewardDebt;

    // The precision factor
    uint256 public PRECISION_FACTOR = 10 ** 12;

    uint256 public period = 180 days;

    mapping(address account => uint256 bal) public stakedBal;

    //rewards tracking
    uint256 public totalRewardsPaid;
    mapping(address account => uint256 total) public totalRewardsReceived;

    // The tribe token
    IERC20 public tribeToken;

    address public stakeWrapperToken;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address account => uint256 debt) public userRewardDebt;

    //do not receive rewards
    mapping(address account => bool isExempt) isRewardExempt;

    bool isInitialized;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initialize(
        address _tribeToken,
        address _stakeWrapperToken,
        address _owner
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isInitialized);
        isInitialized = true;
        tribeToken = IERC20(_tribeToken);

        setStakeWrapperToken(_stakeWrapperToken);

        isRewardExempt[address(0)] = true;

        // Set the timestampLast as now
        timestampLast = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function deposit(address _for, uint256 _amount) external {
        require(msg.sender == stakeWrapperToken);
        _deposit(_for, _amount);
    }

    function withdraw(address _for, uint256 _amount) external {
        require(msg.sender == stakeWrapperToken);
        _withdraw(_for, _amount);
    }

    function claimFor(address _account) external {
        require(msg.sender == stakeWrapperToken);
        _claimFor(_account);
    }

    function _claimFor(address _account) internal {
        uint256 accountBal = stakedBal[_account];
        _updatePool();
        if (accountBal > 0) {
            uint256 pending = ((accountBal) * accTokenPerShare) /
                PRECISION_FACTOR -
                userRewardDebt[_account];
            if (pending > 0) {
                totalRewardsPaid += pending;
                totalRewardsReceived[_account] += (pending);
                tribeToken.safeTransfer(address(stakeWrapperToken), pending);
            }
            _updateRewardDebt(_account);
        }
    }

    function _deposit(address _account, uint256 _amount) internal {
        if (isRewardExempt[_account]) return;
        if (_amount == 0) return;
        _updatePool();
        stakedBal[_account] += _amount;
        totalStaked += _amount;
        _updateRewardDebt(_account);
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in tribeToken)
     */
    function _withdraw(address _account, uint256 _amount) internal {
        if (isRewardExempt[_account]) return;
        if (_amount == 0) return;
        _updatePool();
        stakedBal[_account] -= _amount;
        totalStaked -= _amount;
        _updateRewardDebt(_account);
    }

    function _updateRewardDebt(address _account) internal {
        globalRewardDebt -= userRewardDebt[_account];
        userRewardDebt[_account] =
            (stakedBal[_account] * accTokenPerShare) /
            PRECISION_FACTOR;
        globalRewardDebt += userRewardDebt[_account];
    }

    function addRewards(uint256 _tokenWad) public {
        tribeToken.transferFrom(msg.sender, address(this), _tokenWad);
        _updatePool();
    }

    function setIsRewardExempt(
        address _for,
        bool _to
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isRewardExempt[_for] == _to) return;
        if (_to) {
            _withdraw(_for, stakedBal[_for]);
        } else {
            _deposit(_for, stakedBal[_for]);
        }
        isRewardExempt[_for] = _to;
    }

    function setStakeWrapperToken(
        address _to
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        stakeWrapperToken = _to;
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
    }

    function setPeriod(uint256 _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        period = _to;
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        if (block.timestamp > timestampLast && totalStaked != 0) {
            uint256 adjustedTokenPerShare = accTokenPerShare +
                ((rewardPerSecond *
                    _getMultiplier(timestampLast, block.timestamp) *
                    PRECISION_FACTOR) / totalStaked);
            return
                (stakedBal[_user] * adjustedTokenPerShare) /
                PRECISION_FACTOR -
                userRewardDebt[_user];
        } else {
            return
                (stakedBal[_user] * accTokenPerShare) /
                PRECISION_FACTOR -
                userRewardDebt[_user];
        }
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.timestamp <= timestampLast) {
            return;
        }

        if (totalStaked != 0) {
            accTokenPerShare =
                accTokenPerShare +
                ((rewardPerSecond *
                    _getMultiplier(timestampLast, block.timestamp) *
                    PRECISION_FACTOR) / totalStaked);
        }

        uint256 totalRewardsToDistribute = tribeToken.balanceOf(address(this)) +
            globalRewardDebt -
            ((accTokenPerShare * totalStaked) / PRECISION_FACTOR);
        if (totalRewardsToDistribute > 0) {
            rewardPerSecond = totalRewardsToDistribute / period;
            timestampEnd = block.timestamp + period;
        }
        timestampLast = block.timestamp;
    }

    /*
     * @notice Return reward multiplier over the given _from to _to timestamp.
     * @param _from: timestamp to start
     * @param _to: timestamp to finish
     */
    function _getMultiplier(
        uint256 _from,
        uint256 _to
    ) internal view returns (uint256) {
        if (_to <= timestampEnd) {
            return _to - _from;
        } else if (_from >= timestampEnd) {
            return 0;
        } else {
            return timestampEnd - _from;
        }
    }
}
