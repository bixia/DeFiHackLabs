# Cauldron V4 业务逻辑图

## 📊 系统架构概览

```mermaid
graph TB
    User[用户/攻击者] --> Cauldron[Cauldron V4 合约]
    Cauldron --> BentoBox[BentoBox 资金池]
    Cauldron --> Oracle[价格预言机]
    BentoBox --> MIM[MIM Token]
    BentoBox --> Collateral[抵押品 Token]
    
    style Cauldron fill:#f9f,stroke:#333,stroke-width:4px
    style BentoBox fill:#bbf,stroke:#333,stroke-width:2px
    style User fill:#bfb,stroke:#333,stroke-width:2px
```

## 🏗️ Cauldron核心组件

```mermaid
classDiagram
    class CauldronV4 {
        +IBentoBox bentoBox
        +IERC20 collateral
        +IERC20 magicInternetMoney
        +IOracle oracle
        +mapping userBorrowPart
        +mapping userCollateralShare
        +Rebase totalBorrow
        +BorrowCap borrowLimit
        +uint256 COLLATERIZATION_RATE
        +uint256 LIQUIDATION_MULTIPLIER
        +uint256 BORROW_OPENING_FEE
        
        +cook(actions, values, datas)
        +borrow(to, amount)
        +repay(to, skim, part)
        +addCollateral(to, skim, share)
        +removeCollateral(to, share)
        +liquidate(users, maxBorrowParts, to, swapper, data)
        +updateExchangeRate()
        +_isSolvent(user, exchangeRate)
        +_preBorrowAction(to, amount, newBorrowPart, part)
    }
    
    class BentoBox {
        +mapping balanceOf
        +mapping totals
        +transfer(token, from, to, share)
        +deposit(token, from, to, amount, share)
        +withdraw(token, from, to, amount, share)
        +toShare(token, amount, roundUp)
        +toAmount(token, share, roundUp)
    }
    
    class BorrowCap {
        +uint128 total
        +uint128 borrowPartPerAddress
    }
    
    CauldronV4 --> BentoBox : 使用
    CauldronV4 --> BorrowCap : 包含
```

## 🔄 Cook函数工作流程

```mermaid
flowchart TD
    Start[开始: cook调用] --> Loop{遍历actions数组}
    
    Loop -->|action < 10| Accrue[执行accrue利息累计]
    Accrue --> CheckAction{判断action类型}
    Loop -->|action >= 10| CheckAction
    
    CheckAction -->|ACTION_ADD_COLLATERAL=10| AddCol[添加抵押品]
    CheckAction -->|ACTION_REPAY=2| Repay[还款]
    CheckAction -->|ACTION_REMOVE_COLLATERAL=4| RemoveCol[移除抵押品]
    CheckAction -->|ACTION_BORROW=5| Borrow[借款]
    CheckAction -->|ACTION_BENTO_DEPOSIT=20| BentoDep[BentoBox存款]
    CheckAction -->|ACTION_BENTO_WITHDRAW=21| BentoWith[BentoBox取款]
    CheckAction -->|ACTION_CALL=30| Call[外部调用]
    CheckAction -->|ACTION_LIQUIDATE=31| Liq[清算]
    
    AddCol --> NextAction[继续下一个action]
    Repay --> NextAction
    RemoveCol --> SetCheck1[设置needsSolvencyCheck=true]
    Borrow --> SetCheck2[设置needsSolvencyCheck=true]
    BentoDep --> NextAction
    BentoWith --> NextAction
    Call --> NextAction
    Liq --> NextAction
    
    SetCheck1 --> NextAction
    SetCheck2 --> NextAction
    
    NextAction --> Loop
    Loop -->|完成所有actions| SolvencyCheck{needsSolvencyCheck?}
    
    SolvencyCheck -->|是| UpdateRate[更新汇率]
    UpdateRate --> CheckSolvent{_isSolvent检查}
    CheckSolvent -->|通过| End[执行成功]
    CheckSolvent -->|失败| Revert1[❌ Revert: user insolvent]
    
    SolvencyCheck -->|否| End
    
    style Start fill:#90EE90
    style End fill:#90EE90
    style Revert1 fill:#FF6B6B
    style Borrow fill:#FFD700
    style CheckSolvent fill:#FF6B6B
```

## 💰 借款流程详解 (ACTION_BORROW)

