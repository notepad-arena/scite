#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SciTE 5.6.7 / Scintilla 5.6.7 / Lexilla 5.5.4
# Windows 构建脚本 (MSYS2 MinGW-w64 / UCRT64)
#
# 用法 —— 必须从 "MSYS2 MINGW64"(或 UCRT64) 终端里执行, 不能是 MSYS 终端:
#   ./build-msys2.sh            # 增量构建 Scintilla -> Lexilla -> SciTE
#   ./build-msys2.sh clean      # 先 clean 再完整重建
#   JOBS=4 ./build-msys2.sh     # 指定并行数 (默认 = CPU 核数)
#   DEBUG=1 ./build-msys2.sh    # 调试版 (-g, 不 strip)
#   NO_LUA=1 ./build-msys2.sh   # 不编译内置 Lua 扩展
#
# 说明: 三个 makefile 里用 `ifdef windir` 判断是否在 Windows 下构建。
# MSYS2 会把继承的 Windows 环境变量名统一大写 (WINDIR), 小写 windir 消失,
# 导致 Lexilla 产出 liblexilla.so 而非 lexilla.dll。因此这里显式导出。
# ---------------------------------------------------------------------------
set -euo pipefail

export windir="${windir:-C:/Windows}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS="${JOBS:-$(nproc)}"
MAKE="mingw32-make"

command -v "$MAKE" >/dev/null 2>&1 || {
	echo "错误: 找不到 mingw32-make" >&2
	echo "请执行: pacman -S --needed mingw-w64-x86_64-{gcc,make,binutils}" >&2
	exit 1
}

# 让 SciTE.exe / lexilla.dll 静态链接 MinGW 运行时 (libstdc++/libgcc/winpthread),
# 否则生成的 exe 双击运行会缺少 libstdc++-6.dll 等, 不能单独分发。
STATIC_RUNTIME=1
EXTRA_ARGS=()
if [[ "$STATIC_RUNTIME" == 1 && -z "${DEBUG:-}" ]]; then
	EXTRA_ARGS+=("-static")
fi

if [[ "${1:-}" == "clean" ]]; then
	echo "=== clean ==="
	"$MAKE" -C "$ROOT/scite/win32"    clean || true
	"$MAKE" -C "$ROOT/lexilla/src"    clean || true
	"$MAKE" -C "$ROOT/scintilla/win32" clean || true
fi

echo "=== 1/3 Scintilla (C++17, 静态库 + Scintilla.dll) ==="
cd "$ROOT/scintilla/win32"
# 该 makefile 的链接行已自带 -static, 无需额外参数
"$MAKE" -j"$JOBS"

echo "=== 2/3 Lexilla (C++17, 静态库 + lexilla.dll) ==="
cd "$ROOT/lexilla/src"
"$MAKE" -j"$JOBS" CXXFLAGS="${EXTRA_ARGS[*]}"

echo "=== 3/3 SciTE (C++20, SciTE.exe + 静态 Sc1.exe) ==="
cd "$ROOT/scite/win32"
"$MAKE" -j"$JOBS" LDLIBS="${EXTRA_ARGS[*]}"

echo
echo "构建完成 —— 产物:"
ls -lh "$ROOT/scite/bin/SciTE.exe" "$ROOT/scite/bin/Sc1.exe" \
       "$ROOT/scite/bin/Scintilla.dll" "$ROOT/scite/bin/lexilla.dll"
echo
echo "运行: $ROOT/scite/bin/SciTE.exe   (单文件版: Sc1.exe)"
