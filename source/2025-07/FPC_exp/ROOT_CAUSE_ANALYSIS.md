# FPC Token Hack 根因分析报告

## 📊 执行摘要

- **项目名称**: FPC Token
- **攻击日期**: 2025年7月2日
- **网络环境**: BSC
- **总损失金额**: $4,700,000 USD
- **攻击类型**: 缺陷型代币 - Transfer时Burn机制导致价格操纵
- **漏洞级别**: 🔴 严重

## 🎯 攻击概览

| 角色 | 地址 |
|------|------|
| 攻击者 | `0x18dd258631b23777c101440380bf053c79db3d9d` |
| 攻击合约 | `0xbf6e706d505e81ad1f73bbc0babfe2b414ba3eb3` |
| 受害合约 | FPC Token `0xB192D4A737430AA61CEA4Ce9bFb6432f7D42592F` |

- **攻击交易**: [`0x3a9dd216fb6314c013fa8c4f85bfbbe0ed0a73209f54c57c1aab02ba989f5937`](https://bscscan.com/tx/0x3a9dd216fb6314c013fa8c4f85bfbbe0ed0a73209f54c57c1aab02ba989f5937)
- Twitter: https://x.com/TenArmorAlert/status/1940423393880244327

## 💻 技术分析

### 核心漏洞

**FPC代币的Transfer Burn机制**：

```solidity
// FPC代币合约
contract FPC is ERC20 {
    IPancakePair public pair;
    
    // 🚨 有问题的transfer实现
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (to == address(pair)) {
            // ❌ 转入LP时销毁部分代币
            uint256 burnAmount = amount * BURN_RATE / 100;
            _burn(msg.sender, burnAmount);
            
            // 实际转入LP的数量减少
            uint256 actualAmount = amount - burnAmount;
            return super.transfer(to, actualAmount);
        }
        
        return super.transfer(to, amount);
    }
}
```

**核心问题**：当FPC转入LP时会被部分销毁，导致：
1. LP收到的FPC < 预期数量
2. 但swap仍按完整数量计算
3. 攻击者可以用更少的FPC换到更多USDT

### 攻击流程

```
1. Flashloan 23,020,000 USDT
2. Swap: 1 USDT → 大量FPC（买入）
3. 回调: 转23M USDT到LP (不触发burn)
4. 创建Helper合约，持有247k FPC
5. Helper卖出FPC:
   - transfer到LP时，burn 10%
   - LP只收到222.9k FPC
   - 但swap按247k计算
   - 获得27.7M USDT (实际价值远超FPC)
6. 归还flashloan 23M
7. 获利4.7M USDT
```

## 🎯 根本原因

### 为什么导致Hack？

**代码缺陷**：

```solidity
// ❌ Transfer时burn破坏了AMM的x*y=k平衡

// LP期望：
balance[LP] += 247,441 FPC

// 实际：
balance[LP] += 247,441 * 0.9 = 222,696 FPC

// Swap计算：
// 仍然按247,441 FPC计算应付的USDT
// 导致攻击者获得远超价值的USDT
```

**利用链路**：
```
Flashloan → 买入FPC (不burn) → 卖出FPC (burn) → 价格不对称 → 套利
```

### 修复建议

```solidity
// ✅ 方案1：禁止在transfer时burn
function transfer(address to, uint256 amount) public override returns (bool) {
    // 不在transfer中实施特殊逻辑
    return super.transfer(to, amount);
}

// ✅ 方案2：使用专门的swap函数
function swapForUSDT(uint256 amount) external {
    // 先transfer（会burn）
    _transfer(msg.sender, address(pair), amount);
    
    // 然后按实际收到的数量swap
    uint256 actualReceived = pair.balanceOf(FPC);
    pair.swap(calculateUSDT(actualReceived), 0, msg.sender, "");
}
```

## 📝 总结

FPC攻击利用代币Transfer时的Burn机制导致LP余额与swap计算不一致，通过flashloan大额买卖获得价格套利空间，净赚$4.7M。

**教训**:
- ⚠️ Transfer特殊逻辑会破坏AMM机制
- ⚠️ Burn应该通过专门函数而非transfer
- ⚠️ LP操作必须原子化验证余额变化

---
**报告生成时间**: 2025-10-12  
**版本**: 1.0

