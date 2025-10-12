# GMX Hack 根因分析报告

## 📊 执行摘要

- **项目名称**: GMX V1
- **攻击日期**: 2025年7月9日
- **网络环境**: Arbitrum
- **总损失金额**: $41,000,000 USD
- **攻击类型**: 重入攻击 + GLP Share价格操纵
- **漏洞级别**: 🔴 极其严重

## 🎯 攻击概览

| 角色 | 地址 |
|------|------|
| 攻击者 | 未公开EOA |
| 受害合约 | GMX Vault等多个合约 |

- Twitter: https://x.com/GMX_IO/status/1943336664102756471
- 损失：涉及ETH、BTC、USDC等9种代币

## 💻 技术分析

### 核心漏洞

**重入 + GLP Share价格操纵**：

GMX V1的攻击非常复杂，涉及多个步骤：

1. **重入点**：`fallback()`函数在position关闭时被调用
2. **价格操纵**：通过开平仓操纵`globalShortAveragePrice`
3. **Share套利**：在被操纵的价格下mint/redeem GLP获利

### 攻击流程概览

```
阶段1：建立Position
├─ 创建ETH long positions（2次）
├─ 使用callback在关闭时创建BTC short position
└─ 操纵globalShortAveragePrice

阶段2：重入攻击
├─ 关闭ETH position触发fallback
├─ 在fallback中创建巨额BTC short
├─ 操纵价格使profit虚增
└─ 通过executeDecreasePosition实现

阶段3：GLP Share套利
├─ Flashloan 7.5B USDC
├─ Mint GLP（使用被操纵的价格）
├─ 创建巨额BTC position
├─ 从9种代币中提取profit
├─ Redeem GLP
└─ 获利$41M
```

### 关键代码点

**重入利用**：
```solidity
// GMX在position关闭时会调用callback
function gmxPositionCallback(bytes32, bool, bool) external {
    // 🔥 在这里重入创建新position
    createCloseETHPosition();
}

fallback() external payable {
    if(!isProfit) {
        // 🔥 第一阶段：创建BTC short position
        vault.increasePosition(..., BTC, ..., false);  // short
        positionRouter.createDecreasePosition(...);
    } else {
        // 🔥 第二阶段：执行获利攻击
        profitAttack();
    }
}
```

**GLP价格操纵**：
```solidity
// getGlobalShortAveragePrice被操纵后：
// - 虚增profit
// - GLP share价格不准确
// - 可以用低价mint GLP，高价redeem
```

## 🎯 根本原因

### 为什么导致Hack？

1. **重入保护缺失**：callback允许重入
2. **价格计算缺陷**：globalShortAveragePrice可被操纵
3. **GLP share机制**：share价格依赖可操纵的状态

### 修复建议

```solidity
// 1. 添加重入保护
modifier nonReentrant() {
    require(!locked, "Reentrancy");
    locked = true;
    _;
    locked = false;
}

// 2. 限制callback功能
// 3. 使用更robust的price oracle
// 4. GLP mint/redeem添加延迟
```

## 📝 总结

GMX V1攻击是2025年最大的DeFi hack，攻击者通过精心设计的重入攻击操纵globalShortAveragePrice，然后利用被操纵的价格在GLP share系统中套利，损失$41M。这促使GMX加速向V2迁移。

**教训**:
- ⚠️ 所有外部调用都需要重入保护
- ⚠️ Callback功能必须严格限制
- ⚠️ Share价格计算必须防操纵
- ⚠️ 复杂系统需要更多安全审查

---
**报告生成时间**: 2025-10-12  
**版本**: 1.0

