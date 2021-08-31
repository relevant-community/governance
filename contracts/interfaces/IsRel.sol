// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

// Relevant Governance Token
interface IsRel {
  // Set vesting params for REL and issue vRel
  function setVestedAmount(address account, uint256 amount, bool isShort) external;
}
