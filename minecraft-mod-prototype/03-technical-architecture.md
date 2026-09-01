# 技术架构

## 1. 总体结构

```text
Tetra ItemStack
    ↓ TetraWeaponAdapter
WeaponFacts（只读快照）
    ↓
神裁砧 Menu / Screen
    ↓ C2S 申请
NegotiationService
    ↓ 异步 HTTPS
AiProvider（云端 API）
    ↓ 结构化 DivineTurn
EffectBlueprint + BlueprintValidator
    ↓ 通过
TetraCompiler
    ↓
GeneratedPackService
    ↓ 写入 data/tetra/item_effects 与 improvements
ReloadCoordinator
    ↓ 重载并挂载唯一 improvement
DivineTrialService（候选武器副本 + 真实服务端测试空间）
    ├─ 玩家满意 -> CommitService
    └─ 玩家返修 -> trace + feedback -> AiProvider
    ↓
ContractStorage + ContractRuntime
    ↓
伤害、标记、投射物、小精灵、区域、冷却、战斗日志
```

核心原则：AI 负责理解、对话和提出机制图；Java 代码负责事实、权限、校验、编译、文件路径、重载、执行和存档。AI 永远不直接写 Tetra JSON。

## 2. 模块划分

建议包结构：

```text
forgegod/
├─ api/                 AiProvider、请求与返回 DTO
├─ block/               神裁砧 Block 与 BlockEntity
├─ menu/                服务端 Menu
├─ client/screen/       交涉界面、契约预览、错误状态
├─ network/             SimpleChannel 数据包
├─ weapon/              WeaponAdapter、WeaponFacts、指纹
├─ compat/tetra/        TetraWeaponAdapter
├─ negotiation/         对话状态、摘要、服务编排
├─ blueprint/           EffectBlueprint、Schema、规范化与校验器
├─ compiler/tetra/      Blueprint 到 Tetra-compatible JSON 的编译器
├─ datapack/            generated pack 清单、原子写入、重载与回滚
├─ contract/            候选版本、定稿 DivineContract、绑定与溯源
├─ runtime/             事件图解释器、预算、冷却和熔断
├─ entity/              火花小精灵、受控投射物、范围实体
├─ trial/               神裁幻境、场景生成、重播、trace 与清理
├─ storage/             ItemStack NBT、SavedData 兼容方案
├─ config/              API、超时、调试配置
└─ logging/             可读战报与开发诊断
```

不要让 `compat/tetra` 依赖 `api`，也不要让 AI 供应商 DTO 渗入机制运行时。这样未来可以更换匠魂适配器或 API，而不重写核心逻辑。

## 3. 武器适配层

```java
public interface WeaponAdapter {
    boolean supports(ItemStack stack);
    WeaponFacts inspect(ItemStack stack, ServerPlayer player);
    ItemFingerprint fingerprint(ItemStack stack);
    Optional<DivineContract> readContract(ItemStack stack);
    void attachContract(ItemStack stack, DivineContract contract);
}
```

首版只注册 `TetraWeaponAdapter`。未来的 `TConstructWeaponAdapter` 可以映射到同一份 `WeaponFacts`。

`WeaponFacts` 只包含白名单字段：

```json
{
  "schema_version": 1,
  "weapon_id": "temporary-session-id",
  "weapon_kind": "modular_bow",
  "display_name": "银木猎弓",
  "modules": [
    {
      "slot": "bow/stave",
      "material_id": "example:silverwood",
      "tags": ["wood", "spirit_affinity"]
    }
  ],
  "stats": {
    "damage": 7.0,
    "speed": 1.2,
    "durability_current": 412,
    "durability_max": 520,
    "integrity_free": 2
  },
  "facts": [
    {
      "id": "material.silverwood.spirit_affinity",
      "text": "银木可以短暂容纳弱小灵体"
    }
  ],
  "fingerprint": "sha256-of-canonical-facts-and-stack-state"
}
```

AI 只能引用 `facts[].id`。玩家显示名属于说明，不能替代事实 ID。

## 4. 交涉状态机

