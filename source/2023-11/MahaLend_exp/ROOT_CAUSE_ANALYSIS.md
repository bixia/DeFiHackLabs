# MahaLend Hack 根因分析 (2023-11)

## 执行摘要
- 事件类型: 指数累计/会计逻辑被操纵 → 通胀铸币 → 资金抽干
- 直接原因: 用可被操纵的分母累计 liquidityIndex，结合舍入规则放大铸币
- 影响: 约 ~$20K（快照时点），可扩展为更大损失

## 技术根因
- 索引累计分母选择错误（可被做小）
  - 闪电贷 premium / 回填 fee 分摊路径：
```4380:4392:/Users/samacrush/Downloads/DeFiHackLabs/source/2023-11/MahaLend_exp/MahaLend_impl_0xfd11aba71c06061f446ade4eec057179f19c23c4.sol
function cumulateToLiquidityIndex(
  DataTypes.ReserveData storage reserve,
  uint256 totalLiquidity,
  uint256 amount
) internal returns (uint256) {
  // ((amount / totalLiquidity) + 1) * liquidityIndex
  uint256 result = (amount.wadToRay().rayDiv(totalLiquidity.wadToRay()) + WadRayMath.RAY).rayMul(
    reserve.liquidityIndex
  );
  reserve.liquidityIndex = result.toUint128();
  return result;
}
```
  - 调用处分母取自 aToken totalSupply：
```7418:7421:/Users/samacrush/Downloads/DeFiHackLabs/source/2023-11/MahaLend_exp/MahaLend_impl_0xfd11aba71c06061f446ade4eec057179f19c23c4.sol
reserveCache.nextLiquidityIndex = reserve.cumulateToLiquidityIndex(
  IERC20(reserveCache.aTokenAddress).totalSupply(),
  premiumToLP
);
```
```5875:5878:/Users/samacrush/Downloads/DeFiHackLabs/source/2023-11/MahaLend_exp/MahaLend_impl_0xfd11aba71c06061f446ade4eec057179f19c23c4.sol
reserveCache.nextLiquidityIndex = reserve.cumulateToLiquidityIndex(
  IERC20(reserveCache.aTokenAddress).totalSupply(),
  feeToLP
);
```
  - 先捐赠底层资产抬高余额，再把 totalSupply 压到≈1，可把每笔 premium 放大到极端倍数。

- 舍入规则放大（≥0.5 向上取整）
```1419:1420:/Users/samacrush/Downloads/DeFiHackLabs/source/2023-11/MahaLend_exp/MahaLend_impl_0xfd11aba71c06061f446ade4eec057179f19c23c4.sol
* @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
```
  - 指数极大时，极小 supply 也会被向上取整铸出 ≥1 份额，循环铸币抽干底层。

## 攻击流程（对应 PoC）
1) 向 aToken 合约捐赠 USDC，抬高底层余额
2) 立即 withdraw 大额，使 aToken.totalSupply ≈ 1
3) 重复闪电贷 ~55 次，premium 全部分摊至 LP，指数暴涨
4) 多次小额 supply，借助 0.5 向上取整反复铸出份额
5) withdraw 抽走全部底层，并借出可用资产套利

## 修复建议
- 用“真实总流动性”作为分母
  - 采用底层资产总额或 scaledTotalSupply×index，禁止使用易被操纵的 totalSupply
- 中和外部捐赠
  - 无铸币的外部注入应入库或单独记账，不直接提升 index
- 舍入与最小份额
  - 改为向下取整；设定最小供给/最小份额阈值
- 保护阈值与速率限制
  - 对单笔/短时指数跳变设置上限与冷却；分母过小触发暂停/切换估值

## 参考
- 代码引用如上
- 攻击交易与 PoC：见 `MahaLend_exp.sol`

