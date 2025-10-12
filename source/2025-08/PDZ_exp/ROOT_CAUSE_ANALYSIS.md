# PDZ Token Hack 根因分析报告

## 📊 执行摘要

- **项目名称**: PDZ Token (TbBuild)
- **攻击日期**: 2025年8月15日
- **网络环境**: BSC
- **总损失金额**: 3.3 BNB (~$2,000 USD)
- **攻击类型**: 价格操纵 (Price Manipulation)
- **漏洞级别**: 🔴 高危

## 🎯 攻击概览

| 角色 | 地址 |
|------|------|
| 攻击者 | `0x48234fb95d4d3e5a09f3ec4dd57f68281b78c825` |
| 攻击合约 | `0x1dffe35fb021f124f04d1a654236e0879fa0cb81` |
| 受害合约 | TbBuild `0x664201579057f50D23820d20558f4b61bd80BDda` |

- **攻击交易**: [`0x81fd00eab3434eac93bfdf919400ae5ca280acd891f95f47691bbe3cbf6f05a5`](https://bscscan.com/tx/0x81fd00eab3434eac93bfdf919400ae5ca280acd891f95f47691bbe3cbf6f05a5)
- Twitter: https://x.com/tikkalaresearch/status/1957500585965678828

## 💻 技术分析

### 核心漏洞

```solidity
contract TbBuild {
    // 🚨 使用getAmountsOut计算奖励（可被操纵）
    function burnToHolder(uint256 amount, address _invitation) external {
        // 销毁PDZ代币
        PDZ.burn(msg.sender, amount);
        
        // ❌ 使用实时价格计算奖励
        uint256[] memory amounts = uniswapRouter.getAmountsOut(
            amount,
            [PDZ, WBNB]
        );
        uint256 reward = amounts[1];  // 🚨 可被价格操纵
        
        // 记录待领取奖励
        pendingRewards[msg.sender] += reward;
    }
    
    function receiveRewards(address to) external {
        uint256 reward = pendingRewards[msg.sender];
        pendingRewards[msg.sender] = 0;
        
        // 支付BNB奖励
        payable(to).transfer(reward);
    }
}
```

### 攻击流程

**完整步骤**：
```
1. Flashloan 10 WBNB
2. 买入PDZ (推高PDZ/WBNB价格10x)
3. 调用burnToHolder，使用被操纵的高价计算奖励
4. receiveRewards领取过多的BNB
5. 卖出剩余PDZ
6. 归还flashloan
7. 获利3.3 BNB
```

## 🎯 根本原因

### 为什么导致Hack？

```solidity
// ❌ 使用可操纵的getAmountsOut
uint256[] memory amounts = router.getAmountsOut(amount, path);

// ✅ 应该使用TWAP或固定比例
uint256 reward = (amount * FIXED_RATE) / PRECISION;

// 或使用Chainlink价格
uint256 pdzPrice = getChainlinkPrice();
uint256 reward = (amount * pdzPrice) / 1e18;
```

### 修复方案

1. **使用固定兑换比例**而非实时价格
2. **或使用TWAP价格**（至少30分钟）
3. **添加奖励上限**（单次burn不超过X BNB）
4. **实施冷却期**（防止快速连续burn）

## 📝 总结

PDZ攻击利用`burnToHolder`函数使用`getAmountsOut`实时价格计算奖励的缺陷，通过flashloan推高价格后burn代币获得过多BNB奖励，净赚3.3 BNB。这是价格Oracle操纵的又一案例。

**教训**:
- ⚠️ 永不使用spot价格计算奖励
- ⚠️ 使用TWAP或固定比例
- ⚠️ 添加限额保护

---
**报告生成时间**: 2025-10-12  
**版本**: 1.0

