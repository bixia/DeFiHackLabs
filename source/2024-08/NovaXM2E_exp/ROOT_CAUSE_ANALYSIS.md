# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: NovaXM2E_exp
- **Date**: 2024-08
- **Network**: Bsc
- **Total Loss**: None

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0xb1ad1188d620746e2e64785307a7aacf2e8dbda4a33061a4f2fbc9721048e012
- **Attacker Address(es)**: 
- **Vulnerable Contract(s)**: 
- **Attack Contract(s)**: 

## 🔍 Technical Analysis

Based on the provided information, I'll conduct a detailed analysis of the NovaXM2E exploit. The vulnerability appears to be a price manipulation attack through sandwiching stake and withdraw operations in the token staking contract.

### 1. Vulnerability Summary
**Type**: Price Manipulation / Sandwich Attack
**Classification**: Economic Attack
**Vulnerable Contract**: `tokenStake_0x55C9EEbd368873494C7d06A4900E8F5674B11bD2.sol`
**Vulnerable Functions**: 
- `stake()`
- `withdraw()`
- Oracle price conversion mechanisms

### 2. Step-by-Step Exploit Analysis

**Step 1: Flash Loan Initiation**
- Trace Evidence: Call #9 - Swap function call to PancakePair
- POC Code Reference: `Pair.swap(swapamount, 0, address(this), new bytes(1))`
- Technical Mechanism: The attacker initiates a flash loan of 500,000 USDT from the PancakeSwap pair
- Vulnerability Exploitation: This provides the capital needed to manipulate the token price

**Step 2: USDT to NovaXM2E Swap**
- Trace Evidence: Transfer #3 shows 81,308 NOVAX received
- Contract Code Reference: `InternalSwap.sellToken()` function
- POC Code Reference: `swap_token_to_token(address(USDT), address(NovaXM2E), USDT.balanceOf(address(this)))`
- EVM State Changes: USDT balance decreases, NOVAX balance increases
- Fund Flow: 500,000 USDT → 81,308 NOVAX

**Step 3: Token Approval for Staking**
- POC Code Reference: `NovaXM2E.approve(address(tokenStake), NovaXM2E.balanceOf(address(this)))`
- Contract Code Reference: ERC20 approve function
- Technical Mechanism: Grants staking contract permission to spend attacker's NOVAX tokens

**Step 4: Stake Half of Tokens**
- Trace Evidence: Transfer #4 shows 40,654 NOVAX staked
- Contract Code Reference: `TokenStake.stake()` function
- POC Code Reference: `tokenStake.stake(0, NovaXM2E.balanceOf(address(this)) / 2)`
- EVM State Changes: 
  - `totalUserStakedPoolToken` mapping updated
  - `stakedToken` struct created
- Vulnerability Exploitation: This step establishes the staked position that will be exploited

**Step 5: Swap Remaining Tokens Back to USDT**
- Trace Evidence: Transfer #7 shows 299,840 USDT received
- POC Code Reference: `swap_token_to_token(address(NovaXM2E), address(USDT), NovaXM2E.balanceOf(address(this)))`
- Technical Mechanism: This swap artificially inflates the NOVAX price by reducing supply

**Step 6: Withdraw Staked Position**
- Trace Evidence: Transfer #8 shows 124,973 NOVAX withdrawn
- Contract Code Reference: `TokenStake.withdraw()` function
- POC Code Reference: `tokenStake.withdraw(stakeIndex)`
- Vulnerability Exploitation: The withdrawal uses the inflated price to return more tokens than deposited
- Fund Flow: Receives 124,973 NOVAX for original 40,654 stake (3x return)

**Step 7: Final Swap to USDT**
- Trace Evidence: Transfer #11 shows 226,635 USDT received
- POC Code Reference: Second `swap_token_to_token()` call
- Technical Mechanism: Converts exploited NOVAX gains back to USDT

**Step 8: Flash Loan Repayment**
- Trace Evidence: Transfer #12 shows 501,504 USDT repaid
- POC Code Reference: `USDT.transfer(address(Pair), swapamount * 10_000 / 9975 + 1000)`
- Technical Mechanism: Repays flash loan with small fee

### 3. Root Cause Deep Dive

**Vulnerable Code Location**: `TokenStake.sol` - Oracle price conversion and stake/withdraw logic

The core vulnerability lies in how the staking contract converts between token amounts and USD values:

