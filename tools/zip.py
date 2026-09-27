#!/usr/bin/env python3
"""把服务端包目录打包成 zip。

不直接用 `zip` 命令，因为 Git for Windows 默认不带它；只依赖标准库。

用法:
    python tools/zip.py <源目录> <输出zip>
"""
import os
import sys
import zipfile

# 不该进发布包的文件（每台机器各自生成）
SKIP_FILES = {".previousrun"}
SKIP_DIRS = {".git"}


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    src, dest = sys.argv[1], sys.argv[2]
    if not os.path.isdir(src):
        print(f"错误: 源目录不存在: {src}", file=sys.stderr)
        return 1

    src = os.path.abspath(src)
    # 压缩包内保留顶层目录名，解压后不会散落一地
    root = os.path.basename(src)
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)

    count = 0
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for dirpath, dirnames, filenames in os.walk(src):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)

            rel_dir = os.path.relpath(dirpath, src)
            arc_dir = root if rel_dir == "." else f"{root}/{rel_dir.replace(os.sep, '/')}"

            # 显式写入目录条目，保留 mods/ world/ 这类空目录
            zf.writestr(zipfile.ZipInfo(arc_dir + "/"), "")

            for name in sorted(filenames):
                if name in SKIP_FILES:
                    continue
                path = os.path.join(dirpath, name)
                zf.write(path, f"{arc_dir}/{name}")
                count += 1

    size = os.path.getsize(dest)
    print(f"  打包 {count} 个文件 -> {dest} ({size / 1048576:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
