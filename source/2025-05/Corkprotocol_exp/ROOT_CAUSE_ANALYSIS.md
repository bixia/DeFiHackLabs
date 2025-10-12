# Cork Protocol Hack 根因分析报告

## 📊 执行摘要
- **项目**: Cork Protocol
- **日期**: 2025-05-28
- **网络**: Ethereum
- **损失**: $12,000,000 USD
- **类型**: 访问控制缺陷
- **级别**: 🔴 极其严重

## 🎯 攻击概览
- 攻击者: `0xea6f30e360192bae715599e15e2f765b49e4da98`
- 攻击合约: `0x9af3dce0813fd7428c47f57a39da2f6dd7c9bb09`
- 攻击TX: [`0xfd89cdd0be468a564dd525b222b728386d7c6780cf7b2f90d2b54493be09f64d`](https://app.blocksec.com/explorer/tx/eth/0xfd89cdd0be468a564dd525b222b728386d7c6780cf7b2f90d2b54493be09f64d)
- Post-mortem: https://x.com/SlowMist_Team/status/1928100756156194955

## 💻 技术分析

### 核心漏洞

**initializeModuleCore缺少访问控制**：

```solidity
// 🚨 任何人都可以调用
function initializeModuleCore(
    address asset,
    address ds,
    uint256 param1,
    uint256 param2,
    address recipient
) external {
    // ❌ 没有onlyOwner或其他权限检查
    // 设置关键的模块参数
    // 可以控制资金流向
}
```

### 攻击流程

复杂的多步骤攻击：
```
1. 授权wstETH和LiquidityToken
2. 调用getDeployedSwapAssets获取swap资产地址
3. 通过CorkHook.swap操纵价格
4. 调用depositPsm存入抵押品
5. 🔥 调用initializeModuleCore设置恶意参数
6. 触发赎回/提款操作
7. 通过被操纵的模块配置窃取资金
8. 总计窃取12M USD的wstETH
```

## 🎯 根本原因

**关键函数缺少访问控制**：

```solidity
// ❌ 当前
function initializeModuleCore(...) external {
    // 任何人可调用
}

// ✅ 应该
function initializeModuleCore(...) external onlyOwner {
    // 只有owner可调用
}
```

攻击者通过调用initializeModuleCore设置恶意参数，控制了资金的赎回流程，最终窃取$12M。

## 📝 总结

Cork Protocol攻击利用initializeModuleCore等关键函数缺少访问控制，设置恶意模块参数后窃取$12M。这是2025年第二大DeFi hack。

**教训**: 
- ⚠️ 所有初始化和配置函数必须有严格的访问控制
- ⚠️ 关键参数设置必须通过多签治理
- ⚠️ 大额项目必须有多轮审计

---
**报告生成**: 2025-10-12 | **版本**: 1.0

