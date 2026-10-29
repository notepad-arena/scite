# SciTE 5.6.7 在 Windows 下用 MSYS2 编译

本仓库是 SciTE 的源码树，三个组件必须**按顺序**编译：

| 组件 | 版本 | 构建目录 | 产物 |
|---|---|---|---|
| Scintilla | 5.6.7 | `scintilla/win32` | `scintilla/bin/{Scintilla.dll, libscintilla.a}` |
| Lexilla | 5.5.4 | `lexilla/src` | `lexilla/bin/{lexilla.dll, liblexilla.a}` |
| SciTE | 5.6.7 | `scite/win32` | `scite/bin/{SciTE.exe, Sc1.exe}` + 依赖 dll 与 `.properties` |

已在 MSYS2 **MINGW64** + `gcc 16.2.0` + `mingw32-make 4.4.1` 下实测通过（clean 全量重建）。

---

## 1. 准备工具链

在 MSYS2 终端里（任选一个环境，推荐 MINGW64）：

```bash
pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-binutils
```

- `mingw32-make` 由 `mingw-w64-x86_64-make` 提供（**不是** MSYS 的 `make`）。
- `windres`、`ar`、`ranlib` 来自 `binutils`，GCC 包一般已带上。
- 编译器要求：SciTE 需要 **C++20**，Scintilla/Lexilla 需要 C++17 → **GCC ≥ 10**。
- 内置 Lua 5.4（`scite/lua/`）随源码编译，**不需要**外部 Lua。
- Python 只在执行 `make depend`（重新生成 `deps.mak`）时才用到，正常编译不需要。

## 2. 一键构建（推荐）

打开 **MSYS2 MINGW64** 终端（开始菜单里那个 `MSYS2 MINGW64`，或 `C:\msys64\mingw64.exe`），然后：

```bash
cd /c/Users/Administrator/AIProjects/scite567
./build-msys2.sh          # 增量构建
./build-msys2.sh clean    # 先 clean 再全量重建
```

## 3. 手工三步构建（等价）

```bash
cd /c/Users/Administrator/AIProjects/scite567
export windir=C:/Windows          # ← 关键，见"坑 1"

cd scintilla/win32 && mingw32-make -j$(nproc) && cd ../..
cd lexilla/src     && mingw32-make -j$(nproc) CXXFLAGS="-static" && cd ../..
cd scite/win32     && mingw32-make -j$(nproc) LDLIBS="-static"
```

---

## 三个必须知道的坑

### 坑 1：`windir` 被 MSYS2 改成了大写（最容易踩）

三个 makefile 都用 `ifdef windir` 来判断"是否在 Windows 上构建"。MSYS2 会把继承来的 Windows 环境变量名**统一转成大写**（`WINDIR`），于是小写的 `windir` 在 make 里是空的：

```
$ mingw32-make -p -n | grep SHAREDEXTENSION
SHAREDEXTENSION = so          # ✗ 生成了 liblexilla.so
$ export windir=C:/Windows
$ mingw32-make -p -n | grep SHAREDEXTENSION
SHAREDEXTENSION = dll         # ✓ lexilla.dll
```

后果：Lexilla 产出 `liblexilla.so`、路径分隔符不转换，接着 SciTE 链接/拷贝 `lexilla.dll` 就失败。
**解决：在 MSYS2 bash 里先 `export windir=C:/Windows`。**（脚本里已处理）

### 坑 2：MinGW 运行时 DLL 依赖，需要静态链接

默认链接出来的 `SciTE.exe`、`lexilla.dll` 会依赖
`libstdc++-6.dll`、`libgcc_s_seh-1.dll`、`libwinpthread-1.dll`，双击运行会报"缺少 DLL"。

- Scintilla：链接行本来就带 `-shared -static`，无需处理。
- Lexilla：`mingw32-make CXXFLAGS="-static"`
- SciTE：`mingw32-make LDLIBS="-static"`（`LDLIBS` 在 makefile 里没被赋值，命令行覆盖是安全的；
  **不要**直接覆盖 `LDFLAGS`，会丢掉 makefile 里的 `-mwindows -municode`，链接报 `undefined reference to WinMain`）

