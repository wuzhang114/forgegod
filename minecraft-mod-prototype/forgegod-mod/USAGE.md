# ForgeGod MOD 使用说明

> 原型版本：`0.1.0`  
> Minecraft：`1.20.1`  
> Forge：`47.4.10`  
> Java：`17`  
> Tetra：`6.17.0`  
> Mutil：`6.3.0`

## 1. 这是什么

ForgeGod 是“锻造之神”玩法的 Minecraft 原型 MOD。当前版本用于验证以下技术链：

```text
放置神裁砧
    -> 创建候选 EffectBlueprint
    -> 编译 Tetra-compatible 数据
    -> 写入当前世界 generated datapack
    -> reload 资源
    -> 尝试挂载到神裁砧中的 Tetra 武器
    -> 反馈返修或定稿
```

当前版本支持 DeepSeek 云端 AI、真实火花小精灵实体和神裁砧 GUI。玩家主流程不需要输入命令：右键神裁砧即可使用工作台界面。AI 每次只给出一套建议，玩家可以在同一个真实输入框里写申请或返修意见。AI 密钥可以在游戏主页面配置，也可以通过环境变量提供；不会写入世界存档、聊天或日志。

## 2. 安装试玩版

### 2.1 必需环境

- Minecraft Java Edition `1.20.1`。
- Forge `47.4.10`。
- Java 17，64 位。
- Tetra `6.17.0`。
- Mutil `6.3.0`。

### 2.1 配置云端 AI（可选）

#### 游戏主页面配置（推荐）

启动 Minecraft 到主页面后，点击“锻造之神 AI 设置”按钮：

1. 在输入框粘贴 DeepSeek API Key。
2. 点击“保存”。
3. 返回主页面并进入世界即可使用。

密钥会保存到当前 Minecraft 实例的：

```text
config/forgegod-client.properties
```

文件只保存在本机，不会写入世界存档、聊天或日志。“清除本机密钥”只删除这个文件；如果环境变量仍然存在，环境变量会继续生效。

#### 环境变量配置（可选）

也可以在启动 Minecraft 的同一个系统用户环境中设置：

```text
DEEPSEEK_API_KEY=你的密钥
```

环境变量优先于主页面保存的本机密钥。可选覆盖：`DEEPSEEK_API_ENDPOINT`、`DEEPSEEK_MODEL`。不设置密钥时，MOD 仍可用内置候选运行，AI 请求会失败但不扣返修次数。专用服务器没有主页面按钮，建议在服务器进程环境中设置环境变量。

把以下三个 MOD 文件放进同一个 Minecraft 实例的 `mods` 文件夹：

```text
tetra-6.17.0.jar
mutil-1.20.1-6.3.0.jar
forgegod-1.20.1-0.1.0.jar
```

Tetra 和 Mutil 不会被 ForgeGod JAR 自动替代或打包。版本不匹配时，Forge 可能拒绝加载，或 Tetra 的 Mixin 无法启动。

ForgeGod JAR 位于：

```text
D:\Game-Idea-Workshop\minecraft-mod-prototype\forgegod-mod\build\libs\forgegod-1.20.1-0.1.0.jar
```

### 2.2 创建测试世界

建议使用创造模式新建单人世界。当前原型会在世界目录的 `datapacks` 下创建：

```text
<世界目录>/datapacks/forgegod-generated/
```

这个目录是当前世界专用的候选数据包，不要手动改名或移动其中的文件。

## 3. 最短试玩流程（GUI 主流程）

### 第一步：取得神裁砧

在游戏聊天框输入：

```text
/give @s forgegod:divine_anvil
```

放置神裁砧，并右键打开神裁砧 GUI。把 Tetra 武器放入左侧武器槽，把矿石/供物放入右侧供物槽。武器槽中的物品会由服务器读取事实，不需要玩家把武器一直拿在手上。

注意：右键神裁砧时，主手物品不会被消耗，也不会立即写入正式契约。

### 第二步：查看武器事实

GUI 左侧的“事实卡片”会显示武器名称、耐久、供物和 Tetra 读取状态。事实来自服务端菜单槽位，客户端不能自行伪造。`/forgegod facts` 仍保留给开发测试。

### 第三步：提出申请

在 GUI 顶部输入框写下申请，例如：

```text
连续命中同一目标后召来围绕勇者飞行的火花小精灵
```

点击“请神”。系统会：

1. 把武器事实和申请发送给 DeepSeek。
2. 返回一套候选方案，包含名称、效果描述、触发次数、小精灵数量、持续时间、冷却和耐久代价。
3. 服务端校验候选；API 失败或校验失败不会扣返修次数。

候选会直接保留在神裁砧中，不再进入神裁幻境。点击“编译候选”会写入 generated datapack 并 reload；完成后可以点击“定稿绑定”。

AI 只返回受控蓝图字段，服务端会再次校验数值、事实引用和可执行范围。

### 第四步：自由返修

如果方案不满意，在同一个输入框写下自己的反馈，例如“保留环绕，但小精灵应优先攻击被标记目标，且耐久代价不能超过 2”，点击“返修”。锻造之神会给出一套修改方案并替换当前候选。返修次数显示在 GUI 右上角。

返修会把上一版蓝图和反馈发给 DeepSeek。API 失败、解析失败、编译失败或 reload 失败都不会扣返修次数。命令 `/forgegod ask` 和 `/forgegod repair` 仍可用于无 GUI 的自动化测试，但不是普通玩家必需流程。

