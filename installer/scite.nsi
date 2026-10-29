; ===========================================================================
; SciTE 安装包脚本 (NSIS 3.x / MUI2)
;
; 一个脚本出两种架构的安装包, 由 /DARCH= 选择:
;   makensis /DARCH=x64 scite.nsi   →  payload 取 ..\dist\win64
;   makensis /DARCH=x86 scite.nsi   →  payload 取 ..\dist\win32
; 可选 /DVER=5.6.7 (默认见下方 !define VER)
;
; 中文 LangString 需要 UTF-8 源文件, 编译时加 /INPUTCHARSET UTF8
; 说明: x64 / x86 两个包写同名注册表键, 但分别在 64 位 / 32 位注册表视图里,
;       因此在 64 位 Windows 上可以并存, 互不覆盖。
; ===========================================================================

Unicode true
SetCompressor /SOLID lzma
SetCompressorDictSize 32

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"
!include "WordFunc.nsh"
!include "WinMessages.nsh"


; ---------------------------------------------------------------- 架构参数
!ifndef ARCH
  !define ARCH "x64"
!endif
!ifndef VER
  !define VER "5.6.7"
!endif

!if "${ARCH}" == "x64"
  !define PAYLOAD      "..\dist\win64"
  !define INSTDIR_DEF  "$PROGRAMFILES64\SciTE"
  !define OUTNAME      "SciTE-${VER}-win64-setup"
  !define ARCH_LABEL   "64-bit (x64)"
  !define REGVIEW      64
!else
  !if "${ARCH}" == "x86"
    !define PAYLOAD     "..\dist\win32"
    !define INSTDIR_DEF "$PROGRAMFILES\SciTE"
    !define OUTNAME     "SciTE-${VER}-win32-setup"
    !define ARCH_LABEL  "32-bit (x86)"
    !define REGVIEW     32
  !else
    !error "ARCH 必须为 x64 或 x86"
  !endif
!endif

!define SMFOLDER    "SciTE"
!define APP_KEY      "Software\SciTE"
!define UNINST_KEY   "Software\Microsoft\Windows\CurrentVersion\Uninstall\SciTE"
!define APPPATH_KEY  "Software\Microsoft\Windows\CurrentVersion\App Paths\SciTE.exe"
!define ENV_KEY      "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"

; ---------------------------------------------------------------- 基本信息
Name                 "SciTE ${VER} ${ARCH_LABEL}"
OutFile              "..\dist\${OUTNAME}.exe"
InstallDir           "${INSTDIR_DEF}"
InstallDirRegKey     HKLM "${APP_KEY}" "InstallDir"
RequestExecutionLevel admin
BrandingText         "SciTE ${VER} ${ARCH_LABEL}  -  Scintilla based Text Editor"
ShowInstDetails      show
ShowUninstDetails    show
XPStyle              on

VIProductVersion     "${VER}.0"
VIAddVersionKey /LANG=1033 "ProductName"     "SciTE"
VIAddVersionKey /LANG=1033 "FileDescription" "SciTE ${VER} ${ARCH_LABEL} Setup"
VIAddVersionKey /LANG=1033 "FileVersion"     "${VER}"
VIAddVersionKey /LANG=1033 "CompanyName"     "Neil Hodgson"
VIAddVersionKey /LANG=1033 "LegalCopyright"  "Copyright 1998-2026 by Neil Hodgson"

; ---------------------------------------------------------------- 界面
!define MUI_ABORTWARNING
!define MUI_ICON   "..\scite\win32\SciBall.ico"
!define MUI_UNICON "..\scite\win32\SciBall.ico"
!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_FINISHPAGE_RUN "$INSTDIR\SciTE.exe"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\doc\SciTEDoc.html"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "$(FINISH_README)"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\scite\License.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "SimpChinese"

; ---------------------------------------------------------------- 字符串
LangString FINISH_README   ${LANG_ENGLISH}     "Open the SciTE documentation"
LangString FINISH_README   ${LANG_SIMPCHINESE} "打开 SciTE 使用文档"

LangString DESC_CORE       ${LANG_ENGLISH}     "SciTE.exe, Scintilla.dll, lexilla.dll and all language .properties (required)."
LangString DESC_CORE       ${LANG_SIMPCHINESE} "SciTE 主程序、Scintilla 与 Lexilla 库、全部语言配置文件（必需）。"

LangString DESC_DOCS       ${LANG_ENGLISH}     "HTML documentation and screenshots."
LangString DESC_DOCS       ${LANG_SIMPCHINESE} "HTML 文档与截图。"

