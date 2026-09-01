# 版本与锻造模组研究

> 研究日期：2026-09-01  
> 研究问题：用哪个 Minecraft 版本和锻造模组，最适合验证 AI 锻造博弈，而不是重新制作一整套装备系统？

## 1. 推荐版本

推荐锁定 `Minecraft Java 1.20.1 + Forge 47.4.10 + Java 17`。

原因如下：

- Tetra 与 Tinkers' Construct 当前都提供正式的 1.20.1 文件，因此可以在同一版本上比较和保留后备路线。
- Forge 1.20.1 的入门、事件、网络、菜单、配置和数据存储文档完整。
- Forge 官方 1.20.x 文档明确要求 64 位 Java 17，并推荐 Eclipse Temurin。
- Forge 下载页在 2026-09-01 显示 1.20.1 的 Recommended 为 `47.4.10`，Latest 为 `47.4.23`。原型优先使用 Recommended，减少依赖升级带来的变量。
- 1.20.1 仍使用成熟的 `ItemStack` NBT 方案，适合在单件武器上附加自定义契约；无需在原型阶段同时处理 1.20.5 之后的数据组件迁移。

不选择更新 Minecraft 版本，不代表新版本不能做，而是 Tetra、匠魂、加载器和开发文档的共同交集在 1.20.1 最稳。原型验证成功后再评估迁移。

## 2. Tetra 研究

Tetra 的核心体验是把已有工具拆成可替换模块，并由材料、模块、改造和使用过程共同塑造一件武器。它适合本项目，原因不只是“可以换部件”，而是它已经把武器表达成一组可被读取的结构化事实。

### 2.1 可复用能力

- **Modules**：一件工具由多个模块和模块变体组成。
- **Materials**：材料提供属性、适用槽位、完整性等数据。
- **Improvements**：允许在已有模块上继续改造。
- **Item effects**：数据驱动效果由触发器、条件和结果组成。
- **Custom item effects**：插件可以用 Java 实现自定义效果。

对本原型最有价值的是 Tetra 官方对数据驱动物品效果的定义：

```text
effect = trigger + optional condition + outcome
```

它支持把命中、挖掘等事件和实体、数值、向量、状态、伤害、位移、延迟等结果组织起来。源码还显示 `ItemEffect` 并非封闭枚举，新的效果 ID 可以按字符串创建。这意味着 AI 提案可以先变成受控中间表示，再由编译器写成 Tetra-compatible 数据包，而不必把创造力限制为固定词条抽取。

### 2.2 源码验证与动态挂载路线

本次研究以 Tetra 1.20 分支提交 `d212377491eaf2ef58ea841f0e45d532d5e69f95` 为源码快照，得到以下结论：

- `ItemEffect` 可由字符串 ID 动态创建，并非只能使用预先枚举的固定技能。
- `ItemEffectStore` 会在资源重载时读取效果 JSON，并按触发器整理全局映射。
- Mutil `DataStore` 会读取数据包并同步客户端，但 Tetra 的这些 store 限定使用 `tetra` namespace。
- 动态效果因此应写入当前世界已启用数据包的 `data/tetra/item_effects/forgegod/`。
- 与之对应的唯一 improvement 写入 `data/tetra/improvements/shared/forgegod/`。`shared` 路径是 Tetra 各主模块共同引用的 improvement 入口。
- 重载完成后，插件可以调用 `ItemModuleMajor.addImprovement(...)` 把唯一 improvement 挂到目标模块，再调用 `IModularItem.updateIdentifier(stack)` 清理旧模块缓存键。
- Tetra 的模块数据会在 reload 时重建，因此每次挂载都必须在成功重载后重新解析模块，不保存跨 reload 的对象引用。

首版采用 addon + generated datapack，而不是直接修改或重新发布 Tetra JAR：

```text
EffectBlueprint
    ↓ 严格校验
TetraCompiler
    ↓
世界存档/datapacks/forgegod-generated/
    ├─ data/tetra/item_effects/forgegod/...
    └─ data/tetra/improvements/shared/forgegod/...
    ↓ 受控 reload
唯一 improvement 挂到候选或正式武器
```

