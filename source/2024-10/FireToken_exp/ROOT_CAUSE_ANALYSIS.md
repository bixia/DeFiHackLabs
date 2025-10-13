# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: FireToken_exp
- **Date**: 2024-10
- **Network**: Ethereum
- **Total Loss**: 8.45 ETH

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0xd20b3b31a682322eb0698ecd67a6d8a040ccea653ba429ec73e3584fa176ff2b
- **Attacker Address(es)**: 0x81f48a87ec44208c691f870b9d400d9c13111e2e
- **Vulnerable Contract(s)**: 0x18775475f50557b96C63E8bbf7D75bFeB412082D, 0x18775475f50557b96C63E8bbf7D75bFeB412082D
- **Attack Contract(s)**: 0x9776c0abe8ae3c9ca958875128f1ae1d5afafcb8

## 🎯 根本原因

FireToken 在卖出路径（`_transfer()` 当 `to == uniswapV2Pair`）主动从 LP 扣减并将代币销毁至黑洞地址，再调用 `sync()` 固化失衡。这会在真正交换发生前改变 AMM 储备，使价格计算基于被动减少的 FIRE 储备、未同步补偿的 WETH 储备，从而被攻击者以更优价格从池子抽走 WETH。配合多实例与重复操作，可进一步放大收益。

关键点：
- 向 LP 的“卖出转账”触发从 LP 余额直接扣减并销毁（影响 x·y=k）。
- `sync()` 在销毁后调用，固化失衡，产生套利窗口。
- 可多次重复以累积收益，或用外部资金放大效果。

## 🛠️ 修复建议

- 禁止在向 LP 的转账中主动修改 LP 余额（移除卖出路径下 LP 扣减/销毁）。
- 若需通缩，排除 LP 地址或改为仅对用户侧生效，且不影响 AMM 储备。
- 对路由调用设置最小成交量与频控；监控异常向 LP 的大额直转与频繁 `sync()`。
- 使用经审计的代币模板，避免在 `_transfer` 中引入影响 AMM 储备的副作用。

## 🔍 Technical Analysis

# FireToken Exploit Deep Analysis

## 1. Vulnerability Summary

**Vulnerability Type**: Deflationary Token Logic Flaw with Liquidity Manipulation

**Classification**: Economic Attack / Tokenomics Exploit

**Vulnerable Function**: `_transfer()` in FireToken.sol (lines 274-279)

The exploit takes advantage of a flawed deflationary mechanism in the FireToken contract that automatically burns tokens from the liquidity pool on sells. The attacker manipulates this mechanism to drain value from the WETH-FIRE liquidity pool through a carefully orchestrated series of swaps and transfers.

## 2. Step-by-Step Exploit Analysis

### Step 1: Flash Loan Initiation
- **Trace Evidence**: 
  - Function: `flashLoanSimple()` at 0xc13e21b648a5ee794902342038ff3adab66be987
  - Input: 20 WETH loan to attack contract
- **Contract Code Reference**: 
  - AAVE flash loan contract interface
- **POC Code Reference**: 
  ```solidity
  attackerC.attack() -> flashLoanSimple(20 ETH)
  ```
- **EVM State Changes**: 
  - 20 WETH transferred from AAVE pool to attack contract
- **Fund Flow**: 
  - 20 WETH from AAVE to Attack Contract
- **Technical Mechanism**: 
  - Standard flash loan initiation
- **Vulnerability Exploitation**: 
  - Provides capital for the attack

### Step 2: WETH Withdrawal and Contract Deployment Loop
- **Trace Evidence**: 
  - Multiple WETH withdrawals and deposits
- **Contract Code Reference**: 
  - WETH9.sol withdraw/deposit functions
- **POC Code Reference**: 
  ```solidity
  while (true) {
      IFS(weth).withdraw(20 ether);
      try new AttackerC2{value: 20 ether}() {}
      catch { break; }
  }
  ```
- **EVM State Changes**: 
  - WETH balance converted to ETH and back
- **Fund Flow**: 
  - WETH <-> ETH conversions
- **Technical Mechanism**: 
  - Creates multiple attack contract instances
- **Vulnerability Exploitation**: 
  - Bypasses FireToken's `isContract()` check

### Step 3: WETH to FIRE Swap
- **Trace Evidence**: 
  - swapExactTokensForTokensSupportingFeeOnTransferTokens()
  - 20 WETH -> FIRE
- **Contract Code Reference**: 
  - UniswapV2Router02.swapExactTokensForTokensSupportingFeeOnTransferTokens()
- **POC Code Reference**: 
  ```solidity
  IFS(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      20 ether, 0, path, address(this), block.timestamp
  )
  ```
- **EVM State Changes**: 
  - WETH balance decreases, FIRE balance increases
