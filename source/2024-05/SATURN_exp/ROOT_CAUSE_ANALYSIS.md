# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: SATURN_exp
- **Date**: 2024-05
- **Network**: Bsc
- **Total Loss**: 15 BNB

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0x948132f219c0a1adbffbee5d9dc63bec676dd69341a6eca23790632cb9475312
- **Attacker Address(es)**: 0xc468D9A3a5557BfF457586438c130E3AFbeC2ff9
- **Vulnerable Contract(s)**: 0x9BDF251435cBC6774c7796632e9C80B233055b93, 0x9BDF251435cBC6774c7796632e9C80B233055b93
- **Attack Contract(s)**: 0xfcECDBC62DEe7233E1c831D06653b5bEa7845FcC

## 🔍 Technical Analysis

# SATURN Token Exploit Deep Analysis

## 1. Vulnerability Summary

**Vulnerability Type**: Sell Limit Bypass with Flash Loan Manipulation

**Classification**: Economic Attack / Token Transfer Restriction Bypass

**Vulnerable Functions**:
- `_transfer()` in SATURN token contract (0x9BDF251435cBC6774c7796632e9C80B233055b93)
- `pancakeV3FlashCallback()` in attack contract (0xfcECDBC62DEe7233E1c831D06653b5bEa7845FcC)

**Root Cause**: The SATURN token implements a sell limit restriction (`everyTimeSellLimitAmount`) that can be bypassed by manipulating the token balance of the WBNB-SATURN pair during a flash loan transaction, allowing the attacker to sell large amounts of tokens despite the per-transaction limit.

## 2. Step-by-Step Exploit Analysis

### Step 1: Disabling Token Transfer Restrictions
```
Step 1: Disable transfer restrictions
- Trace Evidence: Call to SATURN contract (0x9BDF...) with signature setEnableSwitch(false)
- Contract Code Reference: SATURN.sol setEnableSwitch() function
- POC Code Reference: testExploit() calls EnableSwitch(false)
- EVM State Changes: enableSwitch set to false
- Technical Mechanism: Disables all transfer restrictions including sell limits
```

### Step 2: Transferring Initial Tokens to Attacker
```
Step 2: Transfer tokens from holder to attacker
- Trace Evidence: SATURN transfer from 0xfcEC... to 0xc468...
- Contract Code Reference: SATURN.sol _transfer() with enableSwitch=false bypasses checks
- POC Code Reference: testExploit() transfers SATURN balance from holder to attacker
- Fund Flow: SATURN tokens moved from holder to attacker contract
- Vulnerability Exploitation: Bypasses normal transfer restrictions
```

### Step 3: Re-enabling Transfer Restrictions
```
Step 3: Re-enable transfer restrictions
- Trace Evidence: Call to SATURN contract with signature setEnableSwitch(true)
- Contract Code Reference: SATURN.sol setEnableSwitch() function
- POC Code Reference: testExploit() calls EnableSwitch(true)
- EVM State Changes: enableSwitch set to true
- Technical Mechanism: Re-enables transfer restrictions but attacker now holds tokens
```

### Step 4: Initiating Flash Loan
```
Step 4: Flash loan from PancakeSwap V3 pool
- Trace Evidence: pancakeV3Pool.flash() call for 3300 WBNB
- Contract Code Reference: IPancakeV3PoolActions.sol flash() function
- POC Code Reference: testExploit() calls pancakeV3Pool.flash()
- Fund Flow: 3300 WBNB transferred from pool to attacker contract
- Technical Mechanism: Standard flash loan initiation
```

### Step 5: Flash Loan Callback Execution
```
Step 5: Flash loan callback execution
- Trace Evidence: pancakeV3FlashCallback execution
- Contract Code Reference: IPancakeV3FlashCallback interface
- POC Code Reference: pancakeV3FlashCallback() function
- EVM State Changes: Callback begins attack sequence
- Vulnerability Exploitation: Core attack logic executes here
```

### Step 6: Checking Sell Limit
```
Step 6: Get current sell limit amount
- Trace Evidence: Call to SATURN.everyTimeSellLimitAmount()
- Contract Code Reference: SATURN.sol everyTimeSellLimitAmount storage variable
- POC Code Reference: getEveryTimeSellLimitAmount() call
- Technical Mechanism: Reads the current sell restriction parameter
```

