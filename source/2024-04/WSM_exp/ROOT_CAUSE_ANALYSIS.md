# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: WSM_exp
- **Date**: 2024-04
- **Network**: Bsc
- **Total Loss**: 979 WSM

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0x5a475a73343519f899527fdb9850f68f8fc73168073c72a3cff8c0c7b8a1e520
- **Attacker Address(es)**: 0x3026C464d3Bd6Ef0CeD0D49e80f171b58176Ce32
- **Vulnerable Contract(s)**: 0xc0afd0e40bb3dcaebd9451aa5c319b745bf792b4
- **Attack Contract(s)**: 0x014eE3c3dE6941cb0202Dd2b30C89309e874B114

## 🔍 Technical Analysis

Based on the provided information, I'll conduct a detailed analysis of the WSM exploit. Let's break this down systematically:

### 1. Vulnerability Summary
**Type**: Price Manipulation Attack via Flash Loan and Presale Contract Interaction
**Classification**: Economic/Price Oracle Manipulation
**Vulnerable Function**: `buyWithBNB()` in the presale contract (called via proxy at 0xFB071...)

### 2. Step-by-Step Exploit Analysis

**Step 1: Flash Loan Initiation**
- Trace Evidence: Call to `flash()` on BNB_WSH_10000 pool (0x84f3...)
- Contract Code: Uniswap V3's flash() function
- POC Ref: `BNB_WSH_10000.flash(address(this), 5_000_000 ether, 0, "");`
- EVM State: Borrows 5M WSM tokens without collateral
- Fund Flow: 5M WSM → Attack Contract
- Mechanism: Standard flash loan pattern

**Step 2: Flash Loan Callback**
- Trace Evidence: `uniswapV3FlashCallback()` execution
- POC Ref: Entire callback function implementation
- EVM State: Now holds 5M WSM debt
- Technical: Must repay + fee within same transaction

**Step 3: Large WSM → BNB Swap**
- Trace Evidence: `exactInputSingle()` to router
- POC Ref: First `exactInputSingle` call with 5M WSM input
- Fund Flow: 5M WSM → 37.34 BNB
- Impact: Dramatically shifts pool price (5M WSM is ~$2.8K)

**Step 4: BNB Withdrawal**
- Trace Evidence: WBNB.withdraw()
- POC Ref: `bnbToken_.withdraw()`
- Fund Flow: 37.34 WBNB → 37.34 native BNB
- Purpose: Prepare for presale interaction

**Step 5: Presale Exploitation**
- Trace Evidence: `proxy_.call{value:...}(buyWithBNB...)`
- Contract Code: Presale contract's buy function
- POC Ref: `buyWithBNB(2_770_000, false)`
- Vulnerability: Presale uses manipulated price
- Impact: Gets 2.77M WSM for undervalued BNB

**Step 6: BNB → WSM Swap Back**
- Trace Evidence: Second `exactInputSingle()`
- POC Ref: Swaps remaining BNB back to WSM
- Fund Flow: 34.46 BNB → 4.797M WSM
- Purpose: Rebalance for loan repayment

**Step 7: Flash Loan Repayment**
- Trace Evidence: WSM transfer back to pool
- POC Ref: `wshToken_.transfer(address(BNB_WSH_10000), 5_000_000 ether + fee0)`
- Fund Flow: 5M + fee WSM → Pool
- Completes: Flash loan cycle

**Step 8: Profit Extraction**
- Trace Evidence: Final WSM transfer to attacker
- POC Ref: Implicit in contract balance changes
- Fund Flow: 2.516M WSM → Attacker
- Profit: ~$1.45K worth of WSM

### 3. Root Cause Deep Dive

**Vulnerable Code Location**: Presale contract's price calculation (via proxy)
Key flaws:
1. **Oracle Manipulation**: Uses real-time pool price without safeguards
2. **No Time-Weighting**: Doesn't use TWAP or other protective measures
3. **Flash Loan Vulnerability**: Susceptible to single-block price manipulation

**Exploitation Mechanism**:
1. Attacker borrows massive WSM amount (5M)
2. Dumps into pool to artificially depress WSM price
3. Presale contract reads manipulated price
4. Buys WSM at artificially low price
5. Reverts pool to normal state before tx ends

### 4. Technical Exploit Mechanics

The attack leverages:
1. **Atomicity**: All steps in one transaction
2. **Price Oracle Design Flaw**: Spot price reliance
3. **Liquidity Concentration**: In WSM/BNB pool
4. **Economic Incentive**: Profit from price difference

### 5. Bug Pattern Identification

**Bug Pattern**: Flash Loan-Assisted Price Oracle Manipulation
**Characteristics**:
- Uses flash loans to temporarily distort prices
- Targets protocols using spot prices
- Often involves multiple swaps in one tx
- Profits from price-sensitive functions

**Detection Methods**:
1. Check for spot price usage in critical functions
2. Look for lack of TWAP/oracle safeguards
3. Identify large swaps preceding sensitive operations

### 6. Vulnerability Detection Guide

**Code Patterns to Search For**:
1. `IUniswapV3Pool(..).slot0()` calls
2. Direct pool price queries
3. `balanceOf()` checks without time weighting

**Testing Strategies**:
1. Simulate large swaps before calls
2. Check price impact sensitivity
3. Test with flash loan scenarios

### 7. Impact Assessment

**Financial Impact**: $1.45K direct loss
**Technical Impact**:
- Undermines presale fairness
- Could drain presale funds completely
- Creates arbitrage opportunities

### 8. Mitigation Strategies

**Immediate Fixes**:
1. Implement TWAP pricing
2. Add minimum/maximum price bounds
3. Use multiple oracle sources

**Long-Term**:
1. Circuit breakers for large swaps
2. Delayed price updates
3. Liquidity requirements

### 9. Lessons for Researchers

**Key Takeaways**:
1. Always audit price oracle implementations
2. Check for flash loan susceptibility
3. Verify time-weighted pricing mechanisms
4. Monitor for large swaps before sensitive ops

**Red Flags**:
- Direct Uniswap pool interactions
- Spot price usage in financial calculations
- Lack of price sanity checks

This analysis demonstrates a classic price oracle manipulation attack made possible by flash loans and inadequate price safeguards. The pattern is reusable across many DeFi protocols that rely on real-time pricing data without proper protections.

## 📈 Transaction Trace Summary
- **Transaction ID**: 0x5a475a73343519f899527fdb9850f68f8fc73168073c72a3cff8c0c7b8a1e520
- **Block Number**: 37,569,861
- **Contract Address**: 0x014ee3c3de6941cb0202dd2b30c89309e874b114
- **Intrinsic Gas**: 22,176
- **Refund Gas**: 110,700
- **Gas Used**: 806,106
- **Call Type**: CALL
- **Nested Function Calls**: 4
- **Event Logs**: 17
- **Asset Changes**: 16 token transfers
- **Top Transfers**: 5000000 wsm ($2881.399996113032102584839), 37.344712626082242493 wbnb ($24105.264376494647406), 5000000 wsm ($2881.399996113032102584839)
- **Balance Changes**: 8 accounts affected
- **State Changes**: 13 storage modifications

## 🔗 References
- **POC File**: source/2024-04/WSM_exp/WSM_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0x5a475a73343519f899527fdb9850f68f8fc73168073c72a3cff8c0c7b8a1e520)

---
*Generated by DeFi Hack Labs Analysis Tool*
