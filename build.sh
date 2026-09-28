#!/usr/bin/env bash
#
# 组装服务端包并打成 zip。
#
#   ./build.sh                    构建全部包
#   ./build.sh 1.20.1-Forge       只构建指定包
#   ./build.sh --list             列出所有包
#   ./build.sh --allow-custom-java  跳过 variables.txt 的 Java 自检（仅供本机测试）
#
# 产出的 zip 在 dist/ 下，直接拖到 GitHub Release 页面即可。
#
# 三个目录各司其职：
#   packs/  构建前从 ServerPackCreator 原始输出现拷进来的源目录（不进版本控制）
#   build/  组装出的可运行服务端目录（不进版本控制，可直接跑起来测试）
#   dist/   打包好的成品 zip（不进版本控制）
#
# packs/ 在仓库里是空的（只有个 .gitkeep 占位），所以每个包构建前都要先把
# SPC 的原始输出整个拷进 packs/<包名>/：
#
#   mkdir -p packs/<包名> && cp -r <SPC输出目录>/. packs/<包名>/
#   ./build.sh <包名>
#
# 本脚本会先调 tools/import.py 删掉客户端实例目录和 manifest.json、把运行产物
# 移到 build/，再补齐缺失的 eula.txt / server.properties / README.md。源目录里
# 没有 variables.txt（也就是忘了拷 SPC 输出）会直接报错中止。
#
# 发布包是轻量的：libraries/ versions/ .fabric/ server.jar 这些由 start 脚本
# 在玩家首次启动时自动下载，tools/zip.py 打包时会一律排除。build/ 里有没有
# 下过依赖不影响产物，只影响你能不能在本机直接把 build/<包名>/ 跑起来测试。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$ROOT/shared"
DEFAULTS="$SHARED/defaults"
PACKS="$ROOT/packs"
BUILD="$ROOT/build"
DIST="$ROOT/dist"

# 从 packs/<包名>/ 复制到构建目录的源文件
PACK_FILES=(
  variables.txt server.properties eula.txt
  ops.json whitelist.json banned-ips.json banned-players.json usercache.json
  README.md HOW-TO-RUN.md
)
PACK_DIRS=(config defaultconfigs mods world)