### Step 7: Manipulating Pair Balance
```
Step 7: Swap WBNB for SATURN to manipulate pair balance
- Trace Evidence: WBNB transfer to router and SATURN transfer to creator
- Contract Code Reference: SATURN.sol _transfer() with enableSwitch=true
- POC Code Reference: swapExactTokensForTokens() call
- Fund Flow: WBNB -> Router -> SATURN to creator address
- Vulnerability Exploitation: Artificially increases SATURN balance in pair
```

### Step 8: Advancing Block Number
```
Step 8: Manipulate block number
- Trace Evidence: vm.roll(block.number + 1) in POC
- Contract Code Reference: N/A (Test environment manipulation)
- POC Code Reference: vm.roll(block.number + 1)
- Technical Mechanism: Simulates block advancement to bypass timing checks
```

### Step 9: Transferring Attack Tokens to Pair
```
Step 9: Transfer large SATURN amount to pair
- Trace Evidence: SATURN transfer to pair address
- Contract Code Reference: SATURN.sol _transfer() with enableSwitch=true
- POC Code Reference: SATURN.transfer() to pair address
- Fund Flow: SATURN from attacker to pair contract
- Vulnerability Exploitation: Bypasses sell limit by making transfer appear as deposit
```

### Step 10: Executing Profitable Swap
```
Step 10: Swap SATURN for WBNB at manipulated price
- Trace Evidence: pair.swap() call
- Contract Code Reference: PancakePair.sol swap() function
- POC Code Reference: pair_WBNB_SATURN.swap() call
- Fund Flow: SATURN in pair -> WBNB to attacker
- Vulnerability Exploitation: Profits from artificially inflated SATURN price
```

### Step 11: Repaying Flash Loan
```
Step 11: Repay flash loan with fee
- Trace Evidence: WBNB transfer back to pancakeV3Pool
- Contract Code Reference: IPancakeV3PoolActions flash repayment
- POC Code Reference: WBNB.transfer() to pancakeV3Pool
- Fund Flow: WBNB from attacker back to pool
```

## 3. Root Cause Deep Dive

**Vulnerable Code Location**: SATURN.sol, _transfer() function

```solidity
function _transfer(address from, address to, uint256 amount) internal virtual override {
    if (enableSwitch) {
        if (!_excludedFees[from] && !_excludedFees[to]) {
            require(enableTrade, "Err unable transfer");

            if (mintLocks[from].time > block.timestamp) {
                require(balanceOf(from) - mintLocks[from].num >= amount, "Transfer amount locked");
            }

            if (to == uniswapV2Pair) {
                require(amount <= everyTimeSellLimitAmount, "Exchange Overflow");
                // sell
                unchecked {
                    _txFee = amount * sellFee / commonDiv;
                    amount -= _txFee;
                }
            } else if (from == uniswapV2Pair) {
                require(amount <= everyTimeBuyLimitAmount, "Exchange Overflow");
                // buy
                unchecked {
                    _txFee = amount * buyFee / commonDiv;
                    amount -= _txFee;
                }
            }
        }
    }
    super._transfer(from, to, amount);
}
```

**Flaw Analysis**:
1. The sell limit check only verifies the transfer amount when tokens are sent TO the pair (selling)
2. The contract doesn't track cumulative sells across multiple transactions
3. The limit can be bypassed by artificially inflating the pair's token balance
4. No protection against flash loan manipulation

**Exploitation Mechanism**:
1. Attacker temporarily disables restrictions to acquire tokens
2. Uses flash loan to manipulate pair balance
3. Makes a large transfer to the pair that appears as a deposit rather than sell
4. Executes swap at manipulated price

## 4. Technical Exploit Mechanics

The attack works by:
1. First bypassing transfer restrictions to acquire tokens
2. Using a flash loan to manipulate the pool's token balance
3. Artificially inflating the pool's SATURN balance to make large transfers appear valid
4. Executing swaps at the manipulated price ratios
5. The key insight is that the sell limit only checks outgoing transfers to the pair, not the actual swap amounts

