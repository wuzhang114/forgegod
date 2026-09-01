# M1 假神闭环原型方案（Godot 4.x / GDScript / 像素 2D）

> 状态：细化方案（2026-09-01 修订：机制执行层由"固定原语图"升级为"MechLang 受限机制语言 + 沙盒 VM"）
> 更新时间：2026-09-01
> 前置决定：像素风 2D 侧视；Godot 4.6/4.7 stable；GDScript；单人投入 15 小时/周以上。
> 参考：`minecraft-mod-prototype/` 已验证的技术原则与本方案中的三个机制样例。

## 0. 目标与边界

### 目标

不带 LLM，验证完整闭环是否好玩：

```text
锻造（三工序）→ 器物档案 WeaponFacts
    → 神前申请（脚本化·假神）
    → 质询 / 议价 / 契约草案
    → 校验器 + 神裁幻境演示 + 有限返修
    → 定稿 → 半自动战斗 → 战报 → 回到锻造
```

验证的问题只有一个：**"打造事实是否真的能支持有趣、公平的武器机制博弈"**——这是整个项目最危险的假设，与 AI 模型无关。

### 边界（明确不做）

- 不接入任何 LLM / 云端 API（假神是脚本化提供者，但保留 `NegotiationProvider` 接口，将来替换）。
- 不做：雇佣兵、游戏内日结、经营经济、多个勇者、护甲/副武器、剧情内容、四幕主线。
- 不做正式美术：全部灰盒占位（色块 + 简单形状 + 程序化粒子），色板统一为 16 色西幻灰盒色板。
- 不做多人、不做存档系统（M1 用内存状态 + 简单的 JSON 导出调试即可）。

### 成功标准（M1 验收）

- 玩家从零到第一场战斗 ≤ 20 分钟，全程不需要看教程文档。
- 玩家能解释：神为什么质询 / 契约为什么是现在这样 / 战斗里效果为什么触发或失效。
- 同一句申请放在不同材料武器上，会产生可感知的差异（至少契约参数不同）。
- 三个契约使用不同的运行时结构（召唤实体 / 状态储蓄释放 / 空间区域），不是换数值。
- 战报能回答"我的锻造选择为什么有效或无效"。
- 5–10 名试玩者中，多数人表示"想出下一次申请"。

## 1. 技术基线

| 项 | 决定 |
| --- | --- |
| 引擎 | Godot 4.6 或 4.7 stable（以 4.6 为最低兼容线） |
| 语言 | GDScript |
| 逻辑分辨率 | 640×360（16:9），窗口 1280×720，整数缩放 2×，`stretch` 用 `canvas_items` |
| 像素规格 | 物理网格 16×16；角色占位 16×24；场景基线即 640×360 |
| 模拟 tick | 固定 20 Hz 战斗模拟；渲染与模拟分离；UI 跟随 `_process` |
| 时间 | 全部用 tick 数表示（`ticks = 秒 × 20`），避免浮点时间漂移 |
| 随机 | 自写种子 RNG（SplitMix64），禁止调用 `randf` 做战斗逻辑 |
| 机制语言 | **MechLang v0.1**：AI 生成的受限机制语言；解析 → 静态校验 → 确定性 VM 执行 |
| 测试 | gdUnit4（headless 跑 core 单测）；不存在 Node 引用，纯 GDScript 可测 |

## 2. 项目目录结构

