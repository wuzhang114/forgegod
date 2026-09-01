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
| `00-m1-plan.md` | M1 假神闭环 + MechLang 语言定义(v0.1→v0.3) |
| `01-mechanism-catalog-100.md` | 100 机制目录(A 88 / B 9 / C 3) |
| `02-battle-system-design.md` | 战斗设计 v1: 六区乘区/25 态/判定链/节点路线图/播放器 |

## 目录速览

```text
core/mechlang/      MechLang 语言(lexer/parser/checker/vm/host_api)
core/runtime/       battle_sim / damage_chain / sim_entity / sim_contract / rng
scenes/battle/      battle_demo(战斗播放器灰盒版)
tests/              run_headless 主入口 + 各类测试
```