```mermaid
sequenceDiagram
    participant User as 用户/攻击者
    participant Cauldron as Cauldron合约
    participant BentoBox as BentoBox
    participant Oracle as 价格预言机
    
    User->>Cauldron: cook([5, 0], values, [amount|to, 0x])
    activate Cauldron
    
    Note over Cauldron: ACTION_BORROW = 5
    Cauldron->>Cauldron: accrue() 累计利息
    Cauldron->>Cauldron: _borrow(to, amount)
    
    rect rgb(255, 240, 240)
        Note over Cauldron: 关键检查点
        Cauldron->>Cauldron: 计算feeAmount (0.5%)
        Cauldron->>Cauldron: totalBorrow.add(amount + fee)
        
        Cauldron->>Cauldron: ✅ CHECK 1: totalBorrow <= cap.total
        alt 超过总限额
            Cauldron-->>User: ❌ Revert: Borrow Limit reached
        end
        
        Cauldron->>Cauldron: newBorrowPart = userBorrowPart + part
        Cauldron->>Cauldron: 🔴 CHECK 2: newBorrowPart <= cap.borrowPartPerAddress
        alt 超过每地址限额
            Cauldron-->>User: ❌ Revert: Borrow Limit reached
        end
        
        Cauldron->>Cauldron: 🔴 _preBorrowAction(to, amount, newBorrowPart, part)
        Note over Cauldron: ⚠️ 这是空函数！
    end
    
    Cauldron->>Cauldron: userBorrowPart[user] = newBorrowPart
    Cauldron->>BentoBox: toShare(MIM, amount, false)
    BentoBox-->>Cauldron: return share
    
    Cauldron->>BentoBox: transfer(MIM, Cauldron, User, share)
    activate BentoBox
    BentoBox->>BentoBox: balanceOf[MIM][Cauldron] -= share
    BentoBox->>BentoBox: balanceOf[MIM][User] += share
    BentoBox-->>Cauldron: Transfer完成
    deactivate BentoBox
    
    Cauldron->>Cauldron: emit LogBorrow(user, to, amount+fee, part)
    Cauldron->>Cauldron: status.needsSolvencyCheck = true
    
    Note over Cauldron: cook循环结束后...
    Cauldron->>Oracle: updateExchangeRate()
    Oracle-->>Cauldron: return exchangeRate
    
    rect rgb(255, 200, 200)
        Note over Cauldron: 🔥 最终Solvency检查
        Cauldron->>Cauldron: _isSolvent(user, exchangeRate)
        alt 抵押品不足
            Cauldron-->>User: ❌ Revert: user insolvent
        else 抵押品充足或检查被绕过
            Cauldron-->>User: ✅ 借款成功
        end
    end
    
    deactivate Cauldron
```

## 🔒 Solvency检查机制

```mermaid
flowchart TD
    Start[_isSolvent检查] --> GetBorrow[获取userBorrowPart]
    GetBorrow --> CheckBorrow{borrowPart == 0?}
    
    CheckBorrow -->|是| ReturnTrue1[✅ return true<br/>无借款=总是solvent]
    CheckBorrow -->|否| GetCollateral[获取userCollateralShare]
    
    GetCollateral --> CheckCollateral{collateralShare == 0?}
    CheckCollateral -->|是| ReturnFalse[❌ return false<br/>有借款无抵押=insolvent]
    CheckCollateral -->|否| CalcValues[计算抵押品价值和借款价值]
    
    CalcValues --> CalcCollateralValue["collateralValue = <br/>bentoBox.toAmount(collateral, <br/>collateralShare × COLLATERIZATION_RATE)"]
    
    CalcCollateralValue --> CalcBorrowValue["borrowValue = <br/>borrowPart × totalBorrow.elastic × exchangeRate <br/>/ totalBorrow.base"]
    
    CalcBorrowValue --> Compare{collateralValue <br/>>= borrowValue?}
    
    Compare -->|是| ReturnTrue2[✅ return true<br/>抵押品充足]
    Compare -->|否| ReturnFalse2[❌ return false<br/>抵押品不足]
    
    style ReturnTrue1 fill:#90EE90
    style ReturnTrue2 fill:#90EE90
    style ReturnFalse fill:#FF6B6B
    style ReturnFalse2 fill:#FF6B6B
    style Compare fill:#FFD700
```

## 🚨 攻击向量分析

