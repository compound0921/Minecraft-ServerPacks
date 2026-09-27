#!/usr/bin/env bash
#
# 组装服务端包并打成 zip。
#
#   ./build.sh                    构建全部包
#   ./build.sh 1.20.1-Forge       只构建指定包
#   ./build.sh --list             列出所有包
#
# 产出的 zip 在 dist/ 下，直接拖到 GitHub Release 页面即可。
#
# 三个目录各司其职：
#   packs/  你要编辑的源文件（进版本控制）
#   build/  组装出的可运行服务端目录（不进版本控制，可直接跑起来测试）
#   dist/   打包好的成品 zip（不进版本控制）
#
# 可以直接把 ServerPackCreator 的原始输出整个丢进 packs/<包名>/，再跑本脚本：
# 它会先调 tools/import.py 删掉客户端实例目录和 manifest.json、把运行产物移到
# build/，再补齐缺失的 eula.txt / server.properties / README.md。
#
# 首次在一台新机器上构建某个版本前，需要先跑一次 start 脚本让它把
# libraries/ 等依赖下载齐，否则打出来的包不含依赖（下面会警告）。

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

pack_names() {
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$@"
  else
    for d in "$PACKS"/*/; do basename "$d"; done
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

if [ "${1:-}" = "--list" ]; then
  pack_names
  exit 0
fi

if [ ! -d "$SHARED" ]; then
  echo "错误: 找不到 $SHARED" >&2
  exit 1
fi

mkdir -p "$DIST"

for name in $(pack_names "$@"); do
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

  # 3. full 包自检：没有 libraries/ 说明依赖还没下载过
  if [ ! -d "$out/libraries" ]; then
    echo "    警告: build/$name 里没有 libraries/，打出的包不含依赖。" >&2
    echo "          请先在 build/$name 里跑一次 start 脚本把依赖下载齐。" >&2
  fi

  # 4. 打包（Windows 终端默认 GBK，强制 UTF-8 免乱码）。
  #    构建目录是 build/1.20.1-Forge，但解压后希望得到 1.20.1-Forge-ServerPack/，
  #    所以显式传入压缩包内的顶层目录名。
  PYTHONIOENCODING=utf-8 python "$ROOT/tools/zip.py" \
    "$out" "$DIST/$name-ServerPack.zip" "$name-ServerPack"
done

echo "完成。产物在 $DIST/"
