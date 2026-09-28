#!/usr/bin/env python3
"""把一份 ServerPackCreator 的原始输出，就地整理成 build 需要的精简源目录。

用法:
    python tools/import.py <仓库根> <包名>

做的事:
  0. 先确认 SPC 的原始输出没被倒进 packs/ 根目录（放错了会静默打出缺文件的包），
     是则报错退出
  1. 删掉 manifest.json（SPC 的元数据，服务端用不到）
  2. 删掉客户端实例目录（SPC 顺带拷进来的，带 .hmcl / natives-* / saves 等标志）
  3. 把运行产生的构建产物（libraries/ versions/ .fabric/ server.jar run.sh …）
     移到 build/<包名>/，让 packs/<包名>/ 只剩源文件
  4. 删掉与 shared/ 内容相同的启动脚本（由 shared/ 统一提供），
     若内容不同则保留并警告，提示先更新 shared/
  5. 清掉保留下来的文件上的只读属性 —— SPC 输出的文件是只读的，
     留着会让用户改不了 variables.txt

只删除能明确识别的目标；遇到不认识的东西一律保留并警告。
"""
import os
import shutil
import stat
import sys

# 需要保留在 packs/<包名>/ 里的服务端源文件 / 目录
KEEP_DIRS = {"config", "defaultconfigs", "mods", "world"}

# 运行服务端才会产生的构建产物，应移出 packs/
ARTIFACT_DIRS = {"libraries", "versions", ".fabric"}
ARTIFACT_FILES = {
    "server.jar", "fabric-server-launcher.jar", "run.sh", "run.bat",
    "user_jvm_args.txt", ".previousrun",
}

# 由 shared/ 统一提供的脚本
SHARED_SCRIPTS = {
    "start.sh", "start.bat", "start.ps1", "install_java.sh", "install_java.ps1",
}

# 判断"这是个客户端实例"的依据
CLIENT_MARKERS = {
    ".hmcl", "options.txt", "saves", "shaderpacks", "screenshots",
    "resourcepacks", "schematics",
}
CLIENT_MARKER_PREFIXES = ("natives-",)

# packs/ 根目录上不该出现的文件：出现即说明 SPC 的原始输出被倒进了 packs/，
# 而不是 packs/<包名>/。这个错误是静默的 —— 这些文件根本不在 build.sh 的取用
# 范围内，包会照打不误，只是缺 variables.txt 等一堆文件，所以必须在这里拦下。
SPC_OUTPUT_MARKERS = {
    "manifest.json", "variables.txt", "server.properties", "eula.txt",
    "HOW-TO-RUN.md", "start.sh", "start.bat", "start.ps1",
    "install_java.sh", "install_java.ps1", "user_jvm_args.txt",
}


def make_writable(path: str) -> None:
    try:
        os.chmod(path, stat.S_IWRITE | stat.S_IREAD)
    except OSError:
        pass


def force_remove(path: str) -> None:
    """删除文件；SPC 输出的文件是只读的，先去掉只读位再删。"""
    make_writable(path)
    os.remove(path)


def force_rmtree(path: str) -> None:
    """递归删除，逐个去掉只读位（shutil.rmtree 在只读文件上会失败）。"""
    for dirpath, _dirnames, filenames in os.walk(path, topdown=False):
        for f in filenames:
            p = os.path.join(dirpath, f)
            make_writable(p)
            try:
                os.remove(p)
            except OSError:
                pass
        make_writable(dirpath)
        try:
            os.rmdir(dirpath)
        except OSError:
            pass
    make_writable(path)
    try:
        os.rmdir(path)
    except OSError:
        pass


def same_text(a: str, b: str) -> bool:
    """忽略行尾差异地比较两个文本文件。

    必须这么做：core.autocrlf 会把 shared/ 里的 .bat/.ps1 检出成 CRLF，
    而 ServerPackCreator 的输出是 LF，逐字节比会把它们全部误判为"不同"。
    """
    try:
        with open(a, "rb") as fa, open(b, "rb") as fb:
            norm = lambda d: d.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
            return norm(fa.read()) == norm(fb.read())
    except OSError:
        return False


