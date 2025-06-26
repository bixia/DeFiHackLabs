# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: YBToken_exp
- **Date**: 2025-04
- **Network**: Bsc
- **Total Loss**: 15261.68240413121964707 BUSD

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0xe1e7fa81c3761e2698aa83e084f7dd4a1ff907bcfc4a612d54d92175d4e8a28b
- **Attacker Address(es)**: 0x00000000b7da455fed1553c4639c4b29983d8538
- **Vulnerable Contract(s)**: 0x113F16A3341D32c4a38Ca207Ec6ab109cF63e434
- **Attack Contract(s)**: 0xbdcd584ec7b767a58ad6a4c732542b026dceaa35

## 🔍 Technical Analysis

# YBToken Flash Loan Exploit Deep Analysis

## 1. Vulnerability Summary

**Vulnerability Type**: Flash loan-based price manipulation with improper LP token accounting

**Classification**: Economic attack (price oracle manipulation) combined with fee calculation flaw

**Vulnerable Functions**:
1. `_tokenTransfer()` in YBToken.sol (fee calculation logic)
2. `swap()` in PancakePair.sol (reserve manipulation)
3. `pancakeV3FlashCallback()` in AttackerC.sol (attack orchestration)

**Root Cause**: The exploit combines several flaws:
- Inadequate protection against flash loan price manipulation
- Fee calculation based on manipulated reserves
- Improper invariant checks during swaps
- Lack of TWAP or other price protection mechanisms

## 2. Step-by-Step Exploit Analysis

### Step 1: Flash Loan Initiation
- **Trace Evidence**: 
  - Call to `flash()` on pancakeV3Pool (0x36696169c63e42cd08ce11f5deebbcebae652050)
  - Borrowed 19,200 BUSD (0x55d398326f99059ff775485246999027b3197955)
  
- **Contract Code Reference**: 
  - `IPancakeV3PoolActions.sol` flash function
  ```solidity
  function flash(
      address recipient,
      uint256 amount0,
      uint256 amount1,
      bytes calldata data
  ) external;
  ```

- **POC Code Reference**: 
  ```solidity
  Uni_Pair_V3(pancakeV3Pool).flash(
      address(this),
      loanAmount, // 19200 BUSD
      0,
      ''
  );
  ```

- **EVM State Changes**: 
  - BUSD balance of attacker contract increases by 19,200
  - Debt obligation created requiring repayment + fee

- **Fund Flow**: 
  - 19,200 BUSD transferred from Pancake pool to attacker contract

- **Technical Mechanism**: 
  - Flash loans allow uncollateralized borrowing if repaid in same transaction
  - No upfront capital needed for large-scale manipulation

### Step 2: First Swap Preparation
- **Trace Evidence**: 
  - Transfer 290.909 BUSD to YB-BUSD LP (0x38231f8eb79208192054be60cb5965e34668350a)
  
- **Contract Code Reference**: 
  - `AttackerC.pancakeV3FlashCallback()`:
  ```solidity
  IERC20(BUSD).transfer(YB_BUSD_LP, loanAmount / swapLength);
  ```

- **POC Code Reference**: 
  - `swapLength = 66` splits loan into smaller chunks
  - Each swap uses ~290.9 BUSD (19200/66)

- **EVM State Changes**: 
  - LP contract BUSD balance increases
  - Reserves not yet updated (will be updated during swap)

- **Fund Flow**: 
  - Partial loan amount moved to LP contract

### Step 3: First Swap Execution
- **Trace Evidence**: 
  - Call to `swap()` on YB-BUSD LP
  - Output: 192.174 YB to child contract
  
- **Contract Code Reference**: 
  - `PancakePair.swap()`:
  ```solidity
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
      require(amount0Out > 0 || amount1Out > 0, 'Pancake: INSUFFICIENT_OUTPUT_AMOUNT');
      (uint112 _reserve0, uint112 _reserve1,) = getReserves();
      require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Pancake: INSUFFICIENT_LIQUIDITY');
      // [...]
  }
  ```

- **POC Code Reference**: 
  ```solidity
  IPancakePair(YB_BUSD_LP).swap(
      getAmount0ToReachK(balance1, reserve0, reserve1),
      0,
      address(child),
      ''
  );
  ```

- **EVM State Changes**: 
  - LP reserves updated after swap
  - Price ratio manipulated due to large single-sided swap

- **Fund Flow**: 
  - YB tokens minted to child contract
  - BUSD remains in LP (but reserve ratio changed)

