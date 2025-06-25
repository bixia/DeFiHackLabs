# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: OnyxDAO_exp
- **Date**: 2024-09
- **Network**: Ethereum
- **Total Loss**: 0.23 WBTC

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0x46567c731c4f4f7e27c4ce591f0aebdeb2d9ae1038237a0134de7b13e63d8729
- **Attacker Address(es)**: 0x680910cf5fc9969a25fd57e7896a14ff1e55f36b
- **Vulnerable Contract(s)**: 0xf10bc5be84640236c71173d1809038af4ee19002, 0xf10bc5be84640236c71173d1809038af4ee19002
- **Attack Contract(s)**: 

## 🔍 Technical Analysis

# Root Cause Analysis: OnyxDAO Exploit

## 1. Vulnerability Summary
The exploit targeted OnyxDAO's NFTLiquidation contract through a price manipulation attack in the `liquidateWithSingleRepay()` function. The attacker artificially manipulated exchange rates between assets to liquidate positions at incorrect valuations, allowing them to steal funds from the protocol.

## 2. Technical Details

### Attack Flow:
1. **Setup Phase**:
   - Attacker deployed multiple malicious contracts:
     - Rate manipulator contract (0xae7d...a223)
     - Fake oTokenRepay (0x4f8b...d068)
     - Fake underlying asset (0x3f10...dc0e)
     - Fake oTokenCollateral (0xad45...a248)

2. **Manipulation Phase**:
   - Attacker manipulated the exchange rates between assets by:
     - Creating artificial price feeds through the rate manipulator
     - Using fake token contracts that reported incorrect values

3. **Exploitation Phase**:
   - Called `liquidateWithSingleRepay()` with manipulated rates:
     - Made the protocol believe collateral was worth less than actual value
     - Made the repayment asset appear more valuable than it was
   - This allowed attacker to:
     - Liquidate positions that weren't actually underwater
     - Pay back less than they should have
     - Receive more collateral than entitled

## 3. Root Cause

The primary vulnerability was in the `liquidateWithSingleRepay()` function (lines 671-678 in the contract). Key flaws:

1. **Lack of Price Feed Validation**:
   - The contract relied on external price feeds without proper validation
   - No checks for stale or manipulated prices

2. **Insufficient Oracle Security**:
   - Used single-source oracles that could be manipulated
   - No time-weighted average price (TWAP) protection

3. **Trust in Untrusted Contracts**:
   - Accepted token contracts without verifying their authenticity
   - Allowed arbitrary contracts to report their own exchange rates

## 4. Attack Vector

The attacker exploited these weaknesses by:

1. Deploying malicious token contracts that reported false exchange rates
2. Using these fake tokens in liquidation transactions
3. Manipulating the protocol's view of:
   - Collateral value (making it appear lower)
   - Repayment asset value (making it appear higher)
4. Triggering liquidations that shouldn't have occurred under normal market conditions
5. Profiting from the difference between real and reported values

## 5. Impact Assessment

### Financial Impact:
- Total loss: ~$3.8M USD across multiple assets:
  - 4.1M VUSD
  - 7.35M XCN
  - 5K DAI
  - 0.23 WBTC
  - 50K USDT

### Technical Impact:
- Compromised trust in the protocol's liquidation mechanism
- Potential for further exploits if underlying issues aren't fixed
- Damage to protocol's reputation for security

## 6. Mitigation Strategies

1. **Oracle Improvements**:
   - Implement multi-source price feeds (Chainlink + Uniswap TWAP + others)
   - Add price staleness checks
   - Use decentralized oracle networks

2. **Contract Validation**:
   - Maintain whitelists of approved token contracts
   - Verify token contract authenticity before interactions

3. **Liquidation Safeguards**:
   - Add minimum/maximum price deviation checks
   - Implement circuit breakers for abnormal liquidation volumes
   - Require minimum collateralization ratios before allowing liquidation

4. **Code Improvements**:
   ```solidity
   // Example improved liquidation check
   function liquidateWithSingleRepay(address borrower, address oTokenCollateral) external {
       require(isWhitelisted(oTokenCollateral), "Invalid collateral");
       require(isWhitelisted(oTokenRepay), "Invalid repay token");
       
       (uint256 collateralValue, uint256 repayValue) = getVerifiedPrices(
           oTokenCollateral,
           oTokenRepay
       );
       
       require(collateralValue < repayValue * liquidationThreshold, "Not underwater");
       // Rest of liquidation logic
   }
   ```

## 7. Lessons Learned

1. **Never Trust External Contracts**:
   - Always validate external contract interactions
   - Maintain strict whitelists for critical components

2. **Defensive Price Feeding**:
   - Single-source oracles are extremely dangerous in DeFi
   - Time-weighted and multi-source price feeds are essential

3. **Liquidation Safeguards**:
   - Liquidations should have multiple sanity checks
   - Abnormal market conditions should trigger pauses

4. **Testing Considerations**:
   - Must test with malicious external contracts
   - Should include price manipulation scenarios in test suites

5. **Monitoring**:
   - Real-time monitoring for abnormal liquidation patterns
   - Automated alerts for unusual price deviations

This attack demonstrates the critical importance of robust oracle systems and defensive programming in DeFi protocols, particularly for liquidation mechanisms that are prime targets for manipulation.

## 📈 Transaction Trace Summary
No trace data available

## 🔗 References
- **POC File**: source/2024-09/OnyxDAO_exp/OnyxDAO_exp.sol
- **Blockchain Explorer**: [View Transaction](https://etherscan.io/tx/0x46567c731c4f4f7e27c4ce591f0aebdeb2d9ae1038237a0134de7b13e63d8729)

---
*Generated by DeFi Hack Labs Analysis Tool*
