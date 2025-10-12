# HORS Hack 根因分析报告

## 📊 执行摘要
- **项目**: HORS
- **日期**: 2025-01-08
- **网络**: BSC
- **损失**: 14.8 WBNB (~$9,000)
- **类型**: 访问控制缺陷
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0x8Efb9311700439d70025d2B372fb54c61a60d5DF`
- 受害合约: `0x6f3390c6C200e9bE81b32110CE191a293dc0eaba`
- 攻击TX: [`0xc8572846ed313b12bf835e2748ff37dacf6b8ee1bab36972dc4ace5e9f25fed7`](https://bscscan.com/tx/0xc8572846ed313b12bf835e2748ff37dacf6b8ee1bab36972dc4ace5e9f25fed7)

## 💻 技术分析

### 核心漏洞
受害合约缺少对router地址的验证，攻击者伪装成router调用函数0xf78283c7，窃取LP代币。

```solidity
// 🚨 缺少router验证
function 0xf78283c7(address token, address router, address lp) external {
    // ❌ 没有检查router是否是可信地址
    // 攻击者传入自己的地址作为router
    
    // 调用router.addLiquidity
    // 实际调用攻击合约的addLiquidity
    // 攻击合约执行: LP.transferFrom(victim, attacker, balance)
}
```

### 攻击流程
```
1. Flashloan 0.1 WBNB
2. 调用victim.0xf78283c7(HORS, attackContract, CAKE_LP)
3. victim调用attackContract.addLiquidity()
4. attackContract执行: transferFrom(victim, attacker, LP_balance)
5. 移除流动性获得WBNB和HORS
6. 归还flashloan
7. 获利14.8 WBNB
```

## 🎯 根本原因

**访问控制缺失**：函数没有验证router地址是否可信，允许攻击者传入恶意合约。

### 修复
```solidity
mapping(address => bool) public trustedRouters;
function someFunction(address router, ...) external {
    require(trustedRouters[router], "Untrusted router");
    // ...
}
```

## 📝 总结
HORS攻击利用函数缺少router白名单验证，通过伪造router窃取LP代币，获利14.8 WBNB。

**教训**: ⚠️ 所有外部地址参数都必须验证

---
**报告生成**: 2025-10-12 | **版本**: 1.0

