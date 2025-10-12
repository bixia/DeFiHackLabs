# d3xai Hack 根因分析报告

## 📊 执行摘要

- **项目名称**: d3xai
- **攻击日期**: 2025年8月16日  
- **网络环境**: BSC
- **总损失金额**: 190 BNB (~$114,000 USD)
- **攻击类型**: 价格操纵 - Proxy Exchange价格差
- **漏洞级别**: 🔴 严重

## 🎯 攻击概览

| 角色 | 地址 |
|------|------|
| 攻击者 | `0x4b63c0cf524f71847ea05b59f3077a224d922e8d` |
| 攻击合约 | `0x3b3e1edeb726b52d5de79cf8dd8b84995d9aa27c` |
| Proxy合约 | `0xb8ad82c4771DAa852DdF00b70Ba4bE57D22eDD99` |

- **攻击交易**: [`0x26bcefc152d8cd49f4bb13a9f8a6846be887d7075bc81fa07aa8c0019bd6591f`](https://bscscan.com/tx/0x26bcefc152d8cd49f4bb13a9f8a6846be887d7075bc81fa07aa8c0019bd6591f)
- Twitter: https://x.com/suplabsyi/status/1956695597546893598

## 💻 技术分析

### 核心漏洞

**Proxy的exchange()函数价格设置不合理**：

```solidity
// Proxy合约提供D3XAT/USDT exchange
// 但价格与Pancake Router不同

// Proxy价格：1 D3XAT = 0.01 USDT (低价买入)
// Pancake价格：1 D3XAT = 0.012 USDT (高价卖出)

// 套利空间：20%
```

### 攻击流程

```
1. Flashloan 20M USDT
2. 通过Proxy以低价买入D3XAT（花费24k USDT）
3. 通过Pancake以更高价买入更多D3XAT（花费6.18M USDT）
4. 通过Proxy以高价卖出第2步的D3XAT（获得22.5k USDT）
5. 通过Pancake卖出第3步的D3XAT（获得6.11M USDT）
6. 归还flashloan
7. 净利润来自价格差
```

**关键套利**：
- Proxy买价 < Proxy卖价 (存在差价)
- Pancake价格可被操纵
- 组合利用获利

## 🎯 根本原因

Proxy的exchange()定价机制与市场脱节，创造了套利空间。攻击者通过复杂的多步骤操作在不同渠道间套利。

### 修复建议

```solidity
// 1. Proxy应使用市场价格（Chainlink或AMM TWAP）
// 2. 添加滑点保护
// 3. 限制单次exchange数量
// 4. 实施冷却期
```

## 📝 总结

d3xai攻击利用Proxy exchange与Pancake之间的价格差进行复杂套利，净赚190 BNB。

**教训**: ⚠️ 定价必须与市场同步，否则创造套利机会

---
**报告生成时间**: 2025-10-12  
**版本**: 1.0

