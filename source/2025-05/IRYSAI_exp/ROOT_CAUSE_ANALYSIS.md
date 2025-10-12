# IRYSAI Hack 根因分析报告

## 📊 执行摘要
- **项目**: IRYSAI Token
- **日期**: 2025-05-20
- **网络**: BSC
- **损失**: $69,600 USD
- **类型**: Rug Pull - setTaxWallet后门
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者1 (设置): `0xc4cE1E4A8Cd2Ba980646e855817252C7AA9C4AE8`
- 攻击者2 (执行): `0x20bB82f7C5069c2588fa900eD438FEFD2Ae36827`
- 代币合约: IRYSAI `0x746727FC8212ED49510a2cB81ab0486Ee6954444`
- Backdoor TX: [`0x8c637fc98ad84b922e6301c0b697167963eee53bbdc19665f5d122ae55234ca6`](https://bscscan.com/tx/0x8c637fc98ad84b922e6301c0b697167963eee53bbdc19665f5d122ae55234ca6)
- Rugpull TX: [`0xe9a66bad8975f2a7b68c74992054c84d6d80ac4c543352e23bf23740b8858645`](https://bscscan.com/tx/0xe9a66bad8975f2a7b68c74992054c84d6d80ac4c543352e23bf23740b8858645)

## 💻 技术分析

### 后门机制

```solidity
contract IRYSAI {
    address public taxWallet;
    
    // 🚨 项目方可随时更改taxWallet
    function setTaxWallet(address newWallet) external onlyOwner {
        taxWallet = newWallet;
    }
}
```

### Rug Pull流程
```
TX1 (设置后门): setTaxWallet(攻击合约)
TX2 (执行):
1. 攻击合约的burn()被调用
2. 将LP中的所有IRYSAI代币转到taxWallet
3. Swap IRYSAI → WBNB
4. 项目方获得69.6k USD
```

## 🎯 根本原因

项目方保留owner权限，可以随时通过setTaxWallet更改税收接收地址，然后通过各种机制将LP中的资金转走。

## 📝 总结

IRYSAI是典型的rug pull，项目方通过setTaxWallet后门卷走$69.6k。

**教训**: ⚠️ 避免投资owner有特权的项目

---
**报告生成**: 2025-10-12 | **版本**: 1.0