```solidity
// In Oracle.sol
function convertUsdBalanceDecimalToTokenDecimal(uint256 _balanceUsdDecimal) public view returns (uint256) {
    uint256 tokenInternalSwap = convertInternalSwap(_balanceUsdDecimal, true);
    uint256 tokenPairConvert;
    if (pairAddress != address(0)) {
        // Gets reserves from pair
        (uint256 _tokenBalance, uint256 _stableBalance) = ...;
        uint256 _tokenAmount = (_balanceUsdDecimal * _tokenBalance) / _stableBalance;
        tokenPairConvert = _tokenAmount;
    }
    // Uses either swap price or average price
    return typeConvert == 1 ? tokenInternalSwap : tokenPairConvert;
}
```

**Flaw Analysis**:
1. The contract uses spot prices from either internal swap or LP pair without TWAP protection
2. Withdrawals use the current price rather than the price at staking time
3. No minimum/maximum delay enforced between stake and withdraw
4. Price calculations can be easily manipulated with large swaps

**Exploitation Mechanism**:
1. Attacker stakes tokens when price is low (after initial swap)
2. Performs large swap to artificially inflate price
3. Withdraws immediately at inflated price
4. Reverts price back to normal after withdrawal

### 4. Technical Exploit Mechanics

The attack succeeds because:
1. The staking contract's USD value calculations are based on real-time prices
2. There's no time lock or TWAP protection on price oracles
3. The small liquidity pool makes it easy to manipulate prices
4. The contract doesn't track the original staking price

### 5. Bug Pattern Identification

**Bug Pattern**: Real-Time Price Dependency in Staking Contracts
**Description**: Contracts that use real-time prices for staking/withdrawal calculations without protection against manipulation

**Code Characteristics**:
- Direct use of `getReserves()` from AMM pairs
- No TWAP or time-weighted price mechanisms
- Immediate unstaking allowed
- Price calculations that don't account for manipulation

**Detection Methods**:
1. Static Analysis:
   - Look for direct AMM reserve usage
   - Check for missing TWAP implementations
   - Identify unstaking without delay

2. Manual Review:
   - Verify price oracle robustness
   - Check for anti-manipulation measures
   - Review staking/withdrawal timing constraints

### 6. Vulnerability Detection Guide

To find similar vulnerabilities:
1. Search for:
   - `getReserves()` calls in staking contracts
   - `balanceOf` checks without time locks
   - Immediate unstaking functionality

2. Tools:
   - Slither for price oracle detection
   - Custom scripts to detect spot price usage
   - Transaction simulation with large swaps

### 7. Impact Assessment

**Financial Impact**:
- Attacker extracted ~$25k in value
- Protocol lost funds from inflated withdrawals
- Other stakers suffer from price manipulation

**Technical Impact**:
- Broken staking economics
- Loss of trust in protocol
- Potential for repeated attacks

### 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Implement TWAP oracles:
```solidity
// Use time-weighted average prices
interface ITWAPOracle {
    function getTwapPrice() external view returns (uint256);
}
```

2. Add staking locks:
```solidity
// Minimum staking period
require(block.timestamp > stakeTime + MIN_STAKE_DURATION, "Locked");
```

**Long-term Improvements**:
1. Use multiple oracle sources
2. Implement circuit breakers for large price swings
3. Add maximum withdrawal amounts

### 9. Lessons for Security Researchers

Key takeaways:
1. Always scrutinize price oracle implementations
2. Look for economic incentives in staking contracts
3. Test protocols with flash loan scenarios
4. Pay special attention to small liquidity pools

This attack demonstrates how seemingly simple price oracle implementations can lead to significant vulnerabilities when combined with staking mechanics. The pattern is reusable across many DeFi protocols, making it critical for researchers to thoroughly audit these components.

## 📈 Transaction Trace Summary
- **Transaction ID**: 0xb1ad1188d620746e2e64785307a7aacf2e8dbda4a33061a4f2fbc9721048e012
- **Block Number**: 41,116,211
- **Contract Address**: 0x42bc5a77985b2149a8fd085bf1d3fcda4eb71d53
- **Intrinsic Gas**: 22,012
- **Refund Gas**: 156,100
- **Gas Used**: 827,691
- **Call Type**: CALL
- **Nested Function Calls**: 13
- **Event Logs**: 29
- **Asset Changes**: 13 token transfers
- **Top Transfers**: 500000 bsc-usd ($500000), 500000 bsc-usd ($500000), 81308.569002347149065682 novax ($1084.38635776520755983896)
- **Balance Changes**: 6 accounts affected
- **State Changes**: 17 storage modifications

## 🔗 References
- **POC File**: source/2024-08/NovaXM2E_exp/NovaXM2E_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0xb1ad1188d620746e2e64785307a7aacf2e8dbda4a33061a4f2fbc9721048e012)

---
*Generated by DeFi Hack Labs Analysis Tool*