这条路线需要实测 `/reload` 的耗时、客户端同步、旧候选清理和失败回滚。神裁流程把重载安排在锻造演出期间，并对同一批候选合并重载；如果实测延迟不可接受，保留“预注册效果 + 本 MOD 运行时”的后备模式。

### 2.3 原版能力与必须封禁的能力

Tetra 原版数据效果已经支持条件、表达式、随机、伤害、状态、粒子、声音、延迟、多结果、循环、实体查询、位移、推力、生成实体和方块操作。不过，原版直接整理的触发器主要是：

- `tetra:on_use`
- `tetra:apply_hit_effects`
- `tetra:mine_block`
- `tetra:break_block`

`ON_HURT`、`ON_KILL`、复杂状态记忆等需求需要本 MOD 通过 Forge 事件和自定义效果节点补充。

原版还存在不适合开放给 AI 的高权限 outcome，包括 `tetra:command`、`tetra:function`、`tetra:set_block`、`tetra:break_block`、带任意 NBT 的 `tetra:spawn_entity`、`tetra:entity_data` 和无硬上限的 `tetra:loop`。这些能力即使能被 JSON 表达，也必须在 AI 编译器中封禁。模型只输出 `EffectBlueprint`，不能直接提交原版 Tetra JSON。

### 2.4 许可边界

Tetra 的 CurseForge 页面标为 All Rights Reserved，但其 GitHub 仓库的 License & Use 明确允许“编写以 Tetra 为依赖的自有代码”，包括 addon、mod integration 和 datapack；同时禁止复制或重新分发大部分等价实现，并对 Perk 内容有特别限制。

因此本项目应：

- 把 Tetra 作为外部依赖，不把它打包进本 MOD。
- 只调用必要接口并编写自己的适配代码。
- 不复制 Tetra 的源码、特殊资产、Perk 内容或大段等价实现。
- 私下可以用研究 fork 验证小补丁；若公开发布完整魔改版 Tetra，必须先取得作者许可。
- 发布前再次核对其当时的许可证与整合要求。

## 3. 匠魂研究

Tinkers' Construct 的成熟点在于材料、部件、工具统计和 Modifier 系统。官方开发文档覆盖 Gradle 接入、材料、工具部件、工具和 JSON Modifier，并说明大多数页面适用于 1.16.5 以来的版本，版本差异会单独标注。

它的优点包括：

- 工具材料、部件和 Modifier 心智模型成熟。
- Tinkers' Construct 与 Mantle 均使用 MIT License，插件开发和源码参考的许可边界更宽松。
- 社区对“材料决定属性、Modifier 改变工具”的理解成本较低。

它不作为首发的原因：

- 本项目要验证的是“在一件已经锻造完成的独特武器上绑定一份动态契约”，而匠魂的 Modifier 更接近注册好的能力类型。
- 为了自由机制仍然要另写事件图运行时，匠魂不会替我们解决 AI 动态契约问题。
- 同时适配两个大型锻造模组会把第一阶段变成兼容性工程。

匠魂仍然是合理的第二适配器。如果 Tetra 的武器事实读取或自定义数据保留出现无法解决的问题，可用同一份 `WeaponAdapter` 接口切换，而不重写 AI 与机制运行时。

## 4. 对比结论

| 维度 | Tetra | Tinkers' Construct | 原型判断 |
|---|---|---|---|
| 锻造体验 | 围绕单件工具持续替换模块和改造 | 材料部件组装与 Modifier | 两者都够用 |
| 与机制图的概念接近度 | 官方已有 trigger/condition/outcome 数据效果 | 以材料、统计和 Modifier 为中心 | **Tetra 更接近** |
| 单件动态契约 | 需要自建 NBT/运行时 | 同样需要自建运行时 | 平手 |
| 插件资料 | Tech wiki 细，API 稳定性需实测 | 开发文档和 Gradle 指南较清楚 | 匠魂略优 |
| 许可 | 自定义许可，明确允许 addon/integration | MIT | 匠魂更宽松 |
| 第一版工作量 | 一个适配器 | 一个适配器 | 不应同时做 |

