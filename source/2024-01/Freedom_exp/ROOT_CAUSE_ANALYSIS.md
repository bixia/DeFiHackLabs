# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: Freedom_exp
- **Date**: 2024-01
- **Network**: Bsc
- **Total Loss**: 74 $

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0x309523343cc1bb9d28b960ebf83175fac941b4a590830caccff44263d9a80ff0
- **Attacker Address(es)**: 0x835b45d38cbdccf99e609436ff38e31ac05bc502
- **Vulnerable Contract(s)**: 0xae3ada8787245977832c6dab2d4474d3943527ab
- **Attack Contract(s)**: 0x4512abb79f1f80830f4641caefc5ab33654a2d49

## 🔍 Technical Analysis

# Freedom_exp Exploit Deep Analysis

## 1. Vulnerability Summary

**Vulnerability Type**: Price Manipulation via Flash Loan and Token Balance Manipulation

**Classification**: Economic Attack / Price Oracle Manipulation

**Vulnerable Functions**:
- `buyToken()` in FREEB contract (0xAE3ADa8787245977832c6DaB2d4474D3943527Ab)
- `_transfer()` in FREE token contract (0x8A43Eb772416f934DE3DF8F9Af627359632CB53F)
- `multiSend()` in FREE token contract

The exploit combines flash loan manipulation with a token balance reporting vulnerability to artificially inflate the perceived value of tokens during a purchase transaction.

## 2. Step-by-Step Exploit Analysis

### Step 1: Flash Loan Initiation
- **Trace Evidence**: 
  - Call to DODO flash loan (0x6098a5638d8d7e9ed2f952d35B2b67c34EC6B476)
  - Borrows 500 WBNB (0x4512abb79f1f80830f4641caefc5ab33654a2d49 receives 500 WBNB)
- **Contract Code Reference**: 
  - DPPAdvanced.sol `flashLoan()` function enables borrowing without collateral
- **POC Code Reference**: 
  ```solidity
  DODO.flashLoan(500 * 1e18, 0, address(this), new bytes(1));
  ```
- **EVM State Changes**: 
  - WBNB balance of attack contract increases by 500
- **Fund Flow**: 
  - 500 WBNB transferred from DODO pool to attack contract
- **Technical Mechanism**: 
  - Flash loan provides temporary capital without requiring collateral
- **Vulnerability Exploitation**: 
  - Provides capital needed to manipulate token prices

### Step 2: WBNB to FREE Token Swap
- **Trace Evidence**: 
  - WBNB balance decreases by 500
  - FREE token balance increases by 10,876.889750197700647166 FREE
- **Contract Code Reference**: 
  - PancakeRouter `swapExactTokensForTokensSupportingFeeOnTransferTokens()`
- **POC Code Reference**: 
  ```solidity
  function WBNBTOTOKEN() internal {
      address[] memory path = new address[](2);
      path[0] = address(WBNB);
      path[1] = address(FREE);
      Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
          WBNB.balanceOf(address(this)), 0, path, address(this), block.timestamp
      );
  }
  ```
- **EVM State Changes**: 
  - WBNB reserves in pair decrease
  - FREE token reserves increase
- **Fund Flow**: 
  - 500 WBNB -> FREE/WBNB pair -> returns FREE tokens
- **Technical Mechanism**: 
  - Standard token swap through PancakeSwap router
- **Vulnerability Exploitation**: 
  - Acquires FREE tokens needed for subsequent manipulation

### Step 3: Token Balance Manipulation
- **Trace Evidence**: 
  - Multiple "fake" transfers of 20 FREE tokens
  - No actual token movement, just event emissions
- **Contract Code Reference**: 
  - FREE token `multiSend()` function:
  ```solidity
  function multiSend(uint num) public {
      address _receiveD;
      address _senD;
      
      for (uint i = 0; i < num; i++) {
          _receiveD = address(MAXADD/ktNum);
          ktNum = ktNum+1;
          _senD = address(MAXADD/ktNum);
          ktNum = ktNum+1;
          emit Transfer(_senD, _receiveD, _initialBalance);
      }
  }
  ```
- **POC Code Reference**: 
  - Implicit through `buyToken()` call which triggers `_afterTokenTransfer`
- **EVM State Changes**: 
  - Only event logs emitted, no actual balance changes
- **Fund Flow**: 
  - No real token movement
- **Technical Mechanism**: 
  - Emits fake Transfer events to manipulate external views of balances
- **Vulnerability Exploitation**: 
  - Creates illusion of token circulation and liquidity

### Step 4: Exploiting buyToken Function
- **Trace Evidence**: 
  - Call to FREEB.buyToken() with listingId = FREEBProxy.balance and expectedPaymentAmount = 5 WBNB
