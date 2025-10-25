# LOVE20 Extension Center Deployment Scripts

一键部署和验证 LOVE20ExtensionCenter 合约的脚本集合。

## 📁 脚本说明

### 00_init.sh

**环境初始化脚本**

- 设置网络参数
- 加载账户配置
- 定义常用函数（`cast_call`, `forge_script`, `check_equal`等）
- 初始化 keystore 密码

### one_click_deploy.sh ⭐

**一键部署主脚本**

自动完成以下步骤：

1. 初始化环境
2. 部署 LOVE20ExtensionCenter 合约
3. 验证合约（仅 thinkium70001 网络）
4. 运行部署检查

### 03_verify.sh

**合约验证脚本**

- 在区块链浏览器上验证合约源代码
- 仅适用于 thinkium70001 系列网络
- 其他网络会自动跳过

### 99_check.sh

**部署验证脚本**

检查 ExtensionCenter 合约的所有参数是否正确：

- uniswapV2FactoryAddress
- launchAddress
- stakeAddress
- submitAddress
- voteAddress
- joinAddress
- randomAddress
- verifyAddress
- mintAddress

## 🚀 使用方法

### 方式 1：一键部署（推荐）

```bash
cd script/deploy
source one_click_deploy.sh <network>
```

示例：

```bash
# 部署到 anvil 本地测试网
source one_click_deploy.sh anvil

# 部署到 thinkium70001_public
source one_click_deploy.sh thinkium70001_public
```

### 方式 2：分步部署

```bash
cd script/deploy

# Step 1: 初始化环境
source 00_init.sh <network>

# Step 2: 部署合约
forge_script_deploy_extension_center

# Step 3: 加载部署地址
source $network_dir/address.extension.center.params

# Step 4: 验证合约（可选，仅 thinkium 网络）
source 03_verify.sh

# Step 5: 检查部署
source 99_check.sh
```

## 📋 前置条件

1. **已部署 LOVE20 核心合约**

   - 确保 `script/network/<network>/address.params` 文件包含所有必需的地址

2. **配置账户文件**

   - `script/network/<network>/.account` 文件包含 keystore 配置

3. **网络配置**
   - `script/network/<network>/network.params` 包含 RPC URL 等信息

## 📝 部署后文件

部署成功后，合约地址会写入：

```
script/network/<network>/address.extension.center.params
```

内容格式：

```bash
extensionCenterAddress=0x...
```

## 🔍 查看可用网络

```bash
cd script/deploy
ls ../network/
```

## ⚠️ 注意事项

1. **密码管理**：首次运行时需要输入 keystore 密码，密码会保存在当前 shell 会话中

2. **Gas 设置**：默认 gas-price 为 5 Gwei，gas-limit 为 50M，可在 `00_init.sh` 中调整

3. **验证失败**：如果合约验证失败，不影响部署成功，可以后续手动验证

4. **检查失败**：如果部署检查失败，说明合约参数配置有误，需要重新部署

## 📊 输出示例

```
=========================================
  One-Click Deploy Extension Center
  Network: anvil
=========================================

[Step 1/4] Initializing environment...
✓ Environment initialized

[Step 2/4] Deploying LOVE20ExtensionCenter...
✓ Extension Center deployed at: 0x59b670e9fA9D0A427751Af201D676719a970857b

[Step 3/4] Skipping contract verification (not a thinkium network)

[Step 4/4] Running deployment checks...
=========================================
Verifying Extension Center Configuration
=========================================
✓ All checks passed (9/9)

=========================================
✓ Deployment completed successfully!
=========================================
Extension Center Address: 0x59b670e9fA9D0A427751Af201D676719a970857b
Network: anvil
=========================================
```

## 🛠️ 故障排除

### 问题：找不到网络

```bash
Error: Network parameter is required.
```

**解决**：检查网络名称是否正确，确保 `script/network/<network>` 目录存在

### 问题：地址参数未找到

```bash
Error: uniswapV2FactoryAddress not found
```

**解决**：确保先部署 LOVE20 核心合约，并且 `address.params` 文件包含所有必需的地址

### 问题：部署检查失败

```bash
✗ N check(s) failed
```

**解决**：检查链上合约状态，可能需要重新部署

## 📚 相关文件

- 部署脚本：`script/DeployLOVE20ExtensionCenter.s.sol`
- 合约源码：`src/LOVE20ExtensionCenter.sol`
- Foundry 配置：`foundry.toml`
