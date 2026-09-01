# ForgeGod 原型实现状态

更新时间：2026-09-01

## 已落地

- Minecraft 1.20.1、Forge 47.4.10、Tetra 6.17.0、Mutil 6.3.0 工程可构建。
- `EffectBlueprint`、事实卡片和服务端预算校验。
- DeepSeek Chat Completions Provider：异步 HTTP、45 秒超时、结构化 JSON 解析；API 密钥从 `DEEPSEEK_API_KEY` 读取。
- `/forgegod ask <申请>` 生成候选；`/forgegod repair <反馈>` 将上一版蓝图、演示 trace 和反馈交给 AI。
- Tetra item effect/improvement JSON 编译、世界专用 datapack 写入、启用和 reload。
- Forge 注册的 `SparkSpriteEntity`：受控寿命、持有者环绕、16 格索敌、魔法伤害、可受伤、水中熄灭。
- 神裁幻境服务端场景：镜头实体、测试人偶、候选小精灵副本、固定场景状态、暂停/慢放/重播和 trace。
- 神裁砧 BlockEntity/Menu/Screen：武器槽、供物槽、事实读取入口、AI、演示、暂停、慢放、定稿、重播按钮。
- `/forgegod accept` 将契约写入主手 ItemStack；正式 `ON_HIT` 运行时完成命中计数、冷却、召唤和耐久消耗。

## 已验证

- `gradlew.bat build` 成功，生成 `build/libs/forgegod-1.20.1-0.1.0.jar`。
- `gradlew.bat runServer` 成功加载 Forge、Tetra、Mutil 和 ForgeGod，服务器完成启动。
- 构建 JAR 已同步到 D 盘原型目录，SHA-256：

```text
67F0B95EB3D3D6C3D31BF20BF7797BDAFE96DA024891A5ED83676FA19D5E9759
```

## 当前边界

- GUI 的 AI 按钮使用一个安全的默认申请文本；复杂申请使用 `/forgegod ask`。
- 神裁幻境目前使用主世界附近的临时实体场景，未创建独立维度；主世界 tick 不会被冻结。
- 运行时首个完整节点是 `ON_HIT -> SPARK_SPRITE`；`ON_HURT`、`ON_KILL`、区域和投射物节点仍需扩展。
- Tetra improvement 仍按当前可用主模块挂载，尚未实现所有武器槽位的专用可视化槽位规则。
- 契约保存在武器 ItemStack NBT，候选历史和 API 用量统计尚未接入 SavedData。
- 当前没有 Create/Ponder 依赖，也没有把 API key 写入源码、存档、日志或文档。

## 试玩入口

```text
/give @s forgegod:divine_anvil
/forgegod ask 连续命中同一目标后召来围绕勇者飞行的火花小精灵
/forgegod trial
/forgegod pause
/forgegod slow
/forgegod replay
/forgegod accept
```
