# IdolsNFT Hack 根因分析报告

## 📊 执行摘要
- **项目**: IdolsNFT
- **日期**: 2025-01-14
- **网络**: Ethereum
- **损失**: 97 stETH (~$330,000)
- **类型**: 逻辑缺陷 - 自我转账奖励漏洞
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0xe546480138d50bb841b204691c39cc514858d101`
- 攻击合约: `0x22d22134612c0741ebdb3b74a58842d6e74e3b16`
- 受害合约: IdolsNFT `0x439cac149b935ae1d726569800972e1669d17094`
- 攻击TX: [`0x5e989304b1fb61ea0652db4d0f9476b8882f27191c1f1d2841f8977cb8c5284c`](https://etherscan.io/tx/0x5e989304b1fb61ea0652db4d0f9476b8882f27191c1f1d2841f8977cb8c5284c)
- Post-mortem: https://rekt.news/theidolsnft-rekt

## 💻 技术分析

### 核心漏洞

**safeTransferFrom的奖励机制漏洞**：

```solidity
contract IdolsNFT is ERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        // 🚨 问题：转账时发放奖励
        _distributeRewards(from);   // 给sender奖励
        _distributeRewards(to);     // 给receiver奖励
        
        // 执行NFT转移
        super.safeTransferFrom(from, to, tokenId);
    }
    
    function _distributeRewards(address user) internal {
        uint256 reward = rewardPerGod;
        allocatedStethRewards -= reward;
        stETH.transfer(user, reward);
    }
}
```

**致命缺陷**：
- 当from == to（自我转账）时
- 同一个地址获得两次奖励
- 但NFT实际上没有转移

### 攻击流程

```
准备：
1. 预计算攻击合约地址
2. 提前转NFT到该地址

攻击（在constructor中执行）：
1. 循环2000次：
   - safeTransferFrom(this, this, tokenId)
   - 每次获得2倍奖励（作为sender和receiver）
   - NFT始终在攻击合约中
2. 直到stETH奖励池耗尽
3. 转移所有stETH和NFT回攻击者
4. selfdestruct合约

重复：攻击者重复此过程15次
总获利：97 stETH
```

**绕过isContract检查**：
```solidity
// 在constructor中执行，此时isContract()返回false
constructor() {
    // 此时address(this).code.length == 0
    // 可以绕过任何isContract检查
    for (...) {
        safeTransferFrom(address(this), address(this), TOKEN_ID);
    }
}
```

## 🎯 根本原因

### 为什么导致Hack？

**逻辑缺陷**：
```solidity
// ❌ 错误：自我转账也发放双倍奖励
function safeTransferFrom(address from, address to, uint256 tokenId) {
    _distributeRewards(from);
    _distributeRewards(to);
    super.safeTransferFrom(from, to, tokenId);
}

// ✅ 正确：检查是否自我转账
function safeTransferFrom(address from, address to, uint256 tokenId) {
    require(from != to, "Cannot transfer to self");
    _distributeRewards(from);
    _distributeRewards(to);
    super.safeTransferFrom(from, to, tokenId);
}
```

### 修复建议
1. **禁止自我转账**: `require(from != to)`
2. **奖励不重复**: 只给真正的接收者奖励
3. **限制频率**: 添加冷却期

## 📝 总结

IdolsNFT攻击利用NFT转账奖励机制的自我转账漏洞，在constructor中循环自我转账获得双倍奖励，重复15次共窃取97 stETH。

**教训**: 
- ⚠️ 转账奖励机制必须防止自我转账滥用
- ⚠️ Constructor执行可绕过isContract检查
- ⚠️ 添加from != to检查

---
**报告生成**: 2025-10-12 | **版本**: 1.0