```text
godot-prototype/
├─ project.godot
├─ README.md                     # 运行方式 + 调试命令
├─ core/                         # 纯逻辑，禁止引用 Node/Scene（可 headless 测试）
│  ├─ mechlang/                  # ★ MechLang 机制语言与沙盒
│  │  ├─ mechlang_def.gd         # 关键字/函数白名单/预算常量
│  │  ├─ lexer.gd                # 文本 → token 流
│  │  ├─ parser.gd               # 递归下降 → AST（Dictionary）
│  │  ├─ checker.gd              # 静态校验（白名单、上界、预算、权限层）
│  │  ├─ vm.gd                   # 确定性解释器（事件驱动、步数/实体预算、熔断）
│  │  └─ host_api.gd             # 宿主函数注入接口（动作/查询两类白名单）
│  ├─ data/
│  │  ├─ material_def.gd         # 材料定义（六属性 + 特性）
│  │  ├─ materials.gd            # 材料静态表（8 种）
│  │  └─ fixtures.gd             # 3 份演示契约的 MechLang 源码
│  ├─ weapons/
│  │  ├─ weapon_facts.gd         # 器物档案构建与 fingerprint
│  │  └─ fact_cards.gd           # 事实白名单生成
│  ├─ negotiation/
│  │  ├─ divine_turn.gd          # 回合结构（JSON 可序列化）
│  │  ├─ negotiation_provider.gd # 接口：turn(state) -> DivineTurn
│  │  └─ scripted_god.gd         # 假神：规则剧本实现
│  ├─ runtime/
│  │  ├─ sim.gd                  # 战斗 + 机制模拟（固定 tick）
│  │  ├─ rng.gd                  # 种子 RNG（SplitMix64）
│  │  ├─ entities.gd             # 实体表（勇者/敌人/小精灵/区域/投射物）
│  │  └─ event_log.gd            # tick 级事件日志（trace）
│  ├─ trial/
│  │  ├─ trial_fixtures.gd       # 按 entrypoint 生成演示场景
│  │  └─ trial_reporter.gd       # trace -> 演示统计
│  └─ report/
│     └─ battle_report.gd        # 战报聚合（按武器）
├─ scenes/                       # Godot 场景，只做显示与输入
│  ├─ main/main.tscn             # 流程串联 + 调试导航（直接跳各场景）
│  ├─ forge/forge_scene.tscn     # 温控/锻打/热处理三工序 UI
│  ├─ altar/altar_scene.tscn     # 交涉界面（对话 + 事实卡片 + 契约预览）
│  ├─ trial/trial_scene.tscn     # 神裁幻境（镜头、时间线、慢放、重播、返修）
│  ├─ battle/battle_scene.tscn   # 半自动战斗 + 干预按钮 + HUD 计数器
│  └─ ui/
│     ├─ pixel_theme.tres        # 灰盒像素 UI 主题
│     └─ debug_draw.gd           # 灰盒绘制辅助（色块/箭头/区域圈）
├─ data/
│  └─ palette/forgegod_16.png    # 16 色灰盒色板（程序生成，锁色板）
└─ tests/                        # gdUnit4 + headless 自跑测试
   ├─ test_mechlang_lexer.gd
   ├─ test_mechlang_checker.gd
   ├─ test_mechlang_vm.gd
   ├─ test_sim_determinism.gd
   └─ run_headless.gd            # godot --headless -s 入口
```

**架构铁律**：`core/` 里的任何文件不得 `extends Node`、不得 `preload` 场景、不得调用 `engine.get_main_loop()`。场景层只做：把输入翻译成 core 调用、把 core 返回的结构画出来。

## 3. MechLang：机制语言与沙盒（核心决策）

> 方向（2026-09-01）：不把 AI 限制在固定原语/词条表里，而是让 AI 编写**我们定义语法的受限代码**。想象空间由语言表达能力保证（变量、状态、事件、循环、嵌套组合，组合空间无限）；执行安全由"解析→静态校验→确定性 VM"保证。AI 永远到不了文件系统、网络、系统调用和无界循环。
>
> v0.2（2026-09-01）：补齐"集合迭代（`for e in enemies_in_range(6)`）、生成型函数返回值（实体/区域引用）、目标状态/标签/环境查询、新事件（attack / projectile_hit / healed）与新上下文（hurt_damage / attack_damage）"。经 47 条机制蓝图逐条对照，器物级机制覆盖率由 32% 提升至约 95%。
>
> v0.2.1（2026-09-01）：新增 5 动词 `dash / damage_self / heal_self / spawn_beam / create_wall`；Dota2/LoL/原神 13 个想象力技能全部复刻通过（128/128）。
>
> v0.3（2026-09-01）：战斗接缝——① 契约特性 `traits { ignores_evade / guaranteed_hit / crit_mult }`（sim 在判定链读取）；② 战斗查询 `armor_value / target_evade / attack_value / hit_chance`；③ 判定结果上下文 `hit_landed / hit_crit`，契约可用完备公式计算伤害（如 `attack_value() * 100 / (100 + armor_value(target)) * hit_crit`）。测试 138/138 全绿。