## 5. Bug Pattern Identification

**Bug Pattern**: Transfer Restriction Bypass via Balance Manipulation

**Description**: 
Token contracts that implement per-transaction limits can be bypassed by manipulating the target contract's balance before making restricted transfers.

**Code Characteristics**:
- Per-transaction amount limits
- No cumulative tracking of transfers
- No protection against flash loan manipulation
- Balance checks without context of previous transactions

**Detection Methods**:
- Static analysis for transfer restrictions without cumulative tracking
- Check for missing flash loan protections
- Verify if transfer limits can be bypassed by intermediate balance changes

**Variants**:
- Different types of transfer restrictions (buy/sell/hold)
- Various balance manipulation techniques
- Combinations with other DeFi protocol interactions

## 6. Vulnerability Detection Guide

**Detection Techniques**:
1. Look for transfer functions with amount restrictions
2. Check if restrictions are based solely on single transaction amounts
3. Verify if protocols interact with AMM pools without slippage controls
4. Search for missing flash loan protections

**Code Patterns to Search For**:
```solidity
// Bad pattern - simple amount check
if (to == pair) {
    require(amount <= maxSell, "Sell limit");
}

// Good pattern - cumulative tracking
if (to == pair) {
    userDailySold[from] += amount;
    require(userDailySold[from] <= maxDailySell, "Daily limit");
}
```

**Testing Strategies**:
1. Test transfers with intermediate balance changes
2. Attempt to bypass limits using flash loans
3. Verify behavior with multiple transactions in same block
4. Check interaction with AMM pools

## 7. Impact Assessment

**Financial Impact**:
- 15 BNB stolen (~$4,500 at time of attack)
- Potential for much larger losses if more funds were available

**Technical Impact**:
- Complete bypass of sell restrictions
- Undermines token economic model
- Loss of trust in project

## 8. Advanced Mitigation Strategies

**Immediate Fixes**:
```solidity
// Track cumulative sells per address
mapping(address => uint256) public dailySold;

function _transfer(address from, address to, uint256 amount) internal override {
    if (to == uniswapV2Pair) {
        dailySold[from] += amount;
        require(dailySold[from] <= everyTimeSellLimitAmount, "Daily sell limit");
    }
    // Reset daily counter with time-based logic
}
```

**Long-term Improvements**:
1. Implement time-weighted sell limits
2. Add flash loan detection
3. Use TWAP-based price checks
4. Implement gradual sell restrictions

## 9. Lessons for Security Researchers

**Research Methodologies**:
1. Always check for bypass possibilities when seeing transfer restrictions
2. Test protocol behavior under flash loan scenarios
3. Verify cumulative effects of multiple transactions
4. Check interactions with AMM pools

**Red Flags**:
- Simple amount-based restrictions without cumulative tracking
- No protection against balance manipulation
- Missing flash loan considerations
- Over-reliance on single transaction checks

**Testing Approaches**:
1. Multi-transaction attack simulations
2. Flash loan integration testing
3. Edge case amount testing
4. Pool balance manipulation tests

## 📈 Transaction Trace Summary
- **Transaction ID**: 0x948132f219c0a1adbffbee5d9dc63bec676dd69341a6eca23790632cb9475312
- **Block Number**: 38,488,209
- **Contract Address**: 0xfcecdbc62dee7233e1c831d06653b5bea7845fcc
- **Intrinsic Gas**: 22,012
- **Refund Gas**: 33,900
- **Gas Used**: 479,189
- **Call Type**: CALL
- **Nested Function Calls**: 3
- **Event Logs**: 18
- **Asset Changes**: 9 token transfers
- **Top Transfers**: 3300 wbnb ($2130083.935546875), 3204.501846852103515422 wbnb ($2068441.7895181690808046), None SATURN ($None)
- **Balance Changes**: 6 accounts affected
- **State Changes**: 16 storage modifications
- **Method**: fallback

## 🔗 References
- **POC File**: source/2024-05/SATURN_exp/SATURN_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0x948132f219c0a1adbffbee5d9dc63bec676dd69341a6eca23790632cb9475312)

---
*Generated by DeFi Hack Labs Analysis Tool*
