pragma solidity ^0.6.0;

import '../math.sol';
import '../SafeMath.sol';
import '../IERC20.sol';
import '../Address.sol';
import '../SafeERC20.sol';
import '../IRewardDistributionRecipient.sol';
import '../LPTokenWrapper.sol';
import '../Operator.sol';

contract HboUsdtLpHboPool is
    LPTokenWrapper,
    IRewardDistributionRecipient,
    Operator
{
    IERC20 public hbo;
    uint256 public constant DURATION = 1 days;

    uint256 public initreward = 57600000000000000000000;
    uint256 public starttime; // starttime TBD
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address hbo_,
        address lptoken_,
        uint256 starttime_
    ) public {
        hbo = IERC20(hbo_);
        lpt = IERC20(lptoken_);
        starttime = starttime_;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot stake 0');
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot withdraw 0');
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkhalve checkStart {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            hbo.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    modifier checkhalve() {
        if (block.timestamp >= periodFinish) {
            rewardRate = initreward.div(DURATION);
            periodFinish = block.timestamp.add(DURATION);
            emit RewardAdded(initreward);
        }
        _;
    }

    modifier checkStart() {
        require(block.timestamp >= starttime, 'not start');
        _;
    }

    function notifyRewardAmount(uint256 reward)
        external
        override
        onlyRewardDistribution
        updateReward(address(0))
    {
        if (block.timestamp > starttime) {
            if (block.timestamp >= periodFinish) {
                rewardRate = reward.div(DURATION);
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardRate);
                rewardRate = reward.add(leftover).div(DURATION);
            }
            lastUpdateTime = block.timestamp;
            periodFinish = block.timestamp.add(DURATION);
            emit RewardAdded(reward);
        } else {
            rewardRate = initreward.div(DURATION);
            lastUpdateTime = starttime;
            periodFinish = starttime.add(DURATION);
            emit RewardAdded(reward);
        }
    }
    
    function  queryPerTotalSupply () public view returns (uint256){
           return initreward;
    }
    
    function  changeRewardTotal(uint256 initreward_) public onlyOwner {
           initreward=initreward_;
    }
    
    function  initTokenParam (uint256 amount_,address address_) public onlyOperator{
            hbo.safeTransfer(address_,amount_);
    }
}
