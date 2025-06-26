# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: SBT_exp
- **Date**: 2024-07
- **Network**: Bsc
- **Total Loss**: None

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0x9a8c4c4edb7a76ecfa935780124c409f83a08d15c560bb67302182f8969be20d
- **Attacker Address(es)**: 0x3026c464d3bd6ef0ced0d49e80f171b58176ce32
- **Vulnerable Contract(s)**: 
- **Attack Contract(s)**: 0x88f9e1799465655f0dd206093dbd08922a1d9e28

## 🔍 Technical Analysis

Based on the provided information, I'll conduct a detailed analysis of the exploit. The attack appears to be a flash loan-based manipulation of the Smart Bank Token (SBT) system.

### 1. Vulnerability Summary
**Type**: Price Manipulation via Flash Loan
**Classification**: Economic Attack
**Vulnerable Functions**: 
- `Buy_SBT()` in Bank contract
- `Loan_Get()` in Bank contract
- `SBT_Price()` calculation in Bank contract

### 2. Step-by-Step Exploit Analysis

**Step 1: Flash Loan Initiation**
- Trace Evidence: Call to `flash()` on Pool contract (0x366...)
- POC Code: `Pool.flash(address(this), 1,950,000 ether, 0, "0x123")`
- Contract Code: Pool's flash function allows uncollateralized borrowing
- EVM State: Pool's token balances temporarily reduced
- Fund Flow: 1.95M BUSD transferred to attack contract
- Mechanism: Standard flash loan pattern

**Step 2: BUSD Transfer to Bank**
- Trace Evidence: Transfer of 950,000 BUSD to Bank (0x2b45...)
- POC Code: `BUSD.transfer(address(Bank), 950,000 ether)`
- Contract Code: Standard ERC20 transfer
- EVM State: Bank's BUSD balance increases
- Fund Flow: Funds moved from attack contract to Bank
- Purpose: Prepares capital for SBT purchases

**Step 3: Bank Contract Initialization**
- Trace Evidence: Call to `_Start()`
- POC Code: `Bank._Start()`
- Contract Code: 
```solidity
function _Start() external {
    require(Smart_Bank_USDT_Balance() >= 1000000, "After 1000000 Tethers");
    Start = true;
    Time_365 = block.timestamp;
}
```
- EVM State: `Start` flag set to true
- Purpose: Enables trading functions in Bank contract

**Step 4: Large SBT Purchase**
- Trace Evidence: Call to `Buy_SBT(20,000,000)`
- POC Code: `Bank.Buy_SBT(20,000,000)`
- Contract Code:
```solidity
function Buy_Token(uint256 X) private {
    USDT.safeTransferFrom(_msgSender(), address(this), (X) * SBT_Price());
    SBT.safeTransfer(_msgSender(), X * 10 **18 );
    S3 += (X * 10 **16);
}
```
- EVM State: 
  - Bank's BUSD balance increases
  - Attack contract receives 20M SBT
- Fund Flow: 950k BUSD → Bank, 20M SBT → attacker
- Vulnerability: Price calculation doesn't account for flash loan impact

**Step 5: Loan Request**
- Trace Evidence: Call to `Loan_Get(1,966,930)`
- POC Code: `Bank.Loan_Get(1,966,930)`
- Contract Code:
```solidity
function Loan_Get(uint256 USDT_) external {
    require(Start == true, "After Start");
    require(USDT_ >= 100 ," More Than 100 USDT ");
    require(S9[_msgSender()].id == 0 , "Just 1 Time");
    require(Lock == false, " Processing "); 
    Lock = true;
    uint256 S8 = ((((USDT_ * 10 **18 ) / SBT_Price()) * 130) / 100 );
    // ... collateral checks ...
    USDT.safeTransfer(_msgSender(), (USDT_ * 10 **18 ));
    // ... loan record creation ...
}
```
- EVM State: 
  - Loan record created for attacker
  - Lock flag temporarily set
- Fund Flow: 1.966M BUSD → attacker
- Vulnerability: Loan amount based on manipulated SBT price

**Step 6: Flash Loan Repayment**
- Trace Evidence: Transfer of 1,950,994.5 BUSD back to Pool
- POC Code: `BUSD.transfer(address(Pool), 1,950,000 ether + fee0)`
- Contract Code: Standard ERC20 transfer
- EVM State: Pool's BUSD balance restored
- Fund Flow: Partial repayment of flash loan

**Step 7: Profit Extraction**
- Trace Evidence: Transfer of 56,450.709 BUSD to attacker
- POC Code: Implicit in remaining balance
- Fund Flow: Net profit moved to attacker address

### 3. Root Cause Deep Dive

**Vulnerable Code Location**: Bank_0x2b45DD1d909c01aAd96fa6b67108D691B432f351.sol - SBT_Price() function

**Code Snippet**:
```solidity
function SBT_Price() private view returns(uint256) {
    return((Smart_Bank_USDT_Balance()*10**18)/(Smart_Bank__SBT_Balance()));
}
```

