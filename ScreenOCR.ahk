; ScreenOCR - Screen OCR with RapidOCR (PaddleOCR ONNX, PP-OCRv5)
; License: MIT (c) scillidan
;
; Third-party libraries:
;   lib/OCR.ahk      - Based on Vis2.ahk by Edison Hua (iseahound), Custom license
;                      https://github.com/iseahound/Vis2
;                      Modified: Removed ImageIdentify, Google Vision, Tesseract,
;                      simplified UX, added notification/config hooks
;   lib/ImagePut.ahk - MIT License, (c) Edison Hua (iseahound)
;                      https://github.com/iseahound/ImagePut
;   lib/Gdip_All.ahk - by tic (Tariq Porter), mod. Rseding91
;                      https://github.com/tariqporter/Gdip

#include <OCR>

scriptDir := A_ScriptDir
iniPath := scriptDir . "\ScreenOCR.ini"

if (!FileExist(iniPath)) {
    MsgBox, 0x10, Error, Configuration file not found:`n%iniPath%
    ExitApp
}

IniRead, ocrHotkey, %iniPath%, OCR, GlobalHotkey, ^!o
IniRead, notifyMethod, %iniPath%, OCR, NotificationMethod, traytip
IniRead, notify, %iniPath%, OCR, Notify, 1
IniRead, screenshotTool, %iniPath%, OCR, ScreenshotTool, builtin

IniRead, rHotkey, %iniPath%, RapidOCR, Hotkey,
IniRead, rLangsRaw, %iniPath%, RapidOCR, Languages, ch

IniRead, recogMsg, %iniPath%, NotifyMessages, RecogMsg, Recognizing...
IniRead, noTextMsg, %iniPath%, NotifyMessages, NoTextMsg, No text found

rapidLangs := ParseLangList(rLangsRaw)

rapidEnabled := rapidLangs.Length() > 0

rapidLang := ""
if (rapidEnabled)
    rapidLang := rapidLangs[1]

langHotkeys := []
IniRead, rapidLangSection, %iniPath%, RapidOCRLangHotkey
if (rapidLangSection != "ERROR") {
    Loop, Parse, rapidLangSection, `n, `r
    {
        if (A_LoopField == "")
            continue
        colonPos := InStr(A_LoopField, ":")
        if (!colonPos)
            continue
        lang := Trim(SubStr(A_LoopField, 1, colonPos - 1))
        hk := Trim(SubStr(A_LoopField, colonPos + 1))
        if (lang != "" && hk != "")
            langHotkeys.Push({lang: lang, hk: hk, engine: "rapidocr"})
    }
}

if (!rapidEnabled) {
    MsgBox, 0x10, Error, No languages configured. Check [RapidOCR] Languages.
    ExitApp
}

EnvGet, envEditor, EDITOR
scriptEditor := (envEditor != "") ? envEditor : "notepad"

Vis2.provider.RapidOCR.python := "uv run"
Vis2.provider.RapidOCR.useAngleCls := 1

Vis2.cfg := {}
Vis2.cfg.recogMsg := recogMsg
Vis2.cfg.noTextMsg := noTextMsg
Vis2.cfg.notifyMethod := notifyMethod
Vis2.cfg.notify := notify
Vis2.cfg.rapidLangs := rapidLangs
Vis2.cfg.rapidLang := rapidLang
Vis2.cfg.rapidEnabled := rapidEnabled

shortcutPath := A_StartMenu . "\Programs\Startup\ScreenOCR.lnk"
isStartup := FileExist(shortcutPath)

if (ocrHotkey != "")
    Hotkey, %ocrHotkey%, GlobalAutoOCR
if (rapidEnabled && rHotkey != "")
    Hotkey, %rHotkey%, RapidOCROCR
for i, entry in langHotkeys {
    fn := Func("DirectOCR").Bind(entry.lang, entry.engine)
    Hotkey, % entry.hk, % fn
}

Menu, Tray, NoStandard
Menu, Tray, Add, Notify, ToggleNotify
if (notify)
    Menu, Tray, Check, Notify
Menu, Tray, Add, Start with Windows, ToggleStartup
if (isStartup)
    Menu, Tray, Check, Start with Windows
Menu, Tray, Add, Check Languages, CheckLangs
Menu, Tray, Add
Menu, Tray, Add, Edit Config, EditConfig
Menu, Tray, Add, Reload, ReloadScript
Menu, Tray, Add, Exit, ExitScript
UpdateTrayTip()
if (FileExist(scriptDir . "\assets\icon.ico"))
    Menu, Tray, Icon, % scriptDir . "\assets\icon.ico"
return

ParseLangList(str) {
    arr := []
    if (str == "" || str == "ERROR")
        return arr
    Loop, Parse, str, `,
    {
        item := Trim(A_LoopField)
        if (item != "")
            arr.Push(item)
    }
    return arr
}

ShowNotification(title, msg) {
    if (Vis2.cfg.notifyMethod = "snoretoast") {
        Run, % "snoretoast -t """ . title . """ -m """ . msg . """ -silent -p """ . A_ScriptDir . "\assets\icon_128.png""",, Hide
    } else {
        TrayTip, %title%, %msg%, 2
    }
}

