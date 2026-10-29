# SciTE 5.6.7 —— Windows 构建说明（MSYS2）

本仓库是 SciTE 的源码树，三个组件必须**按顺序**编译：

| 组件 | 版本 | 构建目录 | 产物 |
|---|---|---|---|
| Scintilla | 5.6.7 | `scintilla/win32` | `scintilla/bin/{Scintilla.dll, libscintilla.a}` |
| Lexilla | 5.5.4 | `lexilla/src` | `lexilla/bin/{lexilla.dll, liblexilla.a}` |
| SciTE | 5.6.7 | `scite/win32` | `scite/bin/{SciTE.exe, Sc1.exe}` + dll + `.properties` |

**x86（32 位）和 x64（64 位）都能编**，两者共用同一批源文件和**同一批目标文件目录**，所以：

- 一条命令只会产出**一种**架构；
- **切换架构前必须先清理**（见「3. 清理产物目录」）；
- 两个脚本会自动把结果分别打包到 `dist/win32` 和 `dist/win64`，因此两种架构可以并存。

已在 MSYS2 下实测通过（`gcc 16.2.0` / `mingw32-make 4.4.1`，x86 + x64 全量重建）：

| | x86 (i686-w64-mingw32) | x64 (x86_64-w64-mingw32) |
|---|---|---|
| `SciTE.exe` | 2.9 MB | 2.7 MB |
| `Sc1.exe` | 7.2 MB | 6.9 MB |
| `Scintilla.dll` | 2.3 MB | 2.2 MB |
| `lexilla.dll` | 3.4 MB | 3.4 MB |
| 文件格式 | `pei-i386` | `pei-x86-64` |
| 启动验证 | ✔（Win10/11 x64 上运行 32 位程序） | ✔ |
| 外部依赖 | 仅系统 DLL | 仅系统 DLL |

---

## 0. 环境准备

### 0.1 安装对应架构的 MinGW-w64 工具链

在 MSYS2 终端里执行（两个架构可以同时装，互不冲突）：

```bash
# 64 位（x64）
pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-binutils

# 32 位（x86）
pacman -S --needed mingw-w64-i686-gcc mingw-w64-i686-make mingw-w64-i686-binutils
```

- `mingw32-make` 由 `mingw-w64-<arch>-make` 提供（**不是** MSYS 的 `make`）。
- `windres` / `ar` / `ranlib` / `objdump` 来自 `binutils`。
- 编译器要求：SciTE 需 **C++20**，Scintilla/Lexilla 需 C++17 → **GCC ≥ 10**。
- 内置 Lua 5.4（`scite/lua/`）随源码编译，**不需要**外部 Lua。
- Python 仅在 `make depend`（重新生成 `deps.mak`）时需要，正常构建不需要。

### 0.2 选择 MSYS2 环境

必须使用 **MINGW64 / MINGW32 / UCRT64** 环境，**不能**用 MSYS 环境（MSYS 的 gcc 产出依赖 `msys-2.0.dll` 的程序）：

| 目标架构 | MSYS2 环境 | 编译器三元组 |
|---|---|---|
| x64 | `MSYS2 MINGW64`（或 `UCRT64` 装 `mingw-w64-ucrt-x86_64-*`） | `x86_64-w64-mingw32` |
| x86 | `MSYS2 MINGW32` | `i686-w64-mingw32` |

两个脚本已内置环境自检：**在任意终端（含 PowerShell / MSYS 终端）执行都会自动切到正确环境**。

---

## 1. 一键脚本（推荐）

```bash
cd /c/Users/Administrator/AIProjects/scite567

# 64 位：清理 + 全量构建 + 校验 + 打包到 dist/win64
./build-win64.sh

# 32 位：清理 + 全量构建 + 校验 + 打包到 dist/win32
./build-win32.sh
```

脚本参数：

| 命令 | 作用 |
|---|---|
| `./build-win64.sh` | 清理 + 全量构建 + 打包（默认，**推荐**） |
| `./build-win64.sh clean` | 只清理产物 |
| `./build-win64.sh build` | 不清理，增量构建（仅同一架构重复构建时用） |

可选环境变量：

```bash
JOBS=4 ./build-win64.sh        # 限制并行数（默认 CPU 核数）
DEBUG=1 ./build-win64.sh       # 调试版：-g、不 strip、不静态链接运行时
NO_LUA=1 ./build-win64.sh      # 不编译内置 Lua 扩展（体积更小）
```

