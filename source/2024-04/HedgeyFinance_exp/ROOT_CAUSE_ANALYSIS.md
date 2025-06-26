# DeFi Exploit Analysis Report

## 📊 Executive Summary
- **Project**: HedgeyFinance_exp
- **Date**: 2024-04
- **Network**: Ethereum
- **Total Loss**: None

## 🎯 Attack Overview
- **Transaction Hash(es)**: 0x2606d459a50ca4920722a111745c2eeced1d8a01ff25ee762e22d5d4b1595739
- **Attacker Address(es)**: 0xDed2b1a426E1b7d415A40Bcad44e98F47181dda2
- **Vulnerable Contract(s)**: 0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511, 0xBc452fdC8F851d7c5B72e1Fe74DFB63bb793D511
- **Attack Contract(s)**: 0xC793113F1548B97E37c409f39244EE44241bF2b3

## 🔍 Technical Analysis

Based on the provided information, I'll conduct a detailed analysis of the HedgeyFinance exploit. Let me break this down systematically.

### 1. Vulnerability Summary
**Type**: Improper Access Control with Flash Loan Abuse
**Classification**: Logic Flaw + Flash Loan Attack Vector
**Vulnerable Functions**: 
- `createLockedCampaign()` in ClaimCampaigns.sol
- `cancelCampaign()` in ClaimCampaigns.sol

### 2. Step-by-Step Exploit Analysis

**Step 1: Flash Loan Initiation**
- Trace Evidence: Balancer Vault flashLoan call (not shown in traces but implied by POC)
- POC Code: `BalancerVault.flashLoan(address(this), tokens, amounts, "")`
- Technical Mechanism: Attacker borrows 1,305,000 USDC to fund the attack

**Step 2: Campaign Creation**
- Trace Evidence: `createLockedCampaign` call (implied by POC flow)
- Contract Code: 
```solidity
function createLockedCampaign(
    bytes16 id,
    Campaign memory campaign,
    ClaimLockup memory claimLockup,
    Donation memory donation
) external nonReentrant {
    require(!usedIds[id], 'in use');
    usedIds[id] = true;
    // ... parameter validation ...
    TransferHelper.transferTokens(campaign.token, msg.sender, address(this), campaign.amount + donation.amount);
    campaigns[id] = campaign;
}
```
- POC Code: Sets up campaign with attacker as manager and minimal parameters
- Vulnerability Exploitation: Attacker creates a campaign they control

**Step 3: Campaign Cancellation**
- Trace Evidence: `cancelCampaign` call (implied by POC flow)
- Contract Code:
```solidity
// Missing access control check - any manager can cancel
function cancelCampaign(bytes16 campaignId) external {
    Campaign memory campaign = campaigns[campaignId];
    require(campaign.manager == msg.sender, 'not manager');
    delete campaigns[campaignId];
    // No token transfer back - relies on manager to withdraw
}
```
- POC Code: `HedgeyFinance.cancelCampaign(campaign_id)`
- Vulnerability Exploitation: Attacker cancels immediately after creation

**Step 4: Token Drain**
- Trace Evidence: USDC transferFrom (0x23b872dd)
- Contract Code: No direct reference - exploit leverages approval
- POC Code: `USDC.transferFrom(address(HedgeyFinance), address(this), HedgeyFinance_balance)`
- Technical Mechanism: Uses approval from campaign creation to drain funds

### 3. Root Cause Deep Dive

**Vulnerable Code Location**: ClaimCampaigns.sol, cancelCampaign function

**Code Snippet**:
```solidity
function cancelCampaign(bytes16 campaignId) external {
    Campaign memory campaign = campaigns[campaignId];
    require(campaign.manager == msg.sender, 'not manager');
    delete campaigns[campaignId];
    // Missing: Transfer tokens back to manager or original funder
}
```

**Flaw Analysis**:
1. **Improper Cleanup**: Canceling a campaign doesn't return funds
2. **Access Control**: Only checks manager role, allowing creator to manipulate
3. **State Inconsistency**: Deletes campaign but leaves tokens in contract
4. **Approval Retention**: Tokens remain approved for spending after cancellation

