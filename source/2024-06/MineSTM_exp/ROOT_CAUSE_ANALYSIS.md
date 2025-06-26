# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: MineSTM_exp
- **Date**: 2024-06
- **Network**: Bsc
- **Total Loss**: None

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0x849ed7f687cc2ebd1f7c4bed0849893e829a74f512b7f4a18aea39a3ef4d83b1
- **Attacker Address(es)**: 0x40a82dfdbf01630ea87a0372cf95fa8636fcad89
- **Vulnerable Contract(s)**: 
- **Attack Contract(s)**: 0x88c17622d33b327268924e9f90a9e475a244e3ab

## 🔍 Technical Analysis

Based on the provided information, I'll conduct a detailed analysis of the exploit. The attack appears to be a flash loan-based manipulation of the MineSTM contract's token economics.

### 1. Vulnerability Summary
**Type**: Price Manipulation via Flash Loan
**Classification**: Economic Attack
**Vulnerable Functions**: 
- `sell()` in MineSTM.sol
- `pancakeV3FlashCallback()` in the attack contract
- The entire liquidity manipulation flow in the MineSTM contract

### 2. Step-by-Step Exploit Analysis

**Step 1: Flash Loan Initiation**
- Trace Evidence: Function `flash()` called on BUSDT_USDC pair
- Contract Code: `BUSDT_USDC_0x92b7807bF19b7DDdf89b706143896d05228f3121.sol` flash function
- POC Code: `BUSDT_USDC.flash()` call in testExploit()
- EVM State: 50,000 USDT borrowed
- Fund Flow: 50k USDT from pool to attack contract
- Mechanism: Standard flash loan initiation

**Step 2: Pair Sync Manipulation**
- Trace Evidence: `BUSDT_STM.sync()` called
- Contract Code: `STM_0xBd0DF7D2383B1aC64afeAfdd298E640EfD9864e0.sol` sync function
- POC Code: `BUSDT_STM.sync()` in callback
- EVM State: Reserves updated to current balances
- Fund Flow: None (state change only)
- Vulnerability: Sync resets pool state before manipulation

**Step 3: Large USDT to STM Swap**
- Trace Evidence: swapExactTokensForTokensSupportingFeeOnTransferTokens()
- Contract Code: Router swap functions in `ROUTER_0x0ff0eBC65deEe10ba34fd81AfB6b95527be46702.sol`
- POC Code: Router swap call with 50k USDT
- EVM State: Massive STM tokens received
- Fund Flow: 50k USDT → STM tokens
- Vulnerability: Large swap distorts price before MineSTM interaction

**Step 4: MineSTM Allowance Setup**
- Trace Evidence: `updateAllowance()` called
- Contract Code: `mineSTM.updateAllowance()` in MineSTM.sol
- POC Code: `mineSTM.updateAllowance()`
- EVM State: Max approvals set for attack contract
- Fund Flow: None (approval only)
- Vulnerability: Prepares for subsequent sell operations

**Step 5: First STM Sell Operation**
- Trace Evidence: `sell(81)` called
- Contract Code: `sell()` in MineSTM.sol
- POC Code: `mineSTM.sell(81)`
- EVM State: 81 STM burned, LP tokens received
- Fund Flow: STM → LP tokens
- Vulnerability: Selling at manipulated price

**Step 6: LP Token Removal**
- Trace Evidence: removeLiquidity() internal call
- Contract Code: Router removeLiquidity in `ROUTER_0x0ff0eBC65deEe10ba34fd81AfB6b95527be46702.sol`
- POC Code: Triggered by sell()
- EVM State: LP tokens converted to USDT/STM
- Fund Flow: LP → USDT+STM
- Vulnerability: Extracts value from manipulated pool

**Step 7: Second STM Sell Operation**
- Trace Evidence: `sell(7)` called
- Contract Code: Same as Step 5
- POC Code: `mineSTM.sell(7)`
- EVM State: Additional 7 STM burned
- Fund Flow: More STM → LP → USDT
- Vulnerability: Further profit extraction

**Step 8: Flash Loan Repayment**
- Trace Evidence: USDT transfer back to pool
- Contract Code: pancakeV3FlashCallback completion
- POC Code: Final transfer in callback
- EVM State: 50,005 USDT repaid (500 USDT fee)
- Fund Flow: 50,005 USDT to pool
- Vulnerability: Loan repaid with profits remaining

