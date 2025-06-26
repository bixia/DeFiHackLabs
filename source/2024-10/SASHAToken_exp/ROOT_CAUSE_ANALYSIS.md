# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: SASHAToken_exp
- **Date**: 2024-10
- **Network**: Ethereum
- **Total Loss**: 249 ETH

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0xd9fdc7d03eec28fc2453c5fa68eff82d4c297f436a6a5470c54ca3aecd2db17e
- **Attacker Address(es)**: 0x493c5655D40B051a64bc88A6af21D73d3A9B72A2, 0x81F48A87Ec44208c691f870b9d400D9c13111e2E
- **Vulnerable Contract(s)**: 
- **Attack Contract(s)**: 0x991493900674b10bdf54bdfe95b4e043257798cf

## 🔍 Technical Analysis

Based on the provided source code, transaction trace data, and POC, I'll conduct a detailed analysis of the exploit. The vulnerability appears to be a fee manipulation attack in the SASHA token contract, allowing the attacker to bypass intended fee mechanisms during swaps.

### 1. Vulnerability Summary
**Type**: Fee Manipulation / Tax Bypass
**Classification**: Logic Flaw in Fee Calculation
**Vulnerable Functions**: 
- `_transfer()` in SASHA.sol (lines 263-305)
- `swapBack()` in SASHA.sol (lines 327-338)

### 2. Step-by-Step Exploit Analysis

**Step 1: Initial Setup and Approvals**
- Trace Evidence: 
  - Function calls to approve() for WETH and SASHA tokens
  - Input data shows max approval (0xffff...ffff) to Uniswap routers
- Contract Code Reference:
  ```solidity
  // In AttackContract.attack()
  IWETH(payable(weth)).approve(UniswapV2_Router2, type(uint256).max);
  IERC20(SASHA).approve(UniswapV2_Router2, type(uint256).max);
  IERC20(SASHA).approve(UniswapV3_Router2, type(uint256).max);
  ```
- EVM State Changes: 
  - Allowance mappings updated for attacker contract
- Technical Mechanism: 
  - Prepares for subsequent swaps by granting unlimited spending approval

**Step 2: WETH Deposit**
- Trace Evidence: 
  - 0.07 ETH deposited to WETH
  - Call to WETH.deposit() with value
- POC Code Reference:
  ```solidity
  IWETH(payable(weth)).deposit{value: 0.07 ether}();
  ```
- Fund Flow: 
  - 0.07 ETH from attacker → WETH contract → attacker's WETH balance
- Vulnerability Exploitation: 
  - Converts ETH to WETH for trading on Uniswap

**Step 3: Initial Swap (WETH → SASHA)**
- Trace Evidence:
  - swapExactTokensForTokensSupportingFeeOnTransferTokens call
  - Input: 70,000,000,000,000,000 WETH (0.07)
- Contract Code Reference:
  ```solidity
  // In SASHA._transfer()
  if (auto1[to]) {
      fees = amount.mul(sellFee).div(100);
  }
  else if(auto1[from]) {
      fees = amount.mul(buyFee).div(100);
  }
  ```
- EVM State Changes:
  - WETH balance decreased in attacker contract
  - SASHA balance increased
- Technical Mechanism:
  - Buys SASHA tokens with minimal fees due to buyFee being 0%

**Step 4: Manipulative Transfer to Pool**
- Trace Evidence:
  - Transfer of 1,000,000,000,000,000,000 SASHA to Uniswap pair
- POC Code Reference:
  ```solidity
  IERC20(SASHA).transfer(UniswapV2_SASHA21, 1_000_000_000_000_000_000);
  ```
- Vulnerability Exploitation:
  - Artificially inflates pool reserves before large sell
  - Bypasses fee checks by directly transferring to pool

**Step 5: Large Sell (SASHA → WETH)**
- Trace Evidence:
  - exactInputSingle call with 99,000,000,000,000,000,000,000 SASHA
- Contract Code Reference:
  ```solidity
  // In SASHA._transfer()
  if (auto2[to]) {
      fees = amount.mul(sellFee).div(100);
  }
  else if(auto2[from]) {
      fees = amount.mul(buyFee).div(100);
  }
  ```
- EVM State Changes:
  - Massive SASHA amount moved with minimal fees
- Technical Mechanism:
  - Exploits fee exemption for certain addresses
  - Uses Uniswap V3 to bypass V2 fee checks

**Step 6: WETH Withdrawal**
- Trace Evidence:
  - WETH.withdraw() call for 249.276 ETH
- POC Code Reference:
  ```solidity
  IWETH(payable(weth)).withdraw(249_276_511_929_373_786_924);
  ```
- Fund Flow:
  - WETH contract → attacker contract → attacker address
- Vulnerability Exploitation:
  - Converts ill-gotten WETH gains back to ETH

### 3. Root Cause Deep Dive

