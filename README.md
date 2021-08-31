# Relevant Protocol Governance Smart Contracts

## sREL token
sREL is governance wrapper for REL tokens and allows staking and vesting

### Roles
 - `owner` (this will eventually be a DAO)
   - can initialize initial vesting accounts
   - can set `vestAdmin` role
 - `vestAdmin` is designed to be a hotwallet that allows automated vesting initialization via the Relevant App

### Staking
 - REL tokens can be staked via the contract in exchange for sRel
 - sRel cannot be transferred or exchanged back to REL unless they are 'unlocked' (unstaked) and unvested
 - `lockPeriod` deterimines the time it takes to unstake the tokens

### Vesting
 - Vested tokens can be added by the `owner` of the contract or via a signature from the `vestAdmin'
 - There are two vesting schedules - short and long, exact params TBD, likely 4 and 16 years respectively
 - The params are global - meant to distribute a set amount of tokens to users
 - Vested tokens can be used to cast governance votes
 - The full amount of vested tokens can be transferred to a new account 