```text
IDLE
  ↓ 放入武器
READY
  ↓ 提交申请
WAITING_FOR_AI
  ├─ 网络错误 -> RECOVERABLE_ERROR
  └─ 返回成功 -> REVIEWING_TURN
                    ├─ QUESTION/COUNTEROFFER -> AWAITING_PLAYER
                    ├─ PROPOSE + 校验失败 -> REVISING
                    └─ PROPOSE + 校验通过 -> PROPOSAL_READY
PROPOSAL_READY
  ├─ 玩家继续谈 -> WAITING_FOR_AI
  ├─ 玩家拒绝 -> READY
  └─ 玩家同意试铸 -> COMPILE_CANDIDATE
COMPILE_CANDIDATE
  ├─ 失败 -> SYSTEM_REPAIR（不扣返修次数）
  └─ 成功 -> RELOAD_GENERATED_PACK
RELOAD_GENERATED_PACK
  ├─ 失败 -> ROLLBACK_PACK（不扣返修次数）
  └─ 成功 -> DIVINE_TRIAL
DIVINE_TRIAL
  ├─ 接受当前候选 -> COMMITTING -> COMPLETE
  ├─ 返修且 attempts > 0 -> AI_REVISION -> COMPILE_CANDIDATE
  ├─ 选择历史有效版本 -> COMMITTING -> COMPLETE
  └─ 放弃 -> ABANDONED
```

初次交涉请求包含固定神明协议、武器事实快照、最近几轮消息、压缩后的有效承诺、上一轮校验错误和玩家本轮输入。返修请求额外包含上一版蓝图、玩家在时间线选中的反馈、确定性演示 trace、校验器警告与必须保留项。不要把整个日志无限追加给 API。

每个有效候选使用不可变编号 `candidate_v1`、`candidate_v2` 等。只有成功进入 `DIVINE_TRIAL` 后，玩家主动返修才扣一次；网络、格式、编译、reload 或执行故障不扣。默认 2 次，可由完成度或供物加 1，配置硬上限 4。

## 5. AI Provider

```java
public interface AiProvider {
    CompletableFuture<DivineTurn> complete(DivineRequest request,
                                            CancellationToken token);
}
```

原型使用云端 API，但供应商信息只存在于实现层。建议直接使用 Java 17 `HttpClient`，减少 SDK 与 Minecraft/Forge 依赖冲突。

配置项：

```text
provider
endpoint
model
api_key_source
connect_timeout_seconds
request_timeout_seconds
max_output_tokens
debug_log_redaction
```

API key 不写入世界存档、武器 NBT、网络数据包或普通日志。开发原型可从环境变量或被 Git 忽略的本机配置读取。未来多人模式应由服务器持有 key，客户端永远不上传自己的 key 给陌生服务器。

发送到云端的内容仅限：玩家本轮申请、必要的交涉摘要、白名单武器事实和固定世界观协议。界面要明确提示这段文字会发往所选 API。

## 6. 结构化 AI 返回

每轮返回必须满足 JSON Schema。逻辑结构建议如下：

```json
{
  "schema_version": 1,
  "turn_type": "QUESTION | COUNTEROFFER | PROPOSE | REFUSE",
  "speech": "锻造之神的可见对白",
  "cited_fact_ids": ["material.silverwood.spirit_affinity"],
  "conversation_summary": "仍然有效的目标、让步和争议",
  "missing_requirements": [],
  "proposal": null
}
```

当 `turn_type` 为 `PROPOSE` 时，`proposal` 包含结构化契约。返回 JSON 即使结构合法，也仍是不可信输入，必须经过：

1. Schema 解析。
2. 枚举和字段长度检查。
3. 事实 ID 存在性检查。
4. 机制节点白名单检查。
5. 复杂度、实体数、循环和资源上限检查。
6. 武器事实与材料权限检查。
7. 可选的沙盒演算。

## 7. EffectBlueprint 与编译产物

```json
{
  "blueprint_version": 1,
  "name": "银木火花之约",
  "fantasy": "连续命中后召来火花小精灵追击标记目标",
  "cited_fact_ids": ["material.silverwood.spirit_affinity"],
  "entrypoints": [{"event": "ON_HIT", "start_node": "same_target_counter"}],
  "nodes": [
    {
      "id": "same_target_counter",
      "op": "COUNTER_WINDOW",
      "args": {"key": "target_uuid", "count": 3, "window_ticks": 200},
      "next": "summon_sprites"
    },
    {
      "id": "summon_sprites",
      "op": "SUMMON_FAMILIAR",
      "args": {"type": "SPARK_SPRITE", "count": 2, "lifetime_ticks": 160},
      "next": "pay_durability"
    },
    {
      "id": "pay_durability",
      "op": "DAMAGE_WEAPON",
      "args": {"amount": 3},
      "next": null
    }
  ],
  "limits": {
    "cooldown_ticks": 600,
    "max_spawned_entities": 2,
    "max_steps_per_trigger": 24,
    "max_lifetime_ticks": 160
  },
  "display": {
    "trigger_text": "10 秒内连续命中同一目标 3 次",
    "effect_text": "召来 2 只火花小精灵，持续 8 秒",
    "cost_text": "额外损耗 3 点耐久，冷却 30 秒"
  }
}
```

