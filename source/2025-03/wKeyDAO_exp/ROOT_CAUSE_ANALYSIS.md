# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: wKeyDAO_exp
- **Date**: 2025-03
- **Network**: Bsc
- **Total Loss**: None

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0xc9bccafdb0cd977556d1f88ac39bf8b455c0275ac1dd4b51d75950fb58bad4c8
- **Attacker Address(es)**: 0x3026c464d3bd6ef0ced0d49e80f171b58176ce32
- **Vulnerable Contract(s)**: 0xd511096a73292a7419a94354d4c1c73e8a3cd851
- **Attack Contract(s)**: 0x3783c91ee49a303c17c558f92bf8d6395d2f76e3

## 🔍 Technical Analysis

Based on the provided information, I'll conduct a detailed analysis of the wKeyDAO exploit. The attack appears to be a price manipulation attack leveraging the token's fee mechanism and flash loans.

### 1. Vulnerability Summary
**Type**: Fee manipulation and arbitrage attack
**Classification**: Economic attack / Fee bypass
**Vulnerable Function**: `_transfer()` in WKEYDAO contract (wKeyDAO_0x194B302a4b0a79795Fb68E2ADf1B8c9eC5ff8d1F.sol)

### 2. Step-by-Step Exploit Analysis

**Step 1: Flash Loan Setup**
- Trace Evidence: Call to `__dodoFlashLoan()` with 1200 BUSD
- POC Code Reference: `attacker.fire()` initiates flash loan
- Contract Code Reference: DODO flash loan interface
- EVM State Changes: 1200 BUSD transferred to attack contract
- Fund Flow: 1200 BUSD from DODO pool → attacker contract
- Technical Mechanism: Standard flash loan pattern
- Vulnerability Exploitation: Provides capital for attack

**Step 2: BUSD Approval**
- Trace Evidence: `approve(wKeyDaoSell, 1_000_000e18)`
- POC Code Reference: `__realAttack()` line approving BUSD
- Contract Code Reference: BUSD's approve function
- EVM State Changes: Allowance set for wKeyDaoSell contract
- Fund Flow: No actual transfer, just permission setup
- Technical Mechanism: Standard ERC20 approval

**Step 3: wKeyDAO Approval**
- Trace Evidence: `approve(pancakeSwapRouterV2, huge_amount)`
- POC Code Reference: `__realAttack()` line approving router
- Contract Code Reference: wKeyDAO's approve function
- EVM State Changes: Allowance set for PancakeSwap router
- Fund Flow: No actual transfer, just permission setup
- Technical Mechanism: Standard ERC20 approval

**Step 4: Initial Buy**
- Trace Evidence: `IwKeyDaoSell(wKeyDaoSell).buy()`
- POC Code Reference: First loop iteration in `__realAttack()`
- Contract Code Reference: wKeyDaoSell's buy function
- EVM State Changes: BUSD spent, wKeyDAO minted
- Fund Flow: 1159 BUSD → wKeyDaoSell, 230000000000 wKeyDAO → attacker
- Technical Mechanism: Direct purchase from contract

**Step 5: First Sell**
- Trace Evidence: `swapExactTokensForTokensSupportingFeeOnTransferTokens()`
- POC Code Reference: First sell in loop
- Contract Code Reference: PancakeSwap router swap function
- EVM State Changes: wKeyDAO balance reduced, BUSD received
- Fund Flow: 230000000000 wKeyDAO → PancakeSwap, 406 BUSD → attacker
- Vulnerability Exploitation: Bypasses fee mechanism by selling immediately

**Step 6: Fee Distribution**
- Trace Evidence: Multiple transfers to fee receivers
- Contract Code Reference: WKEYDAO's `_transfer()` fee logic
- EVM State Changes: Fees distributed to multiple addresses
- Fund Flow: Portions of BUSD sent to fee receivers
- Technical Mechanism: Fee splitting logic in token contract

**Steps 7-10: Repeat Attack Loop**
- Same pattern repeated 4 more times (5 total iterations)
- Each iteration:
  - Buys from wKeyDaoSell
  - Sells on PancakeSwap
  - Collects arbitrage profit
  - Distributes fees

**Final Step: Flash Loan Repayment**
- Trace Evidence: BUSD transfer back to DODO pool
- POC Code Reference: `_flashLoanCallBack()` repayment
- Contract Code Reference: DODO flash loan callback
- EVM State Changes: Loan balance cleared
- Fund Flow: 1200 BUSD returned to DODO pool

### 3. Root Cause Deep Dive

**Vulnerable Code Location**: WKEYDAO.sol, `_transfer()` function

