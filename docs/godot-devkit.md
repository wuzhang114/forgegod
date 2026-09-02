# Godot 开发工具包(官方文档 · Skills · MCP · 命令行工作流)

> 2026-09-02 调研归档。目标:围绕 forgegod(Godot 4.7.2 GDScript)建立文档/工具/工作流三件套。

## 1. 官方文档(入口优先)

| 链接 | 用途 |
|---|---|
| https://docs.godotengine.org/zh-cn/4.x/ | Godot 官方文档(中文,多版本;4.x 即当前主线,与 4.7 兼容) |
| .../tutorials/scripting/gdscript/gdscript_styleguide.html | **GDScript 风格指南**(命名/类型/缩进;AI 生成代码以它为准) |
| .../tutorials/scripting/gdscript/ | GDScript 教程(静态类型/await/信号) |
| .../tutorials/scripting/scenes_and_nodes/ | 场景与节点组织 |
| .../tutorials/best_practices/ | 项目最佳实践(项目结构/逻辑分层) |
| https://godotengine.org/asset-library/ | Godot 资产库(MCP 插件等) |

### 本项目长期踩坑 → 官方条款对照

| 本项目教训 | 官方对应条款 |
|---|---|
| `var x := dict.value` / `arr[i]` 编译失败,必须显式类型 | 静态类型(类型推导对 Variant 不推断) |
| 任何"依赖脚本编译失败"都会假绿 | `--headless -s` 测试要 grep `SCRIPT ERROR|Compile` |
| tween 被 sync 冻结 | Tween 生命周期:持有引用、完成/杀死时点 |
| 状态衰减 50×、硬控不禁移动 | 状态机语义:明确 20Hz tick 与行为接线 |
| const 不能调用 deg_to_rad | 常量表达式限制 |
| UI 外露 tick | 单位与展示分离(内部 tick / 展示秒) |

## 2. 已安装 Skills(本机全局,`npx skills` 生态)

| skill | 来源 | 安装量 | 用途 |
|---|---|---|---|
| `godot-gdscript-patterns` | wshobson/agents | 14.7K | Godot 4 模式:信号/场景/状态机/优化 |
| `godot-gdscript` | gamedev-skills/awesome-gamedev-agent-skills | 1.9K | Godot 4.7 惯用写法:静态类型/生命周期/@export/@onready/await |
| `godot-nodes-scenes` | gamedev-skills | 1.9K | 场景树组织:PackedScene 实例化/autoload/节点安全访问 |

其他候选(未装,需要时 `npx skills add <owner/repo@skill> -g -y`):
- `zate/cc-godot@godot-ui` (2.5K) / `jwynia/agent-skills@godot-best-practices` (2K)
- `gamedev-skills/awesome-gamedev-agent-skills@` 系列:godot-shaders / godot-animation / godot-ui-control / godot-physics

## 3. Godot MCP 服务(选型)

| 项目 | 能力 | 采用建议 |
|---|---|---|
| **letsagents/godot-mcp** | MCP server + Godot Bridge 插件:**运行时错误 / 场景树 / 节点属性 / 截图**,自纠错循环 | **首选**(反馈闭环与我们诊断工作流最契合;`npx @letsagents/godot-mcp`) |
| **IvanMurzak/Godot-MCP** | C# 编辑器插件:in-editor 模式 console-get-logs / script-validate;Asset Library #5245;Apache-2.0 | 备选(需 Godot C# 支持) |
| **LeeSinLiang/godot-mcp** | npm `@iflow-mcp/leesinliang-godot-mcp`,AI 助手交互 Godot | 备选 |

> 说明:本仓库开发主要在 DeepSeek Harness 环境,不具备 MCP 客户端;下方 `devkit.ps1` 是**等价命令行工作流**(运行/测试/导入/冒烟/诊断),已覆盖 MCP 工具 80% 能力。使用 Cursor/Claude Desktop 等 MCP 客户端时,按上表接入即可。

## 4. 命令行开发工作流(本仓库标准)

```powershell
# 全量测试(155 项;必须检查输出无 SCRIPT ERROR/Compile/FAIL)
.\scripts\devkit.ps1 test

# 运行完整流程 / 单独战斗演示
.\scripts\devkit.ps1 run
.\scripts\devkit.ps1 run -Scene scenes/battle/battle_demo.tscn

# 资源导入(新贴图/音频后)
.\scripts\devkit.ps1 import

# 冒烟(150 帧快速启动场景,抓运行时错误)
.\scripts\devkit.ps1 smoke -Scene scenes/battle/battle_demo.tscn

# 诊断脚本(任意 tests/diag_*.gd)
.\scripts\devkit.ps1 diag -Diag tests/diag_xxx.gd

# 关闭正在运行的 Godot 窗口
.\scripts\devkit.ps1 quit
```

## 5. Godot 二进制与项目路径

- 引擎:`D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`(Godot 4.7.2 Steam,tools/64 位/Compatibility 渲染)
- 项目:`D:\Game-Idea-Workshop\godot-prototype`(唯一主开发线)
- 测试入口:`tests/run_headless.gd`(155 断言;子测试文件 test_*.gd)
