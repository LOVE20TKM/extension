# LOVE20 Extension 混入（Mixin）架构文档

## 📖 概述

本目录包含了一套基于 Mixin（混入）模式的 LOVE20 扩展合约架构。采用 mixin 你可以通过组合独立、可复用的模块来实现功能，而不必依赖繁琐的深层继承链。

## 🏗️ 架构优势

### 之前（深继承）

```
Base → AutoScore → Join/Stake
```

- 耦合度高
- 自定义难度大
- 组合不灵活

### 现在（Mixin 组合）

```
Core + Account + Reward + Verification + Score + Join/Stake
```

- 耦合度低
- 易于自定义
- 组合灵活
- 单一职责原则

## 🧩 可用的 Mixin 列表

### 1. **ExtensionCoreMixin**

所有扩展的核心功能。

**提供：**

- 工厂和中心合约引用
- 各协议合约接口（Launch, Stake, Submit, Vote, Join, Verify, Mint, Random）
- 基础初始化
- 访问控制（onlyCenter 修饰器）

**使用场景：** 必选，所有扩展的基础

```solidity
contract MyExtension is ExtensionCoreMixin {
    constructor(address factory_) ExtensionCoreMixin(factory_) {}
}
```

---

### 2. **ExtensionAccountMixin**

账户管理功能。

**提供：**

- 参与者账号列表的存储与管理
- 添加/移除账号
- 查询功能（accounts, accountsCount, accountAtIndex）

**使用场景：** 需要追踪参与者的扩展

```solidity
contract MyExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin
{
    function someFunction() {
        _addAccount(msg.sender);  // 内部辅助函数
    }
}
```

---

### 3. **ExtensionRewardMixin**

奖励分配系统。

**提供：**

- 按轮次存储奖励
- 奖励领取功能
- 抽象奖励计算钩子

**使用场景：** 需要分配奖励的扩展

**必须实现：**

```solidity
function rewardByAccount(uint256 round, address account)
    public view virtual returns (uint256 reward, bool isMinted);
```

---

### 4. **ExtensionVerificationMixin**

验证信息管理。

**提供：**

- 按轮次存储验证信息
- 更新和查询接口
- 历史验证数据记录

**使用场景：** 需要用户验证信息的扩展

```solidity
contract MyExtension is
    ExtensionCoreMixin,
    ExtensionVerificationMixin
{
    function myFunction(string[] memory infos) {
        updateVerificationInfo(infos);
    }
}
```

---

### 5. **ExtensionScoreMixin**

基于分数的奖励计算。

**提供：**

- 分数的存储和管理
- 基于分数的奖励分配
- 自动化生成验证结果

**依赖：**

- ExtensionCoreMixin
- ExtensionAccountMixin
- ExtensionRewardMixin

**必须实现：**

```solidity
function calculateScores()
    public view virtual
    returns (uint256 total, uint256[] memory scores);

function calculateScore(address account)
    public view virtual
    returns (uint256 total, uint256 score);
```

**使用场景：** 如果你的扩展需要基于分数的奖励逻辑

---

### 6. **ExtensionJoinMixin**

基于区块等待的加入/退出功能。

**提供：**

- 按金额加入
- 等待指定区块后可退出
- 最低治理票数检查
- 加入信息追踪

**依赖：**

- ExtensionCoreMixin
- ExtensionAccountMixin
- ExtensionVerificationMixin

**参数：**

- `joinTokenAddress`: 可加入的代币
- `waitingBlocks`: 提现需等待的区块数
- `minGovVotes`: 加入需满足的最低治理票数

**使用场景：** 需要加入机制的扩展

---

### 7. **ExtensionStakeMixin**

基于阶段等待的质押/解押/提款功能。

**提供：**

- 按金额质押
- 解押请求
- 等待指定阶段后可提款
- 最低治理票数检查
- 质押信息追踪

**依赖：**

- ExtensionCoreMixin
- ExtensionAccountMixin
- ExtensionVerificationMixin

