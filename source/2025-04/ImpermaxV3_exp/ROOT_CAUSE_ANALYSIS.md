# ImpermaxV3 Hack 根因分析报告

## 📊 执行摘要
- **项目**: ImpermaxV3
- **日期**: 2025-04-26
- **网络**: Base
- **损失**: $300,000 USD
- **类型**: Flashloan攻击 - LP fee操纵
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0xe3223f7e3343c2c8079f261d59ee1e513086c7c3`
- 攻击合约: `0x98e938899902217465f17cf0b76d12b3dca8ce1b`
- 受害合约: `0x5d93f216f17c225a8b5ffa34e74b7133436281ee`
- 攻击TX: [`0xde903046b5cdf27a5391b771f41e645e9cc670b649f7b87b1524fc4076f45983`](https://basescan.org/tx/0xde903046b5cdf27a5391b771f41e645e9cc670b649f7b87b1524fc4076f45983)
- Post-mortem: https://medium.com/@quillaudits/how-impermax-v3-lost-300k-in-a-flashloan-attack-35b02d0cf152

## 💻 技术分析

### 核心漏洞

**利用Uniswap V3 LP fee提升抵押品价值**：

攻击者通过在Uniswap V3池中反复swap累积fee，使得其持有的LP NFT position的价值虚增，然后用作抵押品过度借款。

### 攻击流程
```
1. Flashloan WETH和USDC
2. 在Uniswap V3池中mint LP position
3. 反复swap WETH ↔ USDC
   - 每次swap产生fee
   - Fee累积在LP position中
   - LP价值增加
4. 将LP NFT存入Impermax作为抵押品
5. 由于LP价值被虚增，可以借出更多资产
6. 借出WETH和USDC
7. 归还flashloan
8. 获利$300k
```

## 🎯 根本原因

**LP position价值计算没有考虑fee操纵**：
- Uniswap V3的fee可以通过反复swap累积
- Impermax将fee计入抵押品价值
- 攻击者用flashloan放大fee累积

### 修复
1. LP价值计算时排除或限制fee部分
2. 使用时间加权的LP价值
3. 限制短时间内的大额借款

## 📝 总结

ImpermaxV3攻击利用Uniswap V3 LP fee累积机制，虚增抵押品价值后过度借款$300k。

**教训**: ⚠️ LP抵押品估值必须考虑fee操纵风险

---
**报告生成**: 2025-10-12 | **版本**: 1.0

