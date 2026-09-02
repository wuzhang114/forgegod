# 自走棋开源项目调研报告

> 日期: 2026-09-02 · 目的: 学习开源自走棋项目的代码思路,为我方 Godot 六边形自走棋战斗
> 调研方式: 两个子代理并行 clone 源码研读(模拟器组 + 工程组),源码在 `_research/`(已 gitignore)

## 一、结论速览(30 秒版)

- 最强参考 = **pokemonAutoChess**(商业级:FSM 索敌 + command 化攻击调度 + 每格效果集 + 数据驱动羁绊)+ **teamfight-simulator**(TFT 模拟器:GameEffect 效果对象 / 前摇弹道 / 三层模型)
- 我们已覆盖:确定性模拟、快照重放、TFT 索敌、集中数值源 —— 与主流做法一致甚至更正统(种子+快照)
- 最大差距:① **攻击"即时命中"**,无前摇/弹道/延迟命中;② **缺批量胜率模拟工具链**;③ 棋盘是**纯占位**,无"每格效果/地形修饰"层;④ 数值还可更表驱动

## 二、项目逐个分析

### 1. teamfight-simulator(TypeScript+Vue3, TFT 战斗模拟器)⭐最高参考
- 30Hz tick;逻辑格 `activeHex` 与视觉坐标 `coord` 分离(插值)
- **GameEffect 效果对象系统**:基类 + Hex/MoveUnit/Projectile/Shape/Target 子类,`update(elapsedMS, diffMS)` 返回 false 移除,带 startsAt/activatesAt/expiresAt 调度 → 前摇(windupMS=攻击间隔/4)、弹道(速度/travelTime/bounce)统一复用
- 数据驱动:冠军/装备/羁绊/强化均为数据文件,效果按名注册函数表;伤害 = `SpellCalculation` 声明式树(parts/subparts/星数表/stat 比值/封顶)
- 索敌:范围内最近敌 + `wasInRange`/`movesBeforeDroppingTarget=3` 目标粘性;寻路从目标格 BFS 找相邻可走格
- 伤害公式与我方几乎同构(攻击×倍率×增伤→护甲 100/(100+def)→暴击→护盾→回蓝→死亡)
- README 明确**三层模型**:层1 确定性模拟 / 层2 可读 tick / 层3 动画 —— 与我们快照回放完全共鸣
- 弱点: `Math.random()` 非确定性;无批量胜率工具;Vue 活体渲染而非快照