静态化后实测导入表只剩系统 DLL：

```
SciTE.exe      ADVAPI32 COMCTL32 comdlg32 GDI32 KERNEL32 msvcrt ole32 SHELL32 USER32 UxTheme
lexilla.dll    KERNEL32 msvcrt
Sc1.exe        ADVAPI32 COMCTL32 comdlg32 GDI32 IMM32 KERNEL32 msvcrt ole32 OLEAUT32 SHELL32 USER32 UxTheme
```

### 坑 3：构建顺序与"环境"选择

- 必须 **Scintilla → Lexilla → SciTE**：SciTE 直接链接 `../../scintilla/bin/*.a` 和 `../../lexilla/bin/*.a`。
- 必须用 **MINGW64 或 UCRT64** 环境，不能用 MSYS 环境（MSYS 的 gcc 生成依赖 msys-2.0.dll 的程序，且默认没装 gcc）。
- 路径不要含空格；`deps.mak` 已经是生成好的，增量构建不需要 Python。

---

## 产物与运行

```
scite/bin/
├── SciTE.exe        2.7 MB   GUI 主程序（动态加载 Scintilla.dll + lexilla.dll）
├── Sc1.exe          7.0 MB   单文件版，Scintilla/Lexilla/Lua 全部静态编入，可单独拷走
├── Scintilla.dll    2.2 MB
├── lexilla.dll      3.5 MB
└── *.properties     93 个文件（Global/语言配置，必须与 exe 同目录）
```

- 运行：`scite\bin\SciTE.exe`（实测启动正常，标题栏 `(Untitled) - SciTE`）
- 分发：把 `SciTE.exe / Scintilla.dll / lexilla.dll / *.properties` 复制到目标目录；
  或直接用 `Sc1.exe`（单文件，无需 dll 和 properties）。
- 版本校验：`(Get-Item scite\bin\SciTE.exe).VersionInfo.FileVersion` → `5.6.7`

## 常用变体

```bash
DEBUG=1 ./build-msys2.sh          # 调试版：-g、不 strip（不清 clean 需先 clean 切回发布版）
NO_LUA=1 ./build-msys2.sh         # 不编译内置 Lua 扩展（体积更小）
JOBS=4 ./build-msys2.sh           # 限制并行数
./build-msys2.sh clean            # 清理 .o/.a/.dll/.exe
```

用 Clang 替代 GCC（需 `pacman -S mingw-w64-x86_64-clang`）：

```bash
cd scintilla/win32 && mingw32-make CLANG=1
cd ../../lexilla/src && mingw32-make CLANG=1
cd ../../scite/win32 && mingw32-make CLANG=1
```

## 备选：不用 MSYS2 终端，直接在 PowerShell / cmd 里编译

`windir` 在 cmd/PowerShell 里本来就是小写可用的，所以这条路不需要坑 1 的补丁：

```powershell
$env:PATH = 'C:\msys64\mingw64\bin;' + $env:PATH
cd C:\Users\Administrator\AIProjects\scite567\scintilla\win32 ; mingw32-make -j8
cd ..\..\lexilla\src     ; mingw32-make -j8 CXXFLAGS="-static"
cd ..\..\scite\win32     ; mingw32-make -j8 LDLIBS="-static"
```

注意：PowerShell 传给原生程序时会吃掉参数里的双引号，`CXXFLAGS="-static"` 这种写法建议放进 `.ps1`
或 `.bat` 脚本里执行，否则 make 会把 `-static` 当成额外目标。

## VS2022 路线（可选）

工程文件已带，也可以用 MSVC：`nmake -f scintilla\win32\scintilla.mak`、
`nmake -f lexilla\src\lexilla.mak`、`nmake -f scite\win32\scite.mak`（需在
"x64 Native Tools Command Prompt" 里执行）。这条路线产物不依赖 MinGW 运行时。