### 3.1 语言语法（简化示例："回雷"）

```text
device 回雷 {
  auth: item                          # item | squad | world（M1 只实现 item）
  budget: { entities: 4, steps: 16, cooldown: 600 }
  state: { counter: 0, stock: 0.0 }

  on block {
    stock = min(stock + blocked_damage * 0.2, 12)
    counter += 1
  }
  on heavy_blow {
    if counter >= 3 {
      reduce_armor(target, 20)
      damage(target, "impact", stock)
      damage(nearest_enemy(target), "lightning", 8)
      cost = 2
      if has_defect("stress_crack") {
        cost += 2
      }
      damage_weapon(cost)
      counter = 0
    }
  }
}
```

- 语法为 C 风格大括号 + 换行/分号分隔（对 AI 生成比对缩进敏感语法更稳）；字符串参数必须加引号，如 `"impact"`。
- 事件集（由 sim 订阅注册）：`hit / block / heavy_blow / hurt / kill / right_click / timer / entity_removed / attack / projectile_hit / healed`。
- 语句：赋值（未声明目标自动成为 handler 局部变量）、if/else、for（迭代源 = 整数常量 1..100 整数循环，或集合查询的集合迭代）、调用宿主函数。
- **v0.1 不提供用户自定义函数**（无递归入口）；表达力靠状态变量 + 事件组合 + 循环，递归需求留到 v0.2（届时必须静态证明终止）——v0.2 同样无递归入口。
- 事件上下文保留变量（handler 内直接可读）：`target / attacker / blocked_damage / hurt_damage / attack_damage / tick`。
- 宿主函数白名单（动作类）：`damage / reduce_armor / knockback / apply_status / spawn_sprite / spawn_projectile / create_zone / damage_weapon / heal_weapon / set_mark / clear_mark / consume_offering / set_weapon_state / destroy_entity`。
- 生成型函数（可出现在表达式位置，返回实体/区域引用）：`spawn_sprite / spawn_projectile / create_zone`。
- 宿主函数白名单（查询类）：`blocked_damage / target_hp_ratio / hp_value / has_status / self_hp_ratio / target_has_tag / world_flag / zone_is_active / mark_count / weapon_stock / has_defect / nearest_enemy / distance / rand_range / count_entities / weapon_state / min / max`。
- 集合查询（只能作 for 迭代源）：`enemies_in_range(radius) / all_enemies()`。
- 用户声明的全部标识符不得与关键字/宿主函数重名（编译器强制）。

v0.2 示例（集合迭代 + 实体引用 + 状态查询，对应"火种引信"）：

```text
on kill {
  if has_status(target, "burning") {
    for e in enemies_in_range(6) {
      damage(e, "fire", 4)
    }
  }
}
```

```text
on heavy_blow {
  s = spawn_sprite(1, 160, 24)     # s 是实体引用,可传给后续函数
  set_mark(s)
  if hp_value(s) < 1 {
    destroy_entity(s)
  }
}
```

### 3.2 编译链

```text
玩家自然语言 → 意图理解 → MechLang 源码（AI/假神产出）
    → lexer → parser → AST
    → checker 静态校验：
        ① 语法与类型 ② 函数白名单 ③ for 上界 ≤ 100
        ④ 每 handler 步数 ≤ budget.steps ⑤ 实体上限 ≤ budget.entities
        ⑥ cooldown ≥ 0 且每个触发路径存在冷却或终止 ⑦ auth 权限层
        ⑧ 引用的事实/状态变量存在
    → 反例测试（沙盒模拟：空目标/超上限/目标消失/递归联动）
    → 确定性 VM 编译（闭环符号表 + 字节码级指令）
    → 写入运行时（契约 + 武器绑定 + 战报钩子）
```

校验失败返回结构化错误列表（`[{code, line, detail}]`），假神/未来 LLM 读取后"重新审视"——系统修复不消耗玩家返修次数。

### 3.3 VM 语义（确定性优先）

