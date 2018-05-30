
pragma solidity ^0.4.18;

import './Ownable.sol';
import './SafeMath.sol';
import './OCoin.sol';
import './RefundVault.sol';

contract OCoinCrowdsale is Ownable {
  using SafeMath for uint256;

  OCoin public token;

  uint256 public endTime;


  uint public minPurchase;
  uint exchangeStage1;
  uint exchangeStage2;
  uint exchangeRate1;
  uint exchangeRate2;
  uint exchangeRate3;
  
  bool public isFinalized = false;

  uint256 public totalToken;
  uint256 public goal;
  uint256 public tokenSaled = 0;

  RefundVault public vault;

  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event Finalized();
  event Withdraw(address to, uint value);

  function OCoinCrowdsale(address _token) public {
    require(_token != address(0));
    vault = new RefundVault();
    token = OCoin(_token);
    endTime = 1524240000;                                   // 2018/4/21 00:00:00
    require(endTime >= now);
    minPurchase = 0.5 ether;
    exchangeStage1 = 1000 ether;
    exchangeStage2 = 500 ether;
    exchangeRate1 = 106666;
    exchangeRate2 = 88888;
    exchangeRate3 = 80000;
    goal = 2000000000 * 10 ** uint256(token.decimals());
    totalToken = 4000000000 * 10 ** uint256(token.decimals());
  }

  // fallback function can be used to buy tokens
  function () external payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    require(beneficiary != address(0));
    require(validPurchase());

    uint256 weiAmount = msg.value;

    // calculate token amount to be created
    uint256 buytokens;
    if (weiAmount >= exchangeStage1) {
      buytokens = weiAmount.mul(exchangeRate1);
    }else if (weiAmount >= exchangeStage2) {
      buytokens = weiAmount.mul(exchangeRate2);
    }else {
      buytokens = weiAmount.mul(exchangeRate3);
    }
    require(buytokens <= totalToken - tokenSaled);

    // update state
    tokenSaled = tokenSaled.add(buytokens);

    uint halfTokens = buytokens / 2;

    token.transfer(beneficiary, halfTokens);
    token.transferToLockedBalance(beneficiary, buytokens - halfTokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, buytokens);

    forwardFunds();
  }

  function finalize() onlyOwner public {
    require(!isFinalized);
    require(hasEnded());

    finalization();
    Finalized();

    token.transfer(owner,token.balanceOf(this));

    isFinalized = true;
  }
  
  function claimRefund() public {
    require(isFinalized);
    require(!goalReached());

    vault.refund(msg.sender);
  }

  function withdraw(address to, uint value) onlyOwner public {
    require(goalReached());
    vault.withdraw(to,value);
    Withdraw(to,value);
  }
  
  function hasEnded() public view returns (bool) {
    return now > endTime;
  }

  function goalReached() public view returns (bool) {
    return tokenSaled >= goal;
  }

  function forwardFunds() internal {
    vault.deposit.value(msg.value)(msg.sender);
  }
  
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now <= endTime;
    bool purchaseAmount = msg.value >= minPurchase;
    return withinPeriod && purchaseAmount;
  }

  function finalization() internal {
    if (goalReached()) {
      vault.close();
    } else {
      vault.enableRefunds();
    }
  }
}