LangString DESC_SC1        ${LANG_ENGLISH}     "Sc1.exe: single-file build with Scintilla, Lexilla and Lua built in."
LangString DESC_SC1        ${LANG_SIMPCHINESE} "Sc1.exe：静态编入 Scintilla、Lexilla、Lua 的单文件版本。"

LangString DESC_CTX        ${LANG_ENGLISH}     "Add 'Edit with SciTE' to the right-click menu of files."
LangString DESC_CTX        ${LANG_SIMPCHINESE} "在文件的右键菜单中加入「用 SciTE 编辑」。"

LangString DESC_DESKTOP    ${LANG_ENGLISH}     "Create a SciTE shortcut on the desktop."
LangString DESC_DESKTOP    ${LANG_SIMPCHINESE} "在桌面创建 SciTE 快捷方式。"

LangString DESC_PATH       ${LANG_ENGLISH}     "Append the install directory to the system PATH (new terminals only)."
LangString DESC_PATH       ${LANG_SIMPCHINESE} "把安装目录加入系统 PATH（仅对新开的终端生效）。"

LangString CTX_LABEL       ${LANG_ENGLISH}     "Edit with SciTE"
LangString CTX_LABEL       ${LANG_SIMPCHINESE} "用 SciTE 编辑"

LangString WARN_NOTX64     ${LANG_ENGLISH}     "This is a 64-bit package and cannot be installed on 32-bit Windows.$\r$\nPlease use the win32 setup instead."
LangString WARN_NOTX64     ${LANG_SIMPCHINESE} "这是 64 位安装包，无法安装在 32 位 Windows 上。$\r$\n请改用 win32 安装包。"

InstType "Typical"
InstType "Full"

; ---------------------------------------------------------------- 初始化
Function .onInit
  ${If} "${ARCH}" == "x64"
    ${IfNot} ${RunningX64}
      MessageBox MB_ICONSTOP "$(WARN_NOTX64)"
      Abort
    ${EndIf}
  ${EndIf}
  SetRegView ${REGVIEW}
FunctionEnd

Function un.onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${EndIf}
  ${If} "${ARCH}" == "x86"
    SetRegView 32
  ${EndIf}
FunctionEnd

; ---------------------------------------------------------------- 安装区段
Section "Core files (required)" SEC_CORE
  SectionIn RO
  SetOutPath "$INSTDIR"
  SetOverwrite on

  File "${PAYLOAD}\SciTE.exe"
  File "${PAYLOAD}\Scintilla.dll"
  File "${PAYLOAD}\lexilla.dll"
  File "${PAYLOAD}\*.properties"
  File "..\scite\License.txt"
  File /oname=luaCOPYRIGHT "..\scite\lua\COPYRIGHT"

  WriteUninstaller "$INSTDIR\uninstall.exe"

  WriteRegStr HKLM "${APP_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "${APP_KEY}" "Version"    "${VER}"
  WriteRegStr HKLM "${APP_KEY}" "Arch"       "${ARCH}"

  WriteRegStr HKLM "${APPPATH_KEY}" ""     "$INSTDIR\SciTE.exe"
  WriteRegStr HKLM "${APPPATH_KEY}" "Path" "$INSTDIR"

  WriteRegStr   HKLM "${UNINST_KEY}" "DisplayName"          "SciTE ${VER} - ${ARCH_LABEL}"
  WriteRegStr   HKLM "${UNINST_KEY}" "DisplayVersion"       "${VER}"
  WriteRegStr   HKLM "${UNINST_KEY}" "DisplayIcon"          "$INSTDIR\SciTE.exe,0"
  WriteRegStr   HKLM "${UNINST_KEY}" "Publisher"            "Neil Hodgson"
  WriteRegStr   HKLM "${UNINST_KEY}" "URLInfoAbout"         "https://www.scintilla.org/SciTE.html"
  WriteRegStr   HKLM "${UNINST_KEY}" "InstallLocation"      "$INSTDIR"
  WriteRegStr   HKLM "${UNINST_KEY}" "UninstallString"      '"$INSTDIR\uninstall.exe"'
  WriteRegStr   HKLM "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Documentation" SEC_DOCS
  SectionIn 1 2
  SetOutPath "$INSTDIR\doc"
  File "..\scite\doc\*.html"
  File "..\scite\doc\*.png"
  File "..\scite\doc\*.jpg"
  File "..\scite\doc\scite.1"
SectionEnd

Section "Single-file build (Sc1.exe)" SEC_SC1
  SectionIn 2
  SetOutPath "$INSTDIR"
  File "${PAYLOAD}\Sc1.exe"
SectionEnd

