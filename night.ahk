;@Ahk2Exe-Bin Unicode 64-bit.bin

;@Ahk2Exe-SetDescription night
;@Ahk2Exe-SetFileVersion 1.0.0
;@Ahk2Exe-SetInternalName night
;@Ahk2Exe-SetCopyright https://github.com/t5mat/night
;@Ahk2Exe-SetOrigFilename night.exe
;@Ahk2Exe-SetProductName night
;@Ahk2Exe-SetProductVersion 1.0.0

global Version := "1.0.0"
global Url := "https://github.com/t5mat/night"

if (!A_IsUnicode || A_PtrSize != 8) {
    ExitApp
}

#SingleInstance Force

#MenuMaskKey vkFF

GroupAdd CurrentProcess, % "ahk_pid " DllCall("GetCurrentProcessId")
GroupAdd SystemMenu, % "ahk_class #32768"
GroupAdd SystemDialog, % "ahk_class #32770"

SendMode Event

DetectHiddenWindows On
SetTitleMatchMode RegEx

CoordMode Mouse, Screen

FileEncoding UTF-8-RAW

global LocateModes := ["events", "hitpoints", "markers"]

global MacroPrefix := "~ night - "
global PleFolderName := "night"
global HashMacroPrefix := "~ night "

global SettingsPath
global AppExePath
global AppName
global KeyCommandsPath
global PlePath
global MacroKeys

global MixConsolePage
global LocateMode

AutoExec()

return

AutoExec()
{
    if (!A_IsCompiled) {
        XmlPath := A_ScriptDir "\night.xml"

        FileRead XmlData, % XmlPath
        XmlHash := HashFile(XmlPath, "MD5")
    } else {
        XmlPath := GetTempFilePath()
        FileInstall night.xml, % XmlPath, true

        FileRead XmlData, % XmlPath
        XmlHash := HashFile(XmlPath, "MD5")

        FileDelete % XmlPath
    }

    if (!(Xml := LoadXml(XmlData))) {
        MsgBox % (0x0 | 0x10 | 0x40000), % "night", % "Could not load night.xml"
        ExitApp
    }

    SplitPath A_ScriptFullPath, , , , SettingsFileName
    SettingsPath := A_ScriptDir "\" SettingsFileName ".ini"

    IniRead AppExePath, % SettingsPath, % "night", % "AppExePath", % A_Space
    if (AppExePath == A_Space || !FileExist(AppExePath)) {
        FileSelectFile AppExePath, 3, % A_ProgramFiles "\Steinberg", % "Select your Cubase.exe/Nuendo.exe file"
        if (ErrorLevel != 0) {
            ExitApp
        }
        IniWrite % AppExePath, % SettingsPath, % "night", % "AppExePath"
    }

    ExeVersionInfo := GetFileVersionInfo(AppExePath, "FileDescription FileVersion")

    AppName := StrSplit(ExeVersionInfo.FileDescription, " ", "", 2)[1]
    if (!(AppName == "Cubase" || AppName == "Nuendo")) {
        MsgBox % (0x0 | 0x10 | 0x40000), % "night", % "Unrecognized Cubase/Nuendo version."
        ExitApp
    }

    AppExe := "ahk_exe i)^\Q" AppExePath "\E$"
    GroupAdd AppExe, % AppExe
    GroupAdd AppTitleBar, % AppExe " ahk_class ^SmtgMain " App
    GroupAdd AppWindow, % AppExe " ahk_class ^SteinbergWindowClass$"
    GroupAdd AppProjectWindow, % "^" AppName "( .*?)? Project - .*$ " AppExe
    GroupAdd AppColorizeWindow, % "^Colorize$ " AppExe

    IniRead KeyCommandsPath, % SettingsPath, % "night", % "KeyCommandsPath", % A_Space
    if (KeyCommandsPath == A_Space || !FileExist(KeyCommandsPath)) {
        Path := A_AppData "\Steinberg"
        loop files, % A_AppData "\Steinberg\*", D
        {
            if (InStr(A_LoopFileName, ExeVersionInfo.FileDescription)) {
                Path := A_LoopFilePath "\Key Commands.xml"
                break
            }
        }

        FileSelectFile KeyCommandsPath, 3, % Path, % "Select your Key Commands.xml file"
        if (ErrorLevel != 0) {
            ExitApp
        }
        IniWrite % KeyCommandsPath, % SettingsPath, % "night", % "KeyCommandsPath"
    }

    IniRead PlePath, % SettingsPath, % "night", % "PlePath", % A_Space
    if (PlePath == A_Space || !InStr(FileExist(PlePath), "D")) {
        FileSelectFolder PlePath, % "*" A_MyDocuments "\Steinberg\" AppName "\User Presets\", 2, % "Select your Project Logical Editor user presets folder"
        if (ErrorLevel != 0) {
            ExitApp
        }
        IniWrite % PlePath, % SettingsPath, % "night", % "PlePath"
    }

    FileRead KeyCommandsData, % KeyCommandsPath

    if (!(KeyCommandsXml := LoadXml(KeyCommandsData)) || !IsValidKeyCommandsXml(KeyCommandsXml)) {
        MsgBox % (0x0 | 0x10 | 0x40000), % "night", % "Could not load key commands file:`n" KeyCommandsPath
        ExitApp
    }

    if (!IsInstalled(XmlHash, KeyCommandsXml)) {
        if (WinExist("ahk_group AppExe")) {
            MsgBox % (0x0 | 0x30 | 0x40000), % "night", % "night is not installed. Please close " AppName " and run night again to install."
            ExitApp
        }

        Uninstall(KeyCommandsPath, PlePath)

        FileRead KeyCommandsData, % KeyCommandsPath
        KeyCommandsXml := LoadXml(KeyCommandsData)

        InstallKeyCommands(Xml, KeyCommandsXml)
        InstallPle(Xml, PlePath)
        InstallHashMacro(XmlHash, KeyCommandsXml)

        FileDelete % KeyCommandsPath
        FileAppend % KeyCommandsXml.xml, % KeyCommandsPath

        MsgBox % (0x0 | 0x40 | 0x40000), % "night", % "night has been installed!`n`n" KeyCommandsPath "`n`n" PlePath
    }

    MacroKeys := LoadMacroKeys(KeyCommandsXml)

    MixConsolePage := 1
    LocateMode := 1

    Menu, Tray, NoStandard
    Menu, Tray, Add, % "night " Version, OpenNightUrl
    Menu, Tray, Add, % "Uninstall", ShowUninstall
    Menu, Tray, Add
    Menu, Tray, Add, % AppName " " ExeVersionInfo.FileVersion, OpenCubase
    Menu, Tray, Add, % AppName " Program Files", OpenCubaseProgramFiles
    Menu, Tray, Add, % AppName " AppData", OpenCubaseAppData
    Menu, Tray, Add, % AppName " Documents", OpenCubaseDocuments
    Menu, Tray, Add
    Menu, Tray, Add, % "Project Colors Patcher", ShowProjectColorsPatcher
    Menu, Tray, Add
    Menu, Tray, Add, % "AutoHotKey " A_AhkVersion, MenuStub
    Menu, Tray, Disable, % "AutoHotKey " A_AhkVersion
    Menu, Tray, Standard
}

