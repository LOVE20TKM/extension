# LOVE20 行动扩展协议之代币参与基类合约（LOVE20ExtensionBaseRewardTokenJoin）

## 0. 关于 LOVE20ExtensionBaseRewardTokenJoin

`LOVE20ExtensionBaseRewardTokenJoin` 组合 `ExtensionReward` 与 `TokenJoin` 能力，为扩展协议提供**基于 ERC20 的参与/退出机制**：

- 用户通过 `join(amount, verificationInfos)` 向扩展合约转入参与代币（join token）
- 用户通过 `exit()` 在满足等待区块数后退出并取回全部参与代币
- 参与者地址会被维护在 ExtensionCenter 的 accounts 集合中

> 注意：这里的等待参数是 `waitingBlocks`（区块数），不是“阶段数”。且每次 `join` 会更新 `joinedBlock`，从而刷新退出等待起点。

## 1. 核心优势

### 1.1 抵抗短周期参与套利

通过 `waitingBlocks` 限制退出时间，适合需要一定持有时长/参与周期的行动参与机制。

### 1.2 自动初始化 + 统一参与者集合

`join()` 首次交互会自动绑定 `actionId`，并把首次参与的地址加入到 ExtensionCenter accounts，便于后续验证与奖励分配；`claimReward()` 不会触发自动初始化。

### 1.3 与验证信息联动

`join` 支持附带 `verificationInfos`，用于写入验证相关的附加信息。

## 2. 初始参数

### 2.1 工厂地址（factory）

用于定位 ExtensionCenter 与核心合约地址。

### 2.2 代币地址（tokenAddress）

该扩展所属的 LOVE20 token 地址。

### 2.3 参与代币地址（joinTokenAddress）

用户参与时转入/退出时返还的 ERC20 代币地址（不可为 0 地址）。

### 2.4 等待区块数（waitingBlocks）

用户从最近一次 `join` 的区块高度开始，需要等待至少 `waitingBlocks` 个区块后才能 `exit()`。

## 3. 参与者

### 3.1 代币参与（join）

参与条件：

- `amount > 0`

参与效果：

- 首次参与：记录 `joinedRound` 并将用户加入 ExtensionCenter accounts
- 累计参与：`amount` 会累加
- 更新 `joinedBlock = block.number`（刷新退出等待起点）
- 从用户地址转入 `amount` 的 `joinTokenAddress` 代币到扩展合约
- 可选：写入 `verificationInfos`

### 3.2 代币退出并取回（exit）

退出条件：

- 必须存在参与余额
- `block.number >= joinedBlock + waitingBlocks`

退出效果：

- 清空用户参与信息（joinedRound/amount/joinedBlock）
- 从 ExtensionCenter accounts 移除该用户
- 将用户全部参与余额的 join token 返还给用户

## 4. 继承者实现指南

`LOVE20ExtensionBaseRewardTokenJoin` 已提供 join/exit 的完整实现；继承者通常还需要：

- 实现 `IExtensionJoinedValue` 三个函数，用于定义“参与价值”的统计口径（例如按质押数量、按加权值等）
- 实现奖励分配逻辑（直接实现 `_calculateReward`，或再组合更高层的奖励模板）
