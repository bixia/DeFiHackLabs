# KRC Token Hack 根因分析报告

## 📊 执行摘要
- **项目**: KRC Token
- **日期**: 2025-05-18
- **网络**: BSC
- **损失**: $7,000 USD
- **类型**: Deflationary Token - Transfer Fee操纵
- **级别**: 🟠 高危

## 🎯 攻击概览
- 攻击者: `0x9943f26831f9b468a7fe5ac531c352baab8af655`
- 攻击合约: `0xd995edcab2efe3283514ff111cedc9aaff0349c8`
- 受害合约: KRC Pair `0xdbead75d3610209a093af1d46d5296bbeffd53f5`
- 攻击TX: [`0x78f242dee5b8e15a43d23d76bce827f39eb3ac54b44edcd327c5d63de3848daf`](https://bscscan.com/tx/0x78f242dee5b8e15a43d23d76bce827f39eb3ac54b44edcd327c5d63de3848daf)

## 💻 技术分析

KRC是deflationary token，transfer时扣除fee。攻击者通过flashloan大额swap后，利用fee机制和skim操纵LP余额，最终套利。

### 攻击流程
```
1. Flashloan 248M USDT + 100k USDT
2. Swap USDT → KRC (两次大额买入)
3. 精确的17次transfer和skim操作
   - 每次transfer都有fee损耗
   - 通过skim调整LP余额
   - 创造套利机会
4. Swap KRC → USDT
5. 归还flashloan  
6. 获利$7k
```

## 🎯 根本原因

Deflationary token的fee机制与AMM不兼容，通过精心设计的transfer序列可以操纵LP余额。

## 📝 总结

KRC攻击利用deflationary token的transfer fee与AMM的不兼容性套利$7k。

**教训**: ⚠️ Deflationary token需要特殊的AMM处理

---
**报告生成**: 2025-10-12 | **版本**: 1.0