UpdateTrayTip() {
    global ocrHotkey, rHotkey, rapidEnabled, langHotkeys
    tip := "ScreenOCR"
    if (ocrHotkey != "")
        tip .= "`nGlobal: " . ocrHotkey
    if (rapidEnabled && rHotkey != "")
        tip .= "`nRapidOCR: " . rHotkey
    if (langHotkeys.Length() > 0) {
        tip .= "`nLang Hotkeys"
        for i, entry in langHotkeys
            tip .= "`n  " . entry.engine . " " . entry.lang . ": " . entry.hk
    }
    Menu, Tray, Tip, %tip%
}

EditConfig:
    Run, %scriptEditor% "%iniPath%"
return

CheckLangs:
    if (ocrChecking)
        return
    ocrChecking := true
    Menu, Tray, Disable, Check Languages
    rapidCachePath := scriptDir . "\cache\rapidocr_lang.txt"
    ShowNotification("ScreenOCR", "Checking languages... RapidOCR loading.")
    tmpOut := A_Temp . "\ahk_ocrs_langs.txt"
    tmpErr := A_Temp . "\ahk_ocrs_langs_err.txt"
    Run, % ComSpec . " /C uv run lib\rapidocr_cli.py --list-langs > """ . tmpOut . """ 2> """ . tmpErr . """",, Hide, ocrPid
    SetTimer, CheckLangsProgress, 500
    ocrWaitStart := A_TickCount
return

CheckLangsProgress:
    Process, Exist, %ocrPid%
    if (ErrorLevel) {
        if (A_TickCount - ocrWaitStart > 120000) {
            Process, Close, %ocrPid%
            Gosub, CheckLangsFail
        }
        return
    }
    errText := ""
    if (FileExist(tmpErr)) {
        FileRead, errText, %tmpErr%
        FileDelete, %tmpErr%
    }
    if (Trim(errText, "`r`n ") != "") {
        Gosub, CheckLangsFail
        return
    }
    langs := ""
    if (FileExist(tmpOut)) {
        FileRead, langs, %tmpOut%
        FileDelete, %tmpOut%
    }
    langs := Trim(langs, "`r`n ")
    clean := ""
    Loop, Parse, langs, `n, `r
    {
        line := Trim(A_LoopField)
        if (line != "" && !RegExMatch(line, "^Installed \d+ packages? in"))
            clean .= (clean ? ", " : "") . line
    }
    FileDelete, %rapidCachePath%
    if (clean != "")
        FileAppend, %clean%, %rapidCachePath%
    if (Vis2.cfg.notify) {
        if (clean)
            rapidShort := "RapidOCR: " . clean
        else
            rapidShort := "RapidOCR: none"
        if (StrLen(rapidShort) > 50)
            rapidShort := SubStr(rapidShort, 1, 47) . "..."
        msg := rapidShort
        ShowNotification("ScreenOCR", msg)
    }
    ocrChecking := false
    Menu, Tray, Enable, Check Languages
    SetTimer, CheckLangsProgress, Off
    MsgBox, 0x24, ScreenOCR, Language lists saved. Open folder to view?
    IfMsgBox Yes
        Run, explore %scriptDir%\cache
return

CheckLangsFail:
    SetTimer, CheckLangsProgress, Off
    if (FileExist(tmpOut))
        FileDelete, %tmpOut%
    if (FileExist(tmpErr))
        FileDelete, %tmpErr%
    if (Vis2.cfg.notify) {
        msg := "RapidOCR: failed (see README)"
        ShowNotification("ScreenOCR", msg)
    }
    ocrChecking := false
    Menu, Tray, Enable, Check Languages
return

GlobalAutoOCR:
    Vis2.cfg.mode := "global"
    Vis2.cfg.currentEngine := "rapidocr"
    Vis2.cfg.currentLang := Vis2.cfg.rapidLang
    if (screenshotTool = "flameshot") {
        RunWait, flameshot gui,, Hide
        OCR("clipboard", Vis2.cfg.currentLang)
    } else {
        OCR(, Vis2.cfg.currentLang)
    }
return

RapidOCROCR:
    if (!rapidEnabled)
        return
    Vis2.cfg.mode := "rapidocr"
    Vis2.cfg.currentEngine := "rapidocr"
    Vis2.cfg.currentLang := Vis2.cfg.rapidLang
    if (screenshotTool = "flameshot") {
        RunWait, flameshot gui,, Hide
        OCR("clipboard", Vis2.cfg.currentLang)
    } else {
        OCR(, Vis2.cfg.currentLang)
    }
return

DirectOCR(lang, engine) {
    if (engine = "rapidocr" && !rapidEnabled)
        return
    Vis2.cfg.mode := engine
    Vis2.cfg.currentEngine := engine
    Vis2.cfg.currentLang := lang
    if (screenshotTool = "flameshot") {
        RunWait, flameshot gui,, Hide
        OCR("clipboard", lang)
    } else {
        OCR(, lang)
    }
}

ToggleStartup:
    if (FileExist(shortcutPath)) {
        FileDelete, %shortcutPath%
        Menu, Tray, Uncheck, Start with Windows
    } else {
        FileCreateShortcut, %A_ScriptFullPath%, %shortcutPath%, %A_ScriptDir%
        Menu, Tray, Check, Start with Windows
    }
return

ToggleNotify:
    notify := !notify
    Vis2.cfg.notify := notify
    IniWrite, %notify%, %iniPath%, OCR, Notify
    if (notify)
        Menu, Tray, Check, Notify
    else
        Menu, Tray, Uncheck, Notify
return

ReloadScript:
    Reload
return

ExitScript:
    ExitApp