- 每 tick：sim 广播事件 → 命中契约的 handler 入队执行。步数预算为**语句级**：每条语句（含 if/for/调用/赋值）计 1 步，for 展开计 迭代次数 × 语句数；预算取契约 `budget.steps` 与全局硬上限（512）的较小值，超出即熔断并写入战报（`BREACH` 标签），不影响世界。表达式求值不计步（长度由解析/校验阶段限制）。
- 所有随机来自注入的种子 RNG（seed = 契约 ID + 武器指纹 + 世界种子），同 seed 同事件序列 → 同结果。
- 状态变量命名空间：`weapon_state`（跨战斗持久，写进契约）、`per_fight`（战斗内）、`local`（函数内）。
- 实体（小精灵/区域/投射物）由 sim 实体表管理，VM 只能通过白名单函数创建，且创建时校验全局上限。
- 完整事件日志（tick、事件、实体、值）→ 支持回放、神裁幻境时间线、战报。

### 3.4 原则红线（永不跨越）

- VM 不可：读写文件、访问网络、执行系统命令、读取玩家隐私、修改引擎/存档边界外的数据。
- AI 不可：生成超出 MechLang 语法的内容指望其被接受；输出必须可解析、可校验、有预算。
- 任何效果必须有：可读描述（玩家能懂）、反制入口（至少一个）、终止条件（循环/寿命/次数/冷却）、相关代价（不与机制无关的罚钱）。

### 3.5 想象力动词族（设计参考，2026-09-01 整理）

> 来源：用 MechLang 复刻 Diablo2 / BG3 / Dota2 / LoL / 原神 共 26 个明星技能后的归纳。结论：**高想象力技能 ≈ 少量通用动词的组合，而不是新系统**。玩家提机制时，90% 的想法落在以下动词族里；策划/假神/AI 可以用这些话术引导玩家表达。

| 动词族 | 含义 | MechLang 载体 | 代表技能 |
| --- | --- | --- | --- |
| 牵引 | 把敌人拉向某处 | `create_zone(pull)` | 谜团·黑洞、深渊足迹 |
| 排斥/击退 | 推开目标 | `knockback` | 盲僧·神龙摆尾 |
| 位移(自身) | 冲刺/跳向目标 | `dash` | 水人·波浪形态 |
| 延迟 | "之后才发生" | `create_zone(delay)` / timer | 月火术、霜华矢绽放 |
| 能量储蓄-释放 | 存起来,满足条件再放 | `state` + 阈值 + 释放 | 蓄能盾击、辛德拉法球 |
| 蓄力-爆发 | 长按/准备后更强 | `state` 计数 + timer | 骨钉大师蓄力斩 |
| 召唤物自治 | 生成一个自己干活的单位 | `spawn_sprite` + timer + `nearest_enemy` | 奥兹、杀生樱 |
| 资源交换 | 用血/耐久/供物换强度 | `damage_self` / `damage_weapon` / `consume_offering` | 胡桃蝶引来生 |
| 距离感知 | 越远越强/越近越强 | `distance(self, target)` | 奈德丽标枪 |
| 状态条件 | "在某种状态下才触发" | `has_status` / `target_has_tag` / `world_flag` | 失衡打击 |
| 规则墙 | 隔绝弹道/划分战场 | `create_wall` | 亚索·风墙 |
| 持续光束 | 直线持续伤害 | `spawn_beam` | 凤凰·太阳射线 |
| 标记-联动 | 先贴标签,之后认领 | `set_mark` / `mark_count` | 猎人印记、猎手印记 |
| 击杀成长 | 杀得越多越强(有上限) | `on kill` + `state` + `min()` | 猎杀者 |

**征集玩家的推荐话术**："你想要的是把敌人吸过来(牵引)、攒够再放(能量储蓄)、还是召唤一个自己打的小帮手(召唤物自治)？"——让玩家在 14 个动词族里选方向,AI/假神再按所选动词族生成 MechLang。超出动词族的提案(位置瞬移/队伍协同/世界级)记录为"奇迹层"转后续系统。

## 4. 数据模型（M1 版本）

### 4.1 材料（8 种，各 1 个鲜明特性）

六属性 0–10：`hardness 硬度 / toughness 韧性 / density 密度 / conduction 导能 / stability 稳定 / craft_difficulty 工艺难度`。

