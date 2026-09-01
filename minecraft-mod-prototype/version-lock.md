# 原型版本锁定

> 锁定日期：2026-09-01  
> 状态：规划基线，创建工程时再次验证依赖解析；验证通过后不得自动升级。

## 运行环境

```text
Minecraft: 1.20.1
Mod loader: Forge
Forge: 47.4.10 (Recommended)
JDK: Java 17, 64-bit
Recommended JDK distribution: Eclipse Temurin 17
```

Forge 官方下载页同时列出 Latest `47.4.23`。本原型故意选择 Recommended `47.4.10`，除非 Tetra/Mutil 实测要求更高补丁版本。

## 首发锻造依赖

```text
Tetra: 6.17.0
Tetra CurseForge project id: 289712
Tetra file id: 8570756

Mutil: 6.3.0
Mutil CurseForge project id: 351914
Mutil file id: 7772906
```

```groovy
implementation fg.deobf("curse.maven:tetra-289712:8570756")
implementation fg.deobf("curse.maven:mutil-351914:7772906")
```

## 备选匠魂依赖

首版不加入，只在 Tetra 风险门失败时做 spike：

```text
Tinkers' Construct: 3.11.2.166
Project id: 74072
File id: 7449219

Mantle: 1.11.104
Project id: 74924
File id: 7563777
```

```groovy
implementation fg.deobf("curse.maven:tinkers-construct-74072:7449219")
implementation fg.deobf("curse.maven:mantle-74924:7563777")
```

## AI 接入

```text
Mode: cloud API
Java client: java.net.http.HttpClient
Output: JSON Schema constrained where provider supports it
Fallback: strict parser + one repair attempt + rule validation
Local Ollama: deferred, not a prototype dependency
```

供应商、模型名、endpoint 和 key 不写死在契约或世界存档中。首个 provider 在开始编码时根据账号、价格、延迟和结构化输出能力确定。

## 升级规则

任何依赖升级都必须重新执行：

1. 开发客户端与服务端启动测试。
2. Tetra 武器事实读取测试。
3. 自定义 NBT/契约迁移测试。
4. 三份演示契约回归测试。
5. 世界保存、退出、重载测试。

不能因为 CurseForge 出现新主文件或 Forge 出现新 Latest 就在构建中使用动态版本。