Section "Explorer context menu" SEC_CTX
  SectionIn 1 2
  ; 文件右键动词要写进 64 位视图, 否则 64 位资源管理器看不到
  ${If} ${RunningX64}
    SetRegView 64
  ${EndIf}
  WriteRegStr HKLM "Software\Classes\*\shell\SciTE"         ""     "$(CTX_LABEL)"
  WriteRegStr HKLM "Software\Classes\*\shell\SciTE"         "Icon" "$INSTDIR\SciTE.exe,0"
  WriteRegStr HKLM "Software\Classes\*\shell\SciTE\command" ""     '"$INSTDIR\SciTE.exe" "%1"'
  SetRegView ${REGVIEW}
SectionEnd

Section "Desktop shortcut" SEC_DESKTOP
  SectionIn 2
  SetShellVarContext all
  CreateShortCut "$DESKTOP\SciTE.lnk" "$INSTDIR\SciTE.exe" "" "$INSTDIR\SciTE.exe" 0
SectionEnd

Section /o "Add to system PATH" SEC_PATH
  SetRegView ${REGVIEW}
  ReadRegStr $0 HKLM "${ENV_KEY}" "Path"
  ${WordReplace} "$0" "$INSTDIR" "" "+" $1
  ${If} "$1" == "$0"
    WriteRegExpandStr HKLM "${ENV_KEY}" "Path" "$0;$INSTDIR"
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=3000
  ${EndIf}
SectionEnd

; 开始菜单快捷方式（始终创建）
Section "-Start menu shortcuts"
    SetShellVarContext all
    CreateDirectory "$SMPROGRAMS\${SMFOLDER}"
    CreateShortCut  "$SMPROGRAMS\${SMFOLDER}\SciTE.lnk" "$INSTDIR\SciTE.exe" "" "$INSTDIR\SciTE.exe" 1
    CreateShortCut  "$SMPROGRAMS\${SMFOLDER}\SciTE Documentation.lnk" "$INSTDIR\doc\SciTEDoc.html"
    CreateShortCut  "$SMPROGRAMS\${SMFOLDER}\Uninstall SciTE.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

; 估算体积（放在最后, 此时文件已全部落盘）
Section "-Finalize"
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "${UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CORE}    "$(DESC_CORE)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DOCS}    "$(DESC_DOCS)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_SC1}     "$(DESC_SC1)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_CTX}     "$(DESC_CTX)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP} "$(DESC_DESKTOP)"
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_PATH}    "$(DESC_PATH)"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---------------------------------------------------------------- 卸载
Section "Uninstall"
  ${If} ${RunningX64}
    SetRegView 64
    DeleteRegKey HKLM "Software\Classes\*\shell\SciTE"
  ${Else}
    SetRegView 32
    DeleteRegKey HKLM "Software\Classes\*\shell\SciTE"
  ${EndIf}

  ; PATH: 去掉安装时追加的 ;$INSTDIR
  ${If} ${RunningX64}
    SetRegView 64
  ${EndIf}
  ${If} "${ARCH}" == "x86"
    SetRegView 32
  ${EndIf}
  ReadRegStr $0 HKLM "${ENV_KEY}" "Path"
  ${WordReplace} "$0" ";$INSTDIR" "" "+" $1
  ${If} "$1" != "$0"
    WriteRegExpandStr HKLM "${ENV_KEY}" "Path" "$1"
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=3000
  ${EndIf}

  DeleteRegKey HKLM "${UNINST_KEY}"
  DeleteRegKey HKLM "${APPPATH_KEY}"
  DeleteRegKey HKLM "${APP_KEY}"

  SetShellVarContext all
  Delete "$DESKTOP\SciTE.lnk"
  Delete "$SMPROGRAMS\${SMFOLDER}\SciTE.lnk"
  Delete "$SMPROGRAMS\${SMFOLDER}\SciTE Documentation.lnk"
  Delete "$SMPROGRAMS\${SMFOLDER}\Uninstall SciTE.lnk"
  RMDir  "$SMPROGRAMS\${SMFOLDER}"

  Delete "$INSTDIR\SciTE.exe"
  Delete "$INSTDIR\Sc1.exe"
  Delete "$INSTDIR\Scintilla.dll"
  Delete "$INSTDIR\lexilla.dll"
  Delete "$INSTDIR\*.properties"
  Delete "$INSTDIR\License.txt"
  Delete "$INSTDIR\luaCOPYRIGHT"
  Delete "$INSTDIR\doc\*.*"
  RMDir  "$INSTDIR\doc"
  Delete "$INSTDIR\uninstall.exe"
  RMDir  "$INSTDIR"
SectionEnd