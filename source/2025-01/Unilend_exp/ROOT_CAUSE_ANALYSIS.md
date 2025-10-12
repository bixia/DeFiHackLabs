# Unilend Hack 根因分析报告

## 📊 执行摘要
- **项目**: Unilend V2
- **日期**: 2025-01-12
- **网络**: Ethereum
- **损失**: 60 stETH (~$204,000)
- **类型**: 逻辑缺陷 - Health Factor计算错误
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0x55f5f8058816d5376df310770ca3a2e294089c33`
- 攻击合约: `0x3f814e5fae74cd73a70a0ea38d85971dfa6fda21`
- 受害合约: UnilendV2Pool `0x4E34DD25Dbd367B1bF82E1B5527DBbE799fAD0d0`
- 攻击TX: [`0x44037ffc0993327176975e08789b71c1058318f48ddeff25890a577d6555b6ba`](https://etherscan.io/tx/0x44037ffc0993327176975e08789b71c1058318f48ddeff25890a577d6555b6ba)
- Post-mortem: https://slowmist.medium.com/analysis-of-the-unilend-hack-90022fa35a54

## 💻 技术分析

### 核心漏洞

**Health Factor计算错误**：

```solidity
// Unilend的健康因子计算存在缺陷
function calculateHealthFactor(address user) internal view returns (uint256) {
    uint256 collateralValue = getCollateralValue(user);
    uint256 borrowValue = getBorrowValue(user);
    
    // 🚨 计算有缺陷
    // 某些edge case下，健康因子计算不准确
    // 允许过度借款
    
    return (collateralValue * LTV) / borrowValue;
}
```

### 攻击流程

```
准备：
1. 存入200 USDC获得lendShares
2. 转移lendShares到攻击合约（NFT #115）

主攻击：
1. Flashloan 60M USDC
2. Flashloan 5.757 wstETH
3. unwrap wstETH → stETH
4. 操纵lend/borrow：
   - lend: -60M USDC（负数，减少lend份额）
   - lend: +stETH（增加stETH lend份额）
5. 🔥 利用health factor计算错误：
   - 借出所有池中的stETH（60 stETH）
   - 尽管实际抵押品不足
6. Redeem underlying取回资产
7. wrap stETH → wstETH
8. 归还flashloan
9. 获利60 stETH
```

## 🎯 根本原因

**Health Factor计算在负数lend场景下失效**：

当使用负数调用lend()时，会减少lendShare，这导致健康因子计算出现错误，允许借出远超抵押品价值的资产。

```solidity
// ❌ 当前实现无法正确处理负数lend
function lend(int amount) external {
    if (amount < 0) {
        // 减少lendShare
        // 但health factor计算没有正确更新
    }
}

// ✅ 应该
function lend(int amount) external {
    // 禁止负数
    require(amount > 0, "Amount must be positive");
    // 或正确处理负数场景的health factor
}
```

### 修复建议
1. 禁止或正确处理负数lend
2. 修复health factor计算
3. 添加借款前的全面检查

## 📝 总结

Unilend攻击利用health factor在负数lend场景下的计算错误，过度借款60 stETH。

**教训**: 
- ⚠️ Health factor计算必须覆盖所有edge cases
- ⚠️ 负数输入需要特别小心处理
- ⚠️ 借款前需要全面验证抵押品充足性

---
**报告生成**: 2025-10-12 | **版本**: 1.0