最终选择：**Tetra 首发，匠魂保留为未来替代或第二适配器。**

## 5. 精确依赖

### Tetra 路线

```groovy
implementation fg.deobf("curse.maven:tetra-289712:8570756")
implementation fg.deobf("curse.maven:mutil-351914:7772906")
```

对应：

- Tetra `6.17.0`，Minecraft 1.20.1，File ID `8570756`。
- Mutil `6.3.0`，Minecraft 1.20.1，File ID `7772906`。

### 匠魂备选路线

```groovy
implementation fg.deobf("curse.maven:tinkers-construct-74072:7449219")
implementation fg.deobf("curse.maven:mantle-74924:7563777")
```

对应：

- Tinkers' Construct `3.11.2.166`，File ID `7449219`。
- Mantle `1.11.104`，File ID `7563777`。

这些坐标来自各文件页面提供的 Curse Maven snippet。实际开工时需要在 `repositories` 中配置 CurseMaven，并确认依赖可解析。

## 6. 技术资料来源

### Minecraft Forge

- [Forge 1.20.x Getting Started](https://docs.minecraftforge.net/en/1.20.x/gettingstarted/)
- [Forge 1.20.1 Downloads](https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html)
- [Forge Events](https://docs.minecraftforge.net/en/1.20.x/concepts/events/)
- [Forge SimpleImpl Networking](https://docs.minecraftforge.net/en/1.20.x/networking/simpleimpl/)
- [Forge Menus](https://docs.minecraftforge.net/en/1.20.x/gui/menus/)
- [Forge Capabilities](https://docs.minecraftforge.net/en/1.20.x/datastorage/capabilities/)
- [Forge Configuration](https://docs.minecraftforge.net/en/1.20.x/misc/config/)

### Tetra

- [Tetra Item Effects](https://tetra.mickelus.se/wiki/1.20/tech/item-effects)
- [Tetra Modules](https://tetra.mickelus.se/wiki/1.20/tech/modules)
- [Tetra Materials](https://tetra.mickelus.se/wiki/1.20/tech/materials)
- [Tetra Improvements](https://tetra.mickelus.se/wiki/1.20/tech/improvements)
- [Tetra Custom Item Effects](https://tetra.mickelus.se/wiki/1.20/tech/custom-item-effects)
- [Tetra 6.17.0 file](https://www.curseforge.com/minecraft/mc-mods/tetra/files/8570756)
- [Mutil 6.3.0 file](https://www.curseforge.com/minecraft/mc-mods/mutil/files/7772906)
- [Tetra repository and License & Use](https://github.com/mickelus/tetra)

### Tinkers' Construct

- [SlimeKnights Developer Documentation](https://slimeknights.github.io/docs/)
- [Gradle Setup](https://slimeknights.github.io/docs/guides/gradle)
- [Adding a Material](https://slimeknights.github.io/docs/guides/material)
- [Modifier JSON](https://slimeknights.github.io/docs/json/modifiers)
- [Tinkers' Construct 3.11.2.166 file](https://www.curseforge.com/minecraft/mc-mods/tinkers-construct/files/7449219)
- [Mantle 1.11.104 file](https://www.curseforge.com/minecraft/mc-mods/mantle/files/7563777)

## 7. 研究限制

- Tetra 的公开 Tech wiki 能确认数据格式和效果概念，但不能保证所有内部 Java API 都是稳定的公共接口。
- 动态 generated datapack、reload、improvement 挂载和自定义 NBT 保留仍需在锁定版本做实际测试，源码可行不等于运行时已经验证。
- CurseForge 文件和 Forge Latest 会继续更新。本原型应冻结版本，不因新版本出现而自动升级。
- MOD 原型不能证明正式独立游戏的开放机制运行时一定可行；它只验证交涉、结构化裁定和实战反馈之间的核心因果链。

本研究使用了 AI 辅助整理，版本号、File ID 和开发要求均在上述公开页面进行了逐项核对。