**Step 9: Profit Extraction**
- Trace Evidence: 13,826 USDT to attacker
- Contract Code: Final transfer in POC
- POC Code: Profit calculation and transfer
- EVM State: Attacker balance increased
- Fund Flow: 13,826 USDT profit
- Vulnerability: Net gain after all operations

### 3. Root Cause Deep Dive

**Vulnerable Code Location**: MineSTM.sol, sell() function
```
function sell(uint256 amount) external {
    eve_token_erc20.transferFrom(msg.sender, address(this), amount);
    (, uint256 r1, ) = inner_pair.getReserves();
    uint256 lpAmount = amount*inner_pair.totalSupply()/(2*r1);
    uniswapV2Router.removeLiquidity(
        address(usdt_token_erc20),
        address(eve_token_erc20),
        lpAmount,
        0,
        0,
        msg.sender,
        block.timestamp
    );
}
```

**Flaw Analysis**:
1. The sell calculation `amount*inner_pair.totalSupply()/(2*r1)` is vulnerable to price manipulation
2. No slippage protection (min amounts set to 0)
3. Relies on manipulated pool reserves
4. Doesn't account for flash loan scenarios

**Exploitation Mechanism**:
1. Attacker inflates STM price via large swap
2. Sells STM at inflated price
3. Removes liquidity based on distorted reserves
4. Profits from the price difference

### 4. Technical Exploit Mechanics

The attack works by:
1. Borrowing large USDT amount to dominate pool
2. Manipulating STM price upward
3. Using MineSTM's sell function which:
   - Uses manipulated reserves for calculation
   - Has no protection against price manipulation
   - Allows removal of liquidity at unfair rates
4. Repaying loan while keeping difference

### 5. Bug Pattern Identification

**Bug Pattern**: Price Manipulation in Liquidity Removal
**Description**: Contracts that calculate liquidity removal amounts based on current pool reserves without protection against temporary price manipulation.

**Code Characteristics**:
- Reliance on getReserves() without TWAP
- No minimum return amount checks
- Allowing large single-block operations
- Lack of reentrancy guards

**Detection Methods**:
- Look for liquidity removal calculations using spot prices
- Check for missing slippage parameters
- Identify unguarded external calls in price-sensitive functions

### 6. Vulnerability Detection Guide

To find similar vulnerabilities:
1. Search for all liquidity removal functions
2. Check how they calculate amounts:
   - `getReserves()` calls
   - Spot price usage
3. Verify slippage protections:
   - Minimum return amounts
   - Deadline parameters
4. Look for flash loan interactions

### 7. Impact Assessment

**Financial Impact**: $13.8k stolen
**Technical Impact**:
- Protocol liquidity drained
- Token economics disrupted
- Loss of user funds

### 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Add minimum return amounts to sell():
```solidity
function sell(uint256 amount, uint256 minUsdt) external {
    // ... existing code ...
    require(amountUsdt >= minUsdt, "Insufficient output");
}
```

**Long-term Improvements**:
1. Implement TWAP pricing
2. Add flash loan detection
3. Rate limiting on large operations

### 9. Lessons for Security Researchers

Key takeaways:
1. Always check price oracle robustness
2. Validate all math in liquidity-sensitive functions
3. Assume any public function can be called in manipulated states
4. Pay special attention to flash loan attack vectors

This analysis shows how careful code review of price calculations and liquidity mechanisms is crucial for DeFi security. The vulnerability stemmed from naive assumptions about pool state consistency within a single transaction.

## 📈 Transaction Trace Summary
- **Transaction ID**: 0x849ed7f687cc2ebd1f7c4bed0849893e829a74f512b7f4a18aea39a3ef4d83b1
- **Block Number**: 39,383,150
- **Contract Address**: 0x88c17622d33b327268924e9f90a9e475a244e3ab
- **Intrinsic Gas**: 22,024
- **Refund Gas**: 99,619
- **Gas Used**: 476,071
- **Call Type**: CALL
- **Nested Function Calls**: 6
- **Event Logs**: 29
- **Asset Changes**: 15 token transfers
- **Top Transfers**: 50000 bsc-usd ($50050.0023365020751953125), 50000 bsc-usd ($50050.0023365020751953125), None STM ($None)
- **Balance Changes**: 5 accounts affected
- **State Changes**: 12 storage modifications

## 🔗 References
- **POC File**: source/2024-06/MineSTM_exp/MineSTM_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0x849ed7f687cc2ebd1f7c4bed0849893e829a74f512b7f4a18aea39a3ef4d83b1)

---
*Generated by DeFi Hack Labs Analysis Tool*
