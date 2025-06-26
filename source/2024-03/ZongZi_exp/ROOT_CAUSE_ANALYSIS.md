# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: ZongZi_exp
- **Date**: 2024-03
- **Network**: Bsc
- **Total Loss**: None

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0x247f4b3dbde9d8ab95c9766588d80f8dae835129225775ebd05a6dd2c69cd79f
- **Attacker Address(es)**: 0x2c42824ef89d6efa7847d3997266b62599560a26
- **Vulnerable Contract(s)**: 
- **Attack Contract(s)**: 0x0bd0d9ba4f52db225b265c3cffa7bc4a418d22a9, 0x0bd0D9BA4f52dB225B265c3Cffa7bc4a418D22A9

## 🔍 Technical Analysis

Based on the provided materials, I'll conduct a deep technical analysis of the exploit. The attack appears to be a sophisticated price manipulation attack leveraging multiple contract interactions.

### 1. Vulnerability Summary
**Type**: Price Manipulation Attack with Flash Loan
**Classification**: Economic attack (DEX price oracle manipulation)
**Vulnerable Functions**: 
- `burnToHolder()` in ZZF.sol
- `receiveRewards()` in ZZF.sol
- `zongziToholder()` in ZONGZI.sol

### 2. Step-by-Step Exploit Analysis

**Step 1: Flash Loan Initiation**
- Trace Evidence: BUSDT_WBNB.swap(0, amount1Out, address(this), abi.encode(uint8(1)))
- Contract Code Reference: PancakePair.sol swap() function (lines 200-250)
- POC Code Reference: testExploit() function calculating amount1Out
- EVM State Changes: WBNB balance transferred from BUSDT_WBNB pair to attack contract
- Fund Flow: 1904.347 WBNB borrowed from BUSDT_WBNB pair
- Technical Mechanism: Flash loan initiated using PancakeSwap's swap function with callback
- Vulnerability Exploitation: Sets up capital for price manipulation

**Step 2: Price Manipulation Setup**
- Trace Evidence: WBNB.transfer(address(helper), _amount1)
- Contract Code Reference: Helper.exploit() function
- POC Code Reference: pancakeCall() function transfers WBNB to Helper
- EVM State Changes: WBNB moved to Helper contract
- Fund Flow: 1904.347 WBNB → Helper contract
- Technical Mechanism: Funds moved to Helper for concentrated manipulation
- Vulnerability Exploitation: Prepares capital for concentrated buys

**Step 3: Initial Buy Pressure**
- Trace Evidence: makeSwap(1e17, address(WBNB), address(ZongZi))
- Contract Code Reference: Router.swapExactTokensForTokensSupportingFeeOnTransferTokens()
- POC Code Reference: Helper.makeSwap() function
- EVM State Changes: WBNB reserves decrease in WBNB_ZONGZI pair
- Fund Flow: 0.1 WBNB → WBNB_ZONGZI pair, ZongZi tokens minted
- Technical Mechanism: Small initial swap to establish price baseline
- Vulnerability Exploitation: Begins price manipulation sequence

**Step 4: Sell Back Tokens**
- Trace Evidence: makeSwap(ZongZi.balanceOf(address(this)), address(ZongZi), address(WBNB))
- Contract Code Reference: ZONGZI._transfer() with fee logic
- POC Code Reference: Helper.makeSwap() second call
- EVM State Changes: ZongZi balance burned, WBNB received
- Fund Flow: ZongZi → WBNB_ZONGZI pair → WBNB to Helper
- Technical Mechanism: Creates artificial volume and price movement
- Vulnerability Exploitation: Manipulates TWAP and creates price distortion

**Step 5: Large Buy Order**
- Trace Evidence: makeSwap(amountIn, address(WBNB), address(ZongZi))
- Contract Code Reference: ZONGZI._transfer() with fee bypass
- POC Code Reference: Helper.makeSwap() third call with large amount
- EVM State Changes: Significant WBNB reserves added to pair
- Fund Flow: ~1904 WBNB → WBNB_ZONGZI pair
- Technical Mechanism: Large buy creates extreme price impact
- Vulnerability Exploitation: Artificially inflates token price

**Step 6: Reward Exploitation**
- Trace Evidence: ZZF.burnToHolder(amounts[0], msg.sender)
- Contract Code Reference: ZZF.burnToHolder() (lines 500-520)
- POC Code Reference: Helper.exploit() calls burnToHolder
- EVM State Changes: ZZF tokens minted to attacker
- Fund Flow: ZongZi burned, ZZF minted
- Technical Mechanism: Exploits reward calculation during price distortion
- Vulnerability Exploitation: Mints rewards based on manipulated price

**Step 7: Reward Claiming**
- Trace Evidence: ZZF.receiveRewards(address(this))
- Contract Code Reference: ZZF.receiveRewards() (lines 400-420)
- POC Code Reference: Helper.exploit() final steps
- EVM State Changes: WBNB transferred from ZZF contract
- Fund Flow: WBNB from ZZF contract → Helper → Attacker
- Technical Mechanism: Claims inflated rewards due to price manipulation
- Vulnerability Exploitation: Converts manipulated position into real profit

### 3. Root Cause Deep Dive

**Vulnerable Code Location**: ZZF.sol, burnToHolder() and receiveRewards()