- **Fund Flow**: 
  - 20 WETH -> FIRE tokens via Uniswap
- **Technical Mechanism**: 
  - Standard Uniswap swap with fee-on-transfer token
- **Vulnerability Exploitation**: 
  - Initial position establishment in FIRE

### Step 4: Manipulate Liquidity Pool Balance
- **Trace Evidence**: 
  - FIRE transfer to UniPair (99217691776 raw units)
- **Contract Code Reference**: 
  - FireToken._transfer() lines 274-279:
  ```solidity
  if (to == uniswapV2Pair && from != address(this)) {
      // Deduct tokens from liquidity pair and transfer to dead address
      uint256 sellAmount = amount.sub(taxAmount);
      if (sellAmount > 0) {
          uint256 liquidityPairBalance = balanceOf(uniswapV2Pair);
          if (liquidityPairBalance >= sellAmount) {
              _balances[uniswapV2Pair] = _balances[uniswapV2Pair].sub(sellAmount);
              _balances[DEAD_ADDRESS] = _balances[DEAD_ADDRESS].add(sellAmount);
              emit Transfer(uniswapV2Pair, DEAD_ADDRESS, sellAmount);
              IUniswapV2Pair(uniswapV2Pair).sync();
          }
      }
  }
  ```
- **POC Code Reference**: 
  ```solidity
  uint256 pairBal = IFS(FIRE).balanceOf(UniPairWETHFIRE);
  IERC20(FIRE).transfer(UniPairWETHFIRE, pairBal);
  ```
- **EVM State Changes**: 
  - FIRE balance in LP decreases, dead address balance increases
- **Fund Flow**: 
  - FIRE from LP -> Dead address
- **Technical Mechanism**: 
  - Triggers deflationary mechanism by simulating a sell
- **Vulnerability Exploitation**: 
  - Artificially reduces LP FIRE balance without proper value compensation

### Step 5: Calculate Profit and Execute Swap
- **Trace Evidence**: 
  - getAmountOut() call and swap()
- **Contract Code Reference**: 
  - UniswapV2Pair.swap() and getReserves()
- **POC Code Reference**: 
  ```solidity
  (uint256 r0, uint256 r1,) = IFS(UniPairWETHFIRE).getReserves();
  uint256 pairBal2 = IFS(FIRE).balanceOf(UniPairWETHFIRE);
  uint256 amountOut = IFS(UniswapV2Router02).getAmountOut(pairBal2 - r0, r0, r1);
  IFS(UniPairWETHFIRE).swap(0, amountOut, address(this), "");
  ```
- **EVM State Changes**: 
  - Reserves updated, WETH transferred out
- **Fund Flow**: 
  - WETH from LP -> Attacker
- **Technical Mechanism**: 
  - Exploits price discrepancy from artificial burn
- **Vulnerability Exploitation**: 
  - Profit taken from manipulated LP state

### Step 6: Repeat Attack with New Contract Instance
- **Trace Evidence**: 
  - Multiple contract deployments and swaps
- **Contract Code Reference**: 
  - Same as above steps
- **POC Code Reference**: 
  - Loop creates new AttackerC2 instances
- **EVM State Changes**: 
  - Repeated state manipulations
- **Fund Flow**: 
  - Multiple WETH extractions
- **Technical Mechanism**: 
  - Compounding effect of multiple manipulations
- **Vulnerability Exploitation**: 
  - Maximizes profit through repeated attacks

### Step 7: Final Profit Extraction
- **Trace Evidence**: 
  - Final WETH transfer to attacker (8.45 ETH)
- **Contract Code Reference**: 
  - Standard ETH transfer
- **POC Code Reference**: 
  ```solidity
  uint256 balWETH = IERC20(weth).balanceOf(address(this));
  IERC20(weth).transfer(msg.sender, balWETH);
  ```
- **EVM State Changes**: 
  - Attacker balance increases
- **Fund Flow**: 
  - WETH -> Attacker EOA
- **Technical Mechanism**: 
  - Final profit realization
- **Vulnerability Exploitation**: 
  - Successful completion of attack

## 3. Root Cause Deep Dive

**Vulnerable Code Location**: FireToken.sol, `_transfer()` function (lines 274-279)

**Code Snippet**:
```solidity
if (to == uniswapV2Pair && from != address(this)) {
    require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
    taxAmount = amount.mul((_buyCount > _reduceSellTaxAt) ? _finalSellTax : _initialSellTax).div(100);
    
    // Deduct tokens from liquidity pair and transfer to dead address
    uint256 sellAmount = amount.sub(taxAmount);
    if (sellAmount > 0) {
        uint256 liquidityPairBalance = balanceOf(uniswapV2Pair);
        if (liquidityPairBalance >= sellAmount) {
            _balances[uniswapV2Pair] = _balances[uniswapV2Pair].sub(sellAmount);
            _balances[DEAD_ADDRESS] = _balances[DEAD_ADDRESS].add(sellAmount);
            emit Transfer(uniswapV2Pair, DEAD_ADDRESS, sellAmount);
            
            // Call sync to update the pair
            IUniswapV2Pair(uniswapV2Pair).sync();
        }
    }
}
```