### Step 4: YB Token Transfer from Child
- **Trace Evidence**: 
  - `transferFrom()` child contract to main attacker
  
- **Contract Code Reference**: 
  - `AttackerCChild` constructor:
  ```solidity
  constructor () {
      IERC20(YB).approve(msg.sender, type(uint256).max);
  }
  ```

- **POC Code Reference**: 
  ```solidity
  IERC20(YB).transferFrom(
      address(child), 
      address(this), 
      IERC20(YB).balanceOf(address(child))
  );
  ```

- **EVM State Changes**: 
  - YB tokens consolidated in main attacker contract

- **Fund Flow**: 
  - YB moved from ephemeral child contract to persistent attacker

### Step 5: Reverse Swap Preparation
- **Trace Evidence**: 
  - Transfer YB back to LP pool
  
- **Contract Code Reference**: 
  - `AttackerC` reverse swap logic:
  ```solidity
  IERC20(YB).transfer(YB_BUSD_LP, balYB / swapLength);
  ```

- **POC Code Reference**: 
  - Same chunking strategy (66 swaps)

- **EVM State Changes**: 
  - LP YB balance increases
  - Reserves not yet updated

### Step 6: Reverse Swap Execution
- **Trace Evidence**: 
  - Call to `swap()` for BUSD output
  
- **Contract Code Reference**: 
  - `PancakePair.swap()` with opposite direction:
  ```solidity
  IPancakePair(YB_BUSD_LP).swap(
      0,
      getAmount1ToReachK(balance0, reserve0, reserve1),
      address(this),
      ''
  );
  ```

- **POC Code Reference**: 
  - Uses `getAmount1ToReachK()` for reverse calculation

- **EVM State Changes**: 
  - Reserves updated again
  - Price ratio returns closer to original (but with profit extracted)

- **Fund Flow**: 
  - BUSD extracted from LP to attacker

### Step 7: Flash Loan Repayment
- **Trace Evidence**: 
  - Transfer back borrowed amount + fee
  
- **Contract Code Reference**: 
  - `pancakeV3FlashCallback()` repayment:
  ```solidity
  IERC20(BUSD).transfer(pancakeV3Pool, loanAmount + fee0);
  ```

- **POC Code Reference**: 
  - Must repay exact borrowed amount + 0.01% fee

- **EVM State Changes**: 
  - Flash loan debt cleared
  - Attacker retains profit

### Step 8: Profit Extraction
- **Trace Evidence**: 
  - Final transfer to attacker EOA
  
- **Contract Code Reference**: 
  - `attack()` function conclusion:
  ```solidity
  uint256 balBUSD = IERC20(BUSD).balanceOf(address(this));
  IERC20(BUSD).transfer(msg.sender, balBUSD);
  ```

- **Fund Flow**: 
  - Net profit transferred to attacker's wallet

## 3. Root Cause Deep Dive

### Vulnerable Code Location: YBToken.sol - Fee Calculation
```solidity
function _tokenTransfer(address sender, address recipient, uint256 tAmount, bool takeFee) private {
    _balances[sender] = _balances[sender] - tAmount;
    uint256 feeAmount;

    if (takeFee) {
        bool isSell;
        uint256 swapFeeAmount;
        uint256 destroyFeeAmount;
        if (_swapPairList[recipient]) {
            //Sell
            isSell = true;
            swapFeeAmount = (tAmount * _totalSellFees) / 10000;
            destroyFeeAmount = (tAmount * _sellDestroyFee) / 10000;
            swapFeeAmount -= destroyFeeAmount;
        } else if (_swapPairList[sender]) {
            //Buy
            swapFeeAmount = (tAmount * _totalBuyFees) / 10000;
            destroyFeeAmount = (tAmount * _buyDestroyFee) / 10000;
            swapFeeAmount -= destroyFeeAmount;
        }
        // [...]
    }
    _takeTransfer(sender, recipient, tAmount - feeAmount);
}
```

**Flaw Analysis**:
1. Fees are calculated based on instantaneous prices that can be manipulated
2. No protection against rapid price changes during flash loans
3. Fee percentages are applied to manipulated trade amounts
4. No time-weighted price checks or trade size limits

### Vulnerable Code Location: PancakePair.sol - Swap Logic
```solidity
function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
    // [...]
    uint balance0Adjusted = (balance0.mul(10000).sub(amount0In.mul(25)));
    uint balance1Adjusted = (balance1.mul(10000).sub(amount1In.mul(25)));
    require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(10000**2), 'Pancake: K');
}
```

