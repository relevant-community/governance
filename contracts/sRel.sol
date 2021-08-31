// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IsRel.sol";
import "./libraries/Utils.sol";

contract sRel is IsRel, ERC20, ERC20Permit, ERC20Votes, Ownable {
  using Utils for Utils.Vest;
  using Utils for Utils.Unlock;

  // r3l is an erc20 token that throws on transfers (doesn't return false)
  address public immutable r3l;
  // vestAdmin role is responsible for sending tokens to vesting contract
  // TODO can this be rel contract?
  address public vestAdmin;

  // this is how long it takes for tokens to become unlocked
  uint public lockPeriod = 4 days;

  // start of all vesting periods
  uint public immutable vestBegin;
  uint public immutable vestShort; // short vesting period
  uint public immutable vestLong; // long vesting period (using immutable here increases contract size)

  mapping(address => uint256) public vestNonce;
  mapping(address => Utils.Unlock) public unlocks;
  mapping(address => Utils.Vest) public vest;

  constructor(address _r3l, uint _vestBegin, uint _vestShort, uint _vestLong)
    ERC20("Staked REL", "sREL")
    ERC20Permit("Staked REL") 
  {
    r3l = _r3l;
    vestBegin = _vestBegin;
    vestShort = _vestShort;
    vestLong = _vestLong;
  }

  // The functions below are overrides required by Solidity.
  function _afterTokenTransfer(address from, address to, uint256 amount)
      internal
      override(ERC20, ERC20Votes)
  {
      super._afterTokenTransfer(from, to, amount);
  }

  function _mint(address to, uint256 amount)
      internal
      override(ERC20, ERC20Votes)
  {
      super._mint(to, amount);
  }

  function _burn(address account, uint256 amount)
      internal
      override(ERC20, ERC20Votes)
  {
      super._burn(account, amount);
  }

  // only unlocked & unvested tokens can be transferred
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20) {
      super._beforeTokenTransfer(from, to, amount);

      // minting and transfers from contract are not subject to unlocks
      if(from == address(0) || from == address(this)) return;
    
      uint unvestedBalance = balanceOf(msg.sender) - vest[msg.sender].vested();
      require(amount <= unvestedBalance, "sRel: you cannot transfer vested tokens");

      // only unlocked tokens can be transferred
      unlocks[from].useUnlocked(amount);
  }

  // ---- STAKING METHODS ----

  // unlock sRel - after lockPeriod tokens can be transferred or withdrawn
  function unlock(uint256 amount) external override(IsRel) {
    unlocks[msg.sender].unlock(amount, lockPeriod);
  }

   // re-lock tokens
  function resetLock() external override(IsRel) {
    unlocks[msg.sender].resetLock();
  }

  // deposit REL in exchange for sREL
  function stakeRel(uint256 amount) external override(IsRel) {
    IERC20(r3l).transferFrom(msg.sender, address(this), amount);
    _mint(msg.sender, amount);
  }

  // withdraws all unlocked tokens
  function unstakeRel(uint256 amount) external override(IsRel) {
    _burn(msg.sender, amount);
    IERC20(r3l).transfer(msg.sender, amount);
  }

  // ---- VESTING METHODS ----

  // onwer can set amount of vested tokens manually
  // NOTE: REL must be sent to this contract before this method is called 
  function setVestedAmount(address account, uint256 amountShort, uint256 amountLong) onlyOwner external override(IsRel) {
    _setVestedAmount(account, amountShort, amountLong);
  }

  /**
  * @dev Claim curation reward tokens (to be called by user)
  * @param  _shortAmount amount to be vested for a short period
  * @param  _longAmount amount to be vested for a long period
  * @param  _sig Signature by contract owner authorizing the transaction
  * NOTE: REL must be sent to this contract before this method is called 
  */
  function vestTokens(uint256 _shortAmount, uint256 _longAmount, bytes memory _sig) external override(IsRel) {
    bytes32 hash = keccak256(abi.encodePacked(_shortAmount, _longAmount, msg.sender, vestNonce[msg.sender]));
    hash = ECDSA.toEthSignedMessageHash(hash);
    address signer = ECDSA.recover(hash, _sig);

    // check that the message was signed by a vest admin
    require(signer == vestAdmin, "sRel: Claim not authorized");
    
    vestNonce[msg.sender] += 1;
    _setVestedAmount(msg.sender, _shortAmount, _longAmount);
  }

  // helper function that initializes vesting amounts
  // NOTE: REL must be sent to this contract before this method is called 
  function _setVestedAmount(address account, uint256 amountShort, uint256 amountLong) internal {
    vest[account].setVestedAmount(amountShort, amountLong);
    require(totalSupply() + amountShort + amountLong <= IERC20(r3l).balanceOf(address(this)), "sRel: Not enought REL in contract");
    _mint(account, amountShort + amountLong);
  }

  // unvest and unlock tokens
  function claimVestedRel() external override(IsRel) {
    uint amount = vest[msg.sender].updateVestedAmount(vestShort, vestLong, vestBegin);
    unlocks[msg.sender].unlock(amount, lockPeriod);
  }

  // transfer all vested tokens to a new address
  function transferVestedTokens(address to) external override(IsRel) {
    uint amount = vest[msg.sender].vested();
    vest[msg.sender].transferVestedTokens(vest[to]);
    transfer(to, amount);
  }
  
  // ---- GOVERNANCE ----

  function updateLockPeriod(uint newLockPeriod) external onlyOwner override(IsRel) {
    lockPeriod = newLockPeriod;
  }

  function setVestAdmin(address newAdmin) external onlyOwner override(IsRel) {
    vestAdmin = newAdmin;
  }

  // ---- VIEW --------

  function unstaked(address account) external view override(IsRel) returns (uint) {
    return unlocks[account].unlockAmnt;
  }

  function unlockTime(address account) external view override(IsRel) returns (uint) {
    return unlocks[account].unlockTime;
  }

  function vested(address account) external view override(IsRel) returns (uint) {
    return vest[account].vested();
  }

  function vestData(address account) external view override(IsRel) returns (Utils.Vest memory) {
    return vest[account];
  }
}
