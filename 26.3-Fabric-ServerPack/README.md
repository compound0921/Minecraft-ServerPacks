# 26.3-Fabric-ServerPack

服务端整合包，由 [ServerPackCreator](https://github.com/Griefed/ServerPackCreator) `8.1.2` 生成。

## 基本信息

| 项目 | 值 |
| --- | --- |
| Minecraft | `26.3` |
| 加载器 | Fabric `0.19.5` |
| 需要的 Java | **Java 25** |
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

```
JAVA="D\:\\BellSoft\\Java25\\bin\\java.exe"
JAVA_ARGS="-Xmx4G -Xms4G"
SKIP_JAVA_CHECK=true
```

> **换机器前必须改这一行**。当前路径写死为本机的 `D:\BellSoft\Java25\bin\java.exe`，请改成自己机器上 Java 25 的路径；或者改成 `java` 让它自动安装（同时要把 `SKIP_JAVA_CHECK` 改回 `false`）。
>
> Windows 路径里的 `\` 和 `:` 需要转义，即前面再加一个 `\`。

## 说明

本仓库**只保留启动服务端所需的文件**，原先由 ServerPackCreator 一并打包的 HMCL 客户端实例（含客户端 mod）已移除。玩家要 JEI、Jade、光影这些体验，需自行从原始客户端整合包取用。

服务端文件结构：

```
26.3-Fabric-ServerPack/
├── start.bat / start.sh / start.ps1   # 启动脚本
├── install_java.sh / .ps1             # 自动安装对应版本 Java
├── variables.txt                      # JAVA / JAVA_ARGS / 版本信息等配置
├── server.properties                  # 服务端配置
├── fabric-server-launcher.jar         # Fabric 服务端启动器
├── .fabric/                           # Fabric loader 与 Minecraft 服务端 jar
├── libraries/                         # 依赖库
├── versions/                          # 版本清单
├── mods/                              # 服务端 mod（目前为空）
└── world/                             # 存档（首次启动后生成）
```