OpenNightUrl()
{
    Run % Url
}

ShowUninstall()
{
    if (WinExist("ahk_group AppExe")) {
        MsgBox % (0x0 | 0x30 | 0x40000), % "night", % "Please close " AppName " before uninstalling night."
        return
    }

    Uninstall(KeyCommandsPath, PlePath)

    IniDelete % SettingsPath, % "night", % "AppExePath"
    IniDelete % SettingsPath, % "night", % "KeyCommandsPath"
    IniDelete % SettingsPath, % "night", % "PlePath"

    MsgBox % (0x0 | 0x40 | 0x40000), % "night", % "night has been uninstalled.`n`n" KeyCommandsPath "`n`n" PlePath
    ExitApp
}

OpenCubase()
{
    Run % AppExePath
}

OpenCubaseProgramFiles()
{
    Run % "explorer.exe /select,""" AppExePath """"
}

OpenCubaseAppData()
{
    SplitPath KeyCommandsPath, , Path
    Run % Path
}

OpenCubaseDocuments()
{
    SplitPath PlePath, , Path
    Run % Path
}

ShowProjectColorsPatcher()
{
    if (WinExist("ahk_group AppWindow")) {
        MsgBox % (0x0 | 0x30 | 0x40000), % "Project Colors Patcher", % "Please close all " AppName " projects before using the Project Colors Patcher."
        return
    }

    FileSelectFile ProjectPaths, M3, , % "Project Colors Patcher - select project files (BACK THEM UP FIRST)", % "Cubase/Nuendo Project Files (*.cpr; *.npr)"
    if (ErrorLevel != 0) {
        return
    }

    FileSelectFile ColorsPath, 3, % A_ScriptDir "\colors", % "Project Colors Patcher - select a colors file"
    if (ErrorLevel != 0) {
        return
    }

    loop parse, ProjectPaths, `n
    {
        if (A_Index == 1) {
            Path := A_LoopField
            continue
        }

        ProjectPath := Path "\" A_LoopField
        if (Patched := PatchProjectColors(ProjectPath, ColorsPath)) {
            MsgBox % (0x0 | 0x40 | 0x40000), % "Project Colors Patcher", % "Patched " Patched " color" (Patched == 1 ? "" : "s") " in:`n" ProjectPath
        } else {
            MsgBox % (0x0 | 0x10 | 0x40000), % "Project Colors Patcher", % "Error patching:`n" ProjectPath
        }
    }
}

MenuStub()
{
}

IsActiveAppWindow()
{
    return WinActive("ahk_group AppWindow")
}

#If IsActiveAppWindow()

$XButton1::
    WinActivate % "ahk_group AppProjectWindow"
    Send % MacroKeys["Show Lower Zone MixConsole Page " MixConsolePage] MacroKeys["Edit - Open/Close Editor"]
    return

$XButton2::
    WinActivate % "ahk_group AppProjectWindow"
    Send % MacroKeys["Show Lower Zone MixConsole Page " MixConsolePage]
    return

#If

IsActiveLowerZoneMixConsole()
{
    return WinActive("ahk_group AppProjectWindow") && GetKeyState("XButton2", "P")
}

#If IsActiveLowerZoneMixConsole()

$WheelDown::
    Send % MacroKeys["Window Zones - Show Next Page"]
    if (MixConsolePage < 3) {
        MixConsolePage += 1
    }
    return

$WheelUp::
    Send % MacroKeys["Window Zones - Show Previous Page"]
    if (MixConsolePage > 1) {
        MixConsolePage -= 1
    }
    return

#If

#If IsActiveAppWindow()

$!WheelDown::
    Send % MacroKeys["Zoom - Zoom Out Vertically"]
    return

$!WheelUp::
    Send % MacroKeys["Zoom - Zoom In Vertically"]
    return

$^!WheelDown::
    Send % MacroKeys["Zoom Out Horizontally and Vertically"]
    return

$^!WheelUp::
    Send % MacroKeys["Zoom In Horizontally and Vertically"]
    return

$+WheelDown::
    Send % MacroKeys["Zoom - Zoom Out Tracks"]
    return

$+WheelUp::
    Send % MacroKeys["Zoom - Zoom In Tracks"]
    return

$^+!WheelDown::
    Send % MacroKeys["Zoom - Zoom Out Of Waveform Vertically"]
    return

$^+!WheelUp::
    Send % MacroKeys["Zoom - Zoom In On Waveform Vertically"]
    return

$^+MButton::
    LocateMode := Mod(LocateMode, 3) + 1
    ToolTipTimeout("locate mode: " LocateModes[LocateMode], 1250)
    return

$^+WheelDown::
    switch (LocateMode) {
    case 1:
        Send % MacroKeys["Locate Next Event"]
    case 2:
        Send % MacroKeys["Locate Next Hitpoint"]
    case 3:
        Send % MacroKeys["Locate Next Marker"]
    }
    return

$^+WheelUp::
    switch (LocateMode) {
    case 1:
        Send % MacroKeys["Locate Previous Event"]
    case 2:
        Send % MacroKeys["Locate Previous Hitpoint"]
    case 3:
        Send % MacroKeys["Locate Previous Marker"]
    }
    return

#If

IsActiveAppExeNonMenu()
{
    return WinActive("ahk_group AppExe") && !GetCurrentMenu()
}

#If IsActiveAppExeNonMenu()

$Escape::
    if (WinActive("ahk_group AppProjectWindow")) {
        return
    }

    if (WinActive("ahk_group AppTitleBar") || WinActive("ahk_group AppColorizeWindow")) {
        WinClose A
        return
    }

    Send % "{Escape down}"
    KeyWait Escape
    Send % "{Escape up}"
    return

global InSpace := false
global InSpaceWriteAutomation := false

$Space::
    InSpace := true
    Send % "{Space}"
    KeyWait Space
    InSpace := false

    if (InSpaceWriteAutomation) {
        InSpaceWriteAutomation := false
        Send % "{Space}" MacroKeys["Automation - Toggle Write Enable All Tracks"]
    }

    return

~*LButton::
    if (InSpace && !InSpaceWriteAutomation) {
        InSpaceWriteAutomation := true
        Send % MacroKeys["Automation - Toggle Write Enable All Tracks"]
    }

    return

#If

IsActiveAppExeMenu()
{
    return WinActive("ahk_group AppExe") && GetCurrentMenu()
}

#If IsActiveAppExeMenu()

$Escape::
    CloseCurrentMenu()
    return

$a::
$^a::
$b::
$c::
$^c::
$d::
$Delete::
$Backspace::
$^d::
$e::
$+e::
$f::
$g::
$+g::
$h::
$i::
$^o::
$p::
$q::
$^q::
$+q::
$^+q::
$r::
$^r::
$s::
$^s::
$+s::
$^+s::
$v::
$^v::
$w::
$+w::
$x::
$+x::
$z::
$Space::
$+Space::
$^Space::
    Menu := GetCurrentMenu()

    ContextTrack := (1 << 0)
    ContextFolderTrack := (1 << 1)
    ContextTrackListTrack := (1 << 2)
    ContextInsertSlot := (1 << 3)
    ContextSendSlot := (1 << 4)
    ContextInsertsRack := (1 << 5)
    ContextSendsRack := (1 << 6)
    ContextEditor := (1 << 7)
    ContextKeyEditor := (1 << 8)
    ContextSelected := (1 << 9)
    ContextSelectedAudio := (1 << 10)
    ContextSelectedMidi := (1 << 11)

    Context := 0
    if (FindMenuItemIndex(Menu, "Copy First Selected Channel's Settings") != -1) {
        Context |= ContextTrack
    } else if (FindMenuItemIndex(Menu, "Select All Events") != -1) {
        Context |= ContextTrack | ContextTrackListTrack
        if (FindMenuItemIndex(Menu, "Show Data on Folder Tracks") != -1) {
            Context |= ContextFolderTrack
        }
    } else if (FindMenuItemIndex(Menu, "Set as last Pre-Fader Slot") != -1) {
        Context |= ContextInsertSlot
    } else if (FindMenuItemIndex(Menu, "Clear Send") != -1) {
        Context |= ContextSendSlot
    } else if (FindMenuItemIndex(Menu, "Bypass") != -1 && FindMenuItemIndex(Menu, "Copy") != -1 && FindMenuItemIndex(Menu, "Paste") != -1 && FindMenuItemIndex(Menu, "Clear") != -1) {
        if (FindMenuItemIndex(Menu, "Load FX Chain Preset...") != -1) {
            Context |= ContextInsertsRack
        } else {
            Context |= ContextSendsRack
        }
    } else if ((Tools := FindMenuItemIndex(Menu, "Tools")) != -1) {
        Context |= ContextEditor
        if ((ZoomToSelection := FindMenuItemIndex(Menu, "Zoom to Selection")) == -1 || GetMenuItemState(Menu, ZoomToSelection) & 0x2) {
            if (FindMenuItemIndex(Menu, "Functions") != -1) {
                Context |= ContextKeyEditor
            }
        } else {
            Context |= ContextSelected
            if (FindMenuItemIndex(Menu, "Create Sampler Track") != -1) {
                Context |= ContextSelectedAudio
            } else if (FindMenuItemIndex(Menu, "Processes") != -1) {
                Context |= ContextSelectedAudio
            } else if (FindMenuItemIndex(Menu, "Export MIDI Loop...") != -1) {
                Context |= ContextSelectedMidi
            } else if (FindMenuItemIndex(Menu, "Open Note Expression Editor") != -1) {
                Context |= ContextKeyEditor | ContextSelectedMidi
            }
        }
    }

    if (Context & ContextTrack) {
        if (Context & ContextTrackListTrack) {
            switch A_ThisHotkey
            {
            case "$a":
                CloseCurrentMenu()
                Send % MacroKeys["Edit - Select All on Tracks"]
                return
            case "$f":
                CloseCurrentMenu()
                Send % MacroKeys["Project - Folding: Tracks To Folder"]
                return
            case "$i":
                CloseCurrentMenu()
                Send % MacroKeys["Editors - Edit In-Place"]
                return
            case "$r":
                CloseCurrentMenu()
                Send % MacroKeys["Clear Selected Tracks"]
                return
            case "$Space":
                if (Context & ContextFolderTrack) {
                    CloseCurrentMenu()
                    Send % MacroKeys["Project - Folding: Toggle Selected Track"]
                } else {
                    TrySelectCurrentMenuItem(Menu, "Hide Automation") || TrySelectCurrentMenuItem(Menu, "Show Used Automation (Selected Tracks)")
                }
                return
            case "$+Space":
                if (Context & ContextFolderTrack) {
                    CloseCurrentMenu()
                    Send % MacroKeys["Project - Folding: Fold Tracks"]
                } else {
                    TrySelectCurrentMenuItem(Menu, "Hide All Automation")
                }
                return
            case "$^Space":
                if (Context & ContextFolderTrack) {
                    CloseCurrentMenu()
                    Send % MacroKeys["Project - Folding: Unfold Tracks"]
                } else {
                    TrySelectCurrentMenuItem(Menu, "Show All Used Automation")
                }
                return
            }
        }

        switch A_ThisHotkey
        {
        case "$^a":
            CloseCurrentMenu()
            Send % MacroKeys["Select All Tracks"]
            return
        case "$c":
            CloseCurrentMenu()
            Send % MacroKeys["Colorize Selected Tracks"]
            FocusColorizeWindow()
            return
        case "$d", "$Delete", "$Backspace":
            CloseCurrentMenu()
            Send % MacroKeys["Project - Remove Selected Tracks"]
            return
        case "$^d":
            CloseCurrentMenu()
            Send % MacroKeys["Project - Duplicate Tracks"]
            return
        case "$e":
            CloseCurrentMenu()
            Send % MacroKeys["Audio - Disable/Enable Track"]
            return
        case "$g":
            CloseCurrentMenu()
            Send % MacroKeys["Mixer - Add Track To Selected: Group Channel"]
            return
        case "$h":
            CloseCurrentMenu()
            Send % MacroKeys["Mixer - HideSelected"]
            return
        case "$^o":
            TrySelectCurrentMenuItem(Menu, "Load Track Preset...")
            return
        case "$s":
            CloseCurrentMenu()
            Send % MacroKeys["FX Channel to Selected Channels..."]
            return
        case "$^s":
            TrySelectCurrentMenuItem(Menu, "Save Track Preset...")
            return
        case "$^+s":
            CloseCurrentMenu()
            Send % MacroKeys["File - Export Selected Tracks"]
            return
        case "$v":
            CloseCurrentMenu()
            Send % MacroKeys["Mixer - Add Track To Selected: VCA Fader"]
            return
        case "$w":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Edit VST Instrument"]
            return
        }

        return
    }

    if (Context & ContextInsertSlot) {
        switch A_ThisHotkey
        {
        case "$d", "$Delete", "$Backspace":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Delete"]
            return
        case "$e":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Activate/Deactivate"]
            return
        case "$+e":
            CloseCurrentMenu()
            Send % "^!{Enter}"
            return
        case "$f":
            TrySelectCurrentMenuItem(Menu, "Set as last Pre-Fader Slot")
            return
        case "$s":
            TrySelectCurrentMenuItem(Menu, "Activate/Deactivate Side-Chaining")
            return
        case "$q":
            TrySelectCurrentMenuItem(Menu, "Switch to A Setting") || TrySelectCurrentMenuItem(Menu, "Switch to B Setting")
            return
        case "$+q":
            TrySelectCurrentMenuItem(Menu, "Apply Current Settings to A and B")
            return
        case "$r":
            CloseCurrentMenu()
            Send % "!{Enter}"
            return
        case "$Space":
            WinGet Active, ID, A
            CloseCurrentMenu()
            Send % "!{Click}"
            Sleep % A_WinDelay * 2
            WinGet ActiveAfter, ID, A
            if (Active == ActiveAfter) {
                Send % "{Click}"
            }
            return
        case "$+Space":
            WinGet Active, ID, A
            CloseCurrentMenu()
            Send % "!{Click}"
            Sleep % A_WinDelay * 2
            WinGet ActiveAfter, ID, A
            if (Active != ActiveAfter) {
                Send % MacroKeys["File - Close"]
            }
            return
        }

        return
    }

    if (Context & ContextSendSlot) {
        switch A_ThisHotkey
        {
        case "$r":
            TrySelectCurrentMenuItem(Menu, "Use Default Send Level")
            return
        case "$d", "$Delete", "$Backspace":
            TrySelectCurrentMenuItem(Menu, "Clear Send")
            return
        case "$^c":
            TrySelectCurrentMenuItem(Menu, "Copy Send")
            return
        case "$e":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Activate/Deactivate"]
            return
        case "$f":
            TrySelectCurrentMenuItem(Menu, "Move to Pre-Fader") || TrySelectCurrentMenuItem(Menu, "Move to Post-Fader")
            return
        case "$q":
            CloseCurrentMenu()
            Send % "{Enter}"
            ControlSetText Edit1, % "-oo", A
            ControlSend Edit1, % "{Enter}", A
            return
        case "$^v":
            TrySelectCurrentMenuItem(Menu, "Paste Send")
            return
        }

        return
    }

    if (Context & ContextInsertsRack) {
        switch A_ThisHotkey
        {
        case "$e":
            TrySelectCurrentMenuItem(Menu, "Bypass")
            return
        case "$^o":
            TrySelectCurrentMenuItem(Menu, "Load FX Chain Preset...")
            return
        case "$^s":
            TrySelectCurrentMenuItem(Menu, "Save FX Chain Preset...")
            return
        case "$Space":
            CloseCurrentMenu()
            Send % "{Up}{Right}+!{Enter}"
            return
        case "$+Space":
            CloseCurrentMenu()
            Send % "{Up}{Right}+{Enter}"
            return
        }

        return
    }

    if (Context & ContextSendsRack) {
        switch A_ThisHotkey
        {
        case "$e":
            TrySelectCurrentMenuItem(Menu, "Bypass")
            return
        }

        return
    }

    if (Context & ContextEditor) {
        if (Context & ContextKeyEditor) {
            switch A_ThisHotkey
            {
            case "$w":
                CloseCurrentMenu()
                Send % MacroKeys["Note Expression - Open/Close Editor"]
                return
            }
        }

        if (!(Context & ContextSelected)) {
            switch A_ThisHotkey
            {
            case "$z":
                CloseCurrentMenu()
                Send % MacroKeys["Zoom - Zoom Full"]
                return
            }

            return
        }

        switch A_ThisHotkey
        {
        case "$c":
            CloseCurrentMenu()
            Send % MacroKeys["Project - Set Track/Event Color"]
            FocusColorizeWindow()
            return
        case "$e":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Mute/Unmute Objects"]
            return
        case "$d", "$Delete", "$Backspace":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Delete"]
            return
        case "$^d":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Repeat"]
            return
        case "$g":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Glue"]
            return
        case "$+g":
            CloseCurrentMenu()
            Send % MacroKeys["Dissolve"]
            return
        case "$r":
            CloseCurrentMenu()
            Send % MacroKeys["Render in Place - Render"]
            return
        case "$^r":
            CloseCurrentMenu()
            Send % MacroKeys["Render in Place - Render Setup..."]
            return
        case "$+s":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - To Real Copy"]
            return
        case "$x":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Split Range"]
            return
        case "$+x":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Crop Range"]
            return
        case "$z":
            CloseCurrentMenu()
            Send % MacroKeys["Zoom - Zoom to Selection Horizontally"]
            return
        case "$Space":
            CloseCurrentMenu()
            Send % MacroKeys["Transport - Locate Selection"]
            return
        case "$^Space":
            CloseCurrentMenu()
            Send % MacroKeys["Edit - Move to Cursor"]
            return
        case "$+Space":
            CloseCurrentMenu()
            Send % MacroKeys["Transport - Locators to Selection"]
            return
        }

        if (Context & ContextSelectedAudio) {
            switch A_ThisHotkey
            {
            case "$b":
                CloseCurrentMenu()
                Send % MacroKeys["Audio - Bounce"]
                return
            case "$p":
                CloseCurrentMenu()
                Send % MacroKeys["Audio - Find Selected in Pool"]
                return
            }

            return
        }

        if (Context & ContextSelectedMidi) {
            switch A_ThisHotkey
            {
            case "$f":
                TryOpenCurrentSubMenu(Menu, "Functions")
                return
            case "$q":
                CloseCurrentMenu()
                Send % MacroKeys["MIDI - Quantize"]
                return
            case "$^q":
                CloseCurrentMenu()
                Send % MacroKeys["MIDI - Quantize Ends"]
                return
            case "$+q":
                CloseCurrentMenu()
                Send % MacroKeys["MIDI - Undo Quantize"]
                return
            case "$^+q":
                CloseCurrentMenu()
                Send % MacroKeys["MIDI - Quantize Lengths"]
                return
            case "$v":
                CloseCurrentMenu()
                Send % MacroKeys["MIDI - Legato"]
                return
            }

            if (!(Context & ContextKeyEditor)) {
                switch A_ThisHotkey
                {
                case "$^s":
                    CloseCurrentMenu()
                    Send % MacroKeys["File - Export MIDI Loop"]
                    return
                }

                return
            }

            return
        }

        return
    }

    Send % "{Blind}" GetSendHotkey(A_ThisHotkey)
    return

#If

IsActiveDialog()
{
    return (WinActive("ahk_group AppExe") || WinActive("ahk_group CurrentProcess")) && WinActive("ahk_group SystemDialog")
}

#If IsActiveDialog()

$F1::
$F2::
$F3::
$F4::
$F5::
$F6::
$F7::
$F8::
$F9::
$F10::
$F11::
$F12::
    Number := SubStr(A_ThisHotkey, 3, 1)
    IniRead Path, % SettingsPath, % "FileDialogPaths", % "F" Number, % A_Space
    if (Path != A_Space && InStr(FileExist(Path), "D")) {
        TryFileDialogNavigate(Path, "A")
    }
    return

#If

IsValidKeyCommandsXml(KeyCommandsXml)
{
    return KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Categories']") && KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")
}

IsInstalled(Hash, KeyCommandsXml)
{
    return !!KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']/item/string[@name='Name' and @value='" HashMacroPrefix Hash "']")
}

InstallKeyCommands(Xml, KeyCommandsXml)
{
    static NextAutoKey := Chr(0xA500)

    Commands := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Categories']/item/string[@name='Name' and @value='Macro']/../list[@name='Commands']")
    Macros := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")

    for XmlMacro in Xml.selectNodes("/night/macros/item") {
        XmlName := XmlMacro.selectSingleNode("string[@name='Name']").getAttribute("value")

        MacroToAdd := XmlMacro.cloneNode(true)

        MacroToAdd.selectSingleNode("string[@name='Name']").setAttribute("value", MacroPrefix XmlName)

        if (Child := MacroToAdd.selectSingleNode("string[@name='Key']")) {
            MacroToAdd.removeChild(Child)
        }

        for Macro in Macros.selectNodes("item") {
            MacroName := Macro.selectSingleNode("string[@name='Name']").getAttribute("value")
            if (XmlName == MacroName) {
                Macros.replaceChild(MacroToAdd, Macro)
                MacroToAdd :=
                break
            }
        }

        if (MacroToAdd) {
            Macros.appendChild(MacroToAdd)
        }

        CommandToAdd := XmlMacro.cloneNode(true)

        CommandToAdd.selectSingleNode("string[@name='Name']").setAttribute("value", MacroPrefix XmlName)

        if (Child := MacroToAdd.selectSingleNode("string[@name='Commands']")) {
            CommandToAdd.removeChild(Child)
        }

        CommandToAddKey := CommandToAdd.selectSingleNode("string[@name='Key']")
        if (CommandToAddKey && CommandToAddKey.getAttribute("value") == "auto") {
            CommandToAddKey.setAttribute("value", NextAutoKey)
            NextAutoKey := Chr(Ord(NextAutoKey) + 1)
        }

        for Command in Commands.selectNodes("item") {
            CommandName := Command.selectSingleNode("string[@name='Name']").getAttribute("value")
            if (XmlName == CommandName) {
                Commands.replaceChild(CommandToAdd, Command)
                CommandToAdd :=
                break
            }
        }

        if (CommandToAdd) {
            Commands.appendChild(CommandToAdd)
        }
    }
}

InstallPle(Xml, PlePath)
{
    FileCreateDir % PlePath "\" PleFolderName

    for Ple in Xml.selectNodes("/night/ple/item") {
        Name := Ple.selectSingleNode("string[@name='Name']").getAttribute("value")
        Path := PlePath "\" PleFolderName "\" Name ".xml"

        Data := Ple.selectSingleNode("Project_Logical_EditorPreset").xml

        FileDelete % Path
        FileAppend % Data, % Path
    }
}

InstallHashMacro(Hash, KeyCommandsXml)
{
    Name := KeyCommandsXml.createElement("string")
    Name.setAttribute("name", "Name")
    Name.setAttribute("value", HashMacroPrefix Hash)

    Item := KeyCommandsXml.createElement("item")
    Item.appendChild(Name)

    Macros := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")
    Macros.appendChild(Item)
}

Uninstall(KeyCommandsPath, PlePath)
{
    FileRead KeyCommandsData, % KeyCommandsPath

    if ((KeyCommandsXml := LoadXml(KeyCommandsData))) {
        UninstallKeyCommands(KeyCommandsXml)

        FileDelete % KeyCommandsPath
        FileAppend % KeyCommandsXml.xml, % KeyCommandsPath
    }

    UninstallPle(PlePath)
}

UninstallKeyCommands(KeyCommandsXml)
{
    Macros := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")
    for Macro in Macros.selectNodes("item") {
        Name := Macro.selectSingleNode("string[@name='Name']").getAttribute("value")
        if (InStr(Name, HashMacroPrefix, true) == 1 || InStr(Name, MacroPrefix, true) == 1) {
            Macros.removeChild(Macro)
        }
    }

    Commands := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Categories']/item/string[@name='Name' and @value='Macro']/../list[@name='Commands']")
    for Command in Commands.selectNodes("item") {
        Name := Command.selectSingleNode("string[@name='Name']").getAttribute("value")
        if (InStr(Name, HashMacroPrefix, true) == 1 || InStr(Name, MacroPrefix, true) == 1) {
            Commands.removeChild(Command)
        }
    }
}

UninstallPle(PlePath)
{
    FileRemoveDir % PlePath "\" PleFolderName, true
}

LoadMacroKeys(KeyCommandsXml)
{
    Keys := []

    Commands := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Categories']/item/string[@name='Name' and @value='Macro']/../list[@name='Commands']")
    for Command in Commands.selectNodes("item") {
        Name := Command.selectSingleNode("string[@name='Name']").getAttribute("value")
        if (InStr(Name, MacroPrefix, true) == 1) {
            Name := StrReplace(Name, MacroPrefix, "", , 1)
            Key := "{" Command.selectSingleNode("string[@name='Key']").getAttribute("value") "}"
            Keys[Name] := Key
        }
    }

    return Keys
}

FocusColorizeWindow()
{
    WinActivate % "ahk_group AppColorizeWindow"
    MouseGetPos X, Y
    WinGetPos, , , Width, Height, % "ahk_group AppColorizeWindow"

    X := Max(50, Min(A_ScreenWidth - 50 - Width, X - Width // 2))
    Y := Max(50, Min(A_ScreenHeight - 50 - Height, Y - 5))

    WinMove % "ahk_group AppColorizeWindow", , % X, % Y
}

PatchProjectColors(ProjectPath, ColorsPath)
{
    if (!(File := FileOpen(ProjectPath, "a")) || !(Mapping := MapFile(File.__Handle, Address))) {
        return false
    }

    Patched := 0

    loop 128 {
        IniRead Value, % ColorsPath, % "Colors", % A_Index, % A_Space
        if (InStr(Value, "#", true) != 1 || StrLen(Value) != 7) {
            continue
        }
        if (!CryptStringToBinary(SubStr(Value, 2) "00", Value, 0xc)) {
            continue
        }
        Value := NumGet(&Value, "UInt")

        Search := CryptUtf8ToString("Color " A_Index, 0xc | 0x40000000) "00efbbbfff"
        SearchCount := CryptStringToBinary(Search, SearchBytes, 0xc)
        Start := 0
        loop {
            Found := SearchBytesInBytes(Address + Start, File.Length - Start, &SearchBytes, SearchCount)
            if (!Found) {
                break
            }

            if (!Start) {
                ++Patched
            }
            Start := (Found - Address) + SearchCount + 4

            if (NumGet(Address + Start - 1, "UChar") != 0) {
                continue
            }
            NumPut(Value, Address + Start - 4, "UInt")
        }
    }

    UnmapFile(Mapping, Address)
    File.Close()

    return Patched
}

ToolTipTimeout(Text, Timeout)
{
    ToolTip % Text
    SetTimer RemoveToolTip, % -Timeout
}

RemoveToolTip()
{
    ToolTip
}

GetSendHotkey(Hotkey)
{
    ; https://www.autohotkey.com/board/topic/9223-the-shortest-way-to-send-a-thishotkey/?p=59906

    if (Hotkey != "$" && Hotkey != "*" && Hotkey != "~") {
        Hotkey := StrReplace(Hotkey, "$")
        Hotkey := StrReplace(Hotkey, "*")
        Hotkey := StrReplace(Hotkey, "~")
    }

    Hotkey2 := StrReplace(Hotkey, "!")
    Hotkey2 := StrReplace(Hotkey2, "#")
    Hotkey2 := StrReplace(Hotkey2, "^")
    Hotkey2 := StrReplace(Hotkey2, "+")

    Hotkey := SubStr(Hotkey, 1, StrLen(Hotkey) - StrLen(Hotkey2))

    if (Hotkey2 == "") {
        return "{" Hotkey "}"
    } else {
        return Hotkey "{" Hotkey2 "}"
    }
}

GetWaitHotkey(Hotkey)
{
    return SubStr(GetSendHotkey(Hotkey), 2, StrLen(Hotkey) - 1)
}

TryFileDialogNavigate(Path, WinTitle)
{
    ControlGetText RestoreText, Edit1, % WinTitle
    if ErrorLevel {
        return
    }

    ControlFocus Edit1, % WinTitle
    ControlSetText Edit1, % Path, % WinTitle
    ControlSend Edit1, % "{Enter}", % WinTitle
    ControlFocus Edit1, % WinTitle
    ControlSetText Edit1, % RestoreText, % WinTitle
}

GetMenuItemCount(Menu)
{
    return DllCall("user32\GetMenuItemCount", "Ptr", Menu)
}

GetMenuItemName(Menu, Index)
{
    Count := DllCall("user32\GetMenuString", "Ptr", Menu, "UInt", Index, "Ptr", 0, "Int", 0, "UInt", 0x400) + 1
    VarSetCapacity(Name, Count << !!A_IsUnicode)
    DllCall("user32\GetMenuString", "Ptr", Menu, "UInt", Index, "Str", Name, "Int", Count, "UInt", 0x400)
    return Name
}

GetMenuItemState(Menu, Index)
{
    return DllCall("user32\GetMenuState", "Ptr", Menu, "UInt", Index, "UInt", 0x400)
}

FindMenuItemIndex(Menu, Name)
{
    loop % GetMenuItemCount(Menu) {
        CurrentName := GetMenuItemName(Menu, A_Index - 1)
        CurrentName := StrSplit(StrReplace(CurrentName, "&"), "`t", , 2)[1]
        if (CurrentName == Name) {
            return A_Index - 1
        }
    }
    return -1
}

GetCurrentMenu()
{
    SendMessage 0x1e1, , , , % "ahk_group SystemMenu"
    if (ErrorLevel == "FAIL") {
        return false
    }
    return ErrorLevel
}

CloseCurrentMenu()
{
    SendMessage 0x1e6, , , , % "ahk_group SystemMenu"
}

OpenCurrentSubMenu(Index)
{
    SendMessage 0x1ed, % Index, 0, , % "ahk_group SystemMenu"
    return GetCurrentMenu()
}

SelectCurrentMenuItem(Index)
{
    PostMessage 0x1f1, % Index, 0, , % "ahk_group SystemMenu"
}

TryOpenCurrentSubMenu(Menu, Name)
{
    Index := FindMenuItemIndex(Menu, Name)
    if (Index == -1) {
        return false
    }
    OpenCurrentSubMenu(Index)
    return true
}

TrySelectCurrentMenuItem(Menu, Name)
{
    Index := FindMenuItemIndex(Menu, Name)
    if (Index == -1) {
        return false
    }
    SelectCurrentMenuItem(Index)
    return true
}

GetTempFilePath()
{
    static FileSystemObject
    if (!FileSystemObject) {
        FileSystemObject := ComObjCreate("Scripting.FileSystemObject")
    }
    return FileSystemObject.GetTempName()
}

HashFile(Path, Algorithm)
{
    OutputPath := GetTempFilePath()
    Shell := ComObjCreate("WScript.Shell")
    Shell.Run("cmd /c certutil -hashfile """ Path """ " Algorithm " >" OutputPath, 0, true)
    FileRead Output, % OutputPath
    FileDelete % OutputPath
    return StrSplit(Output, "`n", "`r", 3)[2]
}

LoadXml(String)
{
    Xml := ComObjCreate("MSXML2.DOMDocument.6.0")
    Xml.setProperty("SelectionLanguage", "XPath")
    Xml.async := false
    if (!Xml.loadXML(String)) {
        return false
    }
    return Xml
}

GetFileVersionInfo(Path, Fields)
{
    ; https://www.autohotkey.com/boards/viewtopic.php?p=46622#p46622

    Size := DllCall("version\GetFileVersionInfoSize", "Str", Path, "Ptr", 0)
    Size := VarSetCapacity(Data, Size + A_PtrSize)
    DllCall("version\GetFileVersionInfo", "Str", Path, "UInt", 0, "UInt", Size, "Ptr", &Data)
    DllCall("version\VerQueryValue", "Ptr", &Data, "Str", "\VarFileInfo\Translation", "PtrP", VersionInfo, "PtrP", VersionInfoSize)
    Language := Format("{:04X}{:04X}", NumGet(VersionInfo + 0, "UShort"), NumGet(VersionInfo + 2, "UShort"))
    Info := {}
    loop parse, % Fields, % A_Space
    {
        if (DllCall("version\VerQueryValue", "Ptr", &Data, "Str", "\StringFileInfo\" Language "\" A_LoopField, "PtrP", VersionInfo, "PtrP", VersionInfoSize)) {
            Info[A_LoopField] := StrGet(VersionInfo, VersionInfoSize)
        }
    }
    return Info
}

MapFile(FileHandle, ByRef Address)
{
    Mapping := DllCall("CreateFileMapping", "Ptr", FileHandle, "Ptr", 0, "Int", 0x4, "Int", 0, "Int", 0, "Ptr", 0, "Ptr")
    if (!Mapping) {
        return false
    }

    Address := DllCall("MapViewOfFile", "Ptr", Mapping, "Int", 0xf001f, "Int", 0, "Int", 0, "Ptr", 0, "Ptr")
    if (!Address) {
        DllCall("CloseHandle", "Ptr", Mapping)
        return false
    }

    return Mapping
}

UnmapFile(Mapping, Address)
{
    DllCall("UnmapViewOfFile", "Ptr", Address)
    DllCall("CloseHandle", "Ptr", Mapping)
}

SearchBytesInBytes(Address, Count, SearchAddress, SearchCount)
{
    static Bin
    if (!VarSetCapacity(Bin)) {
        ; https://www.autohotkey.com/boards/viewtopic.php?t=90318
        Size := CryptStringToBinary("U1ZXQVSLRCRIRItcJFCJ00Qpy4XAvgEAAABBuv////9BD07yhcB+B2dEjVD/6wgBwkGJ0kUpykGD6QFFhdJyQzHSQTnadzxEidBBijhAODwBdShEichBigQAZ0ONPAqJ/zgEOXUVQYP5AnMbg8IB6wVEOc909kQ52nRDQQHyRYXSc78xwOs9vwEAAABBg/kBdt8PH0QAAGYPH4QAAAAAAIn4QYoEAGdFjSQ6RYnkQjgEIXW9g8cBRDnPcuTrs0SJ0EgByEFcX15bwwAARYXAdjoxwEGJwUaKFAlBgPpAdhJBicNCgDwZW3MIQbsgAAAA6wNFMdtFD7bSRQHaRYjSRogUCoPAAUQ5wHLIww", Bin, 0x1)
        DllCall("VirtualProtect", "Ptr", &Bin, "Ptr", Size, "UInt", 0x40, "UIntP", 0)
    }

    return DllCall(&Bin, "Ptr", Address, "Int", Count, "Ptr", SearchAddress, "Short", SearchCount, "Int", 1, "Int", 1, "CDecl Ptr")
}

CryptUtf8ToString(String, Flags)
{
    VarSetCapacity(Binary, StrPut(String, "UTF-8"))
    Size := StrPut(String, &Binary, "UTF-8") - 1
    return CryptBinaryToString(&Binary, Size, Flags)
}

CryptBinaryToString(Binary, Size, Flags)
{
    if (!DllCall("crypt32\CryptBinaryToString", "Ptr", Binary, "UInt", Size, "UInt", Flags, "Ptr", 0, "UIntP", Count)) {
        return false
    }

    VarSetCapacity(String, Count << !!A_IsUnicode)
    if (!DllCall("crypt32\CryptBinaryToString", "Ptr", Binary, "UInt", Size, "UInt", Flags, "Ptr", &String, "UIntP", Count)) {
        return false
    }

    return StrGet(&String)
}

CryptStringToBinary(String, ByRef Binary, Flags)
{
    if (!DllCall("crypt32\CryptStringToBinary", "Str", String, "UInt", 0, "UInt", Flags, "Ptr", 0, "UIntP", Size, "UInt", 0, "UInt", 0)) {
        return false
    }

    VarSetCapacity(Binary, Size)
    if (!DllCall("crypt32\CryptStringToBinary", "Str", String, "UInt", 0, "UInt", Flags, "Ptr", &Binary, "UIntP", Size, "UInt", 0, "UInt", 0)) {
        return false
    }

    return Size
}
