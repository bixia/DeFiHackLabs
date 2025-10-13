# MFT Hack 根因分析报告

## 📊 执行摘要
- **项目**: MFT
- **日期**: 2024
- **网络**: BNB Chain (BSC)
- **损失**: ~ $33.7K
- **类型**: Fee-on-Transfer/销毁机制导致的 AMM 储备失真与价格操纵
- **级别**: 🔴 严重

## 🎯 攻击概览
- **攻击者**: `0x2BeE9915DDEFDC987A42275fbcC39ed178A70aAA`
- **攻击合约**: `0x6E088C3dD1055F5dD1660C1c64dE2af8110B85a8`
- **受害代币 (MFT)**: `0x29Ee4526e3A4078Ce37762Dc864424A089Ebba11`
- **LP Pair**: `0x67C88f71da4Ef48Ad4bEa9000264c9a17Ef2a7Aa`
- **攻击交易**: [`0xe24ee2af7ceee6d6fad1cacda26004adfe0f44d397a17d2aca56c9a01d759142`](https://bscscan.com/tx/0xe24ee2af7ceee6d6fad1cacda26004adfe0f44d397a17d2aca56c9a01d759142)

## 💻 技术分析

PoC 明确指出：

```solidity
// Root cause: MFT.transfer() will burn token from the pool when user trys to sell token.
```

结合 PoC 步骤：
1. 多池 PancakeV3 闪电贷放大资金规模；
2. 多次向 LP `CAKE_LP` 发起 `transferFrom` 以触发 MFT 的特殊 transfer 逻辑（对向池子的转账触发销毁/扣减）；
3. `skim(PLEDGE_ADDR)` 将池内多余余额抽离至指定地址；
4. 以 SupportingFeeOnTransfer 的路径大额买入 MFT，进一步降低池内 MFT 余额；
5. 计算期望卖出回报后，直接在 Pair 上触发 `swap` 卖出，因销毁机制导致储备与价格计算失真，池子被抽干；
6. 归还各笔闪电贷并获利。

核心技术要点：
- 对 LP 的转账被当作“卖出”处理，并在 `transfer` 内部执行销毁/扣费，改变了池子的实际余额但未被定价逻辑即时感知；
- `skim` 进一步抽离“池子认为的多余余额”，为后续价格操纵创造空间；
- SupportingFeeOnTransfer 交换与直接对 Pair 的 `swap` 配合，使得在储备失真条件下完成高回报卖出。

### 影响评估
- 直接损失约 $33.7K（以 PoC 注释统计为准）。
- 风险扩散：任意具备“对 LP 转账即销毁/扣费”的代币均可能触发类似储备失真问题。

## 🎯 根本原因
代币 `transfer` 在“向 LP 合约地址转账”时触发销毁/扣费，导致：
- AMM 储备变量与真实余额失配，破坏恒等式 \(x \times y = k\)；
- `skim` 可抽离由销毁/扣费引入的“幽灵余额”，进一步放大不一致；
- 路由与 Pair 在 SupportingFeeOnTransfer 与直接 `swap` 的组合下未感知上述不变量破坏。

## 🛠️ 修复建议
短期：
- 对 LP 地址进行手续费/销毁豁免，禁止在向池子转账时执行销毁逻辑；
- 禁用或限制 `skim` 的使用，或在销毁逻辑存在时禁止调用；
- 对路由调用设置严格最小成交量（非 0）与频次限制。

长期：
- 对具备 FOT/销毁逻辑的代币进行专项安全审计与仿真测试；
- 引入价格保护（TWAP/Oracle）与反操纵机制；
- 明确区分 EOA 与 AMM 合约的转账路径处理，避免对储备产生隐式副作用。

## 🔗 参考
- 代币合约：`0x29Ee4526e3A4078Ce37762Dc864424A089Ebba11`
- LP：`0x67C88f71da4Ef48Ad4bEa9000264c9a17Ef2a7Aa`
- 攻击交易：`0xe24ee2af...759142`
- 信息来源：`https://x.com/TenArmorAlert/status/1858351609371406617`

---
**报告生成**: 2025-10-12 | **版本**: 1.1