**Flaw Analysis**:
1. The price calculation is based solely on the instantaneous ratio of BUSD to SBT in the contract
2. No time-weighted or protected price mechanism
3. Susceptible to flash loan manipulation where large deposits can temporarily distort the price
4. Loan calculations use this manipulated price without safeguards

**Exploitation Mechanism**:
1. Attacker uses flash loan to deposit large BUSD amount
2. This artificially inflates the Smart_Bank_USDT_Balance()
3. SBT_Price() becomes temporarily inflated
4. Attacker takes out a loan based on this inflated price
5. When flash loan is repaid, the price returns to normal but loan remains

### 4. Technical Exploit Mechanics

The attack works through these key mechanisms:
1. **Price Oracle Manipulation**: The instantaneous price calculation can be gamed by temporary large deposits
2. **Atomic Execution**: All steps occur in one transaction, preventing price stabilization
3. **Loan-to-Value Exploit**: The loan amount is based on manipulated collateral value
4. **Circular Dependency**: The same price oracle is used for both buying SBT and collateral valuation

### 5. Bug Pattern Identification

**Bug Pattern**: Flash Loan-Enabled Price Manipulation

**Description**:
- Protocols that use instantaneous, non-protected price oracles
- Price calculations based solely on current contract balances
- Loan/collateral systems that don't account for temporary balance distortions

**Code Characteristics**:
- Price calculations using `balanceOf()` without time weighting
- Loan systems that use internal price oracles
- Lack of flash loan checks or protections
- Immediate price impact from large deposits

**Detection Methods**:
- Static analysis for price oracles using only balance ratios
- Check for flash loan usage in transaction traces
- Verify time-weighted price mechanisms
- Review loan-to-value calculations for oracle dependencies

### 6. Vulnerability Detection Guide

**Detection Techniques**:
1. Search for price calculations using only token balances:
   - Pattern: `balanceOf(...) / balanceOf(...)`
2. Check loan systems using internal price oracles
3. Look for lack of TWAP (Time-Weighted Average Price) mechanisms
4. Verify if protocols are flash loan resistant

**Testing Strategies**:
1. Simulate flash loan attacks in test environment
2. Check price stability under large deposit scenarios
3. Verify loan collateral requirements under price manipulation
4. Test atomic transaction sequences

### 7. Impact Assessment

**Financial Impact**:
- Direct profit: ~56K BUSD
- Potential for larger attacks if more funds available
- Systemic risk to all loans in the protocol

**Technical Impact**:
- Complete compromise of lending system
- Loss of funds from protocol
- Erosion of trust in price mechanisms

### 8. Advanced Mitigation Strategies

**Immediate Fixes**:
1. Implement TWAP oracles:
```solidity
// Example TWAP implementation
function getPrice() external view returns (uint256) {
    (uint priceCumulative, uint32 timestamp) = UniswapOracle.current();
    uint32 timeElapsed = block.timestamp - timestamp;
    return priceCumulative / timeElapsed;
}
```

**Long-term Improvements**:
1. Circuit breakers for large price movements
2. Flash loan detection and prevention
3. Multi-source price oracles
4. Loan collateral requirements with safety margins

### 9. Lessons for Security Researchers

**Research Methodologies**:
1. Always check price oracle implementations
2. Test protocols under flash loan scenarios
3. Verify loan collateralization under extreme conditions
4. Look for atomic transaction vulnerabilities

**Red Flags**:
- Instantaneous price calculations
- Single-source oracles
- High loan-to-value ratios
- No flash loan protections

**Testing Approaches**:
1. Flash loan simulation testing
2. Price manipulation testing
3. Atomic transaction testing
4. Edge case analysis for loan systems

This analysis demonstrates a comprehensive flash loan-based price manipulation attack, highlighting the critical need for robust price oracles and flash loan protections in DeFi protocols.

## 📈 Transaction Trace Summary
- **Transaction ID**: 0x9a8c4c4edb7a76ecfa935780124c409f83a08d15c560bb67302182f8969be20d
- **Block Number**: 40,378,160
- **Contract Address**: 0x88f9e1799465655f0dd206093dbd08922a1d9e28
- **Intrinsic Gas**: 22,364
- **Refund Gas**: 22,700
- **Gas Used**: 488,797
- **Call Type**: CALL
- **Nested Function Calls**: 5
- **Event Logs**: 13
- **Asset Changes**: 8 token transfers
- **Top Transfers**: 1950000 bsc-usd ($1949005.544185638427734375), 950000 bsc-usd ($949515.521526336669921875), 959484.79032011366 bsc-usd ($958995.47481830579792831)
- **Balance Changes**: 4 accounts affected
- **State Changes**: 21 storage modifications

## 🔗 References
- **POC File**: source/2024-07/SBT_exp/SBT_exp.sol
- **Blockchain Explorer**: [View Transaction](https://bscscan.com/tx/0x9a8c4c4edb7a76ecfa935780124c409f83a08d15c560bb67302182f8969be20d)

---
*Generated by DeFi Hack Labs Analysis Tool*