```solidity
function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
    // ...
    if (_isTradeAndNotInSystem(sender, recipient)) {
        if (sender == mainPair) { // buyer or remove lp
            uint buyFee = amount.mul(buyFeeRatio).div(PRECISION);
            if(buyFee>0){
                amount = amount - buyFee;
                _balances[buyFeeReceiver] += buyFee;
                emit Transfer(sender, buyFeeReceiver, buyFee);
            }
        }
        else if(recipient == mainPair){ // seller or add lp
            uint256 fee = amount.mul(feeRatio).div(PRECISION);
            if (fee > 0) {
                amount = amount - fee;
                _balances[feeReceiver] += fee;
                emit Transfer(sender, feeReceiver, fee);
                emit FeeTaken(sender, feeReceiver, amount, fee);
                IFeeReceiver(feeReceiver).triggerSwapFeeForLottery(fee);
            }
        }
    }
    // ...
}
```

**Flaw Analysis**:
1. The fee mechanism only triggers on mainPair trades
2. Direct purchases from wKeyDaoSell bypass fee mechanism
3. Price difference between wKeyDaoSell and PancakeSwap creates arbitrage
4. No anti-bot or cooldown mechanisms
5. Flash loans enable large-scale exploitation

**Exploitation Mechanism**:
1. Attacker buys cheap from wKeyDaoSell (no fees)
2. Sells at higher price on PancakeSwap (paying fees but still profitable)
3. Repeats to extract value from price difference
4. Uses flash loan to scale attack

### 4. Technical Exploit Mechanics

The attack works because:
1. The wKeyDaoSell contract sells tokens at a fixed price
2. PancakeSwap price is higher due to fees and market dynamics
3. By buying cheap and selling higher, attacker profits
4. Flash loan provides capital to maximize gains
5. The 5 iterations in POC demonstrate repeatability

### 5. Bug Pattern Identification

**Bug Pattern**: Fee Bypass Arbitrage
**Description**: When a protocol has different pricing mechanisms that can be exploited through arbitrage, especially when one path bypasses fees.

**Code Characteristics**:
- Multiple purchase paths with different fee structures
- Direct minting/buying functions without fees
- Secondary markets with fees
- No cooldowns or purchase limits

**Detection Methods**:
- Check all token purchase paths for consistent fee application
- Verify arbitrage opportunities between different purchase methods
- Look for price differences between protocol and AMM prices

### 6. Vulnerability Detection Guide

To find similar vulnerabilities:
1. Map all token acquisition methods
2. Compare prices between different acquisition paths
3. Check for fee consistency across all paths
4. Look for flash loan usage in transactions
5. Analyze token flow patterns in historical transactions

### 7. Impact Assessment

**Financial Impact**:
- $767 profit shown in POC
- Could be scaled with larger flash loans
- Potential to drain protocol funds

**Technical Impact**:
- Distorts token economics
- Could lead to liquidity issues
- Undermines fee collection mechanism

### 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Apply consistent fees across all purchase paths
2. Implement purchase limits or cooldowns

**Long-term Improvements**:
1. Dynamic fee adjustment based on arbitrage opportunities
2. Flash loan resistant mechanisms
3. Price oracle integration

### 9. Lessons for Security Researchers

Key takeaways:
1. Always compare all token acquisition paths
2. Analyze fee application consistency
3. Check for arbitrage possibilities
4. Consider flash loan attack vectors
5. Monitor price differences between protocol and AMMs

This attack demonstrates how seemingly minor inconsistencies in fee application can create significant vulnerabilities when combined with flash loans and arbitrage opportunities.

## 📈 Transaction Trace Summary
- **Transaction ID**: 0xc9bccafdb0cd977556d1f88ac39bf8b455c0275ac1dd4b51d75950fb58bad4c8
- **Block Number**: 47,469,060
- **Contract Address**: 0x3783c91ee49a303c17c558f92bf8d6395d2f76e3
- **Intrinsic Gas**: 22,888
- **Refund Gas**: 3,517,300
- **Gas Used**: 31,873,935
- **Call Type**: CALL
- **Nested Function Calls**: 7
- **Event Logs**: 1547
- **Asset Changes**: 874 token transfers
- **Top Transfers**: 1200 bsc-usd ($1201.2000560760498046875), 1159 bsc-usd ($1160.159054160118103027), None wkeyDAO ($None)
- **Balance Changes**: 11 accounts affected
- **State Changes**: 421 storage modifications

## 🔗 References
- **POC File**: source/2025-03/wKeyDAO_exp/wKeyDAO_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0xc9bccafdb0cd977556d1f88ac39bf8b455c0275ac1dd4b51d75950fb58bad4c8)

---
*Generated by DeFi Hack Labs Analysis Tool*