### 2. pumpkye/AutoChess(Cocos2.x+TS, 核心抽成 AutoChessBattle)⭐胜率工具链
- **20Hz tick**(与我们一致);毫秒计时,60s 超时
- **随机流录制回放**:quick/test 模式生成的随机数 push 进 `_randomSet`,回放模式按序 shift 消费 → 不存快照也能确定性重放(轻量,但只能从头重放,不能任意 seek)
- **headless 核心解耦**:AutoChessBattle 可独立 Node 运行,~300 对局/秒 → 批量随机阵容胜率统计
- 行动队列:每 tick 存活单位按 speed 降序(平局 thisId),speed=先手;技能=普攻(skill,CD=100·ATTACK_BASE_TIME/attSpeed)
- 索敌:当前目标存活即锁定,否则曼哈顿最近敌;移动:步进式找"可走且可攻到目标"的格,`_lockTime` 锁定;刺客跳最远后排
- 伤害:护甲衰减 `1-k1·def/(k2+k3·def)`(k=0.04,def=25≈50% 减伤);魔法 (100-mDef)/100;回蓝 floor(dmg/10);DPS 统计
- 数值:data/npc.xlsx → tools/json2Json.py → Tbx/*.ts;护甲曲线/羁绊门槛集中在 Config
- 弱点: 代码质量差(console.log/eval/无测试);攻击即时无前摇弹道;旧版引擎

### 3. cingfong/AutoChess(纯 HTML/JS 九宫格 PvE) — 低质,跳过
- 非 tick,攻击者轮流队列 + setTimeout;仅克制表×2、升星×1.6 可参考,其余(eval/全局 DOM)不学习

### 4. erikstorm/battler(Godot 3.x 小游戏) — 玩具,仅取一格
- 无网格/无 AI/无 tick,拖拽堆叠 + 数值加减
- 强点: `scripts/slot.gd` **自包含可拖拽格子** + 大量 export 开关(increment/group 匹配、canClear/canReceive/半透明 preview),管理数量/血量 HUD —— Godot 复用格子节点的好范本(G3 API,需转 G4)

### 5. pokemonAutoChess(TypeScript+Colyseus+MongoDB+Phaser) ⭐商业级参考
- 棋盘:**扁平一维数组** `cells[columns*y+x]` + **每格 `boardEffects`(Set 地形/羁绊效果)**,进出格自动加/删;几何助手:Chebyshev 索敌、Manhattan、扇形 `getCellsInFront`、supercover 连线、击退落点、传送/飞离
- 单位:显式 **FSM(idle/moving/attacking)**;移动 cooldown=500/移速 每格,`findPath` 最短路径 + `swapCells`;攻击**目标粘性**(原目标在射程续打,否则转最近);pp≥maxPP 且未被缄默→技能,否则普攻
- **command 化攻击调度**:`getAttackTimings`(delayBeforeShoot+travelTime)排 AttackCommand/DelayedCommand,非连续 dt 结算 → 弹道/延迟命中天然可回放
- 伤害:物/特/真伤分离,特伤=伤害×(1+ap/100),暴击×critPower,减伤=伤害/(1+ARMOR_FACTOR·def),护盾吸收;灼烧/毒/麻痹/诅咒
- 羁绊:数据驱动 `SynergyTriggers`(羁绊→阈值数组),按场上各类型唯一数取阶
- 表现:服务端广播 → Phaser 动画管理器(battle-manager/pokemon-animations/life-bar)统一驱动
- 弱点: Colyseus/Phaser 架构重,与 Godot 单机不对应,取"思路"不取"工程"

### 6. tft-modeling(Python 无头沙盒) ⭐宏观数值数据化
- 宏观与微观完全解耦:无战斗模拟,专注经济/商店/卡池
- 纯数据表:`REROLL_PROBABILITIES[level]`(商店费用概率)、`CHAMPION_POOL_SIZES`(卡池剩余数,`get_random_pooled_champions` 从剩余池抽样并扣减)、`XP_TO_LEVEL_UP`、`ROUND_BASE_GOLD_INCOME`/连胜/利息
- 羁绊:traits.json 阈值 levels 数组;物品:组件+合成表反查
- 价值: 商店概率/卡池/经济曲线全部参数化,便于平衡与 AI 沙盒

## 三、与我方架构的对比要点

| 维度 | 我方 | 主流做法 | 差距 |
|---|---|---|---|
| 时间步 | 20Hz 固定 tick | 20-30Hz + 子 tick 效果对象 | 建议保留 20Hz,效果对象做子 tick 粒度 |
| 确定性 | 种子+逐 tick 快照(任意 seek) | 快照(pumpkye 用随机流,只能从头) | 我们最正统;随机流可作"轻量回放"补充 |
| 索敌 | TFT 式(切换/转火/嘲讽/缄默) | 目标粘性 FSM | 方向一致;可显式 FSM 化统一移动/攻击 |
| 攻击表现 | 即时命中 | 前摇(windup)+弹道+延迟命中 command | **最大差距** |
| 数值源 | balance.gd 集中 | 表驱动 + 集中曲线(k 常量)/声明式伤害 | 可进一步表驱动 |
| 平衡工具 | 148 单测 | 批量胜率模拟(~300 局/秒) | **缺失,建议补** |
| 棋盘 | 六边形轴向,纯占位 | 每格效果集(地形/羁绊修饰层) | 可补修饰层(为我们"铸纹格/淬火格"预留) |

## 四、可落地建议清单(按优先级)

| # | 建议 | 依据 | 工作量 | 状态 |
|---|---|---|---|---|
| 1 | **headless 批量胜率模拟工具链**:我们的 sim 已是纯逻辑,加批量入口输出"阵容 vs 阵容胜率表",对齐平衡性 | pumpkye AutoChessBattle(Node 300 局/秒) | 中 | 未做 |
| 2 | **command 化攻击调度 + 前摇/弹道**:攻击排成带 delayBeforeShoot+travelTime 的 command,命中变延迟事件进快照,表现层用弹道/挥击(顺带解决"攻击瞬间扣血"的表现落差) | teamfight-simulator GameEffect/windupMS/ProjectileEffect;pokemonAutoChess simulation-command.ts | 中 | 未做 |
| 3 | **FSM + 目标粘性统一索敌**:显式 idle/moving/attacking + "原目标在射程续打",受击转火/嘲讽/缄默作为目标筛选分支 | pokemonAutoChess moving/attacking-state.ts | 中 | 大部分已有,重构整合 |
| 4 | **每格效果集(地形/羁绊修饰层)**:棋盘格带 Set 效果,单位进出自动加/删;补齐几何助手(扇形/连线/击退落点) | pokemonAutoChess board.ts | 中 | 未做(为后续"铸纹格"预留) |
| 5 | **数值表驱动化**:护甲曲线集中 k 常量(def/(def+k) 衰减)、声明式伤害 calculation、商店/经济类表(未来商店玩法) | pumpkye Config;teamfight-simulator SpellCalculation;tft-modeling 数据表 | 低-中 | 部分已有 |
| 6 | **自包含格子节点 + export 开关**:HexCell.gd 封装轴向坐标/可落子/高亮预览/拖拽校验/血量 HUD(G4 API) | battler slot.gd | 中 | 未做 |
| 7 | **羁绊阈值数组 + 受击表现解耦**:羁绊=阈值数组+场上唯一计数;受击闪白/浮动伤害由"表现层"统一驱动(与结算解耦) | pokemonAutoChess synergies.ts / pokemon-animations.ts | 中 | 未做(羁绊是后续系统) |

## 五、源码位置

- `_research/teamfight-simulator`(TypeScript)
- `_research/pumpkye-autochessbattle`(Cocos/TS, 核心 `AutoChessBattle` 子模块)
- `_research/cingfong-autochess`(低质参考)
- `_research/battler`(Godot 3.x)
- `_research/pokemonAutoChess`(keldaanCommunity/pokemonAutoChess, gitcode 镜像)
- `_research/tft-modeling`(Python)
