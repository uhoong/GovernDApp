# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```
# 链上提案管理系统开发

## Todo

提案管理系统
governance strategy 关于治理策略，改成模块化
确定各个模块接口

提案发布链上部分参考aave

## 参考资料

### AAVE

#### 1. AAVE 提案提交过程

1. 编写 AIP
2. 准备链上治理

在 AIP 上链之前，需要做好以下准备：

* 审查后的 AIP 合并主分支
* 审查后的 AIP 被分解并且上传至 IPFS
* payload 被检查和充分测试

3. 链上提交 AIP

拥有足够提案权的用户可以链上提交 AIP，使用 governance contract 的 create() 方法。

#### 2. Aave 治理合约作用

##### AaveGovernance 合约作用

记录：
* 采用的 Stratage 合约
* 授权的 executor
* guardian



create()

原理：

* 检查 target，target 是提案通过后发送交易的地址
* 检查 executor 是否合法
* 检查提案创建是否合法



cancel()

原理：

* 获取提案状态，要求状态不能为取消、执行和过期
* 验证取消合法
* 修改提案的 canceled 字段为 true
* executor 取消交易



queue()

原理：

* 验证提案状态，要求状态为成功
* executor 执行队列加入待执行的交易
* 修改提案的 executionTime 字段为当前时间戳加上 executor 的延迟时间



execute()

原理：

* 修改提案的 executed 字段为 true
* executor 执行交易



提案状态定义：

依次验证

* 取消：提案的 canceled 字段为 true
* pending：提案的 startblock 高于当前区块
* active：提案的 endblock 高于当前区块
* failed：proposalValidator（即 executor）验证提案没通过投票，即没达到法定最低票数或支持票数不够
* succeeded：提案的 executionTime 字段为 0
* executed：提案的 executed 字段为 true
* expired：executor 验证当前时间戳是否大于提案的 executionTime 加上追溯时间
* 否则为 queued
