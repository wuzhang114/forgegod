# Minecraft 锻造之神 MOD 原型规划

> 文档状态：原型立项建议稿  
> 更新时间：2026-09-01  
> 目的：借助 Minecraft 现成的锻造、装备和战斗环境，低成本验证“打造武器 -> 与锻造之神交涉 -> AI 生成机制 -> 神裁幻境动态演示 -> 有限返修 -> 定稿实战”的核心玩法。

## 1. 当前结论

首个原型暂定使用：

```text
Minecraft Java Edition 1.20.1
Forge 47.4.10
Java 17
Tetra 6.17.0
Mutil 6.3.0
云端 AI API（具体供应商通过 AiProvider 隔离）
```

选择 Tetra 而不是从零编写锻造系统，也不在第一版同时适配匠魂。Tetra 已经提供材料、模块、改造、武器属性与工作台体验，可以让原型把开发时间集中在真正需要验证的部分：

1. 游戏能否准确读取一件模块化武器的“器物事实”。
2. 玩家是否愿意围绕这些事实与锻造之神多轮质询、辩解和交换代价。
3. AI 的裁定能否编译成 Tetra-compatible 数据效果，而不只是从固定技能表中抽取词条。
4. 玩家能否通过动态演示看懂机制，并用有限返修把结果改到满意。
5. 新机制进入真实战斗后，是否能产生“这是我和神明共同造出来的武器”的感受。

本地 Ollama 不属于首版范围。架构仍保留可替换的 `AiProvider`，但原型先使用云端 API，避免同时承担模型部署、显存适配和 MOD 玩法验证三类风险。

## 2. 最小可玩闭环

```text
制作或改造 Tetra 武器
        ↓
把武器放入“神裁砧”
        ↓
系统读取材料、模块、属性、耐久和工艺事实
        ↓
玩家用自然语言申请一种特殊能力
        ↓
锻造之神质询、反提案或要求代价
        ↓
玩家继续辩解，或接受修改后的神赐契约
        ↓
规则校验器批准 EffectBlueprint
        ↓
编译为 Tetra-compatible 数据与受控扩展节点
        ↓
写入世界专用 generated datapack，并重载候选效果
        ↓
进入“神裁幻境”动态演示
        ↓
满意 -> 定稿；不满意且有次数 -> 反馈给 AI 返修并重新演示
        ↓
契约绑定到正式武器，进入真实战斗
```

第一版只做单人测试。AI 只参与提案与返修，不在每次攻击时调用模型。候选效果由确定性的 Tetra 数据效果和本 MOD 的受控节点执行，神裁幻境使用武器副本，不提前消耗正式材料。

## 3. 原型边界

### 包含

- Tetra 武器事实提取。
- 一个神裁砧方块、菜单和交涉界面。
- 多轮锻造之神对话。
- API 异步请求、超时、取消和失败提示。
- 结构化裁定与服务端二次校验。
- `EffectBlueprint -> Tetra-compatible JSON` 编译器与世界专用 generated datapack。
- 唯一 improvement 的动态挂载、资源重载与失败回滚。
- 类似 Create Ponder 观感、但运行在真实服务端测试空间的“神裁幻境”。
- 确定性重播、触发时间线、伤害/冷却/耐久/召唤物统计。
- 基础 2 次、可由完成度或供物增加的有限返修流程。
- 单件武器的神赐契约保存、Tooltip、候选历史和战斗日志。
- 一套小而可组合的事件图运行时及 Tetra 自定义效果扩展。
- 至少三个明显不同的可玩机制样例。

### 不包含

- AI 自动生成或执行 Java 代码。
- AI 驱动城主、勇者、城市经济或随机事件。
- 完整复刻原游戏的铁匠铺经营和头牌小队系统。
- 正式多人服务器支持。
- 同时支持 Tetra 与匠魂。
- 本地模型安装器或 Ollama 接入。
- AI 直接写入未经校验的 Tetra JSON、执行命令或生成 Java 代码。
- 直接依赖 Create/Ponder，或要求每个 AI 结果拥有新模型和新动画。
- 宣称可以实现玩家提出的任何效果。

原型的任务是验证玩法，不是提前完成正式游戏。AI 的创意自由主要体现在机制图的结构、条件、对象、代价和世界观转译上；底层执行权限仍由可测试的运行时控制。

## 4. AI 如何安全地生成 Tetra 数据效果

Tetra 1.20 的数据驱动物品效果由 `trigger + condition + outcome` 组成。源码研究表明，效果 ID 可以按字符串动态创建，数据效果会在资源重载时重新整理；同时可以把唯一 improvement 挂到目标模块。因此，**动态生成数据包在技术上可行**，而且比只保存一份本 MOD 私有 NBT 更能验证 AI 对 Tetra 机制的创造力。

但模型不能直接操作文件。原型采用编译链：

```text
AI EffectBlueprint
    -> Schema 与事实校验
    -> 强度和执行预算校验
    -> TetraCompiler
    -> data/tetra/item_effects/forgegod/... JSON
       + data/tetra/improvements/shared/forgegod/... JSON
    -> 写入当前世界的 forgegod-generated 数据包
    -> 受控资源重载
    -> 把唯一 improvement 挂到候选武器
```

原版 Tetra 中命令、函数、任意实体 NBT、改方块和无上限循环等高权限结果不进入白名单。Tetra 缺少但原型需要的“受控小精灵、投射物、区域、有限查询”等能力，由本 MOD 注册带硬上限的自定义节点。这样能让 AI 自由组合机制，又不会获得任意代码或任意服务器权限。

## 5. 文档导航

- [01-version-and-mod-research.md](01-version-and-mod-research.md)：版本选择、Tetra/匠魂比较、许可证与资料来源。
- [02-core-prototype-design.md](02-core-prototype-design.md)：玩家流程、锻造博弈、机制样例和验收标准。
- [03-technical-architecture.md](03-technical-architecture.md)：MOD 模块、AI API、数据格式、线程、网络、存档和运行时。
- [04-implementation-roadmap.md](04-implementation-roadmap.md)：分阶段实施顺序、风险门和测试计划。
- [05-ai-tetra-generation-and-divine-trial.md](05-ai-tetra-generation-and-divine-trial.md)：动态 Tetra 数据生成、神裁幻境、有限返修和安全边界。
- [version-lock.md](version-lock.md)：精确版本、依赖坐标和升级规则。

## 6. 当前仍需玩家决定的内容

这些问题不妨碍先搭原型，但会影响后续美术和数值：

- 神裁砧是独立方块，还是依附在 Tetra 工作台旁的神龛。
- 锻造之神在原型里使用严厉、傲慢还是更偏交易者的语气。
- 首批三种演示武器具体选择剑、弓、锤，还是完全跟随玩家现有 Tetra 配方。
- API 供应商与预算上限。代码先通过接口隔离，不把供应商写进存档。

版本尚未由玩家强制指定，因此 `1.20.1` 是本规划根据模组兼容性做出的暂定锁定。如果必须改到另一 Minecraft 版本，应先重新核对 Tetra、Forge、Java 和依赖版本，再开始编码。
