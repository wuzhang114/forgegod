# 锻造之神 · ForgeGod

西幻铁匠铺 × 神裁交涉 × 机制战斗的独立游戏原型(Godot 4 / GDScript,**纯本地运行**)。

玩家从材料、工艺、热处理的取舍里打出一把武器,带着它去见锻造之神——不是挑技能,
而是**用自然语言向神申请一个此前不存在的机制**;神会按武器档案(材料、缺陷、
工艺事实)质询、还价或驳回。谈成后,契约编译成可执行的 MechLang 机制,小队带它
上六边形棋盘;打完回铺子,赏金、伤势、库存、天数进入下一把武器的起点。

## 能玩到什么

- **开始菜单**:新游戏/继续/神祇设置(脚本神 · 本地 AI · 云端 AI,保存即探测连接并预加载交涉上下文)
- **铁匠铺据点**:3D 斜俯视,散步、走近设施按 E 交互
- **锻造四步**:熔炼 → 锻打 → 热处理 → 装配,选择全部写进武器事实卡,神只引用这些事实
- **神前交涉**:内置脚本神或 OpenAI 兼容 AI 神(实测 DeepSeek 官方可用);按帧轮询,不卡界面
- **武装间**:给小队三人任意装备/换装;新游戏自带三把演示武器,各带一个演示契约
- **出征地图**:杀戮尖塔式分支地图,6 层 × 每层多节点(战斗/精英/事件/宝箱/篝火/首领),
  可从铁匠铺或武装间出发;**敌人逐层变强**(每层约 +12% 血 / +10% 攻)
- **六边形战斗**:确定性模拟(固定种子+输入),布阵拖动、主动技按钮、逐帧回放;六区乘区
  伤害、DoT、控制、灼烧格、远程弹道
- **日结算**:赏金/声望/天数+1/重伤休整,材料库存支撑锻造消耗

## 运行

```powershell
# 入口(开始菜单)
godot --path godot-prototype

# 全量测试(164 项断言)
godot --headless --path godot-prototype -s res://tests/run_headless.gd
```

常用开发命令封装在 `scripts/devkit.ps1 test|run|smoke|diag|quit`,见 `docs/godot-devkit.md`。

## 仓库结构

- `godot-prototype/` — 游戏本体(场景 → 用例 → 领域 → 数据逐层分离)
  - `scenes/` 开始菜单、铁匠铺据点、锻造台、神裁砧、武装间、出征地图、战斗
  - `core/` MechLang 机制语言、战斗模拟器、数值表
  - `app/` GameApp 单例、RunState、路由、存档
  - `domain/` 领域逻辑(战斗、武器、内容表、经济、谈判、远征)
  - `application/` 用例(日结算、装备、神祇适配器工厂)
  - `adapters/` 外部接口(脚本神、本地/云端 AI、连接探测)
- `docs/` 设计文档(见下)
- `scripts/` devkit.ps1 与文档工具

## 设计文档

| 文档 | 内容 |
|---|---|
| `docs/world-design.md` | 世界观规划:六域舞台、谱系敌人表、材料体系 |
| `docs/forge-upgrade-design.md` | 锻造升级方案:本源属性修正、部件名、适配、铭刻 |
| `docs/autochess-research.md` | 六款开源自走棋源码研读 |
| `docs/godot-devkit.md` | Godot 开发工具包(MCP 选型、devkit.ps1 工作流) |
| `game-plan.md` 等 | 早期企划稿(系统边界以代码为准) |

## 说明

- API 密钥与游戏存档只在本机用户目录;仓库排除一切 `run/`、`saves/`、`build/` 目录与 `.dat` 文件
- 云端 AI 神可替换:适配器接口在 `domain/negotiation/divine_adjudicator.gd`,
  换模型或接本地推理只需适配 `adjudicate(facts, app) -> DivineTurn`
- AI 神给的契约草案若没过 MechLang 校验,会给它一次修正机会;仍不行则以文字描述为准展示
