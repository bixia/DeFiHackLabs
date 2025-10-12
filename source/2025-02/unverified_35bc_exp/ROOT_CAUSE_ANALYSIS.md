# Unverified_35bc Hack 根因分析报告

## 📊 执行摘要
- **项目**: Unverified Contract 0x35bc
- **日期**: 2025-02-22
- **网络**: BSC
- **损失**: $6,700 USD
- **类型**: 重入攻击 (Reentrancy)
- **级别**: 🔴 高危

## 🎯 攻击概览
- 攻击者: `0xd75652ada2f6a140f2ffcd7cd20f34c21fbc3fbc`
- 受害合约: `0xde91e6e937ec344e5a3c800539c41979c2d85278`
- 攻击TX: [`0xd7a61b07ca4dc5966d00b3cc99b03c6ab2cee688fa13b30bea08f5142023777d`](https://app.blocksec.com/explorer/tx/bsc/0xd7a61b07ca4dc5966d00b3cc99b03c6ab2cee688fa13b30bea08f5142023777d)

## 💻 技术分析

### 核心漏洞

**重入漏洞**：合约在unlockSlot函数中向用户发送BNB，但没有重入保护，允许攻击者在fallback中重入。

```solidity
// 🚨 存在重入漏洞
function unlockSlot(uint256 slot) external payable {
    // 执行一些逻辑
    
    // ❌ 在状态更新前发送ETH
    payable(msg.sender).call{value: amount}("");
    
    // 状态更新
    userSlots[msg.sender][slot] = false;
}
```

### 攻击流程
```
1. 调用unlockSlot(3) with 0.6 BNB
2. 合约向攻击者发送BNB
3. 触发攻击合约的fallback
4. 在fallback中再次调用unlockSlot或其他函数
5. 在状态更新前重复提取资金
6. 获利6.7k USD
```

## 🎯 根本原因

典型的重入攻击，未遵循检查-效果-交互模式。

### 修复
```solidity
// ✅ 添加重入保护
modifier nonReentrant() {
    require(!locked, "Reentrancy");
    locked = true;
    _;
    locked = false;
}

// ✅ 或遵循CEI模式
function unlockSlot(uint256 slot) external payable nonReentrant {
    // Effects: 先更新状态
    userSlots[msg.sender][slot] = false;
    
    // Interactions: 后进行外部调用
    payable(msg.sender).call{value: amount}("");
}
```

## 📝 总结

典型的重入攻击案例，缺少ReentrancyGuard导致$6.7k损失。

**教训**: ⚠️ 所有发送ETH的函数都必须有重入保护

---
**报告生成**: 2025-10-12 | **版本**: 1.0

