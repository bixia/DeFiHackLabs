# NFTG Hack 根因分析报告

## 📊 执行摘要
- **项目**: NFTG
- **日期**: 2024
- **网络**: BNB Chain (BSC)
- **损失**: ~ $10K
- **类型**: 外部合约调用时序/额度控制缺陷（闪电贷窗口内重复提取）
- **级别**: 🟠 中

## 🎯 攻击概览
- **攻击者**: `0x5af00B07a55F55775e4d99249DC7d81F5bc14c22`
- **攻击合约**: `0x6deF9e4a6bb9C3bfE0648A11D3FfF14447079e78`
- **受害合约**: `0x5fbBb391d54f4FB1d1CF18310c93d400BC80042E`
- **攻击交易**: [`0xbd330fd17d0f825042474843a223547132a49abb0746a7e762a0b15cf4bd28f6`](https://bscscan.com/tx/0xbd330fd17d0f825042474843a223547132a49abb0746a7e762a0b15cf4bd28f6)

## 💻 技术分析

PoC 通过 Dodo 风格的 `DPP.flashLoan` 借入 USDT，在回调 `DPPFlashLoanCall` 中多次与目标合约交互，利用其“在转入后立即可按时间/配额计算提取”的缺陷获取超额 USDT：

```solidity
function DPPFlashLoanCall(...) external {
    for (uint256 idx = 0; idx < 11; idx++) {
        IBEP20USDT(BEP20USDT).transfer(addr1, (idx * 1e13) + (11 * 1e13));
        (bool s, ) = addr1.call(abi.encodeWithSelector(bytes4(0x85d07203), 2125 * 1e13 * 3600, address(this)));
        require(s, "call failed");
    }
    IBEP20USDT(BEP20USDT).transfer(DPP, 8255555 * 1e14); // 归还闪电贷
    uint256 bal = IBEP20USDT(BEP20USDT).balanceOf(address(this));
    IBEP20USDT(BEP20USDT).transfer(attacker, bal);
}
```

关键信息：
- 目标合约在收到逐步增量的 USDT 后，立刻允许按某个“时间系数/额度”接口（选择器 `0x85d07203`）提取资金；
- 缺少“单用户/单周期额度上限”与“全局可提余额上限”的强约束，导致回调内循环多次提取；
- 由于处于同一交易上下文（闪电贷窗口），外部状态尚未稳定，配额校验缺失造成超额可得。

### 影响评估
- 直接损失约 $10K；
- 风险在于配额/时间权重的计算与扣减未绑定到交易结束或全局结算周期。

## 🎯 根本原因
外部资金注入与额度/时间系数提取之间缺少原子性与不变量约束：
- 未在单交易内限制重复提取（循环内多次成功）；
- 未对调用者累计额度与全局余额进行严格上限扣减；
- 允许在闪电贷回调期间进行结算提取，导致瞬时资金错配被套利。

## 🛠️ 修复建议
短期：
- 将“可提额度计算”与“资金实际转出”拆分为两个阶段，并引入提交-结算周期；
- 为接口 `0x85d07203` 增加调用频率限制、单用户周期上限、全局上限；
- 在闪电贷回调上下文中拒绝执行结算类接口（require 非回调上下文）。

长期：
- 使用时间滑窗/冷却时间与强一致的会计模型（可提额度以快照扣减）；
- 引入多签/角色授权控制重要结算路径；
- 补充单元测试覆盖“回调内循环多次调用”的情景。

## 🔗 参考
- 受害合约：`0x5fbBb391d54f4FB1d1CF18310c93d400BC80042E`
- 攻击合约：`0x6deF9e4a6bb9C3bfE0648A11D3FfF14447079e78`
- 攻击交易：`0xbd330fd1...bd28f6`
- 信息来源：`https://x.com/TenArmorAlert/status/1861430745572745245`

---
**报告生成**: 2025-10-12 | **版本**: 1.1