```mermaid
flowchart TD
    Attacker[攻击者] --> Recon[侦查阶段]
    
    Recon --> Check1{借款限额是否过高?}
    Check1 -->|是| Check2{_preBorrowAction是否为空?}
    Check1 -->|否| NotVuln1[❌ 不易受攻击]
    
    Check2 -->|是| Check3{Solvency检查可绕过?}
    Check2 -->|否| NotVuln2[❌ 不易受攻击]
    
    Check3 -->|是| Vulnerable[✅ 发现漏洞!]
    Check3 -->|否| NotVuln3[❌ 不易受攻击]
    
    Vulnerable --> Deploy[部署攻击合约]
    Deploy --> PrepareCol[准备微量抵押品<br/>或无需抵押品]
    
    PrepareCol --> Attack[攻击执行]
    
    Attack --> Loop[遍历6个Cauldron]
    Loop --> CallCook["cook([5, 0], <br/>[amount|address(this), 0x])"]
    
    CallCook --> Pass1[✅ borrowPartPerAddress检查通过<br/>限额过高]
    Pass1 --> Pass2[✅ _preBorrowAction通过<br/>空函数]
    Pass2 --> Pass3[✅ _isSolvent通过<br/>微量抵押品或配置错误]
    
    Pass3 --> GetMIM[获得MIM share]
    GetMIM --> NextCauldron{还有更多Cauldron?}
    
    NextCauldron -->|是| Loop
    NextCauldron -->|否| Withdraw[从BentoBox提取所有MIM]
    
    Withdraw --> Swap1[MIM → 3CRV<br/>Curve]
    Swap1 --> Swap2[3CRV → USDT<br/>Curve 3Pool]
    Swap2 --> Swap3[USDT → WETH<br/>Uniswap V3]
    Swap3 --> Success[✅ 攻击成功!<br/>获利$1.7M]
    
    style Attacker fill:#FF6B6B
    style Vulnerable fill:#FFD700
    style Success fill:#FF6B6B
    style Pass1 fill:#FFD700
    style Pass2 fill:#FFD700
    style Pass3 fill:#FFD700
```

## 💸 还款流程 (ACTION_REPAY)

```mermaid
sequenceDiagram
    participant User as 正常用户
    participant Cauldron as Cauldron合约
    participant BentoBox as BentoBox
    
    User->>Cauldron: cook([2, ...], values, [part|to|skim, ...])
    activate Cauldron
    
    Note over Cauldron: ACTION_REPAY = 2
    Cauldron->>Cauldron: accrue() 累计利息
    Cauldron->>Cauldron: _repay(to, skim, part)
    
    rect rgb(240, 255, 240)
        Note over Cauldron: 还款逻辑
        Cauldron->>Cauldron: (totalBorrow, amount) = totalBorrow.sub(part, true)
        Cauldron->>Cauldron: userBorrowPart[to] -= part
        
        Cauldron->>BentoBox: toShare(MIM, amount, true)
        BentoBox-->>Cauldron: return share
        
        Note over Cauldron,BentoBox: 从用户转入MIM到Cauldron
        Cauldron->>BentoBox: transfer(MIM, skim?BentoBox:user, Cauldron, share)
        BentoBox->>BentoBox: balanceOf[MIM][from] -= share
        BentoBox->>BentoBox: balanceOf[MIM][Cauldron] += share
    end
    
    Cauldron->>Cauldron: emit LogRepay(from, to, amount, part)
    Cauldron-->>User: ✅ 还款成功
    
    deactivate Cauldron
    
    Note over User,Cauldron: ⚠️ 还款不触发needsSolvencyCheck
```

## 🏦 抵押品管理

```mermaid
flowchart LR
    subgraph 添加抵押品
        A1[用户] -->|ACTION_ADD_COLLATERAL| A2[addCollateral]
        A2 --> A3[BentoBox.transfer<br/>user → Cauldron]
        A3 --> A4[userCollateralShare增加]
    end
    
    subgraph 移除抵押品
        R1[用户] -->|ACTION_REMOVE_COLLATERAL| R2[_removeCollateral]
        R2 --> R3[userCollateralShare减少]
        R3 --> R4[BentoBox.transfer<br/>Cauldron → user]
        R4 --> R5[设置needsSolvencyCheck=true]
        R5 --> R6{_isSolvent检查}
        R6 -->|通过| R7[✅ 移除成功]
        R6 -->|失败| R8[❌ Revert]
    end
    
    style A4 fill:#90EE90
    style R7 fill:#90EE90
    style R8 fill:#FF6B6B
    style R5 fill:#FFD700
```

## ⚡ 清算流程

```mermaid
flowchart TD
    Start[清算开始] --> UpdateRate[updateExchangeRate]
    UpdateRate --> Accrue[accrue利息]
    Accrue --> LoopUsers[遍历待清算用户]
    
    LoopUsers --> CheckSolvent{_isSolvent检查}
    CheckSolvent -->|solvent| Skip[跳过该用户]
    CheckSolvent -->|insolvent| CalcLiq[计算清算金额]
    
    CalcLiq --> CalcBorrow[borrowAmount = totalBorrow.toElastic(borrowPart)]
    CalcBorrow --> CalcCollateral["collateralShare = <br/>borrowAmount × LIQUIDATION_MULTIPLIER × exchangeRate"]
    
    CalcCollateral --> UpdateState[更新状态]
    UpdateState --> SubBorrow[userBorrowPart减少]
    SubBorrow --> SubCollateral[userCollateralShare减少]
    
    SubCollateral --> TransferCol[转移抵押品给清算人]
    TransferCol --> EmitEvents[发出清算事件]
    
    EmitEvents --> NextUser{还有更多用户?}
    NextUser -->|是| LoopUsers
    NextUser -->|否| SwapIfNeeded{需要交换抵押品?}
    
    SwapIfNeeded -->|是| CallSwapper[调用Swapper合约]
    SwapIfNeeded -->|否| End[清算完成]
    CallSwapper --> End
    
    Skip --> NextUser
    
    style CheckSolvent fill:#FFD700
    style CalcCollateral fill:#FFB6C1
    style End fill:#90EE90
```