`EffectBlueprint` 是唯一允许 AI 生成的机制格式。它不包含文件路径、命令、函数、Java 类名、任意资源位置或任意实体 NBT。`BlueprintValidator` 依次完成 Schema、事实、权限、预算、可终止性和强度检查，再把规范化蓝图交给 `TetraCompiler`。

编译器产出：

```text
data/tetra/item_effects/forgegod/<contract_id>/<effect_id>.json
data/tetra/improvements/shared/forgegod/<contract_id>.json
forgegod/manifest/<contract_id>.json
```

Tetra 原版能安全表达的条件、伤害、状态、粒子、声音、有限延迟和多结果直接编译为原版节点；小精灵、投射物、武器损耗、标记、有限区域查询和有界重复编译为本 MOD 注册的自定义效果节点。原版 `tetra:command`、`tetra:function`、方块修改、任意 NBT 实体生成和无界循环永不进入编译目标集。

`DivineContract` 是玩家最终确认后的不可变记录，保存规范化蓝图、生成文件哈希、编译器版本、Tetra 版本、所选候选编号、武器指纹和事实引用。读档时不重新请求 AI；如果生成文件丢失，按已保存蓝图以原编译器兼容模式重建，而不是让模型重新解释。

## 8. Generated datapack 与 Tetra 挂载

`GeneratedPackService` 只允许写入当前世界的固定数据包根目录，并由 MOD 自己根据 UUID 生成相对路径。写入流程为：先在同一世界目录生成临时清单，解析并校验所有 JSON，原子替换 manifest，再请求服务端资源重载。AI 返回内容不能控制 namespace 或路径。

重载成功后：

1. 重新取得目标 `ItemStack` 和模块对象，不复用 reload 前引用。
2. 调用 `ItemModuleMajor.addImprovement(...)` 挂载该候选的唯一 improvement。
3. 调用 `IModularItem.updateIdentifier(stack)` 清理旧缓存键。
4. 重新读取武器事实，确认 effect 与 improvement 均已生效。
5. 失败时恢复上一份已知可用 manifest 并再次重载。

generated pack 是世界级资源，但候选 improvement ID 与会话/武器 UUID 绑定。被放弃的候选先从可挂载清单移除，再在安全时机垃圾回收文件；不能在战斗执行过程中删除仍被物品引用的定义。

## 9. 运行时

运行时监听 Forge 服务端事件，并把事件映射为契约入口。候选事件包括：

- `LivingHurtEvent` / `LivingDamageEvent`
- `LivingDeathEvent`
- `PlayerInteractEvent.RightClickItem`
- 必要的玩家 tick，但只处理已经注册的短期状态

执行前确认：

- 当前在逻辑服务端。
- 触发武器仍是绑定的 ItemStack。
- 契约未熔断、冷却结束、资源充足。
- 当前调用未超过节点步数和生成实体上限。

禁止通用脚本、反射类名、任意命令、任意 NBT 路径和任意资源位置。每一种 `op` 都由手写 Java 执行器实现，并有独立单元测试。

### 9.1 可终止性

- 图在提交前做环检测。
- 只有专门的 `REPEAT_LIMITED` 节点允许有限循环。
- 单次触发有最大步数。
- 每份契约有同时存活实体上限。
- 延迟任务有最大寿命，区块卸载时可清理。
- 同一触发链使用 trace ID，避免效果互相递归。
- 发生异常时只熔断当前契约，向玩家显示简短错误，并保留开发日志。

### 9.2 确定性

随机分支使用服务器生成的种子，并在战斗日志记录关键选择。AI 不参与实时战斗，因此同一份契约在规则版本不变时具有稳定语义。

## 10. 神裁幻境

不直接依赖 Create Ponder。Ponder 的 StoryBoard 是预注册 Java 场景，新增 entry 通常要求重启，而且 `PonderWorld` 是客户端模拟世界，无法原样执行真实服务端 Tetra 战斗逻辑。

`DivineTrialService` 使用真实服务端临时测试空间或独立维度，持有正式武器的候选副本。场景由触发器模板自动组合：测试人偶、自动攻击者、低生命目标、不同距离的目标阵列和右键触发器。客户端只负责镜头、时间线与控制 UI。

每次重播恢复固定快照与随机种子，并采集：

- 触发与节点执行时间线。
- 伤害、状态、击退和目标选择。
- 冷却、耐久和供物变化。
- 活跃召唤物、投射物、区域数量与寿命。
- 条件未满足、预算截断和熔断原因。

暂停和慢放只作用于隔离的演示调度器，不能改变主世界 tick。离开界面、断线或异常时必须销毁临时实体、取消延迟任务并恢复测试空间。

## 11. 存档策略

第一方案是在 `ItemStack` 自定义 CompoundTag 下保存：

