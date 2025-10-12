# AIRWA Hack 根因分析报告

## 📊 执行摘要
- **项目**: AIRWA Token
- **日期**: 2025-04-04
- **网络**: BSC
- **损失**: 56.73 BNB (~$33,600 USD)
- **类型**: 访问控制 - setBurnRate可被滥用
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0x70f0406e0a50c53304194b2668ec853d664a3d9c`
- 攻击合约: `0x2a011580f1b1533006967bd6dc63af7ae5c82363`
- 受害合约: AIRWA `0x3Af7DA38C9F68dF9549Ce1980eEf4AC6B635223A`
- 攻击TX: [`0x5cf050cba486ec48100d5e5ad716380660e8c984d80f73ba888415bb540851a4`](https://bscscan.com/tx/0x5cf050cba486ec48100d5e5ad716380660e8c984d80f73ba888415bb540851a4)

## 💻 技术分析

### 核心漏洞

**setBurnRate缺少访问控制**：

```solidity
contract AIRWA {
    uint256 public burnRate;
    
    // 🚨 任何人都可以设置burnRate
    function setBurnRate(uint256 _burnRate) external {
        burnRate = _burnRate;  // 0-1000 (0-100%)
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 burnAmount = (amount * burnRate) / 1000;
        
        if (burnAmount > 0) {
            _burn(msg.sender, burnAmount);
        }
        
        _transfer(msg.sender, to, amount - burnAmount);
        return true;
    }
}
```

### 攻击流程
```
1. 买入AIRWA（0.1 BNB worth）
2. 设置burnRate = 980 (98%燃烧率)
3. Transfer 0个代币到LP
   - 触发LP同步，但由于高burn rate破坏余额
4. 设置burnRate = 0 (关闭燃烧)
5. Swap AIRWA → WBNB
   - 由于LP余额被破坏，获得过多WBNB
6. 获利56.73 BNB
```

## 🎯 根本原因

setBurnRate没有访问控制，攻击者可以操纵burn rate破坏LP余额，然后以有利价格swap获利。

### 修复
```solidity
// ✅ 添加访问控制
function setBurnRate(uint256 _burnRate) external onlyOwner {
    require(_burnRate <= MAX_BURN_RATE, "Rate too high");
    burnRate = _burnRate;
}
```

## 📝 总结

AIRWA攻击利用setBurnRate无保护，操纵burn rate破坏LP后套利56.73 BNB。

**教训**: ⚠️ 影响代币经济的函数必须有访问控制

---
**报告生成**: 2025-10-12 | **版本**: 1.0

