# 1.20.1-Forge-ServerPack

服务端整合包，由 [ServerPackCreator](https://github.com/Griefed/ServerPackCreator) `8.1.2` 生成。

## 基本信息

| 项目 | 值 |
| --- | --- |
| Minecraft | `1.20.1` |
| 加载器 | Forge `47.4.23` |
| 需要的 Java | **Java 17** |
| 在线验证 | `online-mode=false`（离线，无正版账号也能进） |
| 端口 | `25565` |
| 内存 | `-Xmx4G -Xms4G` |
| 难度 / 上限 / 视距 | easy / 20 人 / 10 |
| 服务端 mod | `mods/` 为空（客户端 mod 已被剥离） |

> 离线模式需要两个开关同时关掉：除了 `online-mode`，`enforce-secure-profile` 也已设为 `false`。否则离线玩家没有 Mojang 聊天签名，一发消息就会被踢（`Chat disabled due to missing profile public key`）。副作用是聊天不带签名、玩家无法用原版功能举报聊天。

## 启动方法

### Windows

双击 `start.bat`。**不要删除 `.ps1` 文件**，`start.bat` 依赖它们。

### Linux / macOS

```bash
bash start.sh
```

### Java

`variables.txt` 里的 `JAVA` 决定用哪个 Java：

- 当前值为 `java`：首次启动时会自动下载安装合适的 Java 版本（`SKIP_JAVA_CHECK=false`）。
- 也可改成绝对路径，强制使用指定的 Java。Windows 路径要注意转义（`\` 和 `:` 前再加一个 `\`），并把 `SKIP_JAVA_CHECK` 设为 `true`。

```
JAVA="java"
JAVA_ARGS="-Xmx4G -Xms4G"
```

首次启动会通过 ServerStarterJar 安装依赖，需要联网，耐心等待或看 `logs/latest.log`。

> Forge / NeoForge 1.17+ 会额外生成 `run.bat` / `run.sh`，这是 ServerStarterJar 产生的，忽略即可；删掉它们会导致服务端被重新安装。

## 说明

本仓库**只保留启动服务端所需的文件**，原先由 ServerPackCreator 一并打包的 HMCL 客户端实例（含客户端 mod）已移除。玩家要 JEI、Jade、光影这些体验，需自行从原始客户端整合包取用。

服务端文件结构：

```
1.20.1-Forge-ServerPack/
├── start.bat / start.sh / start.ps1   # 启动脚本
├── install_java.sh / .ps1             # 自动安装对应版本 Java
├── variables.txt                      # JAVA / JAVA_ARGS / 版本信息等配置
├── server.properties                  # 服务端配置
├── server.jar                         # ServerStarterJar
├── libraries/                         # 依赖库（Forge 已安装）
├── config/ defaultconfigs/            # 服务端 mod 配置
├── mods/                              # 服务端 mod（目前为空）
└── world/                             # 存档（首次启动后生成）
```