| id | 名称 | 核心特性（事实 id） | 一句话 |
| --- | --- | --- | --- |
| grey_iron | 熟铁 | 耐修 | 维修成本低，多次维修后稳定提高 |
| red_copper | 赤铜 | 导流 | 元素/治疗效果易扩散，承力差 |
| blackwood | 黑木 | 回振 | 格挡或射击后保留部分力量供下一动作 |
| beast_bone | 魔兽骨 | 饥性 | 击杀恢复少量耐久，久不战斗则稳定下降 |
| star_iron | 陨铁 | 天外 | 支持位移、坠落、星火论证；工艺窗口极窄 |
| silverwood | 银木 | 灵亲和 | 可短暂容纳弱小灵体（小精灵来源） |
| void_ore | 虚空矿 | 深渊 | 支持吸引类论证；会吸引附近魔法生物 |
| frost_steel | 霜钢 | 寒凝 | 低温淬火加成；高热下特性失效 |

每个材料属性值在开工时填表，M1 只需要大致正确、能形成取舍。

### 4.2 WeaponFacts（器物档案）

```gdscript
{
  "weapon_id": "w_001",
  "name": "无名战锤",
  "kind": "warhammer",                 # warhammer | longsword | bow
  "action_tags": ["heavy_blow", "armor_break", "block_counter"],
  "parts": [                            # 四职责部件
    {"role": "action",  "part": "head",   "material_id": "star_iron"},
    {"role": "bearing", "part": "handle", "material_id": "blackwood"},
    {"role": "control", "part": "grip",   "material_id": "grey_iron"},
    {"role": "medium",  "part": "core",   "material_id": "red_copper"},
  ],
  "size": {"length": 0.8, "thickness": 0.7, "balance": 0.4},   # 0–1 滑块值
  "craft": {"purity": 91, "structure": 76, "temper": 88, "balance": 84},  # 0–100
  "defects": [
    {"id": "defect.stress_crack", "label": "内应力裂纹",
     "desc": "连续过载时耐久损耗提高"}
  ],
  "facts": [                            # AI/假神只能引用这里的 id
    {"id": "material.star_iron.heavenly", "text": "陨铁支持位移、坠落、星火类论证，但工艺窗口极窄"},
    {"id": "craft.balance.good", "text": "平衡度 84，重心稳定"},
    # ...由材料特性 + 工序结果 + 缺陷自动生成
  ],
  "fingerprint": "sha256(canonical)"
}
```

- `facts` 由系统生成，玩家与假神都不可编辑——这是"神明裁定可信"的地基。
- 交涉期间武器被换/改造 → 指纹变化 → 旧契约作废。

### 4.3 契约与回合

```gdscript
# DivineContract（校验通过的最终产物）
{ contract_id, mechlang_source, ast_hash, weapon_fingerprint,
  readable_description, costs, counters, tooltip_lines,
  compiler_version, budget }

# DivineTurn（回合结构，未来 LLM 同构）
{ speech, stance: "question|counteroffer|propose|refuse",
  cited_fact_ids, missing_fact_ids, draft_mechlang, cost_proposals, summary }
```

## 5. 假神实现（ScriptedGod）

- 实现 `NegotiationProvider` 接口；M1 用规则剧本：对预设 MechLang 契约，按 `WeaponFacts` 事实匹配度走分支：

```text
事实充分（材料特性 + 工艺 + 尺寸匹配） -> PROPOSE 草案（预写 MechLang 源码）
部分满足 -> QUESTION 指向缺失事实卡片（玩家点卡片补充 -> COUNTEROFFER）
完全不满足 -> REFUSE + 指明补强路径（换部件 / 换材料 / 降低规模）
```

- 议价参数固定为 3 组可选代价：耐久 +N / 冷却 +N / 数量 -1 或范围 -30%（玩家三选一）。
- 回合数以 3–5 轮封顶；返修 2 次（演示有效后才扣），硬上限 4。
- 假神对话文本从"剧本槽 + 事实插值"生成（如 "你的{材料}确实支持{特性}，但{缺失}……"），为将来 LLM 提供同构接口与提示词样例。
- `DivineTurn` 全部 JSON 可序列化，`scripted_god.gd` 与未来 `llm_god.gd` 输出完全一致 → 换 AI 不动游戏层。

