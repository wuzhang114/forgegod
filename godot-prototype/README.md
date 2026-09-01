# ForgeGod 原型(Godot 4.7)运行指南

> 像素 2D · 铁匠铺 × 锻造之神 × 自走棋式战斗验证 · 核心逻辑全部 headless 可测。

## 环境

- Godot 4.6+ (本机 Steam 版: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`)
- 命令示例: `$GODOT = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"`

## 1. 战斗演示(B3.6:六边形棋盘 · 斜俯视 · 纸片人 · HD-2D 夜战)

```powershell
& $GODOT --path D:\Game-Idea-Workshop\godot-prototype scenes/battle/battle_demo.tscn
```

- 流程: **布阵(拖动 3 名勇者排兵,玩家区 2 行)→ 开始战斗 → 自动战斗(离线确定性模拟 + 逐 tick 快照播放)**
- 操作: 0.5×/1×/2× 变速 · 暂停/继续 · 跳到结束
- 表现语言: 六边形棋盘(8×5,斜俯视压扁)、纸片人(转向/攻击时绕竖轴翻面、攻击摆动)、HD-2D 氛围(夜云天光/远山剪影/月晕/前景暗角)
- 飘字: MISS(灰) / 伤害(红) / **神赐伤害(金)** / 格挡!(蓝) / 打断!(紫) / 破甲!(橙) / 击倒!(粉)
- HUD: 【蓄能盾击】储能 x/8(逐 tick 快照,与画面严格同步)
- 契约: 守卫·布兰特挂载 [蓄能盾击](格挡积能 → 满 8 重击释放 → 可过载)

## 2. 自动化测试(145 项断言)

```powershell
& $GODOT --headless --path D:\Game-Idea-Workshop\godot-prototype -s res://tests/run_headless.gd
```

覆盖:
- MechLang 词法/解析/静态校验/VM 执行/熔断/确定性(回雷、星火之约等 40+ 契约)
- 88 条机制目录(魔兽/宝可梦/星穹铁道/以撒等 22+ 游戏机制)自动验证
- 战斗 sim: 判定链六区公式 / 动作帧 / 金铲铲对照规则(受击转火/控制打断/嘲讽/缄默/缴械/攻速) / 3vN 全流程 / 同 seed 确定性

## 3. 文档索引

| 文档 | 内容 |
| --- | --- |
| `00-m1-plan.md` | M1 假神闭环 + MechLang 语言定义(v0.1→v0.5) |
| `01-mechanism-catalog-100.md` | 100 机制目录(A 88 / B 9 / C 3) |
| `02-battle-system-design.md` | 战斗设计 v1: 六区乘区/25 态/判定链/节点路线图/播放器 |
| `03-ai-generation-validation.md` | AI 生成 MechLang 验证(30/30 + 修复回环) |
| `04-negotiation-validation.md` | 神前交涉验证(20 案 ×4 武器,20/20) |
| `05-forge-design.md` | 锻造系统设计(Tetra 式面板决策版) |

## 架构分层(数值/语言/逻辑/表现解耦)

```text
core/config/balance.gd       ★ 唯一数值源: 命中/暴击/六区公式/动作倍率/单位模板/25 态调度
core/mechlang/               MechLang 语言引擎(lexer→parser→checker→vm)→ 机制契约
core/forge/forge_core.gd     锻造轴: 材料表(8)→ 四维 → 缺陷 → 事实卡片 → fingerprint
core/negotiation/            假神 ScriptedGod(关键词裁决,DivineTurn 协议)
core/runtime/                battle_sim(六边形自走棋)/ damage_chain(六区)/ rng(确定性)
core/flow/game_session.gd    跨场景会话(锻造→交涉→契约→战斗)
scenes/                      表现层: forge/altar/battle(只消费 core 数据)
tests/                       headless 测试(148 断言): 语言/战斗/锻造/假神/数值
```

铁律: 数值只在 balance.gd(锻造轴数值在 forge_core);core 不引用 Node/场景;一切可 headless 测试;一切确定性(同 seed 同事件流)。

## 目录速览

```text
core/config/       balance.gd(唯一数值源)
core/mechlang/     MechLang 语言(lexer/parser/checker/vm/host_api)
core/forge/        锻造核心(材料/四维/缺陷/事实/fingerprint)
core/negotiation/  假神(关键词裁决)
core/runtime/      battle_sim / damage_chain / hex_grid / sim_entity / sim_contract / rng
core/flow/         game_session(跨场景会话)
scenes/            forge(锻造台)/ altar(神裁砧)/ battle(棋盘战斗)
tests/              run_headless 主入口 + 各类测试(148 断言)
```
