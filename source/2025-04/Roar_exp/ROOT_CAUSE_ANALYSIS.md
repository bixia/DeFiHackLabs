# Roar Hack 根因分析报告

## 📊 执行摘要
- **项目**: Roar (ONE R0AR Token)
- **日期**: 2025-04-16
- **网络**: Ethereum
- **损失**: $777,000 USD
- **类型**: Rug Pull
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者(项目方): `0x8149f77504007450711023cf0ec11bdd6348401f`
- 代币合约: `0xb0415D55f2C87b7f99285848bd341C367FeAc1ea`
- 攻击TX: [`0xab2097bb3ce666493d0f76179f7206926adc8cec4ba16e88aed30c202d70c661`](https://app.blocksec.com/explorer/tx/eth/0xab2097bb3ce666493d0f76179f7206926adc8cec4ba16e88aed30c202d70c661)

## 💻 技术分析

### Rug Pull机制

**项目方后门**：

```solidity
contract R0AR {
    address owner;
    
    // 🚨 隐藏的提款函数
    function EmergencyWithdraw() external {
        // 复杂的时间和数学检查（伪装）
        if (block.timestamp >= T0) {
            if (complexCondition()) {
                // 🔥 将所有代币和LP转给owner
                token.transfer(owner, balance);
                lp.transfer(owner, lpBalance);
            }
        }
    }
}
```

### 攻击流程
```
1. 项目正常运营，吸引用户投资
2. 达到一定TVL后（$777k）
3. 项目方调用EmergencyWithdraw
4. 转走所有代币和LP代币
5. Rug pull完成
```

## 🎯 根本原因

**项目方恶意设计的后门函数**。通过复杂的条件检查来隐藏真实意图，等时机成熟后执行rug pull。

### 识别Rug Pull特征
1. ❌ 合约有owner特权
2. ❌ 存在紧急提款函数
3. ❌ 项目方可以转移用户资金
4. ❌ 代码审计缺失
5. ❌ 匿名团队

## 📝 总结

Roar是典型的Rug Pull案例，项目方通过隐藏的EmergencyWithdraw函数卷走$777k。

**教训**:
- ⚠️ 避免投资有owner特权的项目
- ⚠️ 查看合约是否有紧急提款功能
- ⚠️ 要求项目放弃ownership或使用时间锁

---
**报告生成**: 2025-10-12 | **版本**: 1.0