## 6. 三个演示契约（MechLang 版本）

### 契约 A：火花小精灵（弓 / 银木）

```text
触发：10 秒内连续命中同一目标 3 次（200 tick 窗口）
生成：2 只火花小精灵，围绕持有者 24px 半径轨道飞行，寿限 160 tick
索敌：优先攻击被 SUMMON 时标记、仍存活且在 120px 内的敌人
行为：每 60 tick 喷一枚 6 伤害星火弹（可被墙体/格挡拦截）
代价：触发时武器耐久 -3；冷却 600 tick
反制：小精灵可被击杀（3 HP）；场景有水流/雨水则立即熄灭
```

MechLang 骨架：

```text
device 星火之约 {
  auth: item
  budget: { entities: 2, steps: 12, cooldown: 600 }
  state: { hits: 0 }
  on hit {
    hits += 1
    if hits >= 3 {
      spawn_sprite(2, 160, 24)      # 数量, 寿命 tick, 环绕半径
      set_mark(target)
      damage_weapon(3)
      hits = 0
    }
  }
}
```

### 契约 B：蓄势反震锤（战锤 / 黑木+赤铜+陨铁）

```text
触发：持有者被格挡的伤害按 20% 存入 BUFFER，上限 12
释放：下一次 heavy_blow 命中时对主目标额外影响型伤害（=BUFFER 值）+ 破甲 20
     并电弧传导至 1 名邻近敌人（8 伤害）
代价：释放后耐久 -2；裂纹缺陷存在时再 -2；储能期间换武器缓慢泄漏
反制：敌人拉开距离可让储能浪费
```

### 契约 C：深渊足迹（战锤或剑 / 虚空矿）

```text
触发：右键发动后记录持有者 2 秒路径（40 tick 采样）
延迟：路径节点 1 秒后变成吸引区（半径 32px，持续 1.5 秒 =30 tick）
结果：拉近普通敌人与投射物（每秒 12px），不影响首领
限制：最多 4 个区域；城市地面不可用（封印：只在战斗场景启用）
代价：固定冷却 900 tick + 耐久 -4
反制：敌人离开路径；也吞掉友方投射物（双刃）
```

> 说明：A 验证"召唤实体 + 环绕 + 追踪"；B 验证"事件储蓄 → 跨事件释放"；C 验证"空间采样 + 延迟 + 区域"。三种 MechLang 结构互不相同（状态计数 / 跨事件缓冲 / 空间采样+延迟区域）。

## 7. M0.5 验证门：MechLang 沙盒先行（新增里程碑）

> **状态：已完成（2026-09-01）。** MechLang v0.1 + v0.2 沙盒实现并通过 53/53 headless 测试（Godot 4.7.2），覆盖：词法/解析/静态校验（非法脚本全部被拒）/VM 契约执行（回雷、星火之约）/集合迭代（火种传染）/实体引用（生成型函数返回值）/新事件与上下文/熔断（可复现）/确定性（同 seed 同序列）。剩余收尾：30 条申请 → "AI 生成 MechLang 校验通过率 ≥80%" 的对照测试（等接 AI 时执行）。

在 M1 之前验证"AI/假神能否可靠地产出可执行 MechLang"。B 计划：若通过率 < 门槛，回退"约束 AST + 模板机"混合 —— 机制相同，自由少一档，不影响 M1 其余部分。

### 任务

1. MechLang lexer / parser / checker / VM（纯 GDScript，headless 可测）。
2. 用 3 份演示契约的 MechLang 源码跑通：解析 → 校验 → 编译 → 模拟执行 → trace 一致。
3. 人为构造非法脚本：未知函数、超步数、for 无上界、实体超限、无冷却 —— 全部被静态阶段拒绝。
4. 确定性测试：同 seed 重复执行，trace 逐 tick 一致。
5. 熔断测试：超预算脚本在运行时被掐断并写 `BREACH` 标签。

### 通过条件

