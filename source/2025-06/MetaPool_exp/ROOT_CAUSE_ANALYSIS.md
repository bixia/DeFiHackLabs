# MetaPool Hack 根因分析报告

## 📊 执行摘要
- **项目**: MetaPool  
- **日期**: 2025-06-17
- **网络**: Ethereum
- **损失**: $25,000 USD
- **类型**: 访问控制缺陷
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0x48f1d0f5831eb6e544f8cbde777b527b87a1be98`
- 攻击合约: `0xff13d5899aa7d84c10e4cd6fb030b80554424136`
- 受害合约: mpETH `0x48afbbd342f64ef8a9ab1c143719b63c2ad81710`
- 攻击TX: [`0x57ee419a001d85085478d04dd2a73daa91175b1d7c11d8a8fb5622c56fd1fa69`](https://etherscan.io/tx/0x57ee419a001d85085478d04dd2a73daa91175b1d7c11d8a8fb5622c56fd1fa69)
- Post-mortem: https://www.coindesk.com/business/2025/06/17/liquid-staking-protocol-meta-pool-suffers-usd27m-exploit

## 💻 技术分析

### 核心漏洞

mpETH是liquid staking token，攻击者通过flashloan大额deposit/withdraw操纵mpETH/ETH汇率，然后套利。

### 攻击流程
```
1. Flashloan 200 WETH
2. Deposit 107 ETH获得97 mpETH
3. 操纵mpETH/ETH池价格
4. Withdraw以有利汇率
5. 归还flashloan
6. 获利$25k
```

## 🎯 根本原因

mpETH的mint/redeem汇率可被大额flashloan操纵。

### 修复
1. 使用TWAP汇率
2. Mint/redeem费用
3. 冷却期

## 📝 总结

MetaPool攻击利用mpETH汇率操纵获利$25k。

---
**报告生成**: 2025-10-12 | **版本**: 1.0

