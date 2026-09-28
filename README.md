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

三个目录各司其职：**`packs/` 是构建前现拷进来的原料，`build/` 是中间产物，`dist/` 是发布件。**

```
shared/                    两包共用的启动脚本（ServerPackCreator 生成的 start.* / install_java.*）
shared/defaults/           补齐用的默认文件：eula.txt、server.properties
packs/                     仓库里是空的（只有 .gitkeep 占位）。构建前把 SPC 原始输出
                           拷进 packs/<版本>/，整棵子树都不进版本控制
build/<版本>/               组装出的可运行服务端目录，含 libraries/ 等依赖（不进版本控制，可直接跑）
dist/                      打包好的 zip（不进版本控制）
build.sh                   整理源目录 + 组装 + 打包
tools/import.py            把 ServerPackCreator 的原始输出整理成精简源目录
tools/zip.py               压缩辅助（Git for Windows 自带 bash 但没有 zip 命令）
```

`packs/`、`build/`、`dist/` 全在 `.gitignore` 里，仓库真正跟踪的只有 `shared/`。

`packs/<版本>/` 下的东西**一个都不提交**，因为全都能重新生成：`HOW-TO-RUN.md`、`config/`、
`mods/`、`world/` 是 ServerPackCreator 的输出，`eula.txt`、`server.properties`、`README.md`
由 `build.sh` 运行时从 `shared/defaults/` 补出来。**代价是 `packs/` 里的内容不受版本控制，
所以 `variables.txt` 必须由 SPC 保证正确** —— 见下面「新增 / 更新一个版本」一节。

## 为什么不把库文件放进仓库

`libraries/`、`versions/`、`.fabric/`、`server.jar` 等加起来约 290 MB，但**全部是 start 脚本运行时从
Mojang / Forge / Fabric 官方源自动下载的**，属于构建产物。把它们提交进 git 只会让仓库膨胀到几百 MB、
拖慢每次 push 和 clone，并不增加任何信息。仓库里真正需要维护的内容只有几十 KB。

## 构建

```bash
./build.sh                  # 构建 packs/ 下的全部包
./build.sh 1.20.1-Forge     # 只构建指定包
./build.sh --list           # 列出 packs/ 下的所有包
```

脚本把 `shared/` 的公共脚本和 `packs/<版本>/` 的文件组装进 `build/<版本>/`，
再打包到 `dist/`。已下载的依赖原样保留在 `build/` 里，重复构建不会重新下载。

缺少 `variables.txt` / `eula.txt` / `server.properties` 会直接报错中止，不产 zip。
`packs/` 里一个包都没有时同样报错，不会默默什么都不做。

> 首次在一台新机器上构建某个版本前，要先在 `build/<版本>/` 里跑一次 start 脚本，
> 把 `libraries/` 等依赖下载齐，否则打出来的包不含依赖。脚本会检测并警告。

## 发布

1. 跑 `./build.sh`
2. 到 GitHub 新建 Release，把 `dist/*.zip` 拖上去

包约 123–137 MB。GitHub Release 单个附件上限 2 GB，容量不是限制；但**别用浏览器传**，
大文件容易超时，用 GitHub Desktop 或 HTTP API 更稳。

## 新增 / 更新一个版本

**仓库里不存 `packs/` 的内容，每次构建前把 ServerPackCreator(SPC) 的原始输出现拷进去**，
不用手动挑文件：

```bash
mkdir -p packs/<版本>
cp -r <SPC输出目录>/. packs/<版本>/
./build.sh <版本>
```

> ⚠️ **`packs/<版本>/` 这一层不能少。** 如果直接倒进 `packs/`，`variables.txt`、
> `HOW-TO-RUN.md` 这些文件会停在 `packs/` 根目录，而 `build.sh` 只从 `packs/<版本>/`
> 取文件——旧版本会照常打出一个 zip，只是里面缺 `variables.txt`。现在这种情况会直接报错中止。

> ⚠️ **别在 `packs/<版本>/variables.txt` 里留下机器相关的改动。** 它不进版本控制，
> 也没人替你校对，SPC 每次重新生成都会写回 `JAVA="java"` + `SKIP_JAVA_CHECK=false`。
> 如果你为了本机调试把它改成绝对路径（如 `JAVA="D\:\\...\\java.exe"`）并打开了
> `SKIP_JAVA_CHECK`，**打包前务必改回来**——否则玩家机器上没有这个路径，`start.sh`
> 会直接失败，而自动装 Java 的兜底又被你自己关掉了。

`build.sh` 会先调 `tools/import.py` 把源目录整理干净：

- 确认 SPC 输出没被倒进 `packs/` 根目录（放错了直接报错中止）
- 删掉客户端实例目录（SPC 顺带拷进来的，靠 `.hmcl` / `natives-*` / `saves` 等标志识别）
- 删掉 `manifest.json`
- 把运行产生的 `libraries/` `versions/` `.fabric/` `server.jar` 等**移到** `build/<版本>/`
- 删掉与 `shared/` 内容相同的 `start.*` / `install_java.*`（构建时自动从 `shared/` 复制）；
  内容不同则保留并警告，提示先更新 `shared/`
- 清掉 SPC 写下的只读属性，否则你改不了 `variables.txt`

然后补齐缺失的 `eula.txt`（`eula=true`）、`server.properties`（`online-mode=false`）
和 `README.md`（按 `variables.txt` 里的版本信息生成）。

> 整理只针对能明确识别的目标；遇到不认识的文件或目录一律保留并打印警告。

如果提示缺 `libraries/`，说明这个版本还没下载过依赖：进 `build/<版本>/` 跑一次 start 脚本
把依赖下齐，再重新 `./build.sh <版本>` 即可打出完整包。已下载的依赖会一直留在 `build/` 里，
之后重复构建不会重新下载。

## 重新生成

修改客户端整合包后，用 ServerPackCreator `8.1.2` 重新生成服务端包。`variables.txt` 和 `.previousrun`
记录了上次生成时的版本信息，供其比对。
