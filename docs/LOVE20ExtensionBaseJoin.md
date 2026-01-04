# LOVE20 行动扩展协议之免代币参与基类合约（LOVE20ExtensionBaseRewardJoin）

## 0. 关于 LOVE20ExtensionBaseRewardJoin

`LOVE20ExtensionBaseRewardJoin` 组合 `ExtensionReward` 与 `Join` 能力，为扩展协议提供**免代币（token-free）的参与/退出机制**：

- 用户 `join()` 即加入行动参与列表
- 用户 `exit()` 可随时退出
- 参与者地址会被维护在 ExtensionCenter 的 accounts 集合中，用于后续验证/奖励等流程

## 1. 核心优势

### 1.1 低门槛参与

无需转账/质押任何代币即可参与，适合白名单式、身份式、贡献式参与模型。

### 1.2 与验证信息联动

`join()` 可携带 `verificationInfos`，用于写入验证相关的附加信息（由 `VerificationInfo` 处理）。

### 1.3 自动初始化

`join()` 会自动完成扩展初始化（定位并绑定 `actionId`），避免单独的初始化流程；`claimReward()` 不会触发自动初始化。

## 2. 初始参数

### 2.1 工厂地址（factory）

用于定位 ExtensionCenter 与核心合约地址。

### 2.2 代币地址（tokenAddress）

该扩展所属的 LOVE20 token 地址。

## 3. 参与者

### 3.1 加入参与者（join）

参与条件：

- 不能重复加入（已加入则 revert）

加入效果：

- 记录加入轮次（`joinedRound = join.currentRound()`）
- 将地址加入 ExtensionCenter 的 accounts
- 可选：写入 `verificationInfos`

### 3.2 退出参与者（exit）

退出条件：

- 必须已加入（未加入则 revert）

退出效果：

- 清空加入状态
- 从 ExtensionCenter 的 accounts 移除该地址

## 4. 继承者实现指南

`LOVE20ExtensionBaseRewardJoin` 已提供 join/exit 的完整实现；继承者通常还需要：

- 实现 `IExtensionJoinedValue` 三个函数，用于定义“参与价值”的统计口径
- 实现奖励分配逻辑（直接实现 `_calculateReward`，或再组合更高层的奖励模板）