```solidity
function burnToHolder(uint256 amount, address _invitation) external {
    require(amount >= 0, "TeaFactory: insufficient funds");
    address sender = _msgSender();
    // ... invitation logic ...
    
    address[] memory path = new address[](2);
    path[0] = address(_burnToken);
    path[1] = uniswapRouter.WETH();
    uint256 deserved = uniswapRouter.getAmountsOut(amount, path)[path.length - 1];
    
    require(payable(address(_burnToken)).balance>=deserved,'not enough balance');
    _burnToken.zongziToholder(sender, amount, deserved);
    _BurnTokenToDead(sender,amount);
    burnFeeRewards(sender,deserved);
}
```

**Flaw Analysis**:
1. Price Oracle Manipulation: The contract uses instantaneous DEX prices (getAmountsOut) for reward calculation
2. No TWAP Protection: No time-weighted average price checks
3. Improper Reward Calculation: deserved amount based on manipulatable spot price
4. Reentrancy Risk: External call to _burnToken before state changes

**Exploitation Mechanism**:
1. Attacker manipulates WBNB/ZongZi pair price through large swaps
2. Calls burnToHolder when price is artificially high
3. Gets inflated deserved amount due to manipulated price
4. Receives excessive rewards through receiveRewards()

### 4. Technical Exploit Mechanics

The attack works by:
1. Creating artificial price inflation through concentrated buys
2. Exploiting the real-time price oracle in reward calculations
3. Converting the artificially valued positions into real assets
4. Repeating the process to compound gains

Key technical aspects:
- Flash loans provide capital for large price impacts
- The contract's reliance on spot prices rather than TWAPs
- Fee structures that don't account for extreme price movements
- Reward calculations that don't have sanity checks

### 5. Bug Pattern Identification

**Bug Pattern**: DEX Price Oracle Manipulation
**Description**: Contracts using instantaneous DEX prices for critical calculations without protection against short-term manipulation.

**Code Characteristics**:
- Direct calls to getAmountsOut() for value calculations
- No time-weighted price checks
- Large external calls that could affect price before state changes
- Reward systems based on current price rather than historical averages

**Detection Methods**:
- Static analysis for getAmountsOut() usage in value calculations
- Check for TWAP implementations in price-sensitive functions
- Verify external calls that could affect price occur after state changes
- Look for reward systems without anti-manipulation safeguards

**Variants**:
- Flash loan attacks
- Sandwich attacks
- Reward farming through price manipulation
- Donation attacks to manipulate ratios

### 6. Vulnerability Detection Guide

**Code Patterns to Search For**:
1. Any usage of getAmountsOut() or getReserves() for value calculations
2. Reward systems that use spot prices
3. External calls before critical state changes
4. Lack of price sanity checks (min/max thresholds)

**Static Analysis Rules**:
- Flag all getAmountsOut() calls not protected by TWAP
- Identify reward functions using spot prices
- Detect external calls preceding state changes

**Manual Review Techniques**:
- Trace all price oracle usage paths
- Verify time-weighted protections exist
- Check for proper state change ordering

### 7. Impact Assessment

**Financial Impact**:
- $223K extracted (as noted in POC comments)
- Potential for much larger losses given sufficient liquidity

**Technical Impact**:
- Broken reward economics
- Loss of funds from reward pool
- Protocol insolvency risk

### 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Implement TWAP oracles:
```solidity
// Use TWAP instead of spot price
IOracle(priceOracle).consult(address(token), amount);
```

2. Add price sanity checks:
```solidity
require(price < maxPrice && price > minPrice, "Invalid price");
```

**Long-term Improvements**:
- Circuit breakers for extreme price movements
- Delayed reward claims to prevent instant exploitation
- Multi-oracle consensus systems

### 9. Lessons for Security Researchers

**Research Methodologies**:
1. Trace all price oracle usage
2. Check for external call ordering vulnerabilities
3. Test with extreme price movements
4. Verify reward calculations under manipulation scenarios

**Red Flags**:
- Spot price usage in value calculations
- External calls before state changes
- Complex reward systems without safeguards
- Lack of price manipulation protections

This analysis demonstrates a comprehensive price manipulation attack exploiting multiple contract vulnerabilities. The key lesson is that any financial calculations based on DEX prices must incorporate anti-manipulation measures like TWAPs and sanity checks.

## 📈 Transaction Trace Summary
- **Transaction ID**: 0x247f4b3dbde9d8ab95c9766588d80f8dae835129225775ebd05a6dd2c69cd79f
- **Block Number**: 37,272,888
- **Contract Address**: 0x0bd0d9ba4f52db225b265c3cffa7bc4a418d22a9
- **Intrinsic Gas**: 21,064
- **Refund Gas**: 382,000
- **Gas Used**: 2,331,350
- **Call Type**: CALL
- **Nested Function Calls**: 31
- **Event Logs**: 100
- **Asset Changes**: 74 token transfers
- **Top Transfers**: 1904.347826086956521739 wbnb ($1230399.083941915760869), 1904.347826086956521739 wbnb ($1230399.083941915760869), 0.1 wbnb ($64.60999755859375)
- **Balance Changes**: 15 accounts affected
- **State Changes**: 34 storage modifications

## 🔗 References
- **POC File**: source/2024-03/ZongZi_exp/ZongZi_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0x247f4b3dbde9d8ab95c9766588d80f8dae835129225775ebd05a6dd2c69cd79f)

---
*Generated by DeFi Hack Labs Analysis Tool*
