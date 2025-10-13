# WXETA Hack 根因分析报告

## 📊 执行摘要
- **项目**: WXETA
- **日期**: 2024
- **网络**: BNB Chain (BSC)
- **损失**: ~$110K
- **类型**: 初始化/铸造权限缺陷 → 任意增发 + LP 抽干

## 💻 技术分析与根因
PoC 显示攻击合约直接调用 `initialize(type(uint256).max)` 与 `mint(PancakePair, 1e15 * 1e18)`，随后：
1) 读取 Pair 的稳定币余额 `balanceOf(PancakePair)`；
2) 直接调用 Pair 的 `swap(0, balPair-1e18, this, "")` 抽走稳定币；
3) 在路由上卖出换回 WBNB 并提现。

根本原因：
- `WXetaDiamond.initialize(uint256)` 未限制重复或恶意初始化，允许外部设置关键状态；
- `mint(address,uint256)` 缺少 `onlyOwner/onlyMinter` 等权限控制，任意地址可增发到 LP；
- 在增发到 LP 后立即通过 `swap` 抽走对资产的另一侧储备，形成套现。

## 🛠️ 修复建议
- 对 `initialize` 施加一次性保护（initializer 修饰器）并限制仅部署期可调用；
- `mint`/权限路径使用角色控制（Ownable/AccessControl）且加多签；
- 对 LP/AMM 合约地址禁止直接增发作为接收者；
- 增加事件与断路器，检测异常增发与 Pair 异常 `swap`。

---
**报告生成**: 2025-10-12 | **版本**: 1.0
