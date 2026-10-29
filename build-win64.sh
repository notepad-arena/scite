#!/usr/bin/env bash
# ===========================================================================
# SciTE 5.6.7 / Scintilla 5.6.7 / Lexilla 5.5.4
# Windows **x64 (64 位)** 构建脚本 —— MSYS2 / MinGW-w64 (x86_64-w64-mingw32)
#
# 用法(任意终端均可, 脚本会自动切换到 MSYS2 MINGW64 环境):
#   ./build-win64.sh            # 清理 + 全量构建(推荐)
#   ./build-win64.sh clean      # 只清理产物
#   ./build-win64.sh build      # 不清理, 增量构建(仅在同一架构下重复构建时用)
#
# 可选环境变量:
#   JOBS=4      并行数(默认 CPU 核数)
#   DEBUG=1     调试版(-g, 不 strip, 不静态链接运行时)
#   NO_LUA=1    不编译内置 Lua 扩展
#
# 产物: scite/bin/*(构建目录) 与 dist/win64/*(打包目录)
# ===========================================================================
set -euo pipefail

# ---------- 0. 确保运行在 MSYS2 MINGW64 环境 ----------
if [ "${MSYSTEM:-}" != "MINGW64" ]; then
	echo "[i] 当前环境 MSYSTEM='${MSYSTEM:-}', 自动切换到 MINGW64 ..."
	ABS_SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
	exec env MSYSTEM=MINGW64 CHERE_INVOKING=1 /usr/bin/bash.exe -l "$ABS_SELF" "$@"
fi

# ---------- 1. 关键: makefile 依赖小写的 windir ----------
# MSYS2 会把继承来的 Windows 环境变量名统一大写(WINDIR), 而 Scintilla/Lexilla/SciTE
# 的 makefile 用 `ifdef windir` 判断是否 Windows 构建。不导出会生成 liblexilla.so。
export windir="${windir:-C:/Windows}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
MAKE=mingw32-make
TAG=win64
JOBS="${JOBS:-$(nproc)}"

command -v "$MAKE" >/dev/null 2>&1 || {
	cat >&2 <<-'EOF'
	错误: 找不到 mingw32-make (64 位工具链未安装)
	请先执行:
	  pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-binutils
	EOF
	exit 1
}

BUILD_DIRS=(scintilla/win32 lexilla/src scite/win32)

# 可选开关
EXTRA=()
STATIC_RUNTIME="-static"
if [ -n "${DEBUG:-}" ]; then
	EXTRA+=("DEBUG=1")
	STATIC_RUNTIME=""
fi
if [ -n "${NO_LUA:-}" ]; then EXTRA+=("NO_LUA=1"); fi

# ---------- 2. 清理产物 ----------
# 注意: 必须在 windir 未定义的情况下调用 make clean。因为 windir 存在时 make 会把
# "/" 归一化成 "\", 通配符变成 .\*.o, rm 匹配不到任何文件, 清理会静默失效。
clean() {
	echo "=== 清理编译中间文件与库 ==="
	for d in "${BUILD_DIRS[@]}"; do
		echo "  - $d"
		( cd "$ROOT/$d" && env -u windir "$MAKE" clean ) || true
	done
	echo "=== 清理 bin / dist 产物 ==="
	rm -f  "$ROOT"/scintilla/bin/*.dll "$ROOT"/scintilla/bin/*.a
	rm -f  "$ROOT"/lexilla/bin/*.dll   "$ROOT"/lexilla/bin/*.a
	rm -f  "$ROOT"/scite/bin/SciTE.exe "$ROOT"/scite/bin/Sc1.exe \
	       "$ROOT"/scite/bin/Scintilla.dll "$ROOT"/scite/bin/lexilla.dll \
	       "$ROOT"/scite/bin/*.properties
	rm -rf "$ROOT/dist/$TAG"
	echo "清理完成"
}

# ---------- 3. 构建 ----------
build() {
	echo "=== 1/3 Scintilla ($(gcc -dumpmachine), C++17) ==="
	cd "$ROOT/scintilla/win32"
	"$MAKE" -j"$JOBS" "${EXTRA[@]}"

	echo "=== 2/3 Lexilla (C++17) ==="
	cd "$ROOT/lexilla/src"
	# CXXFLAGS 未被 makefile 赋值, 追加 -static 让 lexilla.dll 静态链接 MinGW 运行时,
	# 否则会依赖 libstdc++-6.dll / libgcc_s_seh-1.dll。
	"$MAKE" -j"$JOBS" "${EXTRA[@]}" CXXFLAGS="$STATIC_RUNTIME"

	echo "=== 3/3 SciTE (C++20) ==="
	cd "$ROOT/scite/win32"
	# 不要覆盖 LDFLAGS! 会丢掉 makefile 内的 -mwindows -municode(报 WinMain 未定义)。
	# LDLIBS 在 makefile 中未被赋值, 追加在链接行末尾, 安全。
	"$MAKE" -j"$JOBS" "${EXTRA[@]}" LDLIBS="$STATIC_RUNTIME"
}

# ---------- 4. 校验 + 打包 ----------
package() {
	echo
	echo "=== 校验架构 ==="
	local expect="pei-x86-64"
	for f in SciTE.exe Sc1.exe Scintilla.dll lexilla.dll; do
		local p="$ROOT/scite/bin/$f"
		local fmt
		fmt="$(objdump -f "$p" | awk '/file format/{print $NF}')"
		printf '  %-14s %-12s %8s bytes\n' "$f" "$fmt" "$(stat -c %s "$p")"
		if [ "$fmt" != "$expect" ]; then
			echo "错误: $f 不是 64 位产物(期望 $expect), 请先执行 ./build-win64.sh clean" >&2
			exit 1
		fi
	done

	echo "=== 打包到 dist/$TAG ==="
	mkdir -p "$ROOT/dist/$TAG"
	cp -a "$ROOT"/scite/bin/SciTE.exe "$ROOT"/scite/bin/Sc1.exe \
	      "$ROOT"/scite/bin/Scintilla.dll "$ROOT"/scite/bin/lexilla.dll \
	      "$ROOT"/scite/bin/*.properties "$ROOT/dist/$TAG/"
	echo "完成: $ROOT/dist/$TAG/SciTE.exe"
}

case "${1:-all}" in
	clean) clean ;;
	build) build; package ;;
	all|"") clean; build; package ;;
	*) echo "用法: $0 [all|clean|build]" >&2; exit 2 ;;
esac