**Vulnerable Code Location**: SASHA.sol, _transfer() function
```solidity
function _transfer(address from, address to, uint256 amount) internal override {
    // ...
    bool takeFee = !swapping && !_isExcludedFromFees[from] && !_isExcludedFromFees[to];

    uint256 fees = 0;
    if (takeFee) {
        if (auto1[to]) {
            fees = amount.mul(sellFee).div(100);
        }
        else if(auto2[to]) {
            fees = amount.mul(sellFee).div(100);
        }
        else if(auto1[from]) {
            fees = amount.mul(buyFee).div(100);
        }
        else if(auto2[from]) {
            fees = amount.mul(buyFee).div(100);
        }
        if (fees > 0) {
            super._transfer(from, address(this), fees);
        }
        amount -= fees;
    }
    super._transfer(from, to, amount);
}
```

**Flaw Analysis**:
1. The fee logic depends on `auto1` and `auto2` mappings which can be manipulated
2. Fees are only applied when `takeFee` is true, which can be bypassed
3. No validation of swap amounts or price impact
4. Fee percentages (buyFee/sellFee) are set to 0, making the checks irrelevant

**Exploitation Mechanism**:
1. Attacker sets up contract to bypass `_isExcludedFromFees` checks
2. Uses direct transfers to manipulate pool reserves
3. Executes large swaps when fees are effectively 0%
4. Takes advantage of multiple swap paths (V2 and V3) to avoid detection

### 4. Technical Exploit Mechanics

The attack works by:
1. First creating artificial liquidity by transferring tokens directly to the pool
2. Then executing a large trade that benefits from the manipulated reserves
3. Using the fee exemption for certain addresses to avoid paying taxes
4. Carefully timing the trades to maximize price impact

The key technical aspects are:
- Bypassing fee checks through direct transfers
- Manipulating pool reserves before large trades
- Using multiple swap routers to avoid detection
- Taking advantage of 0% fee settings

### 5. Bug Pattern Identification

**Bug Pattern**: Fee Bypass Through Direct Pool Manipulation
**Description**: 
Token contracts that implement transfer fees can be exploited when:
1. Fees can be bypassed for certain addresses
2. Direct pool transfers are allowed
3. Fee percentages are set to 0

**Code Characteristics**:
- Existence of `_isExcludedFromFees` mappings
- Multiple swap router integrations
- Direct token transfers to pool addresses
- Configurable fee percentages

**Detection Methods**:
1. Static analysis for:
   - Direct transfers to known pool addresses
   - Fee exemption logic
   - Multiple swap router approvals
2. Check for:
   - Zero fee configurations
   - Lack of transfer validations
   - Pool reserve manipulation possibilities

### 6. Vulnerability Detection Guide

To find similar vulnerabilities:
1. Search for:
   - `_isExcludedFromFees` mappings
   - `autoMarketMakerPair` configurations
   - Multiple router approvals
   - Direct transfers to Uniswap/Sushiswap addresses
2. Analyze:
   - Fee calculation logic
   - Transfer validation checks
   - Swap routing options
3. Test:
   - Large transfers directly to pools
   - Swaps with different routers
   - Fee exemption scenarios

### 7. Impact Assessment

**Financial Impact**:
- Direct loss: 249 ETH (~$600K)
- Potential for unlimited losses if not detected

**Technical Impact**:
- Complete bypass of tokenomics
- Undermines fee structure
- Compromises pool integrity

### 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Implement minimum fee percentages:
```solidity
uint256 public constant MIN_FEE = 1; // 1%
require(sellFee >= MIN_FEE && buyFee >= MIN_FEE);
```

2. Add transfer validations:
```solidity
function _transfer(address from, address to, uint256 amount) internal override {
    require(!isPool[to] && !isPool[from], "Direct pool transfers disabled");
    // ...
}
```

**Long-term Improvements**:
1. Implement time-locked fee changes
2. Add circuit breakers for large swaps
3. Use oracle-based price validation

### 9. Lessons for Security Researchers

Key takeaways:
1. Always audit fee mechanisms thoroughly
2. Check for multiple swap router integrations
3. Validate direct pool transfer scenarios
4. Test edge cases with zero/near-zero fees
5. Monitor for reserve manipulation possibilities

This analysis demonstrates how careful examination of fee mechanisms and transfer logic is crucial for token contract security. The vulnerability pattern shown here can be applied to detect similar issues in other projects.

## 📈 Transaction Trace Summary
- **Transaction ID**: 0xd9fdc7d03eec28fc2453c5fa68eff82d4c297f436a6a5470c54ca3aecd2db17e
- **Block Number**: 20,905,302
- **Contract Address**: 0x991493900674b10bdf54bdfe95b4e043257798cf
- **Intrinsic Gas**: 29,980
- **Refund Gas**: 33,900
- **Gas Used**: 433,811
- **Call Type**: CALL
- **Nested Function Calls**: 10
- **Event Logs**: 19
- **Asset Changes**: 17 token transfers
- **Top Transfers**: 0.07 weth ($169.479091796875), None SASHA ($None), None SASHA ($None)
- **Balance Changes**: 9 accounts affected
- **State Changes**: 12 storage modifications

## 🔗 References
- **POC File**: source/2024-10/SASHAToken_exp/SASHAToken_exp.sol
- **Blockchain Explorer**: [View Transaction](https://etherscan.io/tx/0xd9fdc7d03eec28fc2453c5fa68eff82d4c297f436a6a5470c54ca3aecd2db17e)

---
*Generated by DeFi Hack Labs Analysis Tool*
