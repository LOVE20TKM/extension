# LOVE20 行动扩展协议之自动计分代币参与基类合约（LOVE20ExtensionBaseTokenJoinAuto）

## 0. 关于 LOVE20ExtensionBaseTokenJoinAuto

`LOVE20ExtensionBaseTokenJoinAuto` 在 `LOVE20ExtensionBaseTokenJoin` 的基础上，进一步提供**自动计分（Auto Score）与按分数分配奖励**的模板能力：

- 在关键交互点自动生成当前轮次的验证结果（score 快照）
- 将该轮次参与者集合与分数存档（snapshot）
- 在领取奖励时使用已存档的分数进行比例分配

该基类是抽象模板，继承者必须实现具体的计分逻辑：

- `calculateScores()`
- `calculateScore(account)`

## 1. 核心优势

### 1.1 自动生成分数快照

在用户关键操作前自动触发一次“本轮验证结果生成”，避免依赖额外的管理员调用。

### 1.2 分数可追溯、可查询

每轮生成后会：

- 存档参与者地址数组（accounts snapshot）
- 存档分数数组（scores snapshot）
- 存入 `totalScore` 与 `scoreByAccount`

并发出 `SnapshotCreate(tokenAddress, round, actionId)` 事件。

### 1.3 奖励分配确定性

领取历史轮次奖励时，使用该轮次已生成的快照分数进行比例计算，避免对未来状态的依赖。

## 2. 初始参数

### 2.1 工厂地址（factory）

用于定位 ExtensionCenter 与核心合约地址。

### 2.2 代币地址（tokenAddress）

该扩展所属的 LOVE20 token 地址。

### 2.3 参与代币地址（joinTokenAddress）

用户参与时转入/退出时返还的 ERC20 代币地址。

### 2.4 等待区块数（waitingBlocks）

用户从最近一次 `join` 的区块高度开始，需要等待至少 `waitingBlocks` 个区块后才能 `exit()`。

## 3. 参与者

### 3.1 代币参与（join）

在执行 `join(amount, verificationInfos)` 前，会先尝试为**当前轮次**生成一次分数快照。

### 3.2 代币退出（exit）

在执行 `exit()` 前，会先尝试为**当前轮次**生成一次分数快照。

### 3.3 领取奖励（claimReward）

在执行 `claimReward(round)` 前，会先尝试为**当前轮次**生成一次分数快照；实际可领取的轮次仍必须满足 `round < verify.currentRound()`。

## 4. 验证结果（分数快照）生成规则

### 4.1 生成时机

当发生以下交互之一时，会触发 `_prepareVerifyResultIfNeeded()`：

- `join`
- `exit`
- `claimReward`

### 4.2 一轮只生成一次

每个轮次只会生成一次；若该轮次已生成，则直接跳过。

### 4.3 快照内容

生成时会写入：

- `totalScore[round]`
- `scores[round]`（分数数组）
- `accountsByRound[round]`（参与者数组快照）
- `scoreByAccount[round][account]`（分数映射）

参与者集合来自 ExtensionCenter：`center.accounts(tokenAddress, actionId)`。

### 4.4 未生成快照轮次访问限制

对未生成快照的非当前轮次访问索引函数（如 `accountsByRoundAtIndex`、`scoresAtIndex`）会 revert：`NoSnapshotForFutureRound()`。其他查询函数对未生成快照的轮次返回空数组或 0。

## 5. 奖励分配规则

### 5.1 基本公式

当 `round < verify.currentRound()` 且该轮次已生成快照时：

\[
reward(account, round) = totalActionReward(round) \times \frac{score(account, round)}{totalScore(round)}
\]

### 5.2 未生成快照不分配

若某轮次 `totalScore(round) == 0`（包括未生成快照或所有参与者分数为 0），则该轮次个人奖励为 0。

## 6. 继承者实现指南

继承者必须实现：

- `calculateScores()`：返回总分与与参与者数组顺序一致的分数数组
- `calculateScore(account)`：返回该账户分数与总分（通常与 `calculateScores` 逻辑一致）

实现时需保证：

- 分数数组长度与当前参与者集合长度一致
- 分数数组索引与 `center.accounts(tokenAddress, actionId)` 的顺序一致
