# Pump Hack 根因分析报告

## 📊 执行摘要
- **项目**: Pump
- **日期**: 2025-03-04
- **网络**: BSC
- **损失**: 11.29 BNB ($6,400 USD)
- **类型**: 无滑点保护
- **级别**: 🟠 高危

## 🎯 攻击概览
- 攻击者: `0x5d6e908c4cd6eda1c2a9010d1971c7d62bdb5cd3`
- 攻击TX: [`0xdebaa13fb06134e63879ca6bcb08c5e0290bdbac3acf67914c0b1dcaf0bdc3dd`](https://bscscan.com/tx/0xdebaa13fb06134e63879ca6bcb08c5e0290bdbac3acf67914c0b1dcaf0bdc3dd)

## 💻 技术分析
Pump合约的swap函数缺少滑点保护，攻击者可以以极不利的价格执行交易，窃取差价。

## 🎯 根本原因
Swap函数的amountOutMinimum设为0或没有合理检查。

## 📝 总结
Pump攻击利用无滑点保护获利11.29 BNB。

---
**报告生成**: 2025-10-12 | **版本**: 1.0