- **Contract Code Reference**: 
  - FREEB contract `buyToken()` function:
  ```solidity
  function buyToken(uint256 listingId, uint256 expectedPaymentAmount) external {
      // Vulnerable logic that doesn't properly verify token balances
  }
  ```
- **POC Code Reference**: 
  ```solidity
  FREEB.buyToken(FREEBProxy.balance, 5 * 1e18);
  ```
- **EVM State Changes**: 
  - FREE token balances appear inflated due to fake transfers
- **Fund Flow**: 
  - Attack contract receives tokens based on manipulated price
- **Technical Mechanism**: 
  - buyToken calculates value based on manipulated balance reports
- **Vulnerability Exploitation**: 
  - Purchases tokens at artificially low price due to balance manipulation

### Step 5: FREE to WBNB Swap
- **Trace Evidence**: 
  - FREE balance decreases by 10,876.889750197700647166
  - WBNB balance increases by 560.332909139618131632
- **Contract Code Reference**: 
  - PancakeRouter `swapExactTokensForTokensSupportingFeeOnTransferTokens()`
- **POC Code Reference**: 
  ```solidity
  function TOKENTOWBNB() internal {
      address[] memory path = new address[](2);
      path[0] = address(FREE);
      path[1] = address(WBNB);
      Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
          FREE.balanceOf(address(this)), 0, path, address(this), block.timestamp
      );
  }
  ```
- **EVM State Changes**: 
  - FREE token reserves increase
  - WBNB reserves decrease
- **Fund Flow**: 
  - FREE tokens -> FREE/WBNB pair -> returns WBNB
- **Technical Mechanism**: 
  - Standard token swap through PancakeSwap router
- **Vulnerability Exploitation**: 
  - Converts manipulated token holdings back to WBNB at profit

### Step 6: Flash Loan Repayment
- **Trace Evidence**: 
  - 500 WBNB transferred back to DODO pool
- **Contract Code Reference**: 
  - DPPAdvanced.sol `flashLoan()` callback
- **POC Code Reference**: 
  ```solidity
  WBNB.transfer(address(DODO), 500 * 1e18);
  ```
- **EVM State Changes**: 
  - WBNB balance of attack contract decreases by 500
- **Fund Flow**: 
  - 500 WBNB returned to DODO pool
- **Technical Mechanism**: 
  - Completes flash loan cycle
- **Vulnerability Exploitation**: 
  - Returns borrowed capital while keeping profit

### Step 7: Profit Extraction
- **Trace Evidence**: 
  - 60.332909139618131633 WBNB sent to attacker address
- **Contract Code Reference**: 
  - Standard ERC20 transfer
- **POC Code Reference**: 
  - Implicit in testExploit() function
- **EVM State Changes**: 
  - Final WBNB balance of attack contract
- **Fund Flow**: 
  - 60.33 WBNB profit to attacker
- **Technical Mechanism**: 
  - Simple token transfer
- **Vulnerability Exploitation**: 
  - Realizes profit from the exploit

## 3. Root Cause Deep Dive

### Vulnerable Code Location: FREE.sol - balanceOf() and multiSend()
```solidity
function balanceOf(address account) public view virtual override returns (uint) {
    uint balance=super.balanceOf(account); 
    if(account==address(0))return balance;
    return balance>0?balance:_initialBalance;
}

function multiSend(uint num) public {
    address _receiveD;
    address _senD;
    
    for (uint i = 0; i < num; i++) {
        _receiveD = address(MAXADD/ktNum);
        ktNum = ktNum+1;
        _senD = address(MAXADD/ktNum);
        ktNum = ktNum+1;
        emit Transfer(_senD, _receiveD, _initialBalance);
    }
}
```

**Flaw Analysis**:
1. The `balanceOf()` function returns a fake balance (`_initialBalance`) for addresses with zero balance, creating false liquidity perception
2. `multiSend()` emits fake Transfer events without actual token movements, manipulating external views of token distribution
3. Combined, these allow the contract to report inflated balances and fake activity
4. The FREEB contract's `buyToken()` function relies on these manipulated balance reports

**Exploitation Mechanism**:
1. Attacker uses flash loan to get capital
2. Swaps to get FREE tokens
3. Triggers fake transfers to manipulate balance reports
4. Uses manipulated price to buy tokens cheaply
5. Sells tokens at real market price
6. Repays flash loan and keeps profit

## 4. Technical Exploit Mechanics

The attack works by exploiting several key mechanisms:

1. **Balance Reporting Manipulation**:
   - The FREE token's `balanceOf()` returns non-zero values even for empty addresses
   - This makes the token appear more widely distributed and liquid than it really is

2. **Fake Transfer Events**:
   - The `multiSend()` function emits Transfer events between non-existent addresses
   - These events create the illusion of token circulation without actual movement

