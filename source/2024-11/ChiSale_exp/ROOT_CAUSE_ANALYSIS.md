# ChiSale Hack 根因分析报告

## 📊 执行摘要
- **项目**: ChiSale
- **日期**: 2024
- **网络**: Ethereum Mainnet
- **损失**: ~ $16.3K
- **类型**: 外部协议集成/费用处理逻辑缺陷（Balancer FlashLoan 费用处理）
- **级别**: 🟠 中

## 🎯 攻击概览
- **攻击者**: `0xEE4073183E07Aa0FC1B96D6308793840f02B6e88`
- **受害合约**: `0x050163597d9905ba66400f7b3ca8f2ef23df702d`
- **相关协议**: Balancer Vault `0xBA12222222228d8Ba445958a75a0704d566BF2C8`
- **攻击交易**: [`0x586a2a4368a1a45489a8a9b4273509b524b672c33e6c544d2682771b44f05e87`](https://app.blocksec.com/explorer/tx/eth/0x586a2a4368a1a45489a8a9b4273509b524b672c33e6c544d2682771b44f05e87)

## 💻 技术分析

PoC 展示了通过 Balancer Vault 发起 WETH 闪电贷的最小化复现：

```solidity
address private constant VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer
address private constant RECEIVER = 0x931b8905C310Ab133373f50ba66FEba2793F80eA; // 自定义回调接收者
address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

function flashLoan() public {
    address[] memory tokens = new address[](1);
    tokens[0] = WETH;
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 25_000 ether;
    bytes memory userData = "";

    (bool ok, ) = VAULT.call(
        abi.encodeWithSelector(
            IBalancerVaultLocal.flashLoan.selector,
            RECEIVER,
            tokens,
            amounts,
            userData
        )
    );
    require(ok, "flashLoan failed");
}
```

虽然该最小 PoC 未还原完整套利过程，但结合事件披露与仓库记录，核心问题在于：受害合约与外部协议（Balancer）的费用/回调处理不当，允许在闪电贷期间通过错误的费用计算或资金流转顺序获得可提走的余额差，从而造成实际损失。

关键风险点：
- 对 Balancer `receiveFlashLoan` 回调的资产流向与结算顺序缺乏严格校验；
- 未正确读取并应用 `ProtocolFeesCollector.getFlashLoanFeePercentage()`，导致费用不足或被他人代付；
- 可重入/重入样式的资金移动窗口存在，被利用以留存额外余额。

### 影响评估
- 直接损失约 $16.3K。
- 受害合约的资金安全依赖外部协议回调时序与费用结算的正确性。

## 🎯 根本原因
与外部协议（Balancer Vault）交互时，未对闪电贷费用、回调时序与资金结算进行完备的校验与原子性保障：
- 未以只读方式查询并验证当前费用比例，或未在同一事务内保证足额返还；
- 回调期间资金可被中间转移，结算时产生剩余；
- 缺少不变量与余额前后置检查（欠费/多余余额未被捕获）。

## 🛠️ 修复建议
短期：
- 与 Balancer 交互时，严格按官方接口在同一事务内计算并支付 `flashLoan` 费用；
- 在 `receiveFlashLoan` 回调中增加资金不变量检查：`beforeBalance + borrowed == afterBalance + fee + outputs`；
- 若非必要，不将回调委托给外部任意 `RECEIVER` 地址，避免复杂资金路径。

长期：
- 引入形式化的结算不变量与单元测试，覆盖“费用变化”“多资产贷款”“失败回滚”等场景；
- 使用已审计的闪电贷适配器封装，对各协议进行差异化处理；
- 在生产中启用运行时断言与事件审计，及时发现费用结算异常。

## 🔗 参考
- 受害合约：`0x050163597d9905ba66400f7b3ca8f2ef23df702d`
- Balancer Vault：`0xBA12222222228d8Ba445958a75a0704d566BF2C8`
- 攻击交易：`0x586a2a43...44f05e87`
- 信息来源：`https://x.com/TenArmorAlert/status/1854357930382156107`

---
**报告生成**: 2025-10-12 | **版本**: 1.1
