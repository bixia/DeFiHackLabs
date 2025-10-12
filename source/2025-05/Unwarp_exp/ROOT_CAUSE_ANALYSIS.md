# Unwarp Hack 根因分析报告

## 📊 执行摘要
- **项目**: Unwarp  
- **日期**: 2025-05-14
- **网络**: Base
- **损失**: $9,000 USDT
- **类型**: 访问控制缺陷
- **级别**: 🟠 高危

## 🎯 攻击概览
- 攻击者: `0x5cc162c556092fe1d993b95d1b9e9ce58a11dbc9`
- 攻击合约: `0x0c6a8c285d696d4d9b8dd4079a72a6460a4da05f`
- 受害合约: `0x8befc1d90d03011a7d0b35b3a00ec50f8e014802`
- 攻击TX: [`0xac6f716c57bbb1a4c1e92f0a9531019ea2ecfcaea67794bbd27115d400ae9b41`](https://app.blocksec.com/explorer/tx/base/0xac6f716c57bbb1a4c1e92f0a9531019ea2ecfcaea67794bbd27115d400ae9b41)

## 💻 技术分析

### 核心漏洞

**unwrapWETH缺少访问控制**：

```solidity
// 🚨 任何人都可以调用
function unwrapWETH(uint256 amount, address recipient) external {
    // ❌ 没有权限检查
    // 将合约的WETH unwrap并发送给recipient
    WETH.withdraw(amount);
    payable(recipient).transfer(amount);
}
```

### 攻击流程
```
1. Flashloan 100.85 WETH from Balancer
2. Transfer WETH到受害合约
3. 调用unwrapWETH(104.83 WETH, attacker)
4. 受害合约的WETH被unwrap并发送给攻击者
5. 攻击者获得更多ETH than flashloan
6. Wrap回WETH归还flashloan
7. 获利~4 WETH ($9k)
```

## 🎯 根本原因

unwrapWETH函数缺少访问控制，允许任何人unwrap合约的WETH并发送到任意地址。

### 修复
```solidity
function unwrapWETH(uint256 amount, address recipient) external onlyOwner {
    // 添加权限检查
}
```

## 📝 总结

Unwarp攻击利用unwrapWETH无保护获利$9k。

**教训**: ⚠️ 所有涉及资金转移的函数都必须有访问控制

---
**报告生成**: 2025-10-12 | **版本**: 1.0