```text
forgegod:contract
forgegod:contract_hash
forgegod:contract_runtime_version
```

但在正式依赖此方案前，必须验证 Tetra 的以下操作是否保留未知 NBT：

- 工作台更换模块。
- 添加 improvement。
- 修理、磨损、附魔与重命名。
- 丢弃和拾取。
- 死亡后回收。
- 退出重进和世界重载。

如果任何关键路径会丢弃自定义 NBT，则改用“双层保存”：武器只携带稳定的 `contract_id`，完整契约放在世界 `SavedData` 中，并在 Tetra 改造事件或物品迁移流程中重新绑定。这个问题是开工后的第一个技术风险门。

不可变契约定义与高频运行状态分开。冷却、临时计数器和活动实体由服务端 `ContractRuntimeStore` 管理，避免每 tick 改写 ItemStack NBT。

## 12. 网络与线程

### 12.1 数据包

使用 Forge `SimpleChannel`，至少包含：

```text
C2S_OpenOrResumeNegotiation
C2S_SubmitPlayerTurn
C2S_CancelRequest
C2S_StartTrial
C2S_TrialControl
C2S_SubmitRepairFeedback
C2S_SelectCandidate
C2S_CommitCandidate
S2C_NegotiationSnapshot
S2C_RequestStatus
S2C_DivineTurn
S2C_ProposalValidation
S2C_CompileStatus
S2C_TrialSnapshot
S2C_TrialTrace
S2C_CandidateHistory
S2C_CommitResult
```

服务端不信任客户端传来的武器属性、契约或价格。客户端只发送请求 ID、菜单上下文和玩家文字；事实由服务端重新读取。

### 12.2 API 与 reload 异步流程

不得阻塞 Minecraft server tick：

```text
服务端主线程：验证菜单、武器和频率
        ↓
后台线程：发出 HTTPS 请求、解析 JSON、执行纯数据校验与 JSON 编译
        ↓
服务端主线程：重新检查玩家、容器和武器指纹
        ↓
服务端 reload 管线：装载 generated pack，重新解析模块并挂载候选
        ↓
神裁幻境演示；玩家确认后才修改正式 ItemStack 和结算供物
```

每个请求带唯一 ID 和取消标记。API 超时、界面关闭或世界退出后，迟到的响应不得修改游戏状态。

## 13. 神裁砧与神裁幻境界面

界面最少包含：

- 武器槽和只读事实卡片。
- 对话记录。
- 玩家输入框和发送按钮。
- 请求中、限流、重试、已取消等明确状态。
- 契约预览页：触发、效果、代价、事实依据、反制。
- 候选历史、剩余返修次数和编译/reload 状态。
- 幻境的暂停、慢放、重播、重置、接管测试和目标切换控件。
- 可点击的触发时间线与“保留、修改、不可接受”反馈入口。
- 接受当前候选、返修、选择旧版本、放弃四类动作。

按钮的最终行为都走服务端验证。输入长度、轮数和调用频率设上限，防止误操作产生大量 API 费用。

## 14. 测试层次

### 纯 Java 测试

- Contract JSON 解析和规范化。
- 事实引用检查。
- 图环检测、步数预算、实体预算。
- Blueprint 到 Tetra JSON 的快照测试与恶意路径测试。
- 候选编号、返修扣次和历史版本选择。
- 每个 op 的输入边界。
- 对话状态机和迟到响应处理。

### GameTest / 集成测试

- 武器绑定后能触发契约。
- 客户端不能伪造伤害、材料和提案。
- 世界重载后契约仍在。
- 区块卸载会清理召唤物和延迟任务。
- API 失败不会消耗材料。
- generated pack 可重载、失败可回滚，唯一 improvement 挂载正确。
- 演示使用副本，不修改正式武器，退出后不残留实体或任务。
- 相同快照与随机种子产生相同 trace。

### 手工兼容测试

- Tetra 工作台全流程的 NBT 保留。
- 与目标 Tetra/Mutil/Forge 精确版本同时启动。
- 单人暂停、死亡、维度切换、存档退出期间的请求取消。
- generated pack 多次重载后的客户端同步、耗时与内存变化。
- 三种演示契约在自动与手动模式下的视觉可读性和性能。

## 15. 未来扩展点

- 新增 `TConstructWeaponAdapter`。
- 新增本地 `OllamaProvider` 或内置模型，不改变契约格式。
- 把机制图迁移到正式游戏运行时。
- 增加队友、半自动战斗、跨武器联动和世界代价。
- 建立机制数据集：保存申请、事实、交涉、契约、校验失败和实战结果。

这些扩展只有在最小闭环被玩家验证后才进入计划。