## 📊 BentoBox交互模式

```mermaid
flowchart TD
    subgraph BentoBox Share系统
        A[实际Token金额<br/>Amount] <-->|toShare/toAmount| B[BentoBox份额<br/>Share]
    end
    
    subgraph Cauldron操作BentoBox
        C1[存款] --> D1[deposit: Token → Share]
        C2[取款] --> D2[withdraw: Share → Token]
        C3[转账] --> D3[transfer: Share在账户间转移]
    end
    
    subgraph 余额管理
        E1[balanceOf mapping] --> E2[token → user → share]
        E3[totals mapping] --> E4[token → Rebase总量]
    end
    
    D1 --> E1
    D2 --> E1
    D3 --> E1
    
    style A fill:#FFD700
    style B fill:#87CEEB
```

## 🔐 关键安全检查点总结

```mermaid
mindmap
  root((Cauldron<br/>安全检查))
    借款限额检查
      总借款限额 total
      每地址限额 borrowPartPerAddress
      ::icon(fa fa-shield)
    Solvency检查
      抵押品充足性
      价格预言机准确性
      COLLATERIZATION_RATE配置
      ::icon(fa fa-balance-scale)
    前置检查Hook
      _preBorrowAction
        ⚠️ 当前为空函数
      _beforeUserLiquidated
      ::icon(fa fa-exclamation-triangle)
    BentoBox权限
      allowed modifier
      masterContract批准
      ::icon(fa fa-key)
    紧急机制
      暂停功能
      参数调整
      ::icon(fa fa-pause)
```

## 🎯 漏洞利用路径图

```mermaid
graph LR
    A[配置错误] --> D[漏洞组合]
    B[空函数] --> D
    C[检查可绕过] --> D
    
    D --> E[攻击者发现]
    E --> F[批量借款]
    F --> G[提取资金]
    G --> H[套现离场]
    
    style A fill:#FF6B6B
    style B fill:#FF6B6B
    style C fill:#FF6B6B
    style D fill:#8B0000,color:#fff
    style E fill:#FFD700
    style H fill:#FF6B6B
```

## 📈 正常vs攻击场景对比

```mermaid
flowchart TD
    subgraph 正常借款场景
        N1[用户存入抵押品<br/>150%抵押率] --> N2[调用borrow<br/>合理金额]
        N2 --> N3[✅ borrowPartPerAddress检查<br/>通过]
        N3 --> N4[✅ _preBorrowAction<br/>通过或为空]
        N4 --> N5[✅ _isSolvent检查<br/>150%抵押率通过]
        N5 --> N6[✅ 获得借款<br/>正常使用]
    end
    
    subgraph 攻击场景
        A1[攻击者无/微量抵押品<br/>0-10%抵押率] --> A2[调用cook with ACTION_BORROW<br/>最大金额]
        A2 --> A3[✅ borrowPartPerAddress检查<br/>配置过高-通过!]
        A3 --> A4[✅ _preBorrowAction<br/>空函数-通过!]
        A4 --> A5[✅ _isSolvent检查<br/>被绕过-通过!]
        A5 --> A6[✅ 窃取大量MIM<br/>$1.7M]
    end
    
    style N6 fill:#90EE90
    style A6 fill:#FF6B6B
    style A3 fill:#FFD700
    style A4 fill:#FFD700
    style A5 fill:#FFD700
```

---

## 📝 图表说明

### 使用的颜色代码
- 🟢 绿色: 正常流程/成功操作
- 🔴 红色: 错误/攻击/失败
- 🟡 黄色: 关键检查点/警告
- 🔵 蓝色: 系统组件
- 🟣 紫色: 核心合约

### 关键符号
- ✅ 检查通过
- ❌ 检查失败/Revert
- 🔴 高风险点
- ⚠️ 警告/注意事项
- 🔥 漏洞利用点

---

**文档版本**: 1.0  
**生成时间**: 2025-10-12  
**基于**: Cauldron V4 实际合约源代码分析