脚本最后会用 `objdump -f` 校验产物架构，**架构不符立即报错**（防止拿错架构的 `.o` 混编）。

---

## 2. 手工构建

### 2.1 Windows x64（64 位）

```bash
cd /c/Users/Administrator/AIProjects/scite567
export windir=C:/Windows                  # 必须，见「4. 坑 1」

# —— 清理（换架构或要全量重建时必须先做，见第 3 节）——
(cd scintilla/win32 && env -u windir mingw32-make clean)
(cd lexilla/src     && env -u windir mingw32-make clean)
(cd scite/win32     && env -u windir mingw32-make clean)

# —— 构建 ——
cd scintilla/win32 && mingw32-make -j$(nproc) && cd ../..
cd lexilla/src     && mingw32-make -j$(nproc) CXXFLAGS="-static" && cd ../..
cd scite/win32     && mingw32-make -j$(nproc) LDLIBS="-static"
```

### 2.2 Windows x86（32 位）

**与 x64 完全相同的命令**，区别只有两点：**在 `MSYS2 MINGW32` 环境里执行**（`gcc -dumpmachine` 应为 `i686-w64-mingw32`），以及**切换前必须清理**（否则会拿到 x64 的 `.o`，链接报 `file format not recognized`）。

```bash
cd /c/Users/Administrator/AIProjects/scite567
export windir=C:/Windows                  # 必须，见「4. 坑 1」
gcc -dumpmachine                          # 确认输出 i686-w64-mingw32

(cd scintilla/win32 && env -u windir mingw32-make clean)
(cd lexilla/src     && env -u windir mingw32-make clean)
(cd scite/win32     && env -u windir mingw32-make clean)

cd scintilla/win32 && mingw32-make -j$(nproc) && cd ../..
cd lexilla/src     && mingw32-make -j$(nproc) CXXFLAGS="-static" && cd ../..
cd scite/win32     && mingw32-make -j$(nproc) LDLIBS="-static"
```

从 PowerShell / cmd 直接进 MINGW32 环境执行也可以：

```powershell
$env:MSYSTEM = 'MINGW32'
& C:\msys64\usr\bin\bash.exe -l -c "cd /c/Users/Administrator/AIProjects/scite567 && export windir=C:/Windows && ./build-win32.sh"
```

### 2.3 封装成 `-static` 的原因（两个架构都一样）

| 目标 | 追加参数 | 说明 |
|---|---|---|
| Scintilla | 无 | 其 makefile 链接行本来就带 `-shared -static` |
| Lexilla | `CXXFLAGS="-static"` | `CXXFLAGS` 在 makefile 里未被赋值，命令行覆盖安全 |
| SciTE | `LDLIBS="-static"` | `LDLIBS` 在 makefile 里未被赋值，追加在链接行末尾 |

不这样做的话，`SciTE.exe` / `lexilla.dll` 会依赖 `libstdc++-6.dll`、`libgcc_s_seh-1.dll`、`libwinpthread-1.dll`，拷到别的机器上双击就报缺 DLL。

> **不要用 `LDFLAGS="-static"`**：命令行覆盖 `LDFLAGS` 会丢掉 makefile 里的 `-mwindows -municode`，链接报 `undefined reference to 'WinMain'`。

---

## 3. 清理产物目录

### 3.1 需要清理哪些东西

| 位置 | 内容 | 谁生成 |
|---|---|---|
| `scintilla/win32/*.o` | Scintilla 目标文件 | 编译产生 |
| `lexilla/src/*.o` | Lexilla 与全部 lexer 目标文件（数量最多） | 编译产生 |
| `scite/win32/*.o` | SciTE 目标文件 | 编译产生 |
| `lua` 相关 `*.o` | 内置 Lua 目标文件（在 `scite/win32` 下） | 编译产生 |
| `scintilla/bin/{*.dll,*.a}` | `Scintilla.dll`、`libscintilla.a` | 链接产生 |
| `lexilla/bin/{*.dll,*.a}` | `lexilla.dll`、`liblexilla.a` | 链接产生 |
| `scite/bin/{SciTE.exe,Sc1.exe,Scintilla.dll,lexilla.dll,*.properties}` | 最终可执行文件、拷贝过来的 dll 与配置 | 链接 / 拷贝产生 |
| `dist/win32`、`dist/win64` | 脚本打的包 | 打包产生 |

