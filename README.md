# Minecraft Server Packs

Minecraft 服务端整合包，由 [ServerPackCreator](https://github.com/Griefed/ServerPackCreator) `8.1.2` 生成。

本仓库只保留启动服务端所需的文件（ServerPackCreator 原本一并打包的 HMCL 客户端实例已移除）。**每个包的具体配置和说明见各自的 README。**

## 启动

- **Windows**：双击 `start.bat`。**不要删除 `.ps1` 文件**，`start.bat` 依赖它们。
- **Linux / macOS**：`bash start.sh`

## Java

Java 版本必须和该包要求的版本一致（两包不同，见各自的 README），用错会报 `UnsupportedClassVersionError`。

`variables.txt` 里的 `JAVA` 决定用哪个 Java：

- 值为 `java`：首次启动会自动下载安装合适的 Java 版本。
- 值为绝对路径：强制使用该 Java。**换机器前必须改掉**，改成自己机器上的路径，或者改回 `java` 走自动安装（同时把 `SKIP_JAVA_CHECK` 改回 `false`）。

> Windows 路径里的 `\` 和 `:` 需要转义，即前面再加一个 `\`。

## 配置

- 内存改 `variables.txt` 里的 `JAVA_ARGS`（当前 `-Xmx4G -Xms4G`）。
- 改 `server.properties` 后需重启服务端。常改的几项：`online-mode`（`true` 需正版验证，改 `false` 让离线玩家进）、`white-list`、`max-players`、`difficulty`、`motd`。

## 常见问题

**端口 25565 被占用**
改 `server.properties` 的 `server-port`。

**首次启动卡在下载 / 安装**
Forge 包首次启动会通过 ServerStarterJar 安装依赖，需要联网，耐心等待或看 `logs/latest.log`。

## 重新生成

修改客户端整合包后，用 ServerPackCreator `8.1.2` 重新生成服务端包。`variables.txt` 和 `.previousrun` 记录了上次生成时的版本信息，供其比对。