3. **Price Oracle Manipulation**:
   - The FREEB contract's price calculations rely on these manipulated balance reports
   - By making the token appear more liquid, the attacker can manipulate the effective price

4. **Flash Loan Amplification**:
   - The attacker uses a flash loan to temporarily boost their purchasing power
   - This allows larger price impact than would be possible with their own capital

## 5. Bug Pattern Identification

**Bug Pattern**: Fake Balance Reporting with Event Spamming

**Description**:
A token contract that:
1. Reports false balances for empty addresses
2. Allows emission of fake transfer events
3. Has functions that rely on these manipulated balance reports

**Code Characteristics**:
- Overridden `balanceOf()` that doesn't match actual balances
- Functions that emit Transfer events without token movements
- Price calculations that depend on balance reports
- Lack of validation in purchase functions

**Detection Methods**:
1. Static Analysis:
   - Check for `balanceOf()` overrides that don't match storage
   - Look for event emission without state changes
   - Verify price calculations use verified data

2. Manual Review:
   - Audit all balance reporting functions
   - Verify Transfer events correspond to actual transfers
   - Check price calculations use reliable data sources

**Variants**:
1. Fake liquidity reporting
2. Phantom token balances
3. Event spam price manipulation

## 6. Vulnerability Detection Guide

**Code Patterns to Search For**:
1. `balanceOf()` functions that return non-zero for empty addresses
2. Functions that emit Transfer events without token movements
3. Price calculations based solely on token balances
4. Lack of validation in purchase/sale functions

**Static Analysis Rules**:
1. Flag any `balanceOf()` that doesn't directly read from balances mapping
2. Detect Transfer events emitted without corresponding token transfers
3. Identify price calculations using unverified balance data

**Manual Review Techniques**:
1. Verify all balance reporting matches actual storage
2. Check all event emissions correspond to real state changes
3. Audit price calculation logic for external dependencies

**Testing Strategies**:
1. Test `balanceOf()` with empty addresses
2. Verify event logs match actual token movements
3. Test price calculations with manipulated inputs

## 7. Impact Assessment

**Financial Impact**:
- Direct profit of ~60 WBNB ($74 at time of attack)
- Potential for much larger impacts if exploited at scale

**Technical Impact**:
- Compromises token price integrity
- Undermines trust in token economics
- Potential ripple effects on integrated protocols

**Potential for Similar Attacks**:
- High - this pattern can be replicated in other tokens
- Particularly dangerous for new tokens with custom balance logic

## 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Remove fake balance reporting:
```solidity
function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
}
```

2. Disable fake transfers:
```solidity
function multiSend(uint num) public onlyOwner {
    // Add access control
    // Add real transfer logic
}
```

**Long-term Improvements**:
1. Use time-weighted average prices (TWAP)
2. Implement circuit breakers for large price movements
3. Add validation to purchase functions

**Monitoring Systems**:
1. Track Transfer event to actual transfer ratios
2. Monitor for abnormal balance reports
3. Implement price sanity checks

## 9. Lessons for Security Researchers

**Discovery Methods**:
1. Thoroughly review all balance reporting functions
2. Verify correspondence between events and state changes
3. Test price calculations with edge cases

**Red Flags**:
1. Custom `balanceOf()` implementations
2. Functions that emit events without state changes
3. Price calculations based solely on balances

**Testing Approaches**:
1. Test with zero-balance addresses
2. Verify event logs match actual transfers
3. Attempt to manipulate price calculations

**Research Methodologies**:
1. Symbolic execution to find balance discrepancies
2. Differential testing against standard implementations
3. Fuzzing price calculation inputs

## 📈 Transaction Trace Summary
- **Transaction ID**: 0x309523343cc1bb9d28b960ebf83175fac941b4a590830caccff44263d9a80ff0
- **Block Number**: 35,123,711
- **Contract Address**: 0x4512abb79f1f80830f4641caefc5ab33654a2d49
- **Intrinsic Gas**: 22,084
- **Refund Gas**: 130,826
- **Gas Used**: 632,048
- **Call Type**: CALL
- **Nested Function Calls**: 3
- **Event Logs**: 28
- **Asset Changes**: 23 token transfers
- **Top Transfers**: 500 wbnb ($323549.98779296875), 500 wbnb ($323549.98779296875), None FREE ($None)
- **Balance Changes**: 10 accounts affected
- **State Changes**: 6 storage modifications

## 🔗 References
- **POC File**: source/2024-01/Freedom_exp/Freedom_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0x309523343cc1bb9d28b960ebf83175fac941b4a590830caccff44263d9a80ff0)

---
*Generated by DeFi Hack Labs Analysis Tool*