`bin/empty.txt`、`bin/__init__.py` 是版本库占位文件，清理时不要删。

### 3.2 用脚本清理（推荐）

```bash
./build-win64.sh clean     # 清 x64（含 dist/win64）
./build-win32.sh clean     # 清 x86（含 dist/win32）
```

两个脚本的 `clean` 做的是同一套编译产物清理（见 3.3 的 1)、2) 两步），与架构无关，任选其一即可把 `.o`/`.a`/`dll`/`exe` 清干净；
区别只在于各自额外删除自己的打包目录（`build-win64.sh clean` → `dist/win64`，`build-win32.sh clean` → `dist/win32`），
想把两个 `dist` 一起删掉就两个都跑一遍。

### 3.3 手工清理 —— 注意 `make clean` 的坑

「坑 4」说：**导出了 `windir` 时 `mingw32-make clean` 会静默失效**。所以手工清理必须 `env -u windir`：

```bash
cd /c/Users/Administrator/AIProjects/scite567

# 1) 三个构建目录的目标文件 + 各自 bin 下的库
(cd scintilla/win32 && env -u windir mingw32-make clean)
(cd lexilla/src     && env -u windir mingw32-make clean)
(cd scite/win32     && env -u windir mingw32-make clean)

# 2) 补齐 make clean 删不到的东西
#    · lexilla 的 clean 在 windir 缺失时目标是 liblexilla.so，lexilla.dll 不会被删
#    · scite/win32 的 clean 不会动 ../bin（exe、dll、properties 都在那里）
rm -f lexilla/bin/*.dll lexilla/bin/*.a
rm -f scite/bin/SciTE.exe scite/bin/Sc1.exe
rm -f scite/bin/Scintilla.dll scite/bin/lexilla.dll
rm -f scite/bin/*.properties

# 3) 打包目录
rm -rf dist/win32 dist/win64
```

验证是否干净（应无输出）：

```bash
find scintilla/win32 lexilla/src scite/win32 -maxdepth 1 \( -name '*.o' -o -name '*.a' \)
ls scintilla/bin/*.dll scintilla/bin/*.a lexilla/bin/*.dll lexilla/bin/*.a 2>/dev/null
```

### 3.4 纯 PowerShell 清理（不用 make）

```powershell
$root = 'C:\Users\Administrator\AIProjects\scite567'
foreach ($d in 'scintilla\win32','lexilla\src','scite\win32') {
    Get-ChildItem "$root\$d" -Include *.o,*.a,*.obj,*.res,*.exe,*.dll -File |
        Remove-Item -Force
}
Remove-Item "$root\scintilla\bin\*.dll","$root\scintilla\bin\*.a" -Force -ErrorAction SilentlyContinue
Remove-Item "$root\lexilla\bin\*.dll","$root\lexilla\bin\*.a"     -Force -ErrorAction SilentlyContinue
Remove-Item "$root\scite\bin\*.exe","$root\scite\bin\*.dll","$root\scite\bin\*.properties" -Force -ErrorAction SilentlyContinue
Remove-Item "$root\dist" -Recurse -Force -ErrorAction SilentlyContinue
```

（cmd 用户也可以用源码自带的 `scite\delbin.bat`、`scintilla\delbin.bat`、`lexilla\delbin.bat`，
它们递归删除 `*.o *.a *.obj *.dll *.exe *.res` 等，但**不删** `scite\bin` 下的 exe/dll。）

### 3.5 什么时候必须清理

| 场景 | 是否必须 clean |
|---|---|
| x86 ↔ x64 切换 | **必须**（否则链接报 `file format not recognized`） |
| `DEBUG=1` ↔ 发布版切换 | **必须** |
| `CLANG=1` ↔ GCC 切换 | **必须** |
| 增量改代码 / 同一架构重复构建 | 不需要（用 `./build-win*.sh build`） |

---

## 4. 四个坑

### 坑 1：`windir` 被 MSYS2 改成大写（最容易踩）

三个 makefile 都用 `ifdef windir` 判断「是否在 Windows 上构建」。MSYS2 会把继承的 Windows 环境变量名**统一大写**（`WINDIR`），小写 `windir` 在 make 里是空的：

```
$ mingw32-make -p -n | grep SHAREDEXTENSION
SHAREDEXTENSION = so          # ✗ 生成 liblexilla.so
$ export windir=C:/Windows
$ mingw32-make -p -n | grep SHAREDEXTENSION
SHAREDEXTENSION = dll         # ✓ lexilla.dll
```