**Flaw Analysis**:
1. The contract automatically burns tokens from the LP on sells without proper economic safeguards
2. The burn occurs before the actual swap is completed, creating a temporary imbalance
3. No check for malicious transfer patterns or contract interactions
4. Sync is called after the burn, but the damage is already done to the reserves
5. The deflationary mechanism doesn't account for flash loan or multi-step attacks

**Exploitation Mechanism**:
1. Attacker transfers FIRE to the LP, triggering the burn mechanism
2. This artificially reduces the LP's FIRE balance without proper ETH compensation
3. The attacker then swaps at the now-favorable exchange rate
4. The sync happens too late to prevent the arbitrage opportunity

## 4. Technical Exploit Mechanics

The attack works by:
1. Creating a temporary imbalance in the LP through forced burns
2. Exploiting the time gap between burn and sync operations
3. Using multiple contract instances to bypass isContract() checks
4. Compounding the effect through repeated manipulations
5. Extracting value from the artificially created price discrepancy

## 5. Bug Pattern Identification

**Bug Pattern**: Deflationary Token LP Manipulation

**Description**: 
Tokens with automatic burn/transfer mechanisms that affect LP balances can be manipulated when the state changes aren't properly synchronized with swap operations.

**Code Characteristics**:
- Automatic balance modifications during transfers
- LP interactions without proper checks
- Burns/transfers that affect token ratios
- Lack of reentrancy guards for multi-step operations

**Detection Methods**:
- Static analysis for LP balance modifications during transfers
- Check for sync() calls after state changes
- Look for transfer hooks that affect LP balances
- Test for price impact of artificial transfers

**Variants**:
- Fee-on-transfer token exploits
- Rebasing token manipulations
- LP donation attacks

## 6. Vulnerability Detection Guide

**Detection Techniques**:
1. Search for transfer functions that modify LP balances
2. Look for sync() or similar calls after state changes
3. Check for isContract() bypass possibilities
4. Analyze tokenomics for deflationary mechanisms

**Static Analysis Rules**:
- Flag any transfer function that modifies LP balances
- Warn about sync() operations after state changes
- Detect transfer hooks that could affect pricing

**Testing Strategies**:
- Simulate flash loan attacks
- Test multi-contract interaction scenarios
- Verify price stability after artificial transfers

## 7. Impact Assessment

**Financial Impact**: 8.45 ETH (~$20K) stolen
**Technical Impact**: 
- LP imbalance and potential loss of confidence
- Protocol economic model broken
- Possible permanent damage to tokenomics

## 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Remove automatic LP burns
2. Add time locks for large transfers
3. Implement better contract checks

**Long-term Improvements**:
1. Redesign tokenomics without LP-affecting transfers
2. Add circuit breakers for abnormal activity
3. Implement monitoring for suspicious patterns

## 9. Lessons for Security Researchers

**Research Methodologies**:
1. Analyze all transfer hooks in token contracts
2. Test interactions with flash loans
3. Verify LP behavior under manipulation

**Red Flags**:
- Automatic LP balance modifications
- Sync operations after state changes
- Complex tokenomics with multiple mechanisms

**Testing Approaches**:
- Multi-step attack simulations
- Edge case testing for transfer functions
- Economic model stress tests

## 📈 Transaction Trace Summary
- **Transaction ID**: 0xd20b3b31a682322eb0698ecd67a6d8a040ccea653ba429ec73e3584fa176ff2b
- **Block Number**: 20,869,375
- **Contract Address**: 0x9776c0abe8ae3c9ca958875128f1ae1d5afafcb8
- **Intrinsic Gas**: 22,012
- **Refund Gas**: 785,500
- **Gas Used**: 4,639,752
- **Call Type**: CALL
- **Nested Function Calls**: 4
- **Event Logs**: 263
- **Asset Changes**: 204 token transfers
- **Top Transfers**: 20 weth ($48524.19921875), 20 weth ($48524.19921875), None FIRE ($None)
- **Balance Changes**: 22 accounts affected
- **State Changes**: 12 storage modifications

## 🔗 References
- **POC File**: source/2024-10/FireToken_exp/FireToken_exp.sol
- **Blockchain Explorer**: [View Transaction](https://etherscan.io/tx/0xd20b3b31a682322eb0698ecd67a6d8a040ccea653ba429ec73e3584fa176ff2b)

---
*Generated by DeFi Hack Labs Analysis Tool*
