# ForgeGod 原型实现状态

更新时间：2026-09-01

## 已落地

- Minecraft 1.20.1、Forge 47.4.10、Tetra 6.17.0、Mutil 6.3.0 工程可构建。
- `EffectBlueprint`、事实卡片和服务端预算校验。
- DeepSeek Chat Completions Provider：异步 HTTP、45 秒超时、结构化 JSON 解析；API 密钥支持主页面 GUI 配置和 `DEEPSEEK_API_KEY`，环境变量优先。
- `/forgegod ask <申请>` 生成单套候选；`/forgegod repair <反馈>` 将上一版蓝图和反馈交给 AI。
- Tetra item effect/improvement JSON 编译、世界专用 datapack 写入、启用和 reload。
- Forge 注册的 `SparkSpriteEntity`：受控寿命、持有者环绕、16 格索敌、魔法伤害、可受伤、水中熄灭。
- 已移除神裁幻境功能：当前版本不创建镜头、测试人偶或临时演示实体，避免进入演示时状态重置。
- 神裁砧 BlockEntity/Menu/Screen：武器槽、供物槽、事实读取入口、真实输入框、单套 AI 建议、返修、编译和定稿按钮。
- 同一把武器按稳定 UUID 关联待处理会话；定稿后写入契约并锁定再次请神。
- 客户端注册 `R` 按键；按住并悬停已定稿武器时显示神裁属性。
- 主页面新增“锻造之神 AI 设置”按钮；本机密钥保存到当前实例 `config/forgegod-client.properties`，可在 GUI 中保存或清除。
- `/forgegod accept` 将已编译候选契约写入神裁砧武器槽中的 ItemStack；正式 `ON_HIT` 运行时完成命中计数、冷却、召唤和耐久消耗。

## 已验证

- `gradlew.bat build` 成功，生成 `build/libs/forgegod-1.20.1-0.1.0.jar`。
- `gradlew.bat runServer` 成功加载 Forge、Tetra、Mutil 和 ForgeGod，服务器完成启动。
- 构建 JAR 已同步到 D 盘原型目录，SHA-256：

```text
8C4AD5BCAC8210B9A05BE8C72BBB18C791BE082311DB7B8F5796ACC88CB7E03F
```

## 当前边界

- GUI 支持玩家直接输入申请和返修意见；命令仍可用于脚本化测试和故障复现。
- 神裁幻境已移除；候选编译不改变玩家镜头、暂停状态或主世界位置。
- 运行时首个完整节点是 `ON_HIT -> SPARK_SPRITE`；`ON_HURT`、`ON_KILL`、区域和投射物节点仍需扩展。
- Tetra improvement 仍按当前可用主模块挂载，尚未实现所有武器槽位的专用可视化槽位规则。
- 契约保存在武器 ItemStack NBT，候选历史和 API 用量统计尚未接入 SavedData。
- 当前没有 Create/Ponder 依赖，也没有把 API key 写入源码、存档、日志或文档；GUI 只保存玩家在本机输入的密钥。

## 试玩入口

```text
/give @s forgegod:divine_anvil
/forgegod ask 连续命中同一目标后召来围绕勇者飞行的火花小精灵
/forgegod trial
/forgegod accept
```
