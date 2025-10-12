# RICE Hack 根因分析报告

## 📊 执行摘要
- **项目**: RICE  
- **日期**: 2025-05-24
- **网络**: Base
- **损失**: 34.5 WETH ($88,100 USD)
- **类型**: 访问控制缺陷
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0x2a49c6fd18bd111d51c4fffa6559be1d950b8eff`
- 攻击合约: `0x7ee23c81995fe7992721ac14b3af522718b63f8f`
- 受害合约: `0xcfe0de4a50c80b434092f87e106dfa40b71a5563`
- 攻击TX: [`0x8421c96c1cafa451e025c00706599ef82780bdc0db7d17b6263511a420e0cf20`](https://basescan.org/tx/0x8421c96c1cafa451e025c00706599ef82780bdc0db7d17b6263511a420e0cf20)

## 💻 技术分析

### 核心漏洞

**registerProtocol和setMasterContractApproval缺少访问控制**：

```solidity
// 🚨 任何人都可以注册protocol
function registerProtocol() external {
    // 注册调用者为protocol
}

// 🚨 任何人都可以设置master contract approval
function setMasterContractApproval(
    address user,
    address masterContract,
    bool approved,
    uint8 v,
    bytes32 r,
    bytes32 s
) external {
    // ❌ 没有验证调用者权限
    // ❌ 没有验证签名
    masterContractApproved[user][masterContract] = approved;
}
```

### 攻击流程
```
1. 调用registerProtocol()注册为protocol
2. 调用setMasterContractApproval设置权限
3. 利用被授予的权限操作用户资金
4. 窃取34.5 WETH
```

## 🎯 根本原因

关键的权限设置函数缺少访问控制，任何人都可以注册为protocol并设置master contract approval。

## 📝 总结

RICE攻击利用registerProtocol和setMasterContractApproval无保护，获得系统权限后窃取$88k。

**教训**: ⚠️ 权限管理函数必须有严格的访问控制

---
**报告生成**: 2025-10-12 | **版本**: 1.0

