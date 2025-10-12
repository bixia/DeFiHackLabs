# SuperRare Hack 根因分析报告

## 📊 执行摘要
- **项目**: SuperRare  
- **日期**: 2025-07-28
- **网络**: Ethereum
- **损失**: $730,000 USD
- **类型**: 访问控制缺陷
- **级别**: 🔴 严重

## 🎯 攻击概览
- 攻击者: `0x5b9b4b4dafbcfceea7afba56958fcbb37d82d4a2`
- 攻击合约: `0x08947cedf35f9669012bda6fda9d03c399b017ab`
- 受害合约: Staking Contract `0x3f4D749675B3e48bCCd932033808a7079328Eb48`
- 攻击TX: [`0xd813751bfb98a51912b8394b5856ae4515be6a9c6e5583e06b41d9255ba6e3c1`](https://app.blocksec.com/explorer/tx/eth/0xd813751bfb98a51912b8394b5856ae4515be6a9c6e5583e06b41d9255ba6e3c1)
- Post-mortem: https://blog.solidityscan.com/superrare-hack-analysis-488d544d89e0

## 💻 技术分析

### 核心漏洞

**updateMerkleRoot缺少访问控制**：

```solidity
// 🚨 任何人都可以更新Merkle root
function updateMerkleRoot(bytes32 newRoot) external {
    // ❌ 没有onlyOwner检查
    merkleRoot = newRoot;
}

function claim(uint256 amount, bytes32[] calldata proof) external {
    // 验证Merkle proof
    require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
    
    // 转移RARE代币
    RARE.transfer(msg.sender, amount);
}
```

### 攻击流程
```
1. 调用updateMerkleRoot(攻击者控制的root)
2. 使用伪造的proof调用claim(全部余额, proof)
3. 窃取所有质押的RARE代币（730k USD）
```

## 🎯 根本原因

Merkle airdrop/claim系统的root更新函数缺少访问控制，攻击者可以设置任意root然后claim所有资金。

### 修复
```solidity
function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
    // 添加权限检查
    merkleRoot = newRoot;
}
```

## 📝 总结

SuperRare攻击利用updateMerkleRoot无保护，设置恶意root后claim所有质押资金，损失$730k。

**教训**: ⚠️ Merkle root更新必须有严格的访问控制

---
**报告生成**: 2025-10-12 | **版本**: 1.0

