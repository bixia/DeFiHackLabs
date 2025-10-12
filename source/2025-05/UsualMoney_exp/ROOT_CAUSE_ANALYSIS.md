# UsualMoney Hack 根因分析报告

## 📊 执行摘要
- **项目**: UsualMoney (USD0+ Vault)
- **日期**: 2025-05-27
- **网络**: Ethereum
- **损失**: $43,000 USD
- **类型**: 价格套利 (Arbitrage)
- **级别**: 🟠 高危

## 🎯 攻击概览
- 攻击者: `0x2ae2f691642bb18cd8deb13a378a0f95a9fee933`
- 攻击合约: `0xf195b8800b729aee5e57851dd4330fcbb69f07ea`
- 受害合约: USD0+ Vault `0x35D8949372D46B7a3D5A56006AE77B215fc69bC0`
- 攻击TX: [`0x585d8be6a0b07ca2f94cfa1d7542f1a62b0d3af5fab7823cbcf69fb243f271f8`](https://etherscan.io/tx/0x585d8be6a0b07ca2f94cfa1d7542f1a62b0d3af5fab7823cbcf69fb243f271f8)
- Post-mortem: https://www.quadrigainitiative.com/hackfraudscam/usualmoneyusdssyncvaultpricingarbitrageexploit.php

## 💻 技术分析

### 核心问题

**Vault定价与市场价格偏差**：

USD0+ Vault的mint/redeem价格与Curve等外部市场的USD0价格存在偏差，创造套利空间。

### 攻击流程
```
1. Flashloan 1.9M USD0+
2. Deposit到VaultRouter获得shares
3. 通过Curve等市场swap，利用价格差
4. Redeem shares
5. 归还flashloan
6. 获利$43k
```

## 🎯 根本原因

Vault的内部定价机制与外部市场不同步，攻击者通过flashloan在两个价格体系间套利。

### 修复
1. 同步内外部价格
2. 添加mint/redeem费用
3. 实施冷却期

## 📝 总结

UsualMoney攻击是价格套利，利用vault定价与市场价差获利$43k。

**教训**: ⚠️ Vault定价必须与市场同步或有防护机制

---
**报告生成**: 2025-10-12 | **版本**: 1.0

