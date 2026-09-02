## forgegod Godot 开发脚本(等价 MCP 的命令行工作流)。
## 用法见 docs/godot-devkit.md §4。
## 注意: Godot 控制台输出走 stderr,所有调用必须 2>&1 合并。
param(
	[string]$Action = "test",
	[string]$Scene = "scenes/battle/battle_demo.tscn",
	[string]$Diag = "tests/diag_cast.gd"
)

$Godot = "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$Project = Join-Path $PSScriptRoot "..\godot-prototype"

switch ($Action.ToLower()) {
	"test" {
		Write-Host "== 全量测试(检查无 SCRIPT ERROR/Compile/FAIL) ==" -ForegroundColor Cyan
		& $Godot --path $Project --headless -s tests/run_headless.gd 2>&1
	}
	"run" {
		Write-Host "== 启动 $Scene ==" -ForegroundColor Cyan
		& $Godot --path $Project $Scene 2>&1
	}
	"import" {
		Write-Host "== 资源导入(新贴图/音频后) ==" -ForegroundColor Cyan
		& $Godot --path $Project --headless --import 2>&1
	}
	"smoke" {
		Write-Host "== 冒烟: $Scene (150 帧) ==" -ForegroundColor Cyan
		& $Godot --path $Project $Scene --quit-after 150 2>&1
	}
	"diag" {
		Write-Host "== 诊断: $Diag ==" -ForegroundColor Cyan
		& $Godot --path $Project --quit-after 900 -s $Diag 2>&1
	}
	"quit" {
		Get-Process "godot.windows.opt.tools.64" -ErrorAction SilentlyContinue |
			Stop-Process -Force
		Write-Host "已关闭 Godot 窗口" -ForegroundColor Cyan
	}
	default {
		Write-Host "用法: devkit.ps1 <test|run|import|smoke|diag|quit> [-Scene ...] [-Diag ...]" -ForegroundColor Yellow
	}
}
