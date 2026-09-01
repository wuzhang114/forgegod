# ForgeGod Minecraft MOD 原型

完整中文使用说明见 [USAGE.md](USAGE.md)。
本轮实际实现清单见 [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md)。

当前原型锁定 Minecraft 1.20.1、Forge 47.4.10、Java 17、Tetra 6.17.0 和 Mutil 6.3.0。

## 当前已实现

- `forgegod:divine_anvil` 神裁砧方块。
- `EffectBlueprint` 结构化候选模型和基础预算校验。
- Tetra-compatible item effect/improvement JSON 编译器。
- 当前世界 `datapacks/forgegod-generated` 的安全写入、启用、reload。
- `TetraWeaponAdapter` 与候选 improvement 挂载桥接。
- 候选版本、2 次返修、历史候选和定稿状态机。
- DeepSeek 云端神谕 Provider（可通过主页面按钮配置本机密钥，也可使用 `DEEPSEEK_API_KEY`；环境变量优先）。
- 真实火花小精灵实体、寿命/环绕/索敌/魔法伤害/水中熄灭。
- 神裁砧内的候选编译、返修和定稿绑定流程；当前版本不创建神裁幻境或临时镜头。
- 神裁砧 BlockEntity/Menu/Screen，以及定稿契约绑定和 `ON_HIT` 战斗运行时。
- GUI 主流程支持真实文本输入、单套 AI 建议、自由返修输入和定稿绑定；命令仅保留为开发测试入口。
- 开发测试命令入口（普通玩家使用 GUI）：

```text
/give @s forgegod:divine_anvil
/forgegod facts
/forgegod trial
/forgegod ask <自然语言申请>
/forgegod repair <反馈>
/forgegod accept
/forgegod abandon
```

启动游戏后，主页面新增“锻造之神 AI 设置”按钮，可直接输入、保存或清除本机 DeepSeek API Key。保存位置是当前实例的 `config/forgegod-client.properties`；如果同时设置了 `DEEPSEEK_API_KEY`，环境变量优先。进入世界后，把神裁砧放下并右键，GUI 可以发起 AI 神谕、返修、编译候选和定稿绑定。每把武器只允许建立一次神谕申请；定稿后不能再次请神。API 不可用时不会扣返修次数，仍可保留当前候选。

## 构建

需要 JDK 17。工程自带 Gradle Wrapper 8.5：

```text
gradlew.bat build
gradlew.bat runServer
```

Windows 下也可以直接双击工程根目录的 `run-test-client.bat` 启动隔离的 Forge 开发客户端。它使用工程内的 `run/` 目录，不会启动或修改 PCL 的实例；当前系统环境中的 `DEEPSEEK_API_KEY` 会自动传给开发客户端，也可以在该开发客户端主页面通过“锻造之神 AI 设置”保存到 `run/config/forgegod-client.properties`。

开发服务器只使用工程内的 `run/` 目录。正式发布前仍需补齐更多 Tetra 槽位适配、供物消耗规则和跨存档契约持久化测试。
