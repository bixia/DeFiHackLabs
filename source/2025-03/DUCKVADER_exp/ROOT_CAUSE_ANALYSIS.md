# DUCKVADER Hack 根因分析报告

## 📊 执行摘要
- **项目**: DUCKVADER NFT
- **日期**: 2025-03-11
- **网络**: Base
- **损失**: 5 ETH ($9,600 USD)
- **类型**: Free Mint Bug
- **级别**: 🟠 高危

## 🎯 攻击概览
- 攻击者: `0x2383a550e40a61b41a89da6b91d8a4a2452270d0`
- 攻击合约: `0x652f9ac437a870ce273a0be9d7e7ee03043a91ff`
- 受害合约: `0xaa8f35183478b8eced5619521ac3eb3886e98c56`
- 攻击TX: [`0x9bb1401233bb9172ede2c3bfb924d5d406961e6c63dee1b11d5f3f79f558cae4`](https://basescan.org/tx/0x9bb1401233bb9172ede2c3bfb924d5d406961e6c63dee1b11d5f3f79f558cae4)

## 💻 技术分析

### 核心漏洞

**buyTokens函数可以免费mint**：

```solidity
// 🚨 可以用0支付mint代币
function buyTokens(uint256 usdtAmount) external payable {
    // ❌ 没有检查msg.value或usdtAmount
    // 可以传0免费mint
    _mint(msg.sender, calculateAmount(usdtAmount));
}
```

### 攻击流程
```
1. 创建10个合约
2. 每个合约调用buyTokens(0)免费mint
3. Transfer代币到主合约
4. Swap DUCKVADER → WETH
5. 获利5 ETH
```

## 🎯 根本原因

buyTokens没有验证支付，允许免费mint代币。

### 修复
```solidity
function buyTokens(uint256 usdtAmount) external payable {
    require(msg.value >= price || usdtAmount >= price, "Payment required");
    // ...
}
```

## 📝 总结

DUCKVADER攻击利用免费mint漏洞获利5 ETH。

**教训**: ⚠️ Mint函数必须验证支付

---
**报告生成**: 2025-10-12 | **版本**: 1.0

