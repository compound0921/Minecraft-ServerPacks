# Minecraft Server Packs

Minecraft 服务端整合包，由 [ServerPackCreator](https://github.com/Griefed/ServerPackCreator) `8.1.2` 生成。

## 下载

**本仓库不含可直接运行的完整服务端包**，请到 [Releases](../../releases) 页面下载对应版本的 zip，解压即用。完整包已自带全部依赖，无需联网安装。

各版本的 Java 要求、配置说明见包内的 `README.md`。

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
如果用的不是 Release 里的完整包，Forge 包首次启动会通过 ServerStarterJar 安装依赖，需要联网，耐心等待或看 `logs/latest.log`。

---

# 维护说明

## 目录结构

三个目录各司其职：**`packs/` 是你编辑的，`build/` 是中间产物，`dist/` 是发布件。**

```
shared/              两包共用的启动脚本（ServerPackCreator 生成的 start.* / install_java.*）
packs/<版本>/         该版本特有的源文件：variables.txt、server.properties、config/、mods/、world/ ……
build/<版本>/         组装出的可运行服务端目录，含 libraries/ 等依赖（不进版本控制，可直接跑）
dist/                打包好的 zip（不进版本控制）
build.sh             组装 + 打包
tools/zip.py         压缩辅助（Git for Windows 自带 bash 但没有 zip 命令）
```

`build/` 和 `dist/` 都在 `.gitignore` 里，仓库只跟踪 `packs/` 与 `shared/` 下的源文件。

## 为什么不把库文件放进仓库

`libraries/`、`versions/`、`.fabric/`、`server.jar` 等加起来约 290 MB，但**全部是 start 脚本运行时从
Mojang / Forge / Fabric 官方源自动下载的**，属于构建产物。把它们提交进 git 只会让仓库膨胀到几百 MB、
拖慢每次 push 和 clone，并不增加任何信息。仓库里真正需要维护的内容只有约 0.3 MB。

## 构建

```bash
./build.sh                  # 构建全部
./build.sh 1.20.1-Forge     # 只构建指定包
./build.sh --list           # 列出所有包
```

脚本把 `shared/` 的公共脚本和 `packs/<版本>/` 的版本文件组装进 `build/<版本>/`，
再打包到 `dist/`。已下载的依赖原样保留在 `build/` 里，重复构建不会重新下载。

> 首次在一台新机器上构建某个版本前，要先在 `build/<版本>/` 里跑一次 start 脚本，
> 把 `libraries/` 等依赖下载齐，否则打出来的包不含依赖。脚本会检测并警告。

## 发布

1. 跑 `./build.sh`
2. 到 GitHub 新建 Release，把 `dist/*.zip` 拖上去

包约 123–137 MB。GitHub Release 单个附件上限 2 GB，容量不是限制；但**别用浏览器传**，
大文件容易超时，用 GitHub Desktop 或 HTTP API 更稳。

## 新增一个版本

1. 在 `packs/<新版本>/` 放该版本特有的源文件（`variables.txt`、`server.properties`、`config/`、`mods/` 等）
2. 别把 ServerPackCreator 输出里的**客户端实例目录**（以整合包名命名的子文件夹）带进来
3. 把新版本的 `start.*`、`install_java.*` 与 `shared/` 里的对比一下：**一致就删掉**，
   不一致则先更新 `shared/`（所有版本共用一份，改动会影响全部）
4. 首次构建前，先跑一次 start 脚本把依赖下载到 `build/<新版本>/`
5. `./build.sh <新版本>` —— `build.sh` 会自动发现 `packs/` 下的新目录，不需要改脚本

## 重新生成

修改客户端整合包后，用 ServerPackCreator `8.1.2` 重新生成服务端包。`variables.txt` 和 `.previousrun`
记录了上次生成时的版本信息，供其比对。