**参数：**

- `stakeTokenAddress`: 可质押的代币
- `waitingPhases`: 提款需等待的阶段数
- `minGovVotes`: 质押需满足的最低治理票数

**使用场景：** 需要质押功能的扩展

---

## 📚 用法示例

### 示例 1：支持加入功能的扩展

```solidity
contract MyJoinExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionJoinMixin
{
    constructor(
        address factory_,
        address joinTokenAddress_,
        uint256 waitingBlocks_,
        uint256 minGovVotes_
    )
        ExtensionCoreMixin(factory_)
        ExtensionJoinMixin(
            factory_,
            joinTokenAddress_,
            waitingBlocks_,
            minGovVotes_
        )
    {}

    // 实现分数计算
    function calculateScores()
        public view override
        returns (uint256 total, uint256[] memory scores)
    {
        scores = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            scores[i] = _joinInfo[_accounts[i]].amount;
            total += scores[i];
        }
    }

    function calculateScore(address account)
        public view override
        returns (uint256 total, uint256 score)
    {
        (total, ) = calculateScores();
        score = _joinInfo[account].amount;
    }
}
```

### 示例 2：支持质押功能的扩展

```solidity
contract MyStakeExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionStakeMixin
{
    constructor(
        address factory_,
        address stakeTokenAddress_,
        uint256 waitingPhases_,
        uint256 minGovVotes_
    )
        ExtensionCoreMixin(factory_)
        ExtensionStakeMixin(
            factory_,
            stakeTokenAddress_,
            waitingPhases_,
            minGovVotes_
        )
    {}

    // 实现分数计算
    function calculateScores()
        public view override
        returns (uint256 total, uint256[] memory scores)
    {
        scores = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            scores[i] = _stakeInfo[_accounts[i]].amount;
            total += scores[i];
        }
    }

    function calculateScore(address account)
        public view override
        returns (uint256 total, uint256 score)
    {
        (total, ) = calculateScores();
        score = _stakeInfo[account].amount;
    }
}
```

### 示例 3：自定义计分逻辑

```solidity
contract MyCustomExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionJoinMixin
{
    // ... constructor ...

    // 自定义计分：取加入金额的平方根作为分数
    function calculateScores()
        public view override
        returns (uint256 total, uint256[] memory scores)
    {
        scores = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            uint256 amount = _joinInfo[_accounts[i]].amount;
            scores[i] = sqrt(amount);  // 自定义逻辑
            total += scores[i];
        }
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        // ... 实现平方根函数 ...
    }
}
```

## 🎯 Mixin 选择导航

**需要基础扩展功能？**  
→ `CoreMixin` + `AccountMixin` + `RewardMixin`

**需要加入功能？**  
→ 增加 `VerificationMixin` + `JoinMixin`

**需要质押功能？**  
→ 增加 `VerificationMixin` + `StakeMixin`

**需要基于分数的奖励？**  
→ 增加 `ScoreMixin`（实现奖励分配）

**需要自定义奖励逻辑？**  
→ 只用 `RewardMixin` 并实现 `rewardByAccount()`

## 🔧 如何创建自定义 Mixin

你可以按照以下原则编写自己的 mixin：

1. **单一职责**：每个 mixin 只做好一件事
2. **可组合性**：mixin 间可自由组合且不冲突
3. **最小化依赖**：只依赖必要的其它 mixin
4. **清晰接口**：同时暴露内部辅助和对外方法

```solidity
abstract contract MyCustomMixin is ExtensionCoreMixin {
    // 状态变量
    mapping(address => uint256) internal _myData;

    // 事件
    event MyEvent(address indexed account, uint256 value);

    // 外部接口
    function myPublicFunction() external {
        _myInternalLogic();
    }

    // 内部辅助（供组合用）
    function _myInternalLogic() internal {
        _myData[msg.sender] = block.timestamp;
        emit MyEvent(msg.sender, block.timestamp);
    }
}
```