- 三份演示契约源码 100% 通过校验并产生预期 trace。
- 非法脚本 100% 被拒（静态可判的全部静态拒绝）。
- VM 单场战斗 tick 数 < 上限，且任何情况下不会死循环或实体泄漏。
- headless 测试全绿（`godot --headless -s tests/run_headless.gd`）。

## 8. 场景与 UI 细节（灰盒标准）

- **ForgeScene**：三个工序小面板（温控滑杆 + 时间条 / 锻打热图 16×32 网格点击 / 热处理三选项），每次操作实时刷新 4 维完成度读数与缺陷提示；完成按钮 → 生成 `WeaponFacts`。
- **AltarScene**：底部对话气泡 + 右侧事实卡片（可点击引用）+ 契约预览（可读描述 + 参数 + 代价 + 反制 + 引用的事实）+ 预算条；按钮：提交 / 接受代价选项 / 确认契约 / 放弃。
- **TrialScene**：同一战斗 sim 的演示实例（固定 seed + 固定输入脚本）；底部时间线（事件标记可点击）、慢放 0.25×/0.5×、暂停、重播、返修（在时间线上选问题 + 保留项/改项/不可接受项）、从历史版本定稿。
- **BattleScene**：1 名守卫勇者 vs 3 台石甲傀儡（灰盒）；干预按钮：集火 / 保护 / 过载（授权触发契约）/ 撤退；HUD 显示计数器（如"回振 0/3"）与契约状态。
- **ReportScene（并入 Battle 结算）**：按武器汇总 触发次数 / 有效收益 / 浪费 / 代价支出 / 缺陷触发 / 联动 / BREACH 熔断 / 建议。

## 9. 排期（15h+/周，约 5 周）

| 周 | 任务 | 出口（验收点） |
| --- | --- | --- |
| W0.5 | MechanLang lexer/parser/checker/VM + 3 份契约源码 + 非法脚本与确定性测试 | headless 测试全绿；非法脚本全被拒 |
| W1 | 数据模型、WeaponFacts、fingerprint、假神接口 + gdUnit4 测试 | `core` headless 测试全绿 |
| W2 | Sim + MechLang VM 接入 + 契约 B 跑通；ForgeScene + AltarScene（假神） | 手搓一把战锤 → 契约 B → 战斗中触发"回雷" |
| W3 | TrialScene（幻境 + 返修）+ 契约 A/C；BattleScene 完整干预与战报 | 三契约全可演示、可返修、可定稿 |
| W4 | 流程串联（main 导航）、体验打磨、5–10 人试玩、按反馈修复 | 验收标准全部达到 |

**风险门（W2 结束必须过）**：如果不能"造一把锤子 → 拿到契约 → 战斗中清晰触发并看懂代价"，停下来改核心（sim / MechLang / 契约结构），而不是继续加内容。

## 10. 与 Mod 原型的复用/区分

复用（理念与数据结构）：WeaponFacts 白名单格式、DivineTurn 结构、静态校验 + 反例测试 + 编译链的顺序、神裁幻境"先演示后定稿 + 有限返修"、三个演示机制、防幻觉（引用真实 fact_id）原则。

复用（升级）：Minecraft 原型的"EffectBlueprint 有限原语图"在本项目中升级为 MechLang（可变量、可嵌套、可组合的语言），AI 产出从"技能图"变为"程序"。

不复用（MC 专属）：Tetra 适配、datapack 编译/reload 挂载、Forge 事件适配、Minecraft 实体系统。

## 11. 立即开工时的第一组任务

1. 建 `godot-prototype/` 目录与 `project.godot`（4.6/4.7）。
2. `core/mechlang/`：lexer → parser → checker → vm（先跑通"回雷"源码）。
3. `core/runtime/rng.gd`（SplitMix64）+ 最小 sim 骨架（固定 tick、实体表、event log）。
4. `core/mechlang/tests/`：3 份契约源码 + 10+ 条非法脚本 + 确定性/熔断测试（headless 运行）。
5. `core/weapons/weapon_facts.gd`：从"部件+尺寸+工序输入"生成 facts 与 fingerprint。
6. 三个契约的 MechLang 源码（`data/fixtures.gd`）先以"假数据→校验→模拟"跑通。
