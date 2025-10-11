# 如何开发并在行动中使用扩展协议

## 1. 基于 ILOVE20ExtensionFactory，开发扩展协议工厂合约，基于 ILOVE20Extension 开发具体扩展协议

## 2. 部署工厂合约，并在 Center 里使用 addExtensionFactory 注册添加 扩展协议工厂合约

## 3. 使用工厂合约，创建具体行动所使用的扩展协议合约

## 4. 发起行动，并在白名单中填写扩展协议合约，并投票

## 5. 行动阶段，在初始化扩展协议

- 先发送 1 个代币给扩展合约
- Center 合约调用 initializeExtension 将扩展协议合约加入行动