def looks_like_client_dir(path: str) -> bool:
    try:
        entries = set(os.listdir(path))
    except OSError:
        return False
    if entries & CLIENT_MARKERS:
        return True
    return any(e.startswith(CLIENT_MARKER_PREFIXES) for e in entries)


def move_into(src: str, dest_dir: str, rel: str) -> None:
    """把 src 移到 dest_dir/rel；目标已存在则不动。"""
    dest = os.path.join(dest_dir, rel)
    if os.path.exists(dest):
        print(f"    跳过 {rel}：{dest_dir} 里已有一份")
        return
    parent = os.path.dirname(dest)
    if parent:
        os.makedirs(parent, exist_ok=True)
    else:
        os.makedirs(dest_dir, exist_ok=True)
    shutil.move(src, dest)
    print(f"    移出 {rel} -> build/")


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    root, name = os.path.abspath(sys.argv[1]), sys.argv[2]
    packs = os.path.join(root, "packs")
    pack = os.path.join(packs, name)
    build = os.path.join(root, "build", name)
    shared = os.path.join(root, "shared")

    # 0. SPC 的原始输出得整个拷进 packs/<包名>/，不是 packs/。放错层级时那些文件
    #    不会被 build.sh 取用，会打出一个缺 variables.txt 的包，所以直接中止。
    stray = sorted(m for m in os.listdir(packs) if m in SPC_OUTPUT_MARKERS)
    if stray:
        print("错误: packs/ 根目录出现了 ServerPackCreator 的输出文件:", file=sys.stderr)
        for m in stray:
            print(f"        packs/{m}", file=sys.stderr)
        print("      这些文件不在 build.sh 的取用范围内，会被忽略，"
              "打出的包会缺 variables.txt 等文件。", file=sys.stderr)
        print("      正确做法是把 SPC 输出整个拷进包目录：", file=sys.stderr)
        print("        cp -r <SPC输出目录>/. packs/<包名>/", file=sys.stderr)
        return 1

    if not os.path.isdir(pack):
        print(f"错误: 找不到 {pack}", file=sys.stderr)
        return 1

    removed = kept = 0

    # 1. manifest.json
    mf = os.path.join(pack, "manifest.json")
    if os.path.isfile(mf):
        force_remove(mf)
        print("    删除 manifest.json")
        removed += 1

    # 2~4. 遍历 pack 顶层
    for entry in sorted(os.listdir(pack)):
        path = os.path.join(pack, entry)

        if os.path.isdir(path):
            if entry in KEEP_DIRS:
                kept += 1
                continue
            if entry in ARTIFACT_DIRS:
                print(f"    产物目录 {entry}/")
                move_into(path, build, entry)
                continue
            if looks_like_client_dir(path):
                force_rmtree(path)
                print(f"    删除客户端实例目录 {entry}/")
                removed += 1
                continue
            print(f"    ! 保留无法识别的目录 {entry}/（请人工确认）")
            kept += 1
            continue

        if entry in SHARED_SCRIPTS:
            ref = os.path.join(shared, entry)
            if os.path.isfile(ref) and same_text(path, ref):
                force_remove(path)
                print(f"    删除 {entry}（与 shared/ 相同，构建时自动复制）")
                removed += 1
            else:
                print(f"    ! {entry} 与 shared/ 不同 —— 请先更新 shared/{entry}，再删掉这份")
                kept += 1
            continue

        if entry in ARTIFACT_FILES:
            move_into(path, build, entry)
            continue

        kept += 1

    # 5. 清掉剩余文件上的只读属性，让用户能直接编辑
    freed = 0
    for dirpath, _dirnames, filenames in os.walk(pack):
        for f in filenames:
            p = os.path.join(dirpath, f)
            try:
                if not (os.stat(p).st_mode & stat.S_IWRITE):
                    make_writable(p)
                    freed += 1
            except OSError:
                pass
    if freed:
        print(f"    解除 {freed} 个文件的只读属性")

    print(f"  整理完成：删除 {removed} 项，保留 {kept} 项")
    return 0


if __name__ == "__main__":
    sys.exit(main())