# 列出要构建的包名，一行一个。packs/ 里没有包时输出为空。
pack_names() {
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@"
  else
    # [ -d ] 这一步是必需的：packs/ 为空时 "$PACKS"/*/ 不匹配，会原样保留
    # 通配符本身，于是 d 变成字面量 ".../packs/*/"，basename 出来是个 "*"。
    for d in "$PACKS"/*/; do
      [ -d "$d" ] || continue
      basename "$d"
    done
  fi
}

# 补齐缺失的必需文件，写进源目录，和已有的包保持一致
fill_defaults() {
  local src="$1" mc ml mlv jv vars="$1/variables.txt"

  if [ ! -f "$src/eula.txt" ]; then
    cp -f "$DEFAULTS/eula.txt" "$src/eula.txt"
    echo "    补入 eula.txt（eula=true）"
  fi
  if [ ! -f "$src/server.properties" ]; then
    cp -f "$DEFAULTS/server.properties" "$src/server.properties"
    echo "    补入 server.properties（online-mode=false）"
  fi
  if [ ! -f "$src/README.md" ] && [ -f "$vars" ]; then
    mc=$(sed -n 's/^MINECRAFT_VERSION=//p' "$vars" | head -1)
    ml=$(sed -n 's/^MODLOADER=//p' "$vars" | head -1)
    mlv=$(sed -n 's/^MODLOADER_VERSION=//p' "$vars" | head -1)
    jv=$(sed -n 's/^RECOMMENDED_JAVA_VERSION=//p' "$vars" | head -1)
    cat > "$src/README.md" <<EOF
# ${mc} ${ml} 服务端包

Minecraft **${mc}** + ${ml} **${mlv}**

## 需要 Java ${jv}

Java 版本不对会报 \`UnsupportedClassVersionError\`。

## 启动

- **Windows**：双击 \`start.bat\`（不要删除 \`.ps1\` 文件，\`start.bat\` 依赖它们）
- **Linux / macOS**：\`bash start.sh\`

## 配置

- **内存**：改 \`variables.txt\` 的 \`JAVA_ARGS\`
- **正版验证**：\`server.properties\` 的 \`online-mode\`，改 \`false\` 可让离线玩家进入
- **白名单**：\`server.properties\` 的 \`white-list\`

改 \`server.properties\` 后需重启服务端生效。
EOF
    echo "    补入 README.md（按 variables.txt 生成）"
  fi
}

# 前置开关。用 while 而不是只看 $1，这样开关和包名可以任意先后。
ALLOW_CUSTOM_JAVA=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --allow-custom-java) ALLOW_CUSTOM_JAVA=1; shift ;;
    *) break ;;
  esac
done

if [ "${1:-}" = "--list" ]; then
  pack_names
  exit 0
fi

if [ ! -d "$SHARED" ]; then
  echo "错误: 找不到 $SHARED" >&2
  exit 1
fi

# packs/ 里一个包都没有：刚克隆下来、或还没把 SPC 输出拷进来。
# 单独拦这一句是因为不拦的话下面循环一次都不跑，脚本会若无其事地报"完成"。
if [ -z "$(pack_names "$@")" ]; then
  echo "错误: packs/ 里没有任何包。" >&2
  echo "      把 ServerPackCreator 的原始输出拷进来再构建：" >&2
  echo "        mkdir -p packs/<包名> && cp -r <SPC输出目录>/. packs/<包名>/" >&2
  exit 1
fi

mkdir -p "$DIST"

# 用 while read 而不是 for $(...)：未加引号的命令替换会做路径展开，
# 包名里带 * 或空格时会被拆散甚至展开成当前目录的文件列表。
while IFS= read -r name; do
  src="$PACKS/$name"
  out="$BUILD/$name"

  if [ ! -d "$src" ]; then
    echo "错误: 未知的包 '$name'，可用: $(pack_names | tr '\n' ' ')" >&2
    exit 1
  fi

  echo "==> $name"

  # 0a. 若 packs/<包名>/ 是一份 SPC 原始输出，先整理成精简源目录
  PYTHONIOENCODING=utf-8 python "$ROOT/tools/import.py" "$ROOT" "$name"

  # 0b. 补齐缺失的必需文件
  fill_defaults "$src" "$name"

  # 1. 公共脚本。.sh 强制 LF：core.autocrlf=true 会让 Windows 工作区里的
  #    start.sh 变成 CRLF，Linux 玩家解压后执行会报 bad interpreter。
  mkdir -p "$out"
  for f in "$SHARED"/*; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    case "$base" in
      *.sh) tr -d '\r' < "$f" > "$out/$base"; chmod +x "$out/$base" ;;
      *)    cp -f "$f" "$out/$base" ;;
    esac
  done

  # 2. 版本特有文件。用显式列表而非通配，否则会递归进构建输出目录自身。
  for f in "${PACK_FILES[@]}"; do
    [ -f "$src/$f" ] && cp -f "$src/$f" "$out/$f"
  done
  for d in "${PACK_DIRS[@]}"; do
    if [ -d "$src/$d" ]; then
      mkdir -p "$out/$d"
      # .gitkeep 只是占位，不进发布包；空目录则由 zip.py 写入目录条目保留
      find "$src/$d" -mindepth 1 -maxdepth 1 ! -name .gitkeep \
        -exec cp -rf {} "$out/$d/" \;
    fi
  done

  # 3. 必需文件自检：缺了就中止，绝不打出一个跑不起来的包。
  #    variables.txt 不在 fill_defaults 的补齐范围内（它得由 SPC 提供），源目录被
  #    搞乱时它会悄悄缺失，而打出来的 zip 单看文件名是看不出问题的。
  #    查 $src 而不是 $out：build/ 是增量的，上次构建留下的旧文件会让 $out 上的
  #    校验白白放过一个残源，打出的包里那份还是过期的。
  missing=""
  for f in variables.txt eula.txt server.properties; do
    [ -f "$src/$f" ] || missing="$missing $f"
  done
  if [ -n "$missing" ]; then
    echo "错误: packs/$name 缺少必需文件:$missing" >&2
    echo "      packs/ 里不存这些东西，构建前要把 SPC 的原始输出整个拷进 packs/$name/：" >&2
    echo "        mkdir -p packs/$name && cp -r <SPC输出目录>/. packs/$name/" >&2
    echo "      （注意是拷进 packs/$name/，不是 packs/ 根目录 —— 放错层级不会被取用）" >&2
    exit 1
  fi

  # 4. variables.txt 自检：不能带本机专属的 Java 路径。
  #    这种包在别人机器上直接起不来 —— 路径不存在，而自动装 Java 的兜底又正好被
  #    SKIP_JAVA_CHECK=true 关掉了，玩家只能自己去翻 variables.txt 才知道。
  #    单看 zip 文件名完全看不出来，所以只能在这一步拦。variables.txt 不进版本控制，
  #    SPC 每次重新生成都写回 JAVA="java"，光靠 README 提醒拦不住（26.3 那次就是）。
  if [ "$ALLOW_CUSTOM_JAVA" -eq 0 ]; then
    jv="$(sed -n 's/^JAVA="\(.*\)"$/\1/p' "$src/variables.txt" | head -1)"
    sjc="$(sed -n 's/^SKIP_JAVA_CHECK=\(.*\)$/\1/p' "$src/variables.txt" | head -1)"
    if [ "$jv" != "java" ] || [ "$sjc" != "false" ]; then
      echo "错误: packs/$name/variables.txt 带着本机专属的 Java 配置，打出的包别人跑不起来。" >&2
      echo "        当前 JAVA=\"$jv\"  SKIP_JAVA_CHECK=${sjc:-未设置}" >&2
      echo "      发布包要求 JAVA=\"java\" 且 SKIP_JAVA_CHECK=false，由 start 脚本自动装 Java。" >&2
      echo "      确实要出一个只给本机用的包，就加 --allow-custom-java。" >&2
      exit 1
    fi
  fi

  # 4b. build/ 里下过的依赖不会进包（zip.py 排除了），提一句免得以为漏打了
  if [ -d "$out/libraries" ] || [ -d "$out/.fabric" ] || [ -d "$out/versions" ]; then
    echo "    build/$name 里有本机下过的依赖，打包时已排除（发布包不含依赖）。"
  fi

  # 5. 打包（Windows 终端默认 GBK，强制 UTF-8 免乱码）。
  #    构建目录是 build/1.20.1-Forge，但解压后希望得到 1.20.1-Forge-ServerPack/，
  #    所以显式传入压缩包内的顶层目录名。
  PYTHONIOENCODING=utf-8 python "$ROOT/tools/zip.py" \
    "$out" "$DIST/$name-ServerPack.zip" "$name-ServerPack"
done < <(pack_names "$@")

echo "完成。产物在 $DIST/"
