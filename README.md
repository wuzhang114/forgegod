# 锻造之神 · ForgeGod

> 一款以"铁匠铺经营、武器锻造、与 AI 扮演的锻造之神交涉、小队验证"为核心的西幻游戏(独立开发,原型阶段)。
> 核心主张:**玩家打造一把有材料、工艺、缺陷和历史的武器,与锻造之神共同发明一种此前没有的机制,再亲眼在战斗中承担它的后果。**

## 一句话理解这个项目

玩家经营铁匠铺,用部件与材料打造武器 → 向由 AI 扮演的锻造之神用自然语言申请"神赐机制"(不是从技能列表选!)→ 神明基于**武器的事实档案**(材料/工艺/缺陷)质询、还价、驳回或应允 → 契约编译为可执行的机制图 → 武装间调配装备 → 在**六边形棋盘自走棋战场**上验证 → 战报回炉(奖赏/伤势/日推进),驱动下一把武器。

## 仓库结构

| 路径 | 内容 |
|---|---|
| `游戏设计文档(根目录)` | 愿景/核心玩法/剧情/机制生成/本地 AI 部署等早期企划(历史设计,当前以代码为准) |
| `scripts/` | 文档生成工具 + Godot 开发脚本(devkit.ps1) |
| `docs/` | 专题文档(自走棋源码研究 / Godot 开发工具包) |
| **`godot-prototype/`** | **独立游戏原型(Godot 4.x / GDScript,唯一主要开发线)** |
| `godot-prototype/app/` | 应用根:GameApp(autoload)/ RunState(唯一事实来源)/ AppRouter / SaveRepository |
| `godot-prototype/domain/` | 领域层:战斗 / 武器 / 内容注册表 / 经济 / 谈判协议 |
| `godot-prototype/application/` | 应用层用例:日结算 / 装备用例 / 神祇适配器工厂 |
| `godot-prototype/adapters/` | 适配器:脚本神 / 本地 AI / **云端 AI(真实裁决)** / 连接探针 / 上下文预加载 |
| `godot-prototype/data/` | 判例库(mechanism-library.json,47 条神赐蓝图) |
| `session-log.md` | 开发日志(设计决策/踩坑记录) |

> 层级:场景 UI → Application 用例 → Domain 规则 → 数据资源(ContentRegistry);
> 数值唯一源 `balance.gd`;内容唯一源 `ContentRegistry`;状态唯一源 `RunState`。
> **玩家存档(user://)从不入库**;仓库禁止任何 `run/`、`saves/`、`build/` 目录与 `.dat` 文件(gitignore 强制)。
> 历史说明:早期 Minecraft Mod 原型(含其 MC 世界存档)已彻底移除——需要时仅可凭 git 历史追溯,不再入库。

## godot-prototype 快速开始

```powershell
# 运行全部测试(163 项断言)
godot --headless --path godot-prototype -s res://tests/run_headless.gd

# 完整玩家闭环:锻造台 → 神裁砧交涉 → 武装间 → 棋盘战斗 → 日结算回炉
godot --path godot-prototype scenes/forge/forge_scene.tscn

# 开发工具(等价 MCP 的命令行工作流)
.\scripts\devkit.ps1 test|run|smoke|diag|quit
```

## 原型技术亮点(均已实测)

- **MechLang 受限机制语言**:AI/假神输出可静态校验的机制代码(解析→白名单→预算→确定性 VM);模型生成 30/30(100%)通过,错误可结构化回环修复。
- **AI 锻造之神(云端真实裁决)**:DeepSeek 官方端点,按 PROMPT_god 协议输出 `DivineTurn`(质询/还价/应允/驳回 + 事实引用 + MechLang 草案 + **AI 生成的技能描述 summary**);开始界面保存 API 即检测连接(探针:端点自动补全/密钥误填拦截/错误原文透传)并预加载上下文(协议+武器档案+判例库);交涉异步不卡 UI;草案校验失败自动回环纠正,仍失败则展示描述降级(不死局)。
- **神前交涉验证**(脚本神):4 武器 × 20 申请,20/20 通过四道防线。
- **六边形棋盘自走棋战斗**:确定性离线模拟(20Hz,种子+输入决定一切)+ 逐 tick 快照重放;六区伤害乘区;25 态(DoT 跳伤/叠层×3);金铲铲式索敌(目标粘性/受击转火/嘲讽/控制/缴械/缄默/攻速);棋盘格效果层;远程弹道延迟命中;契约 traits 真实生效;主动技动态按钮(设备名);重击触发契约提示需守卫装备。
- **武器库/武装间**:神裁后多武器界面——装备/换装/卸下(一把武器一人持有),默认三把演示武器(誓约盾锤/嗜血之刃/灼烧之弓)自带契约;四维→战斗面板 100% 同源(ForgeCalculator)。
- **经营垂直切片**:锻造耗材、战斗结算(赏金/声望/日+1/伤势/休整、幂等)、RunState 全程持久(存档/读档)。

## 设计文档索引(概念 → 系统)

| 文档 | 内容 |
| --- | --- |
| `game-plan.md` | 对外项目愿景(已定案的核心内容) |
| `core-gameplay-design.md` | 三层武器结构/模块化锻造/神赐交涉/最小可玩版本 |
| `ai-mechanism-generation.md` | 开放式机制生成:三种自由/MechLang/机制数据集/模型路线 |
| `godot-prototype/02-battle-system-design.md` | 战斗设计:六区乘区/25 态/判定链/节点路线图/播放器 |
| `godot-prototype/05-forge-design.md` | 锻造系统(Tetra 式面板决策版) |
| `godot-prototype/00-m1-plan.md` | M1 假神闭环与 MechLang 语言定义(v0.1→v0.5) |
| `godot-prototype/tests/negotiation/PROMPT_god.md` | AI 神协商协议(裁决姿态/事实引用/输出格式) |
| `docs/autochess-research.md` | 自走棋开源项目源码调研(6 项目 → 可落地建议) |
| `docs/godot-devkit.md` | Godot 官方文档入口/Skills/MCP 选型/devkit 工作流 |
| `session-log.md` | 开发日志:设计决策、踩坑记录、每日交付 |

## 状态

- 核心循环(锻造→神裁(AI/脚本可切)→武装→战斗→结算回炉)已可完整游玩;**云端 AI 神真实裁决已贯通**(探针/预加载/异步交涉/自纠错)。
- 测试:godot-prototype **163/163** 断言全绿;四场景冒烟无脚本错误。
- 待做:多轮交涉与判例库沉淀、出征路线图 UI、Local AI 适配器实装、正式美术。

---

*仓库名暂为临时占位;项目内部工作名"余火铁匠铺"、神明"赫铎恩"均为可替换占位名。*