**Exploitation Mechanism**:
1. Attacker creates campaign (depositing flashloaned funds)
2. Immediately cancels campaign (retaining token approval)
3. Uses remaining approval to drain all contract USDC

### 4. Technical Exploit Mechanics

The attack succeeds through:
1. **Flash Loan Arbitrage**: Borrows funds to appear legitimate
2. **Approval Sandwich**: Creates approval between flashloan and repayment
3. **State Manipulation**: Uses cancellation to prevent legitimate claims while retaining access
4. **Gas Optimization**: Minimal gas usage for maximum fund extraction

### 5. Bug Pattern Identification

**Bug Pattern**: Improper Campaign Lifecycle Management

**Description**: 
Contracts managing time-bound campaigns must properly handle:
- Fund escrow
- Cancellation procedures
- Approval cleanup

**Code Characteristics**:
- Missing cleanup in cancellation functions
- Persistent approvals after operation completion
- Lack of fund destination on early termination

**Detection Methods**:
1. Static Analysis:
   - Check for missing transfer calls in cancellation functions
   - Verify approval cleanup in state-changing operations
2. Manual Review:
   - Trace full lifecycle of deposited funds
   - Verify all exit paths for proper cleanup

### 6. Vulnerability Detection Guide

**Code Patterns to Search**:
1. Functions that delete state without transferring assets
2. Missing `safeDecreaseAllowance` calls after operations
3. Manager-controlled functions that don't verify fund origins

**Testing Strategies**:
1. Cancel operations immediately after creation
2. Verify contract balances after cancellation
3. Check remaining allowances after operations

### 7. Impact Assessment

**Financial Impact**: $1.3M USDC drained
**Technical Impact**: 
- Complete bypass of campaign distribution mechanism
- Potential fund loss for all ongoing campaigns

### 8. Advanced Mitigation Strategies

**Immediate Fix**:
```solidity
function cancelCampaign(bytes16 campaignId) external {
    Campaign memory campaign = campaigns[campaignId];
    require(campaign.manager == msg.sender, 'not manager');
    TransferHelper.withdrawTokens(campaign.token, msg.sender, campaign.amount);
    delete campaigns[campaignId];
}
```

**Long-term Improvements**:
1. Implement approval expiration
2. Add fund origin tracking
3. Require minimum campaign duration

### 9. Lessons for Security Researchers

**Key Red Flags**:
1. Unexpired approvals after operations
2. Missing asset transfers in state-changing functions
3. Manager privileges without proper constraints

**Research Methodologies**:
1. Lifecycle testing - verify all start/middle/end states
2. Approval tracing - map all token allowances
3. Privilege escalation checks - verify all admin functions

This analysis demonstrates a classic case of improper state and asset management in campaign-style contracts, where the cancellation path wasn't properly secured. The exploit shows how even simple oversights in access control and asset cleanup can lead to significant losses when combined with flash loan capabilities.

## 📈 Transaction Trace Summary
- **Transaction ID**: 0x2606d459a50ca4920722a111745c2eeced1d8a01ff25ee762e22d5d4b1595739
- **Block Number**: 19,687,890
- **Contract Address**: 0xc793113f1548b97e37c409f39244ee44241bf2b3
- **Intrinsic Gas**: 21,560
- **Refund Gas**: 4,800
- **Gas Used**: 59,353
- **Call Type**: CALL
- **Nested Function Calls**: 6
- **Event Logs**: 1
- **Asset Changes**: 1 token transfers
- **Top Transfers**: 1303910.12 usdc ($1303722.3506555557251)
- **Balance Changes**: 2 accounts affected
- **State Changes**: 2 storage modifications

## 🔗 References
- **POC File**: source/2024-04/HedgeyFinance_exp/HedgeyFinance_exp.sol
- **Blockchain Explorer**: [View Transaction](https://etherscan.io/tx/0x2606d459a50ca4920722a111745c2eeced1d8a01ff25ee762e22d5d4b1595739)

---
*Generated by DeFi Hack Labs Analysis Tool*