后果：Lexilla 产出 `liblexilla.so`、路径分隔符不转换，SciTE 链接/拷贝 `lexilla.dll` 失败。
**解决：`export windir=C:/Windows`**（两个脚本已处理）。

### 坑 2：需要静态链接 MinGW 运行时

见 2.3。不静态化就依赖 `libstdc++-6.dll` 等，不能单独分发。

### 坑 3：构建顺序与 MSYS2 环境选择

- 必须 **Scintilla → Lexilla → SciTE**（SciTE 直接链接 `../../scintilla/bin/*.a` 和 `../../lexilla/bin/*.a`）。
- 必须用 MINGW64/MINGW32/UCRT64 环境，**不是** MSYS 环境。
- 路径不要含空格。

### 坑 4：`make clean` 在 MSYS2 bash 里会静默失效

`windir` 存在时，`normalize` 会把 `/` 换成 `\`，清理命令展开成：

```
C:/msys64/usr/bin/rm.exe -f  .\*.exe .\*.o .\*.a ...      # ← 通配符被转义，匹配不到任何文件
```

看起来"成功"了，实际什么都没删。下一次构建就会拿旧架构的 `.o` 去链接，报
`File format not recognized` / `incompatible`。

**解决：`env -u windir mingw32-make clean`**（`scite/win32` 的 makefile 有 `SHELL_TYPE` 保护，不受影响，但统一加上更保险）。

---

## 5. 产物与分发

```
dist/win64/                  dist/win32/
├── SciTE.exe    2.7 MB      ├── SciTE.exe    2.9 MB    ← GUI 主程序（动态加载两个 dll）
├── Sc1.exe      6.9 MB      ├── Sc1.exe      7.2 MB    ← 单文件版（Scintilla/Lexilla/Lua 全静态）
├── Scintilla.dll 2.2 MB     ├── Scintilla.dll 2.3 MB
├── lexilla.dll   3.4 MB     ├── lexilla.dll   3.4 MB
└── *.properties  93 个      └── *.properties  93 个    ← 必须与 exe 同目录
```

- 运行：`dist\win64\SciTE.exe`（实测标题栏 `(Untitled) - SciTE`，版本资源 `5.6.7`）。
- 分发：整个目录拷走即可（两个 dll + `*.properties` 必须与 exe 同级）；
  只需单文件时用 `Sc1.exe`（无需 dll 和 properties）。
- 32 位产物在 64 位 Windows 上可直接运行；64 位产物不能在 32 位系统上运行。
- 版本校验：`(Get-Item dist\win64\SciTE.exe).VersionInfo.FileVersion` → `5.6.7`

---

## 6. 备选路线

### 6.1 用 Clang 替代 GCC

```bash
pacman -S --needed mingw-w64-x86_64-clang        # 或 mingw-w64-i686-clang
export windir=C:/Windows
cd scintilla/win32 && mingw32-make CLANG=1
cd ../../lexilla/src && mingw32-make CLANG=1
cd ../../scite/win32 && mingw32-make CLANG=1
```

### 6.2 PowerShell / cmd 里直接用 mingw32-make

`windir` 在 cmd/PowerShell 里本来就是小写可用的，不需要坑 1 的补丁：

```powershell
$env:PATH = 'C:\msys64\mingw64\bin;' + $env:PATH      # 32 位改为 mingw32\bin
cd C:\Users\Administrator\AIProjects\scite567\scintilla\win32 ; mingw32-make -j8
cd ..\..\lexilla\src ; mingw32-make -j8 CXXFLAGS="-static"
cd ..\..\scite\win32 ; mingw32-make -j8 LDLIBS="-static"
```

注意：PowerShell 传给原生程序会吃掉参数里的双引号，`CXXFLAGS="-static"` 这类写法建议放进
`.ps1`/`.bat` 文件里执行，否则 make 会把 `-static` 当成额外目标。

### 6.3 VS2022（MSVC）

工程文件已带，在「x64 Native Tools Command Prompt」里：

```bat
nmake -f scintilla\win32\scintilla.mak
nmake -f lexilla\src\lexilla.mak
nmake -f scite\win32\scite.mak
```

MSVC 路线产物不依赖 MinGW 运行时（改用 VC 运行时），但本仓库没有 x86 的 VS 工程配置，
32 位推荐还是走 MSYS2。
