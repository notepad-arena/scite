#!/usr/bin/env bash
# ===========================================================================
# SciTE —— 生成 Windows 安装包 (NSIS)
#
# 用法:
#   ./package-win.sh          # 编译 win32 + win64 两个安装包
#   ./package-win.sh clean    # 删除已生成的安装包
#
# 前置条件:
#   1. 已安装 NSIS 3.x (makensis)；未加入 PATH 也可, 脚本会自动探测常见安装路径,
#      或用 MAKENSIS=/path/to/makensis.exe ./package-win.sh 指定
#   2. dist/win32 与 dist/win64 已由 build-win32.sh / build-win64.sh 生成
#
# 产物: dist/SciTE-<版本>-win32-setup.exe 、dist/SciTE-<版本>-win64-setup.exe
# ===========================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# ---------- 版本号: 以 scite/src/SciTE.h 为准 ----------
VER="$(sed -n 's/^#define VERSION_SCITE "\([^"]*\)".*/\1/p' "$ROOT/scite/src/SciTE.h" | tr -d '\r' | head -1)"
if [ -z "$VER" ]; then
	echo "错误: 无法从 scite/src/SciTE.h 读取 VERSION_SCITE" >&2
	exit 1
fi

# ---------- 定位 makensis ----------
MAKENSIS="${MAKENSIS:-}"
if [ -z "$MAKENSIS" ]; then
	if command -v makensis >/dev/null 2>&1; then
		MAKENSIS="$(command -v makensis)"
	else
		for c in "/c/Program Files (x86)/NSIS/makensis.exe" \
		         "/c/Program Files/NSIS/makensis.exe" \
		         "/c/ProgramData/chocolatey/bin/makensis.exe"; do
			if [ -x "$c" ]; then MAKENSIS="$c"; break; fi
		done
	fi
fi
if [ -z "$MAKENSIS" ] || [ ! -x "$MAKENSIS" ]; then
	cat >&2 <<-'EOF'
	错误: 找不到 makensis (NSIS)
	  安装: https://nsis.sourceforge.io/  (或 winget install NSIS.NSIS)
	  或用环境变量指定: MAKENSIS="/c/Program Files (x86)/NSIS/makensis.exe" ./package-win.sh
	EOF
	exit 1
fi

OUT32="$ROOT/dist/SciTE-$VER-win32-setup.exe"
OUT64="$ROOT/dist/SciTE-$VER-win64-setup.exe"

if [ "${1:-all}" = "clean" ]; then
	rm -f "$OUT32" "$OUT64"
	echo "已删除安装包:"
	echo "  $OUT32"
	echo "  $OUT64"
	exit 0
fi

# ---------- 检查 payload ----------
missing=0
for a in win32 win64; do
	if [ ! -f "$ROOT/dist/$a/SciTE.exe" ]; then
		echo "错误: 缺少 dist/$a/SciTE.exe, 请先运行 ./build-$a.sh" >&2
		missing=1
	fi
done
[ "$missing" -eq 0 ] || exit 1

echo "SciTE 版本 : $VER"
echo "makensis   : $MAKENSIS"
echo

cd "$ROOT/installer"
for arch in x64 x86; do
	echo "=== 编译 $arch 安装包 ==="
	# MSYS2 会把以 "/" 开头的参数当成路径自动转换(例如 /V2 -> C:/msys64/V2),
	# 这里关闭参数转换, 否则 makensis 的参数全部失效。
	MSYS2_ARG_CONV_EXCL='*' "$MAKENSIS" /V2 /INPUTCHARSET UTF8 /DARCH="$arch" /DVER="$VER" scite.nsi
	echo
done

echo "=== 产物 ==="
for f in "$OUT32" "$OUT64"; do
	printf '  %-42s %8s  %s\n' "$(basename "$f")" \
		"$(du -h "$f" | cut -f1)" "$(sha256sum "$f" | cut -c1-16)..."
done
