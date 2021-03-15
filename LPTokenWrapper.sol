// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import './SafeMath.sol';
import './SafeERC20.sol';
import './IERC20.sol';

contract LPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public lpt;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    // lp 总量
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // lp 份额
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    // 抵押
    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        // 提前授权 mdex 池子合约帮我花费
        lpt.safeTransferFrom(msg.sender, address(this), amount);
    }

    // 解押
    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        //
        lpt.safeTransfer(msg.sender, amount);
    }
}
