# LeverageSIR Hack 根因分析报告

## 📊 执行摘要
- **项目**: LeverageSIR
- **日期**: 2025-03-30
- **网络**: Ethereum
- **损失**: $353,800 USD (17.8k USDC, 1.4 WBTC, 119.87 WETH)
- **类型**: Storage Slot冲突 (Storage Collision)
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0x27defcfa6498f957918f407ed8a58eba2884768c`
- 攻击合约: `0xea55fffae1937e47eba2d854ab7bd29a9cc29170`
- 受害合约: `0xb91ae2c8365fd45030aba84a4666c4db074e53e7`
- 攻击TX: [`0xa05f047ddfdad9126624c4496b5d4a59f961ee7c091e7b4e38cee86f1335736f`](https://etherscan.io/tx/0xa05f047ddfdad9126624c4496b5d4a59f961ee7c091e7b4e38cee86f1335736f)

## 💻 技术分析

### 核心漏洞

**EIP-1153 (tstore/tload) 与 Storage Slot1冲突**：

```solidity
// Vault使用tstore(1, amount)临时存储数据
// 但slot1也被用作其他关键状态

function mint(...) external {
    // 🚨 使用tstore存储临时数据
    assembly {
        tstore(1, amount)
    }
    
    // 后续操作读取slot1
    // 但由于tstore/tload的特性，数据被覆盖
}
```

### 攻击流程
```
1. 创建特殊的Uniswap V3 pool和NFT position
2. 调用vault.initialize()
3. 调用vault.mint()操纵slot1
4. 利用storage collision，让vault误以为有巨额抵押品
5. 借出大量USDC、WBTC、WETH
6. 获利$353k
```

## 🎯 根本原因

**EIP-1153临时存储与常规storage slot冲突**。合约错误地假设tstore不会影响其他状态，导致关键变量被覆盖。

### 修复
```solidity
// 1. 不要混用tstore和regular storage
// 2. 使用明确分离的slot范围
// 3. 充分测试EIP-1153的edge cases
```

## 📝 总结

LeverageSIR攻击利用EIP-1153 tstore与storage slot1的冲突，操纵关键状态后过度借款$353k。

**教训**: ⚠️ 新特性(EIP-1153)需要极其谨慎使用

---
**报告生成**: 2025-10-12 | **版本**: 1.0

