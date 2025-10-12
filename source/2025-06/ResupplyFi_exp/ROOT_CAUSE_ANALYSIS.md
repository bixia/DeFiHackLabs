# ResupplyFi Hack 根因分析报告

## 📊 执行摘要

- **项目名称**: ResupplyFi
- **攻击日期**: 2025年6月26日
- **网络环境**: Ethereum Mainnet
- **总损失金额**: $9,600,000 USD
- **攻击类型**: Share价格操纵 (Share Price Manipulation)
- **漏洞级别**: 🔴 严重

## 🎯 攻击概览

| 角色 | 地址 |
|------|------|
| 攻击者 | `0x6d9f6e900ac2ce6770fd9f04f98b7b0fc355e2ea` |
| 攻击合约 | `0xf90da523a7c19a0a3d8d4606242c46f1ee459dc7` |
| 受害合约 | ResupplyVault `0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6` |

- **攻击交易**: [`0xffbbd492e0605a8bb6d490c3cd879e87ff60862b0684160d08fd5711e7a872d3`](https://etherscan.io/tx/0xffbbd492e0605a8bb6d490c3cd879e87ff60862b0684160d08fd5711e7a872d3)
- Post-mortem: https://mirror.xyz/0x521CB9b35514E9c8a8a929C890bf1489F63B2C84/ygJ1kh6satW9l_NDBM47V87CfaQbn2q0tWy_rtp76OI

## 💻 技术分析

### 核心漏洞

**ERC4626 Share价格膨胀攻击**：

```solidity
// ResupplyVault使用sCRVUSD作为抵押品
// sCRVUSD是一个share token（ERC4626）

// 🚨 Share价格计算
function convertToAssets(uint256 shares) public view returns (uint256) {
    uint256 totalAssets = totalAssets();
    uint256 totalShares = totalSupply();
    
    if (totalShares == 0) return shares;
    
    // 价格 = 总资产 / 总shares
    return (shares * totalAssets) / totalShares;
}

// 🔥 攻击点：操纵totalAssets/totalShares比率
```

### 攻击流程

```
1. Flashloan 4,000 USDC
2. Swap USDC → crvUSD
3. 操纵sCRVUSD Oracle：
   - 转2,000 crvUSD到controller（影响价格）
   - Mint 1 wei sCRVUSD
4. 向ResupplyVault添加1 wei sCRVUSD作为抵押品
5. sCRVUSD被高估（因为totalAssets被操纵）
6. 借出10,000,000 reUSD（远超1 wei抵押品的真实价值）
7. Swap reUSD → crvUSD
8. Redeem sCRVUSD
9. Swap回USDC
10. 归还flashloan
11. 获利$9.6M
```

## 🎯 根本原因

### 为什么导致Hack？

**第一次存款攻击（First Deposit Attack）**：

```solidity
// 当vault为空时：
totalAssets = 0
totalShares = 0

// 攻击者操作：
// 1. 先deposit 1 wei
totalShares = 1

// 2. 直接转入大量资产（绕过deposit）
vault.asset.transfer(vault, 10000e18);
totalAssets = 10000e18

// 3. 此时share价格 = 10000e18 / 1 = 10000e18 per share
// 4. 攻击者的1 wei share价值10000e18资产！
```

**用作抵押品时的影响**：

```solidity
// ResupplyVault计算抵押品价值：
collateralValue = convertToAssets(userShares);

// 如果攻击者持有1 wei sCRVUSD：
// 但convertToAssets(1) = 10000e18
// 可以借出远超真实价值的资金！
```

### 修复建议

```solidity
// ✅ 防止第一次存款攻击
constructor() {
    // 锁定最小shares
    _mint(address(1), 1000);  // 永久锁定
}

// ✅ 或使用虚拟股份
function convertToShares(uint256 assets) public view returns (uint256) {
    uint256 supply = totalSupply() + VIRTUAL_SHARES;
    uint256 totalAssets = totalAssets() + VIRTUAL_ASSETS;
    return (assets * supply) / totalAssets;
}
```

## 📝 总结

ResupplyFi攻击是经典的**ERC4626第一次存款攻击**，操纵sCRVUSD的share价格后用1 wei抵押品借出$9.6M。

**教训**:
- ⚠️ ERC4626必须防止第一次存款攻击
- ⚠️ 锁定初始shares或使用虚拟股份
- ⚠️ 验证抵押品价值的合理性

---
**报告生成时间**: 2025-10-12  
**版本**: 1.0