### 第五步：定稿或放弃

候选编译成功后，点击“定稿绑定”。契约会写入神裁砧 GUI 选中的武器 ItemStack。正式战斗中连续命中达到蓝图次数后会召唤小精灵，触发冷却并消耗武器耐久。同一把武器一旦定稿，就不能再次请神。关闭 GUI 不会清除候选；`/forgegod abandon` 可清除尚未定稿的当前申请。

按住 `R` 并将鼠标移到已定稿武器上，可以查看神裁属性，包括修订号、命中条件、小精灵数量、持续时间、冷却和耐久代价。松开 `R` 后只保留契约名称提示。

## 4. 命令速查

| 命令 | 作用 |
|---|---|
| `/forgegod help` | 显示命令帮助 |
| `/forgegod facts` | 查看主手物品的基础武器事实 |
| `/forgegod trial` | 编译当前候选、写入数据包并 reload |
| `/forgegod ask <申请>` | 调用 DeepSeek 生成候选蓝图 |
| `/forgegod repair <反馈>` | 消耗一次有效返修机会并创建下一候选 |
| `/forgegod accept` | 定稿当前已编译的候选 |
| `/forgegod abandon` | 清除当前候选会话 |

普通玩家不需要输入上述命令；命令仅用于开发测试和故障复现。

## 5. 候选文件在哪里

成功执行 `/forgegod trial` 后，候选数据会写入：

```text
<世界目录>/datapacks/forgegod-generated/
├─ pack.mcmeta
├─ data/tetra/item_effects/forgegod/<候选 UUID>/spark_sprites.json
├─ data/tetra/improvements/shared/forgegod/<候选 UUID>.json
└─ data/forgegod/manifest/candidate_<版本>.json
```

候选 UUID 由系统生成，玩家输入不能控制文件路径、namespace 或文件名。编译器只接受受控的蓝图字段，不接受命令、函数、任意 NBT 或任意资源路径。

## 6. 构建开发版

源码工程位于：

```text
C:\Users\31353\Documents\ChatGPT\game\forgegod-mod
```

工程使用 Gradle Wrapper 8.5。建议使用 JDK 17：

```text
gradlew.bat build
```

构建产物：

```text
build/libs/forgegod-1.20.1-0.1.0.jar
build/libs/forgegod-1.20.1-0.1.0-sources.jar
```

启动开发服务器：

```text
gradlew.bat runServer
```

开发服务器只使用工程内的 `run/` 目录，不会使用你的正式 Minecraft 存档。首次构建需要下载 Forge、Minecraft 映射、Tetra 和 Mutil 依赖，耗时可能较长。

### 一键启动开发测试客户端

在以下目录双击：

```text
C:\Users\31353\Documents\ChatGPT\game\forgegod-mod\run-test-client.bat
```

脚本会自动执行 `gradlew.bat runClient`，启动隔离的 Forge 1.20.1 开发客户端。它使用工程内的 `run/` 目录，不会打开或修改 PCL 的 `1.20.1-Forge` 实例。脚本不会主动读取或输出 API 密钥；如果系统环境中已设置 `DEEPSEEK_API_KEY`，开发客户端会自动继承它，也可以在开发客户端主页面通过“锻造之神 AI 设置”保存到 `run/config/forgegod-client.properties`。

## 7. 常见问题

### MOD 启动时报 Tetra Mixin 错误

优先检查：

- 是否确实使用 Forge `47.4.10`。
- Tetra 是否为 `6.17.0`。
- Mutil 是否为 `1.20.1-6.3.0`。
- 是否把 Fabric/NeoForge 版本误放进 Forge 实例。

不要把不同 Minecraft 小版本的 Tetra 文件混用。

### `/forgegod trial` 提示 reload 失败

检查当前世界目录是否可写，以及 `datapacks/forgegod-generated` 是否被杀毒软件或其他程序锁定。删除候选前先退出世界；如果仍失败，重新创建一个测试世界。

### Tetra 挂载显示 `false`

这通常表示神裁砧武器槽中的物品不是 Tetra 模块化物品，或者该物品没有可接受候选 improvement 的主模块。候选 JSON 仍可能已经写入 generated datapack，但不会被普通原版剑直接识别。

### 为什么 AI 请求失败

先检查主页面“锻造之神 AI 设置”中的当前来源；如果使用环境变量，确认 `DEEPSEEK_API_KEY` 在启动游戏的环境中可见，再检查网络、endpoint 和模型名。失败不会销毁当前候选；可继续使用内置候选或稍后重试。

## 8. 当前版本限制

- 没有 Create/Ponder 依赖；当前版本暂不创建神裁幻境、镜头或测试人偶。
- GUI 支持自由申请和自由返修输入，每轮只显示一套 AI 建议；`/forgegod ask` 仅作为无 GUI 的开发测试入口。
- 目前主要运行时效果是 ON_HIT 火花小精灵；ON_HURT、ON_KILL 和区域节点仍在扩展。
- 契约写在武器 ItemStack NBT；当前候选状态保存在服务器运行期间，重启服务器后需要重新申请。
- 神裁砧 GUI 当前显示核心事实、单套候选和真实输入框；完整对话历史仍未加入。

当前版本的目的不是提供完整玩法，而是让开发者能够确认：Forge + Tetra 环境能启动，候选蓝图能编译，generated datapack 能写入并 reload，且返修状态机可以被实际操作。
