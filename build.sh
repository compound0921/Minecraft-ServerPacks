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
# 组装规则：shared/ 的公共脚本 + packs/<版本>/ 的版本特有文件
#          -> packs/<版本>/<版本>-ServerPack/  -> dist/<版本>-ServerPack.zip
#
# 注意：packs/<版本>/<版本>-ServerPack/ 是构建输出，不进版本控制。
# 首次在这台机器上构建前，需要先跑一次 start 脚本让它把 libraries/ 等
# 依赖下载齐，否则打出来的包不含依赖（下面会警告）。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$ROOT/shared"
PACKS="$ROOT/packs"
DIST="$ROOT/dist"

# 从 shared/ 和 packs/<p>/ 复制到构建输出目录的源文件
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
  out="$src/$name-ServerPack"

  if [ ! -d "$src" ]; then
    echo "错误: 未知的包 '$name'，可用: $(pack_names | tr '\n' ' ')" >&2
    exit 1
  fi

  echo "==> $name"

  # 1. 公共脚本。.sh 强制 LF：core.autocrlf=true 会让 Windows 工作区里的
  #    start.sh 变成 CRLF，Linux 玩家解压后执行会报 bad interpreter。
  mkdir -p "$out"
  for f in "$SHARED"/*; do
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
      # .gitkeep 只是占位，不进发布包
      # .gitkeep 只是占位，不进发布包；空目录则由 zip.py 写入目录条目保留
      find "$src/$d" -mindepth 1 -maxdepth 1 ! -name .gitkeep \
        -exec cp -rf {} "$out/$d/" \;
    fi
  done

  # 3. full 包自检：没有 libraries/ 说明依赖还没下载过
  if [ ! -d "$out/libraries" ]; then
    echo "    警告: $out 里没有 libraries/，打出的包不含依赖。" >&2
    echo "          请先在该目录跑一次 start 脚本把依赖下载齐。" >&2
  fi

  # 4. 打包（Windows 终端默认 GBK，强制 UTF-8 免乱码）
  PYTHONIOENCODING=utf-8 python "$ROOT/tools/zip.py" "$out" "$DIST/$name-ServerPack.zip"
done

echo "完成。产物在 $DIST/"