**Flaw Analysis**:
1. 0.25% fee is insufficient protection against large swaps
2. Constant product check can still allow significant price impact
3. No minimum liquidity requirements enforced
4. No trade size limits relative to pool size

## 4. Technical Exploit Mechanics

The attacker exploits several interconnected mechanisms:

1. **Price Manipulation**:
   - Large one-sided swaps distort the price ratio in the LP
   - Fees are calculated based on this manipulated price
   - Reverse swaps at distorted prices extract value

2. **Fee Arbitrage**:
   - Buy/sell fees are different (400 vs 500 basis points)
   - Attack path exploits this differential
   - Flash loan enables large enough volume to overcome fees

3. **Reserve Accounting**:
   - The `getAmountToReachK()` functions precisely calculate swap amounts
   - Targets specific reserve ratios to maximize profit
   - Chunked swaps minimize price impact per swap

## 5. Bug Pattern Identification

**Bug Pattern**: Flash Loan-Enabled Price Oracle Manipulation

**Description**: 
- Protocol uses instantaneous DEX prices without protection
- Fees calculated based on manipulatable prices
- Large trades can significantly impact price ratios

**Code Characteristics**:
- Direct use of `getReserves()` for pricing
- Fee calculations without time-weighted checks
- No trade size limits relative to pool liquidity
- Lack of flash loan detection/protection

**Detection Methods**:
- Static analysis for direct reserve price usage
- Check for missing TWAP implementations
- Verify trade size limits relative to pool
- Look for flash loan callback functions

**Variants**:
- Single-block arbitrage
- Reserve ratio manipulation
- Fee differential exploitation

## 6. Vulnerability Detection Guide

**Code Patterns to Search For**:
1. Direct `getReserves()` usage in price calculations
2. Fee calculations based on instantaneous prices
3. Large swaps without size limits
4. Missing flash loan protections

**Static Analysis Rules**:
- Flag any pricing based solely on current reserves
- Identify fee calculations without time checks
- Detect large ratio changes in reserve values

**Manual Review Techniques**:
- Check all price oracle implementations
- Verify fee calculation robustness
- Test edge cases with large swaps
- Review trade size limits

## 7. Impact Assessment

**Financial Impact**:
- $15,261 BUSD stolen
- Significant LP value extraction
- Potential for repeated attacks

**Technical Impact**:
- LP token holders suffer losses
- Price stability compromised
- Protocol trust damaged

## 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Implement TWAP price oracles
2. Add trade size limits
3. Increase swap fees temporarily

**Long-term Improvements**:
1. Time-weighted pricing for all calculations
2. Dynamic fee adjustments for large swaps
3. Flash loan detection systems

**Monitoring**:
- Large reserve ratio changes
- Abnormal fee volumes
- Flash loan activity patterns

## 9. Lessons for Security Researchers

**Discovery Methods**:
- Analyze all price oracle implementations
- Test with extreme swap sizes
- Verify fee calculation robustness

**Red Flags**:
- Direct reserve usage in pricing
- No trade size limits
- Differential buy/sell fees

**Testing Approaches**:
- Flash loan simulation tests
- Price manipulation scenarios
- Edge case volume testing

## 📈 Transaction Trace Summary
- **Transaction ID**: 0xe1e7fa81c3761e2698aa83e084f7dd4a1ff907bcfc4a612d54d92175d4e8a28b
- **Block Number**: 48,415,276
- **Contract Address**: 0xbdcd584ec7b767a58ad6a4c732542b026dceaa35
- **Intrinsic Gas**: 23,408
- **Refund Gas**: 2,800,000
- **Gas Used**: 22,911,044
- **Call Type**: CALL
- **Nested Function Calls**: 13
- **Event Logs**: 2149
- **Asset Changes**: 1366 token transfers
- **Top Transfers**: 19200 bsc-usd ($19200), 290.90909090909090909 bsc-usd ($290.90909090909090909), None YB ($None)
- **Balance Changes**: 106 accounts affected
- **State Changes**: 17 storage modifications

## 🔗 References
- **POC File**: source/2025-04/YBToken_exp/YBToken_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0xe1e7fa81c3761e2698aa83e084f7dd4a1ff907bcfc4a612d54d92175d4e8a28b)

---
*Generated by DeFi Hack Labs Analysis Tool*