## 📋 与原始设计对比

| 项目         | 原始架构 | Mixin 架构            |
| ------------ | -------- | --------------------- |
| **继承深度** | 3 层     | 1 层（扁平）          |
| **复用性**   | 较低     | 较高                  |
| **定制性**   | 困难     | 容易                  |
| **测试难度** | 复杂     | 简单（按 mixin 测试） |
| **代码重复** | 可能较多 | 极低                  |
| **灵活性**   | 低       | 高                    |

## 🚀 迁移指南

### 从 Base/AutoScore/Join 模式迁移到 Mixin

**改造前：**

```solidity
contract MyExtension is LOVE20ExtensionAutoScoreJoin {
    constructor(...) LOVE20ExtensionAutoScoreJoin(...) {}
    // 功能定制受限
}
```

**改造后：**

```solidity
contract MyExtension is
    ExtensionCoreMixin,
    ExtensionAccountMixin,
    ExtensionRewardMixin,
    ExtensionVerificationMixin,
    ExtensionScoreMixin,
    ExtensionJoinMixin
{
    constructor(...)
        ExtensionCoreMixin(factory_)
        ExtensionJoinMixin(factory_, token_, blocks_, votes_)
    {}

    // 完全开放定制——可随意重写函数
    function calculateScores() public view override returns (...) {
        // 你的自定义逻辑
    }
}
```

## 💡 最佳实践

1. **一定要先继承 CoreMixin** ——一切的基础
2. **尽早加上 AccountMixin** ——大多数扩展都需要参与者追踪
3. **二选一：Join 或 Stake** ——除非确有必要，否则别混用
4. **用 ScoreMixin 实现按分数分配** ——或者自行实现分配逻辑
5. **重写时小心** ——必要时调用父类实现
6. **单独测试每个 mixin** ——调试更高效
7. **写清文档注释你的组合** ——说明为何选择各个 mixin

## 🐛 常见问题排查

### 问题：构造函数冲突

```solidity
// ❌ 错误（缺少 CoreMixin 构造参数）
contract Bad is ExtensionCoreMixin, ExtensionJoinMixin {
    constructor() {}  // 缺少 factory_ 参数!
}

// ✅ 正确
contract Good is ExtensionCoreMixin, ExtensionJoinMixin {
    constructor(address factory_, ...)
        ExtensionCoreMixin(factory_)
        ExtensionJoinMixin(factory_, ...)
    {}
}
```

### 问题：缺少实现

```solidity
// ❌ 错误（缺少必要实现）
contract Bad is ExtensionScoreMixin {
    // 没有实现 calculateScores() 和 calculateScore()
}

// ✅ 正确
contract Good is ExtensionScoreMixin {
    function calculateScores() public view override returns (...) {
        // 实现
    }
    function calculateScore(address) public view override returns (...) {
        // 实现
    }
}
```

### 问题：存储变量名冲突

```solidity
// ❌ 错误（变量名重复）
contract Bad is ExtensionAccountMixin {
    address[] internal _accounts;  // AccountMixin 已有同名变量!
}

// ✅ 正确
contract Good is ExtensionAccountMixin {
    address[] internal _myCustomAccounts;  // 自定义名称
}
```

## 📖 深入阅读

- [Solidity 官方文档 - 多重继承](https://docs.soliditylang.org/zh/latest/contracts.html#multiple-inheritance-and-linearization)
- [OpenZeppelin - 权限管理](https://docs.openzeppelin.com/contracts/4.x/access-control)
- [Solidity 设计模式](https://fravoll.github.io/solidity-patterns/)

---

## ✨ 总结

Mixin 架构带来了：

- ✅ **模块化**：按需选择功能模块
- ✅ **灵活性**：高自由度组合与拓展
- ✅ **易维护**：每个混入可独立测试
- ✅ **高复用**：组合多样
- ✅ **结构清晰**：每个 mixin 单一职责

现在就根据你的需求选择 Mixin，构建专属的自定义扩展吧！
