# PeapodsFinance Hack 根因分析报告

## 📊 执行摘要
- **项目**: PeapodsFinance
- **日期**: 2025-02-08
- **网络**: Ethereum
- **损失**: $3,500 USD
- **类型**: 价格操纵
- **级别**: 🟠 中危

## 🎯 攻击概览
- 攻击者: `0xedee6379fe90bd9b85d8d0b767d4a6deb0dc9dcf`
- 攻击TX: [`0x2c1a19982aa88bee8a5d9a5dfeb406f2bfe1cfc1213f20e91d91ce3b55c86cc5`](https://etherscan.io/tx/0x2c1a19982aa88bee8a5d9a5dfeb406f2bfe1cfc1213f20e91d91ce3b55c86cc5)
- Post-mortem: https://blog.solidityscan.com/peapods-finance-hack-analysis-bdc5432107a5

## 💻 技术分析

通过flashloan swap pOHM获得PEAS，存入TokenRewards获得高额奖励，利用价格操纵套利。

### 攻击流程
```
1. Flashloan pOHM
2. Swap pOHM → PEAS
3. Deposit到TokenRewards
4. 利用被操纵的奖励机制
5. Withdraw获利
6. 归还flashloan
```

## 📝 总结

PeapodsFinance攻击利用TokenRewards奖励计算的价格操纵漏洞获利$3.5k。

---
**报告生成**: 2025-10-12 | **版本**: 1.0

