#SingleInstance Force
#MenuMaskKey vkFF
#NoEnv

if (!A_IsUnicode || A_PtrSize != 8) {
    ExitApp
}

DetectHiddenWindows On
SetTitleMatchMode RegEx

Join(Items, Separator) {
    loop % Items.Count() {
        if (A_Index == 1) {
            String := "" Items[A_Index]
            continue
        }
        String := String Separator Items[A_Index]
    }
    return String
}

JoinPath(Path, ChildPath) {
    VarSetCapacity(Joined, 260 << !!A_IsUnicode, 1)
    DllCall("shlwapi\PathCombine", "UInt", &Joined, "UInt", &Path, "UInt", &ChildPath)
    return Joined
}

EnsureTrailingBackslash(String) {
    if (SubStr(String, 0, 1) != "\") {
        return String "\"
    }
    return String
}

ReadFileUtf8(Path) {
    FileRead Data, % "*P65001 " Path
    return Data
}

ConsumeFileUtf8(Path) {
    Data := ReadFileUtf8(Path)
    FileDelete % Path
    return Data
}

WriteFileUtf8(Path, Data) {
    FileDelete % Path
    FileAppend % Data, % Path, % "UTF-8-RAW"
}

GenerateRandomGuid() {
    return ComObjCreate("Scriptlet.TypeLib").GUID
}

CreateTempFilePath() {
    loop {
        Path := JoinPath(A_Temp, GenerateRandomGuid())
        if (!FileExist(Path)) {
            return Path
        }
    }
}

HashFile(Path, Algorithm) {
    OutputPath := CreateTempFilePath()
    Shell := ComObjCreate("WScript.Shell")
    Shell.Run("cmd /c certutil -hashfile """ Path """ " Algorithm " >" OutputPath, 0, true)
    return StrSplit(ConsumeFileUtf8(OutputPath), "`n", "`r", 3)[2]
}

LoadXml(String) {
    Xml := ComObjCreate("MSXML2.DOMDocument.6.0")
    Xml.setProperty("SelectionLanguage", "XPath")
    Xml.async := false
    if (!Xml.loadXML(String)) {
        return
    }
    return Xml
}

GetFileVersionInfo(Path, Fields) {
    ; https://www.autohotkey.com/boards/viewtopic.php?p=46622#p46622

    Size := DllCall("version\GetFileVersionInfoSize", "Str", Path, "Ptr", 0, "UInt")
    Size := VarSetCapacity(Data, Size + A_PtrSize)
    DllCall("version\GetFileVersionInfo", "Str", Path, "UInt", 0, "UInt", Size, "Ptr", &Data)
    DllCall("version\VerQueryValue", "Ptr", &Data, "Str", "\VarFileInfo\Translation", "PtrP", VersionInfo, "PtrP", VersionInfoSize)
    Language := Format("{:04X}{:04X}", NumGet(VersionInfo + 0, "UShort"), NumGet(VersionInfo + 2, "UShort"))
    Info := {}
    for _, Field in Fields {
        if (DllCall("version\VerQueryValue", "Ptr", &Data, "Str", "\StringFileInfo\" Language "\" Field, "PtrP", VersionInfo, "PtrP", VersionInfoSize, "Int")) {
            Info[Field] := StrGet(VersionInfo, VersionInfoSize)
        }
    }
    return Info
}

MapFile(FileHandle, ByRef Address) {
    Mapping := DllCall("CreateFileMapping", "Ptr", FileHandle, "Ptr", 0, "Int", 0x4, "Int", 0, "Int", 0, "Ptr", 0, "Ptr")
    if (!Mapping) {
        return false
    }

    Address := DllCall("MapViewOfFile", "Ptr", Mapping, "Int", 0xF001F, "Int", 0, "Int", 0, "Ptr", 0, "Ptr")
    if (!Address) {
        DllCall("CloseHandle", "Ptr", Mapping)
        return false
    }

    return Mapping
}

UnmapFile(Mapping, Address) {
    DllCall("UnmapViewOfFile", "Ptr", Address)
    DllCall("CloseHandle", "Ptr", Mapping)
}

SearchBytesInBytes(Address, Count, SearchAddress, SearchCount) {
    static Bin
    if (!VarSetCapacity(Bin)) {
        ; https://www.autohotkey.com/boards/viewtopic.php?t=90318
        Size := CryptStringToBinary("U1ZXQVSLRCRIRItcJFCJ00Qpy4XAvgEAAABBuv////9BD07yhcB+B2dEjVD/6wgBwkGJ0kUpykGD6QFFhdJyQzHSQTnadzxEidBBijhAODwBdShEichBigQAZ0ONPAqJ/zgEOXUVQYP5AnMbg8IB6wVEOc909kQ52nRDQQHyRYXSc78xwOs9vwEAAABBg/kBdt8PH0QAAGYPH4QAAAAAAIn4QYoEAGdFjSQ6RYnkQjgEIXW9g8cBRDnPcuTrs0SJ0EgByEFcX15bwwAARYXAdjoxwEGJwUaKFAlBgPpAdhJBicNCgDwZW3MIQbsgAAAA6wNFMdtFD7bSRQHaRYjSRogUCoPAAUQ5wHLIww", Bin, 0x1)
        DllCall("VirtualProtect", "Ptr", &Bin, "Ptr", Size, "UInt", 0x40, "UIntP", 0)
    }

    return DllCall(&Bin, "Ptr", Address, "Int", Count, "Ptr", SearchAddress, "Short", SearchCount, "Int", 1, "Int", 1, "CDecl Ptr")
}

CryptUtf8ToString(String, Flags) {
    VarSetCapacity(Binary, StrPut(String, "UTF-8"))
    Size := StrPut(String, &Binary, "UTF-8") - 1
    return CryptBinaryToString(&Binary, Size, Flags)
}

CryptBinaryToString(Binary, Size, Flags) {
    if (!DllCall("crypt32\CryptBinaryToString", "Ptr", Binary, "UInt", Size, "UInt", Flags, "Ptr", 0, "UIntP", Count, "Int")) {
        return false
    }

    VarSetCapacity(String, Count << !!A_IsUnicode)
    if (!DllCall("crypt32\CryptBinaryToString", "Ptr", Binary, "UInt", Size, "UInt", Flags, "Ptr", &String, "UIntP", Count, "Int")) {
        return false
    }

    return StrGet(&String)
}

CryptStringToBinary(String, ByRef Binary, Flags) {
    if (!DllCall("crypt32\CryptStringToBinary", "Str", String, "UInt", 0, "UInt", Flags, "Ptr", 0, "UIntP", Size, "UInt", 0, "UInt", 0, "Int")) {
        return false
    }

    VarSetCapacity(Binary, Size)
    if (!DllCall("crypt32\CryptStringToBinary", "Str", String, "UInt", 0, "UInt", Flags, "Ptr", &Binary, "UIntP", Size, "UInt", 0, "UInt", 0, "Int")) {
        return false
    }

    return Size
}

ShellParseDisplayName(Path) {
    ; no way im doing THAT one
    ; https://en.delphipraxis.net/topic/4827-parse-pidl-from-name-located-on-portable-device/
    ; https://stackoverflow.com/questions/42966489/how-to-use-shcreateitemfromparsingname-with-names-from-the-shell-namespace
    ; https://stackoverflow.com/questions/27593315/how-can-i-iterate-across-the-photos-on-my-connected-iphone-from-windows-7-in-pyt

    for Item in ComObjCreate("Shell.Application").NameSpace(0x0).Items {
        if (InStr(Item.Path, "::{", true) == 1 && Item.Name == Path) {
            ParsePath := "shell:" Item.Path
            break
        }
    }

    if (!ParsePath) {
        static SpecialFolders := Object("Desktop", "shell:::{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}"
            , "Documents", "shell:::{A8CDFF1C-4878-43BE-B5FD-F8091C1C60D0}"
            , "Downloads", "shell:::{374DE290-123F-4565-9164-39C4925E467B}"
            , "Music", "shell:::{1CF1260C-4DD0-4EBB-811F-33C572699FDE}"
            , "Pictures", "shell:::{3ADD1653-EB32-4CB0-BBD7-DFA0ABB5ACCA}"
            , "Public", "shell:::{4336A54D-038B-4685-AB02-99BB52D3FB8B}"
            , "Recycle Bin", "shell:::{645FF040-5081-101B-9F08-00AA002F954E}"
            , "This PC", "shell:::{20D04FE0-3AEA-1069-A2D8-08002B30309D}")

        ParsePath := SpecialFolders[Path]
    }

    if (!ParsePath) {
        ParsePath := EnsureTrailingBackslash(Path)
    }

    DllCall("shell32\SHParseDisplayName", "Str", ParsePath, "Ptr", 0, "Ptr*", Pidl, "UInt", 0, "UInt*", 0)
    return Pidl
}

ShellGetPidlPath(Pidl) {
    VarSetCapacity(Path, 512)
    DllCall("shell32\SHGetPathFromIDListW", "UInt", Pidl, "Str", Path)
    return Path
}

ShellOpenFolderAndSelect(Path, Paths, Flags) {
    PathsCount := Paths.Count()

    PathPidl := ShellParseDisplayName(Path)
    VarSetCapacity(PathsPidls, PathsCount * A_PtrSize, 0)
    loop % Paths.Count() {
        NumPut(ShellParseDisplayName(Paths[A_Index]), PathsPidls, (A_Index - 1) * A_PtrSize, "Ptr")
    }

    DllCall("shell32\SHOpenFolderAndSelectItems", "Ptr", PathPidl, "UInt", PathsCount, "Ptr", &PathsPidls, "Int", Flags)

    DllCall("ole32\CoTaskMemFree", "Ptr", PathPidl)
    loop % Paths.Count() {
        DllCall("ole32\CoTaskMemFree", "Ptr", NumGet(PathsPidls, (A_Index - 1) * A_PtrSize, "Ptr"))
    }
}

GetMonitorFromPoint(X, Y) {
    return DllCall("MonitorFromPoint", "Int64", X | (Y << 32), "UInt", 0)
}

GetMonitorWorkArea(Monitor, ByRef X, ByRef Y, ByRef Width, ByRef Height) {
    VarSetCapacity(MonitorInfo, 0x28)
    NumPut(0x28, &MonitorInfo, 0x0)
    DllCall("GetMonitorInfo", "Ptr", Monitor, "Ptr", &MonitorInfo)

    X := NumGet(&MonitorInfo + 0x14, "Int")
    Y := NumGet(&MonitorInfo + 0x18, "Int")
    Width := NumGet(&MonitorInfo + 0x1c, "Int") - X
    Height := NumGet(&MonitorInfo + 0x20, "Int") - Y
}

global _FindWindowChildrenRecursiveList

_FindWindowChildrenRecursiveProc(hwnd, lParam) {
    _FindWindowChildrenRecursiveList.Push(hwnd)
}

global _FindWindowChildrenRecursiveCallback := RegisterCallback("_FindWindowChildrenRecursiveProc", "F")

FindWindowChildrenRecursive(Hwnd) {
    _FindWindowChildrenRecursiveList := []
    DllCall("EnumChildWindows", "Ptr", Hwnd, "Ptr", _FindWindowChildrenRecursiveCallback, "Ptr", 0)
    return _FindWindowChildrenRecursiveList
}

SetWinEventHook(EventMin, EventMax, FuncName) {
    DllCall("SetWinEventHook", "UInt", EventMin, "UInt", EventMax, "Ptr", 0, "Ptr", RegisterCallback(FuncName, "F"), "UInt", 0, "UInt", 0, "UInt", 0)
}

GetHwndClass(Hwnd) {
    WinGetClass Cls, % "ahk_id " Hwnd
    return Cls
}

GetControlHwndNN(Hwnd, ControlHwnd, ControlClass) {
    WinGet Controls, ControlListHwnd, % "ahk_id " Hwnd
    Nn := 0
    loop parse, Controls, `n
    {
        WinGetClass Class_, % "ahk_id " A_LoopField
        if (Class_ == ControlClass) {
            Nn += 1
            if (A_LoopField == ControlHwnd) {
                break
            }
        }
    }
    return Nn
}

GetFocus(Hwnd) {
    CurrentThreadId := DllCall("GetCurrentThreadId", "UInt")
	HwndThreadId := DllCall("GetWindowThreadProcessId", "UInt", Hwnd, "UIntP", 0, "UInt")
	if (!DllCall("AttachThreadInput", "UInt", CurrentThreadId, "UInt", HwndThreadId, "Int", 1, "Int")) {
        return
    }
    Focus := DllCall("GetFocus", "Ptr")
    DllCall("AttachThreadInput", "UInt", CurrentThreadId, "UInt", HwndThreadId, "Int", 0)
    return Focus
}

SetFocus(Hwnd, ControlHwnd) {
    CurrentThreadId := DllCall("GetCurrentThreadId", "UInt")
	HwndThreadId := DllCall("GetWindowThreadProcessId", "UInt", Hwnd, "UIntP", 0, "UInt")
	if (!DllCall("AttachThreadInput", "UInt", CurrentThreadId, "UInt", HwndThreadId, "Int", 1, "Int")) {
        return
    }
    DllCall("SetFocus", "Ptr", ControlHwnd)
    DllCall("AttachThreadInput", "UInt", CurrentThreadId, "UInt", HwndThreadId, "Int", 0)
}

global ToolTipTitle := "ahk_class ^tooltips_class32$"

ToolTip(Text := "", X := "", Y := "", Timeout := 0, WhichToolTip := "") {
    static Timers := {}

    if (!WhichToolTip) {
        WhichToolTip := 1
    }

    ToolTip % Text, % X, % Y, % WhichToolTip

    if (Timers[WhichToolTip]) {
        F := Timers[WhichToolTip]
        Timers[WhichToolTip] :=
        SetTimer % F, Off
    }

    if (Text && Timeout) {
        F := Func("ToolTip").Bind(, , , , WhichToolTip)
        Timers[WhichToolTip] := F
        SetTimer % F, % -Timeout
    }
}

global MenuTitle := "ahk_class ^#32768$"

GetMenuItemCount(Menu) {
    return DllCall("GetMenuItemCount", "Ptr", Menu, "Int")
}

GetMenuItemName(Menu, Index) {
    Count := DllCall("GetMenuString", "Ptr", Menu, "UInt", Index, "Ptr", 0, "Int", 0, "UInt", 0x400, "Int") + 1
    VarSetCapacity(Name, Count << !!A_IsUnicode)
    DllCall("GetMenuString", "Ptr", Menu, "UInt", Index, "Str", Name, "Int", Count, "UInt", 0x400)
    return Name
}

GetMenuItemState(Menu, Index) {
    return DllCall("GetMenuState", "Ptr", Menu, "UInt", Index, "UInt", 0x400, "UInt")
}

FindMenuItemIndex(Menu, Name) {
    loop % GetMenuItemCount(Menu) {
        CurrentName := GetMenuItemName(Menu, A_Index - 1)
        CurrentName := StrSplit(StrReplace(CurrentName, "&"), "`t", , 2)[1]
        if (CurrentName == Name) {
            return A_Index - 1
        }
    }
    return -1
}

GetActiveMenu() {
    SendMessage 0x1E1, , , , % MenuTitle
    if (ErrorLevel == "FAIL") {
        return false
    }
    return ErrorLevel
}

CloseActiveMenu() {
    SendMessage 0x1E6, , , , % MenuTitle
}

OpenActiveSubMenu(Index) {
    SendMessage 0x1ED, % Index, 0, , % MenuTitle
}

SelectActiveMenuItem(Index) {
    PostMessage 0x1F1, % Index, 0, , % MenuTitle
}

TryOpenActiveSubMenu(Menu, Name) {
    Index := FindMenuItemIndex(Menu, Name)
    if (Index == -1) {
        return false
    }
    OpenActiveSubMenu(Index)
    return true
}

TrySelectActiveMenuItem(Menu, Name) {
    Index := FindMenuItemIndex(Menu, Name)
    if (Index == -1) {
        return false
    }
    SelectActiveMenuItem(Index)
    return true
}

global DialogTitle := "ahk_class ^#32770$"

global FileDialogListViewControlClassNN := "DirectUIHWND2"

IsDialogFileDialog(WinTitle) {
    ControlGet ControlHwnd, Hwnd, , % FileDialogListViewControlClassNN, % WinTitle
    return !!ControlHwnd
}

FileDialogActiveGetFolderPath(ByRef ActiveControlHwnd, ByRef ActiveControlClass, ByRef ActiveControlNn) {
    SendPlay % "^{l}"

    Start := A_TickCount
    while ((ActiveControlClass ActiveControlNn) != "Edit2") {
        if (A_TickCount - Start > 1000) {
            return
        }
        Sleep % 5
    }

    ControlGetText Path, , % "ahk_id " ActiveControlHwnd
    ControlSend, , % "{Escape}", % "ahk_id " ActiveControlHwnd
    return Path
}

FileDialogActiveNavigate(Hwnd, Paths) {
    ControlGet ControlHwnd, Hwnd, , % "Edit1", % "ahk_id " Hwnd
    SetFocus(Hwnd, ControlHwnd)
    ControlSetText, , % """" Join(Paths, """ """) """", % "ahk_id " ControlHwnd
    SendPlay % "{Enter}{Delete}"
}

;@Ahk2Exe-Bin Unicode 64-bit.bin

;@Ahk2Exe-SetDescription night
;@Ahk2Exe-SetFileVersion 1.2.0
;@Ahk2Exe-SetInternalName night
;@Ahk2Exe-SetCopyright https://github.com/t5mat/night
;@Ahk2Exe-SetOrigFilename night.exe
;@Ahk2Exe-SetProductName night
;@Ahk2Exe-SetProductVersion 1.2.0

global Version := "1.2.0"
global Url := "https://github.com/t5mat/night"

global MacroPrefix := "~ night - "
global PleFolderName := "night"
global VersionMacroPrefix := "~ night "

global SelfPid := DllCall("GetCurrentProcessId", "UInt")

global SettingsPath
global AppExePath
global AppExeVersionInfo
global AppName
global KeyCommandsPath
global PlePath
global MacroKeys

FindAppExeWindow() {
    return WinExist("ahk_exe i)^\Q" AppExePath "\E$")
}

FindAppProjectWindow() {
    WinGet Hwnds, List, % "^" AppName "(?: .*?)? Project - .*$ ahk_class ^SteinbergWindowClass$ ahk_exe i)^\Q" AppExePath "\E$"
    loop % Hwnds {
        for _, Child in FindWindowChildrenRecursive(Hwnds%A_Index%) {
            if (WinExist("ahk_class ^SteinbergChildWindowNoMouseHandlingClass$ ahk_id " Child)) {
                return Hwnds%A_Index%
            }
        }
    }
}

IsAppColorizeWindow(Hwnd) {
    return (WinExist("^Colorize$ ahk_class ^SteinbergWindowClass$ ahk_exe i)^\Q" AppExePath "\E$ ahk_id " Hwnd) && FindWindowChildrenRecursive(Hwnd).Count() == 0)
}

global HwndContextFileDialog := (1 << 0)
global HwndContextSelf := (1 << 1)
global HwndContextApp := (1 << 2)
global HwndContextAppMenu := (1 << 3)
global HwndContextAppTitleBar := (1 << 4)
global HwndContextAppWindow := (1 << 5)
global HwndContextAppChildWindow := (1 << 6)
global HwndContextAppProjectWindow := (1 << 7)
global HwndContextAppColorizeWindow := (1 << 8)

FindHwndContext(Hwnd) {
    Context := 0

    if (IsDialogFileDialog(DialogTitle " ahk_id " Hwnd)) {
        Context := Context | HwndContextFileDialog
    }

    if (WinExist("ahk_pid " SelfPid " ahk_id " Hwnd)) {
        Context := Context | HwndContextSelf
    } else if (WinExist("ahk_exe i)^\Q" AppExePath "\E$ ahk_id " Hwnd)) {
        Context := Context | HwndContextApp
        if (WinExist("ahk_class ^SmtgMain MenuWindowClass$ ahk_id " Hwnd)) {
            Context := Context | HwndContextAppMenu
        } else if (WinExist("ahk_class ^SmtgMain " AppName ".*$ ahk_id " Hwnd)) {
            Context := Context | HwndContextAppTitleBar
        } else if (WinExist("ahk_class ^SteinbergWindowClass$ ahk_id " Hwnd)) {
            Context := Context | HwndContextAppWindow

            Children := FindWindowChildrenRecursive(Hwnd)
            if (Children.Count() == 0) {
                if (WinExist("^Colorize$ ahk_id " Hwnd)) {
                    Context := Context | HwndContextAppColorizeWindow
                }
            } else {
                for _, Child in Children {
                    if (WinExist("ahk_class ^SteinbergChildWindowNoMouseHandlingClass$ ahk_id " Child)) {
                        Context := Context | HwndContextAppChildWindow
                        if (WinExist("^" AppName "(?: .*?)? Project - .*$ ahk_id " Hwnd)) {
                            Context := Context | HwndContextAppProjectWindow
                        }

                        break
                    }
                }
            }
        }
    }

    return Context
}

global AppMenuContextTrack := (1 << 0)
global AppMenuContextFolderTrack := (1 << 1)
global AppMenuContextTrackList := (1 << 2)
global AppMenuContextMixConsoleTracks := (1 << 3)
global AppMenuContextInsertSlot := (1 << 4)
global AppMenuContextNonEmptyInsertSlot := (1 << 5)
global AppMenuContextSendSlot := (1 << 6)
global AppMenuContextRack := (1 << 7)
global AppMenuContextInsertsRack := (1 << 8)
global AppMenuContextEditor := (1 << 9)
global AppMenuContextKeyEditor := (1 << 10)
global AppMenuContextSelected := (1 << 11)
global AppMenuContextSelectedAudio := (1 << 12)
global AppMenuContextSelectedMidi := (1 << 13)

FindAppMenuContext(Menu) {
    Context := 0

    if (FindMenuItemIndex(Menu, "Add Track...") != -1 && FindMenuItemIndex(Menu, "Global Meter Settings") != -1) {
        Context |= AppMenuContextMixConsoleTracks
        if (FindMenuItemIndex(Menu, "Link Selected Channels") != -1 || FindMenuItemIndex(Menu, "Unlink Selected Channels") != -1) {
            Context |= AppMenuContextTrack
        }
    } else if (FindMenuItemIndex(Menu, "Select All Events") != -1) {
        Context |= AppMenuContextTrackList | AppMenuContextTrack
        if (FindMenuItemIndex(Menu, "Show Data on Folder Tracks") != -1) {
            Context |= AppMenuContextFolderTrack
        }
    } else if (FindMenuItemIndex(Menu, "Hide All Automation") != -1) {
        Context |= AppMenuContextTrackList
    } else if (FindMenuItemIndex(Menu, "Set as last Pre-Fader Slot") != -1) {
        Context |= AppMenuContextInsertSlot
        if (FindMenuItemIndex(Menu, "Load Preset...") != -1) {
            Context |= AppMenuContextNonEmptyInsertSlot
        }
    } else if (FindMenuItemIndex(Menu, "Clear Send") != -1) {
        Context |= AppMenuContextSendSlot
    } else if (FindMenuItemIndex(Menu, "Bypass") != -1 && FindMenuItemIndex(Menu, "Copy") != -1 && FindMenuItemIndex(Menu, "Paste") != -1 && FindMenuItemIndex(Menu, "Clear") != -1) {
        Context |= AppMenuContextRack
        if (FindMenuItemIndex(Menu, "Load FX Chain Preset...") != -1) {
            Context |= AppMenuContextInsertsRack
        }
    } else if ((Tools := FindMenuItemIndex(Menu, "Tools")) != -1) {
        Context |= AppMenuContextEditor
        if ((ZoomToSelection := FindMenuItemIndex(Menu, "Zoom to Selection")) == -1 || GetMenuItemState(Menu, ZoomToSelection) & 0x2) {
            if (FindMenuItemIndex(Menu, "Functions") != -1) {
                Context |= AppMenuContextKeyEditor
            }
        } else {
            Context |= AppMenuContextSelected
            if (FindMenuItemIndex(Menu, "Create Sampler Track") != -1) {
                Context |= AppMenuContextSelectedAudio
            } else if (FindMenuItemIndex(Menu, "Processes") != -1) {
                Context |= AppMenuContextSelectedAudio
            } else if (FindMenuItemIndex(Menu, "Export MIDI Loop...") != -1) {
                Context |= AppMenuContextSelectedMidi
            } else if (FindMenuItemIndex(Menu, "Open Note Expression Editor") != -1) {
                Context |= AppMenuContextKeyEditor | AppMenuContextSelectedMidi
            }
        }
    }

    return Context
}

IsValidKeyCommandsXml(KeyCommandsXml) {
    return KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Categories']") && KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")
}

IsInstalled(Hash, KeyCommandsXml) {
    return !!KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']/item/string[@name='Name' and @value='" VersionMacroPrefix Version " " Hash "']")
}

InstallKeyCommands(Xml, KeyCommandsXml) {
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

InstallPle(Xml, PlePath) {
    FileCreateDir % (PleFolderPath := JoinPath(PlePath, PleFolderName))

    for Ple in Xml.selectNodes("/night/ple/item") {
        Name := Ple.selectSingleNode("string[@name='Name']").getAttribute("value")
        Path := JoinPath(PleFolderPath, Name ".xml")

        Data := Ple.selectSingleNode("Project_Logical_EditorPreset").xml

        WriteFileUtf8(Path, Data)
    }
}

InstallVersionMacro(Hash, KeyCommandsXml) {
    Name := KeyCommandsXml.createElement("string")
    Name.setAttribute("name", "Name")
    Name.setAttribute("value", VersionMacroPrefix Version " " Hash)

    Item := KeyCommandsXml.createElement("item")
    Item.appendChild(Name)

    Macros := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")
    Macros.appendChild(Item)
}

Uninstall(KeyCommandsPath, PlePath) {
    KeyCommandsData := ReadFileUtf8(KeyCommandsPath)

    if ((KeyCommandsXml := LoadXml(KeyCommandsData))) {
        UninstallKeyCommands(KeyCommandsXml)
        WriteFileUtf8(KeyCommandsPath, KeyCommandsXml.xml)
    }

    UninstallPle(PlePath)
}

UninstallKeyCommands(KeyCommandsXml) {
    Macros := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")
    for Macro in Macros.selectNodes("item") {
        Name := Macro.selectSingleNode("string[@name='Name']").getAttribute("value")
        if (InStr(Name, VersionMacroPrefix, true) == 1 || InStr(Name, MacroPrefix, true) == 1) {
            Macros.removeChild(Macro)
        }
    }

    Commands := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Categories']/item/string[@name='Name' and @value='Macro']/../list[@name='Commands']")
    for Command in Commands.selectNodes("item") {
        Name := Command.selectSingleNode("string[@name='Name']").getAttribute("value")
        if (InStr(Name, VersionMacroPrefix, true) == 1 || InStr(Name, MacroPrefix, true) == 1) {
            Commands.removeChild(Command)
        }
    }
}

UninstallPle(PlePath) {
    FileRemoveDir % JoinPath(PlePath, PleFolderName), true
}

LoadMacroKeys(KeyCommandsXml) {
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

PatchProjectColors(ProjectPath, ColorsPath) {
    if (!(File := FileOpen(ProjectPath, "a")) || !(Mapping := MapFile(File.__Handle, Address))) {
        return false
    }

    Patched := 0

    loop 128 {
        IniRead Value, % ColorsPath, % "Colors", % A_Index, % A_Space
        if (InStr(Value, "#", true) != 1 || StrLen(Value) != 7) {
            continue
        }
        if (!CryptStringToBinary(SubStr(Value, 2) "00", Value, 0xC)) {
            continue
        }
        Value := NumGet(&Value, "UInt")

        Search := CryptUtf8ToString("Color " A_Index, 0xC | 0x40000000) "00efbbbfff"
        SearchCount := CryptStringToBinary(Search, SearchBytes, 0xC)
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

ShowActiveAppMenuInfo() {
    Gui ActiveAppMenuInfo:Destroy

    if (!ActiveAppMenu) {
        return
    }

    Rows := []
    if ((ActiveAppMenuContext & AppMenuContextTrackList) || (ActiveAppMenuContext & AppMenuContextMixConsoleTracks)) {
        Rows.Push(["n", "add track"])
        Rows.Push(["Ctrl+n", "add track from track preset"])
        Rows.Push(["Shift+n", "add track dialog"])
        Rows.Push(["", ""])
        Rows.Push(["Ctrl+a", "select all tracks"])

        if (ActiveAppMenuContext & AppMenuContextTrack) {
            Rows.Push(["", ""])
            Rows.Push(["Tab", "show/hide editor"])
            Rows.Push(["d/Delete/Backspace", "delete"])
            Rows.Push(["Ctrl+d", "duplicate"])
            Rows.Push(["e", "toggle enabled"])
            Rows.Push(["h", "hide"])
            Rows.Push(["c", "colorize"])
            Rows.Push(["s", "send to a new FX channel"])
            Rows.Push(["g", "send to a new group channel"])
            Rows.Push(["v", "send to a new VCA fader"])
            Rows.Push(["Ctrl+o", "load track preset"])
            Rows.Push(["Ctrl+s", "save as track preset"])
            Rows.Push(["Ctrl+Shift+s", "save as track archive"])

            if (ActiveAppMenuContext & AppMenuContextTrackList) {
                Rows.Push(["", ""])
                Rows.Push(["i", "toggle edit in-place"])
                Rows.Push(["f", "move to a new folder"])
                Rows.Push(["a", "select all data"])
                Rows.Push(["r", "clear all data"])

                if (ActiveAppMenuContext & AppMenuContextFolderTrack) {
                    Rows.Push(["", ""])
                    Rows.Push(["Space", "collapse/expand first selected folder track"])
                    Rows.Push(["Ctrl+Space", "expand all folder tracks"])
                    Rows.Push(["Shift+Space", "collapse all folder tracks"])
                } else {
                    Rows.Push(["", ""])
                    Rows.Push(["Space", "show used automation/hide automation"])
                    Rows.Push(["Ctrl+Space", "show all used automation"])
                    Rows.Push(["Shift+Space", "hide all automation"])
                }
            }
        }
    } else if (ActiveAppMenuContext & AppMenuContextInsertSlot) {
        Rows.Push(["Tab", "open/focus plugin window"])
        Rows.Push(["", "(doesn't work if mouse is under the bypass/arrow buttons)"])
        Rows.Push(["Shift+Tab", "close plugin window"])
        Rows.Push(["", "(doesn't work if mouse is under the bypass/arrow buttons)"])
        Rows.Push(["d/Delete/Backspace", "delete"])
        Rows.Push(["w", "replace"])
        Rows.Push(["e", "toggle bypass"])
        Rows.Push(["Shift+e", "toggle activated"])
        Rows.Push(["f", "set as last pre-fader slot"])
        Rows.Push(["s", "toggle sidechaining activated"])
        Rows.Push(["q", "switch between A/B settings"])
        Rows.Push(["Shift+q", "apply current settings to A and B"])
    } else if (ActiveAppMenuContext & AppMenuContextSendSlot) {
        Rows.Push(["d/Delete/Backspace", "clear"])
        Rows.Push(["w", "replace"])
        Rows.Push(["Ctrl+c", "copy"])
        Rows.Push(["Ctrl+v", "paste"])
        Rows.Push(["e", "toggle activated"])
        Rows.Push(["f", "move to pre/post fader"])
        Rows.Push(["r", "use default level"])
        Rows.Push(["q", "set level to -oo"])
    } else if (ActiveAppMenuContext & AppMenuContextRack) {
        if (ActiveAppMenuContext & AppMenuContextInsertsRack) {
            Rows.Push(["Tab", "open/focus all plugin windows"])
            Rows.Push(["Shift+Tab", "close all plugin windows"])
            Rows.Push(["e", "toggle bypass all"])
            Rows.Push(["Ctrl+o", "load FX chain preset"])
            Rows.Push(["Ctrl+s", "save as FX chain preset"])
        } else {
            Rows.Push(["e", "toggle bypass all"])
        }
    } else if (ActiveAppMenuContext & AppMenuContextEditor) {
        if (!(ActiveAppMenuContext & AppMenuContextSelected)) {
            Rows.Push(["z", "zoom to view horizontally"])
        } else {
            Rows.Push(["z", "zoom to selection horizontally"])
            Rows.Push(["d/Delete/Backspace", "delete"])
            Rows.Push(["c", "colorize"])
            Rows.Push(["e", "toggle muted"])
            Rows.Push(["Ctrl+d", "repeat"])
            Rows.Push(["g", "glue"])
            Rows.Push(["Shift+g", "dissolve"])
            Rows.Push(["Shift+s", "convert shared to real copies"])
            Rows.Push(["r", "render in place"])
            Rows.Push(["Ctrl+r", "render in place (settings)"])

            Rows.Push(["", ""])
            Rows.Push(["Space", "locate selection start"])
            Rows.Push(["Shift+Space", "move left/right locators to selection"])
            Rows.Push(["Ctrl+Space", "move selection to cursor"])

            Rows.Push(["", ""])
            Rows.Push(["", "(range tool)"])
            Rows.Push(["x", "split range"])
            Rows.Push(["Shift+x", "crop range"])

            if (ActiveAppMenuContext & AppMenuContextSelectedAudio) {
                Rows.Push(["", ""])
                Rows.Push(["", "(audio)"])
                Rows.Push(["b", "bounce"])
                Rows.Push(["p", "show in pool"])
            } else if (ActiveAppMenuContext & AppMenuContextSelectedMidi) {
                Rows.Push(["", ""])
                Rows.Push(["", "(MIDI)"])
                Rows.Push(["f", "open functions menu"])
                Rows.Push(["q", "quantize event starts"])
                Rows.Push(["Ctrl+q", "quantize event ends"])
                Rows.Push(["Ctrl+Shift+q", "quantize event lengths"])
                Rows.Push(["Shift+q", "reset quantize"])
                Rows.Push(["v", "legato"])
                Rows.Push(["Ctrl+s", "export first selected part as MIDI loop"])
            }
        }

        if (ActiveAppMenuContext & AppMenuContextKeyEditor) {
            Rows.Push(["", ""])
            Rows.Push(["Tab", "toggle note expression editor"])
        }
    } else {
        return
    }

    Length := 0
    for _, Row in Rows {
        Length := Max(Length, StrLen(Row[1]))
    }

    Text := ""
    for Index, Row in Rows {
        Text := Text " " Format("{:" Length "}", Row[1]) "  " Row[2] " " (Index < Rows.Count() ? "`n" : "")
    }

    CoordMode Mouse, Screen
    MouseGetPos X, Y
    Monitor := GetMonitorFromPoint(X, Y)
    GetMonitorWorkArea(Monitor, MonitorX, MonitorY, MonitorWidth, MonitorHeight)

    MenuHwnd := WinExist(MenuTitle)
	VarSetCapacity(MenuRect, 0x10)
	DllCall("GetClientRect", "Ptr", MenuHwnd, "Ptr", &MenuRect)
	DllCall("ClientToScreen", "Ptr", MenuHwnd, "Ptr", &MenuRect)
	DllCall("ClientToScreen", "Ptr", MenuHwnd, "Ptr", &MenuRect + 0x8)

    Gui ActiveAppMenuInfo:New, -Caption +Border +ToolWindow +E0x20 +AlwaysOnTop +HwndInfoHwnd
    WinSet Transparent, 200, % "ahk_id " InfoHwnd

    Gui ActiveAppMenuInfo:Font, s9 w900, % "Consolas"
    Gui ActiveAppMenuInfo:Color, FFDB4C
    Gui ActiveAppMenuInfo:Add, Text, , % Text

    Gui ActiveAppMenuInfo:Show, Hide

	WinGetPos, , , InfoWidth, InfoHeight, % "ahk_id " InfoHwnd

    static Padding := 10

	VarSetCapacity(InfoRightRect, 0x10)
    NumPut(MonitorX + MonitorWidth - Padding - InfoWidth, &InfoRightRect + 0x0, "Int")
    NumPut(MonitorY + MonitorHeight - Padding - InfoHeight, &InfoRightRect + 0x4, "Int")
    NumPut(MonitorX + MonitorWidth - Padding, &InfoRightRect + 0x8, "Int")
    NumPut(MonitorY + MonitorHeight - Padding, &InfoRightRect + 0xC, "Int")

    VarSetCapacity(Dest, 0x10)
    Left := DllCall("IntersectRect", "Ptr", &Dest, "Ptr", &MenuRect, "Ptr", &InfoRightRect, "Int")
    WinMove % "ahk_id " InfoHwnd, , % (Left ? (MonitorX + Padding) : (MonitorX + MonitorWidth - Padding - InfoWidth)), % (MonitorY + MonitorHeight - Padding - InfoHeight)

    Gui ActiveAppMenuInfo:Show, NoActivate
}

global ActiveHwnd
global ActiveHwndContext
global ActiveControlHwnd
global ActiveControlClass
global ActiveControlNN
global ActiveMenuCount
global ActiveAppMenu
global ActiveAppMenuContext
global MenuTime

global ColorizeHwnd
global LastAppWindowDestroyTime
global AddTrackHwnd

WaitActiveAppMenu(ByRef Menu, ByRef Context) {
    Start := A_TickCount
    while (!ActiveAppMenu) {
        if (A_TickCount - Start > 1000) {
            return false
        }
        Sleep % 5
    }

    Menu := ActiveAppMenu
    Context := ActiveAppMenuContext
    return true
}

IsActiveAppMenuTime() {
    return (ActiveAppMenu || (MenuTime && A_TickCount - MenuTime <= 500))
}

SetEventHook() {
    SetWinEventHook((EVENT_SYSTEM_FOREGROUND := 0x0003), EVENT_SYSTEM_FOREGROUND, "EventProc")
    SetWinEventHook((EVENT_SYSTEM_MENUPOPUPSTART := 0x0006), EVENT_SYSTEM_MENUPOPUPSTART, "EventProc")
    SetWinEventHook((EVENT_SYSTEM_MENUPOPUPEND := 0x0007), EVENT_SYSTEM_MENUPOPUPEND, "EventProc")
    SetWinEventHook((EVENT_OBJECT_DESTROY := 0x8001), EVENT_OBJECT_DESTROY, "EventProc")
    SetWinEventHook((EVENT_OBJECT_FOCUS := 0x8005), EVENT_OBJECT_FOCUS, "EventProc")
    SetWinEventHook((EVENT_OBJECT_NAMECHANGE := 0x800C), EVENT_OBJECT_NAMECHANGE, "EventProc")

    ActiveHwnd := WinExist("A")
    ActiveHwndContext := FindHwndContext(ActiveHwnd)
    ActiveControlHwnd := GetFocus(ActiveHwnd)
    ActiveControlClass := GetHwndClass(ActiveControlHwnd)
    ActiveControlNn := GetControlHwndNN(ActiveHwnd, ActiveControlHwnd, ActiveControlClass)
    Menu := GetActiveMenu()
    ActiveMenuCount := Menu ? 1 : 0
    ActiveAppMenu := (ActiveHwndContext & HwndContextAppChildWindow) ? Menu :
    ActiveAppMenuContext := FindAppMenuContext(ActiveAppMenu)
    ShowActiveAppMenuInfo()
    MenuTime := 0

    ColorizeHwnd :=
    LastAppWindowDestroyTime :=
    AddTrackHwnd :=
}

EventProc(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    if ((EVENT_SYSTEM_FOREGROUND := 0x0003) == event) {
        HandleWindowForeground(dwmsEventTime, hwnd)
        return
    }

    if ((EVENT_SYSTEM_MENUPOPUPSTART := 0x0006) == event) {
        HandleMenuPopupStart(dwmsEventTime)
        return
    }

    if ((EVENT_SYSTEM_MENUPOPUPEND := 0x0007) == event) {
        HandleMenuPopupEnd(dwmsEventTime)
        return
    }

    if ((EVENT_OBJECT_DESTROY := 0x8001) == event && idObject == (OBJID_WINDOW := 0x00000000)) {
        HandleWindowDestroy(dwmsEventTime, hwnd)
        return
    }

    if ((EVENT_OBJECT_FOCUS := 0x8005) == event) {
        HandleObjectFocus(dwmsEventTime, hwnd)
        return
    }

    if ((EVENT_OBJECT_NAMECHANGE := 0x800C) == event && idObject == (OBJID_WINDOW := 0x00000000)) {
        HandleWindowNameChange(dwmsEventTime, hwnd)
        return
    }
}

HandleWindowForeground(Time, Hwnd) {
    LastActiveHwnd := ActiveHwnd
    LastActiveHwndContext := ActiveHwndContext

    ActiveHwnd := Hwnd
    ActiveHwndContext := FindHwndContext(ActiveHwnd)

    if (ActiveHwnd != ColorizeHwnd && ColorizeHwnd) {
        WinClose % "ahk_id " ColorizeHwnd
    }

    if (ActiveHwnd != AddTrackHwnd && AddTrackHwnd) {
        WinClose % "ahk_id " AddTrackHwnd
    }

    if ((ActiveHwndContext & HwndContextAppMenu) && !(LastActiveHwndContext & HwndContextAppProjectWindow) && LastAppWindowDestroyTime && (Time - LastAppWindowDestroyTime <= 150)) {
        if (!(Hwnd := FindAppProjectWindow())) {
            return
        }
        DllCall("SetForegroundWindow", "Ptr", Hwnd)
        return
    }
}

HandleWindowDestroy(Time, Hwnd) {
    if (ActiveMenuCount && !ActiveAppMenu) {
        ActiveAppMenu := (ActiveHwndContext & HwndContextAppChildWindow) ? GetActiveMenu() :
        ActiveAppMenuContext := ActiveAppMenu ? FindAppMenuContext(ActiveAppMenu) : 0
        ShowActiveAppMenuInfo()
    }

    if (ColorizeHwnd == Hwnd) {
        ColorizeHwnd :=
    }

    if (AddTrackHwnd == Hwnd) {
        AddTrackHwnd :=
    }

    if (WinExist("ahk_exe i)^\Q" AppExePath "\E$ ahk_id " Hwnd)) {
        LastAppWindowDestroyTime := Time
    }
}

HandleWindowNameChange(Time, Hwnd) {
    if (IsAppColorizeWindow(Hwnd)) {
        if (ColorizeHwnd == Hwnd) {
            return
        }
        ColorizeHwnd := Hwnd

        WinGetPos, , , Width, Height, % "ahk_id " Hwnd

        CoordMode Mouse, Screen
        MouseGetPos X, Y
        Monitor := GetMonitorFromPoint(X, Y)
        GetMonitorWorkArea(Monitor, MonitorX, MonitorY, MonitorWidth, MonitorHeight)

        static Padding := 10
        X := Max(MonitorX + Padding, Min(MonitorX + MonitorWidth - Padding - Width, X - Width // 2))
        Y := Max(MonitorY + Padding, Min(MonitorY + MonitorHeight - Padding - Height, Y - 5))

        DllCall("SetForegroundWindow", "Ptr", Hwnd)
        WinMove % "ahk_id " Hwnd, , % X, % Y
        return
    }
}

HandleObjectFocus(Time, Hwnd) {
    ActiveControlHwnd := Hwnd
    ActiveControlClass := GetHwndClass(ActiveControlHwnd)
    ActiveControlNn := GetControlHwndNN(ActiveHwnd, ActiveControlHwnd, ActiveControlClass)

    if (ActiveHwnd == DllCall("GetAncestor", "Ptr", ActiveControlHwnd, "UInt", 2)) {
        ActiveHwndContext := FindHwndContext(ActiveHwnd)
    }
}

HandleMenuPopupStart(Time) {
    ActiveMenuCount += 1
    ActiveAppMenu := (ActiveHwndContext & HwndContextAppChildWindow) ? GetActiveMenu() :
    ActiveAppMenuContext := ActiveAppMenu ? FindAppMenuContext(ActiveAppMenu) : 0
    MenuTime := 0
    ShowActiveAppMenuInfo()
}

HandleMenuPopupEnd(Time) {
    if (ActiveMenuCount > 0) {
        ActiveMenuCount -= 1
    }
    ActiveAppMenu :=
    ShowActiveAppMenuInfo()
}

CreateTrayMenu() {
    Menu Tray, Tip, % "night"

    Menu Tray, NoStandard
    Menu Tray, Add, % "night " Version, TrayMenuNight
    Menu Tray, Add, % "Uninstall", TrayMenuUninstall
    Menu Tray, Add
    Menu Tray, Add, % AppName " " AppExeVersionInfo.FileVersion, TrayMenuApp
    Menu Tray, Add, % AppName " Program Files", TrayMenuProgramFiles
    Menu Tray, Add, % AppName " AppData", TrayMenuAppData
    Menu Tray, Add, % AppName " Documents", TrayMenuDocuments
    Menu Tray, Add
    Menu Tray, Add, % "Project Colors Patcher", TrayMenuProjectColorsPatcher
    Menu Tray, Add
    Menu Tray, Add, % "AutoHotkey " A_AhkVersion, TrayMenuStub
    Menu Tray, Disable, % "AutoHotkey " A_AhkVersion
    Menu Tray, Standard
}

TrayMenuNight() {
    Run % Url
}

TrayMenuUninstall() {
    if (FindAppExeWindow()) {
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

TrayMenuApp() {
    Run % AppExePath
}

TrayMenuProgramFiles() {
    SplitPath AppExePath, , Path
    ShellOpenFolderAndSelect(Path, [AppExePath], 0)
}

TrayMenuAppData() {
    SplitPath KeyCommandsPath, , Path
    ShellOpenFolderAndSelect(Path, [Path], 0)
}

TrayMenuDocuments() {
    SplitPath PlePath, , Path
    ShellOpenFolderAndSelect(Path, [Path], 0)
}

TrayMenuProjectColorsPatcher() {
    if (FindAppProjectWindow()) {
        MsgBox % (0x0 | 0x30 | 0x40000), % "Project Colors Patcher", % "Please close all " AppName " projects before using the Project Colors Patcher."
        return
    }

    FileSelectFile ProjectPaths, M3, , % "Project Colors Patcher - select project files (BACK THEM UP FIRST)", % "Cubase/Nuendo Project Files (*.cpr; *.npr)"
    if (ErrorLevel != 0) {
        return
    }

    FileSelectFile ColorsPath, 3, % JoinPath(A_ScriptDir, "colors"), % "Project Colors Patcher - select a colors file", % "Colors Files (*.ini)"
    if (ErrorLevel != 0) {
        return
    }

    loop parse, ProjectPaths, `n
    {
        if (A_Index == 1) {
            Path := A_LoopField
            continue
        }

        ProjectPath := JoinPath(Path, A_LoopField)
        if (Patched := PatchProjectColors(ProjectPath, ColorsPath)) {
            MsgBox % (0x0 | 0x40 | 0x40000), % "Project Colors Patcher", % "Patched " Patched " color" (Patched == 1 ? "" : "s") " in:`n" ProjectPath
        } else {
            MsgBox % (0x0 | 0x10 | 0x40000), % "Project Colors Patcher", % "Error patching:`n" ProjectPath
        }
    }
}

TrayMenuStub() {
}

AutoExec() {
    SetControlDelay -1
    SetWinDelay -1
    SetBatchLines -1

    if (!A_IsCompiled) {
        XmlPath := JoinPath(A_ScriptDir, "night.xml")
        XmlHash := HashFile(XmlPath, "MD5")
        XmlData := ReadFileUtf8(XmlPath)
    } else {
        FileInstall night.xml, % (XmlPath := CreateTempFilePath()), true
        XmlHash := HashFile(XmlPath, "MD5")
        XmlData := ConsumeFileUtf8(XmlPath)
    }

    if (!(Xml := LoadXml(XmlData))) {
        MsgBox % (0x0 | 0x10 | 0x40000), % "night", % "Could not load night.xml"
        ExitApp
    }

    SplitPath A_ScriptFullPath, , , , SettingsFileName
    SettingsPath := JoinPath(A_ScriptDir, SettingsFileName ".ini")

    IniRead AppExePath, % SettingsPath, % "night", % "AppExePath", % A_Space
    if (AppExePath == A_Space || !FileExist(AppExePath)) {
        FileSelectFile AppExePath, 3, % JoinPath(A_ProgramFiles, "Steinberg"), % "Select your Cubase.exe/Nuendo.exe file", % "Executable Files (*.exe)"
        if (ErrorLevel != 0) {
            ExitApp
        }
        IniWrite % AppExePath, % SettingsPath, % "night", % "AppExePath"
    }

    AppExeVersionInfo := GetFileVersionInfo(AppExePath, ["FileDescription", "FileVersion"])

    AppName := StrSplit(AppExeVersionInfo.FileDescription, " ", "", 2)[1]
    if (!(AppName == "Cubase" || AppName == "Nuendo")) {
        MsgBox % (0x0 | 0x10 | 0x40000), % "night", % "Unrecognized Cubase/Nuendo version."
        ExitApp
    }

    IniRead KeyCommandsPath, % SettingsPath, % "night", % "KeyCommandsPath", % A_Space
    if (KeyCommandsPath == A_Space || !FileExist(KeyCommandsPath)) {
        Path := JoinPath(A_AppData, "Steinberg")
        loop files, % JoinPath(Path, "*"), D
        {
            if (InStr(A_LoopFileName, AppExeVersionInfo.FileDescription)) {
                Path := JoinPath(A_LoopFilePath, "Key Commands.xml")
                break
            }
        }

        FileSelectFile KeyCommandsPath, 3, % Path, % "Select your Key Commands.xml file", % "XML Files (*.xml)"
        if (ErrorLevel != 0) {
            ExitApp
        }
        IniWrite % KeyCommandsPath, % SettingsPath, % "night", % "KeyCommandsPath"
    }

    IniRead PlePath, % SettingsPath, % "night", % "PlePath", % A_Space
    if (PlePath == A_Space || !InStr(FileExist(PlePath), "D")) {
        FileSelectFolder PlePath, % "*" JoinPath(A_MyDocuments, "Steinberg\" AppName "\User Presets\"), 2, % "Select your Project Logical Editor user presets folder"
        if (ErrorLevel != 0) {
            ExitApp
        }
        IniWrite % PlePath, % SettingsPath, % "night", % "PlePath"
    }

    KeyCommandsData := ReadFileUtf8(KeyCommandsPath)

    if (!(KeyCommandsXml := LoadXml(KeyCommandsData)) || !IsValidKeyCommandsXml(KeyCommandsXml)) {
        MsgBox % (0x0 | 0x10 | 0x40000), % "night", % "Could not load key commands file:`n" KeyCommandsPath
        ExitApp
    }

    if (!IsInstalled(XmlHash, KeyCommandsXml)) {
        if (FindAppExeWindow()) {
            MsgBox % (0x0 | 0x30 | 0x40000), % "night", % "night is not installed. Please close " AppName " and run night again to install."
            ExitApp
        }

        Uninstall(KeyCommandsPath, PlePath)

        KeyCommandsData := ReadFileUtf8(KeyCommandsPath)
        KeyCommandsXml := LoadXml(KeyCommandsData)

        InstallKeyCommands(Xml, KeyCommandsXml)
        InstallPle(Xml, PlePath)
        InstallVersionMacro(XmlHash, KeyCommandsXml)

        WriteFileUtf8(KeyCommandsPath, KeyCommandsXml.xml)

        MsgBox % (0x0 | 0x40 | 0x40000), % "night", % "night has been installed!`n`n" KeyCommandsPath "`n`n" PlePath
    }

    MacroKeys := LoadMacroKeys(KeyCommandsXml)

    SetEventHook()

    CreateTrayMenu()
}

AutoExec()

global MixConsolePage := 1
global LocateMode := 1
global InSpace := false
global InSpaceWriteAutomation := false

return

#If !ActiveMenuCount && (ActiveHwndContext & HwndContextAppWindow)

~*RButton::
    HandleAppWindowWildcardRButton() {
        MenuTime := A_TickCount
    }

~*AppsKey::
    HandleAppWindowWildcardAppsKey() {
        MenuTime := A_TickCount
    }

$XButton1::
    HandleAppWindowXButton1() {
        if (!(Hwnd := FindAppProjectWindow())) {
            return
        }
        DllCall("SetForegroundWindow", "Ptr", Hwnd)
        SendEvent % MacroKeys["Show Lower Zone MixConsole Page 1"] MacroKeys["Edit - Open/Close Editor"]
    }

$XButton2::
    HandleAppWindowXButton2() {
        if (!(Hwnd := FindAppProjectWindow())) {
            return
        }
        DllCall("SetForegroundWindow", "Ptr", Hwnd)
        SendEvent % MacroKeys["Show Lower Zone MixConsole Page 1"] (MixConsolePage < 2 ? "" : MacroKeys["Window Zones - Show Next Page"]) (MixConsolePage < 3 ? "" : MacroKeys["Window Zones - Show Next Page"])
    }

~XButton2 & 1::
    HandleAppWindowXButton21() {
        MixConsolePage := 1
        SendEvent % MacroKeys["Window Zones - Show Previous Page"] MacroKeys["Window Zones - Show Previous Page"]
    }

~XButton2 & 2::
    HandleAppWindowXButton22() {
        MixConsolePage := 2
        SendEvent % MacroKeys["Window Zones - Show Previous Page"] MacroKeys["Window Zones - Show Previous Page"] MacroKeys["Window Zones - Show Next Page"]
    }

~XButton2 & 3::
    HandleAppWindowXButton23() {
        MixConsolePage := 3
        SendEvent % MacroKeys["Window Zones - Show Next Page"] MacroKeys["Window Zones - Show Next Page"]
    }

#If !ActiveMenuCount && (ActiveHwndContext & HwndContextAppWindow) && GetKeyState("XButton2", "P")

$WheelDown::
    HandleAppWindowWheelDown() {
        if (MixConsolePage < 3) {
            MixConsolePage += 1
            SendEvent % MacroKeys["Window Zones - Show Next Page"]
        }
    }

$WheelUp::
    HandleAppWindowWheelUp() {
        if (MixConsolePage > 1) {
            MixConsolePage -= 1
            SendEvent % MacroKeys["Window Zones - Show Previous Page"]
        }
    }

#If !ActiveMenuCount && (ActiveHwndContext & HwndContextAppChildWindow)

$!WheelDown::
    HandleAppWindowAltWheelDown() {
        SendEvent % MacroKeys["Zoom - Zoom Out Vertically"]
    }

$!WheelUp::
    HandleAppWindowAltWheelUp() {
        SendEvent % MacroKeys["Zoom - Zoom In Vertically"]
    }

$^!WheelDown::
    HandleAppWindowCtrlAltWheelDown() {
        SendEvent % MacroKeys["Zoom Out Horizontally and Vertically"]
    }

$^!WheelUp::
    HandleAppWindowCtrlAltWheelUp() {
        SendEvent % MacroKeys["Zoom In Horizontally and Vertically"]
    }

$+WheelDown::
    HandleAppWindowShiftWheelDown() {
        SendEvent % MacroKeys["Zoom - Zoom Out Tracks"]
    }

$+WheelUp::
    HandleAppWindowShiftWheelUp() {
        SendEvent % MacroKeys["Zoom - Zoom In Tracks"]
    }

$^+MButton::
    HandleAppWindowCtrlShiftMButton() {
        static LocateModes := ["events", "hitpoints", "markers"]

        LocateMode := Mod(LocateMode, 3) + 1
        ToolTip("locate mode: " LocateModes[LocateMode], , , 1250)
    }

$^+WheelDown::
    HandleAppWindowCtrlShiftWheelDown() {
        switch (LocateMode) {
        case 1:
            SendEvent % MacroKeys["Locate Next Event"]
        case 2:
            SendEvent % MacroKeys["Locate Next Hitpoint"]
        case 3:
            SendEvent % MacroKeys["Locate Next Marker"]
        }
    }

$^+WheelUp::
    HandleAppWindowCtrlShiftWheelUp() {
        switch (LocateMode) {
        case 1:
            SendEvent % MacroKeys["Locate Previous Event"]
        case 2:
            SendEvent % MacroKeys["Locate Previous Hitpoint"]
        case 3:
            SendEvent % MacroKeys["Locate Previous Marker"]
        }
    }

$^+!WheelDown::
    HandleAppWindowCtrlShiftAltWheelDown() {
        SendEvent % MacroKeys["Zoom - Zoom Out Of Waveform Vertically"]
    }

$^+!WheelUp::
    HandleAppWindowCtrlShiftAltWheelUp() {
        SendEvent % MacroKeys["Zoom - Zoom In On Waveform Vertically"]
    }

#If !ActiveMenuCount && (ActiveHwndContext & HwndContextApp)

$Escape::
    HandleAppEscape() {
        if ((ActiveHwndContext & HwndContextAppProjectWindow) || (ActiveHwndContext & HwndContextAppTitleBar) && FindAppProjectWindow()) {
            return
        }

        if ((ActiveHwndContext & HwndContextAppTitleBar) || (ActiveHwndContext & HwndContextAppColorizeWindow)) {
            WinClose % "ahk_id " ActiveHwnd
            return
        }

        SendEvent % "{Escape down}"
        KeyWait % "Escape"
        SendEvent % "{Escape up}"
    }

$Space::
    HandleAppSpace() {
        InSpace := true
        SendEvent % "{Space}"
        KeyWait % "Space"
        InSpace := false

        if (InSpaceWriteAutomation) {
            InSpaceWriteAutomation := false
            SendEvent % "{Space}" MacroKeys["Automation - Toggle Write Enable All Tracks"]
        }
    }

~*LButton::
    HandleAppWildcardLButton() {
        if (InSpace && !InSpaceWriteAutomation) {
            InSpaceWriteAutomation := true
            SendEvent % MacroKeys["Automation - Toggle Write Enable All Tracks"]
        }
    }

#If !ActiveMenuCount && ((ActiveHwndContext & HwndContextSelf) || (ActiveHwndContext & HwndContextApp)) && (ActiveHwndContext & HwndContextFileDialog)

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
    HandleDialogFButton() {
        IniRead Path, % SettingsPath, % "FileDialogPaths", % SubStr(A_ThisHotkey, 2), % A_Space
        if (Path == A_Space) {
            return
        }

        Pidl := ShellParseDisplayName(Path)
        if (!Pidl) {
            return
        }

        Path := ShellGetPidlPath(Pidl)
        DllCall("ole32\CoTaskMemFree", "Ptr", Pidl)

        FileDialogActiveNavigate(ActiveHwnd, [Path])
    }

$+F1::
$+F2::
$+F3::
$+F4::
$+F5::
$+F6::
$+F7::
$+F8::
$+F9::
$+F10::
$+F11::
$+F12::
    HandleDialogShiftFButton() {
        Path := FileDialogActiveGetFolderPath(ActiveControlHwnd, ActiveControlClass, ActiveControlNn)
        IniWrite % Path, % SettingsPath, % "FileDialogPaths", % SubStr(A_ThisHotkey, 3)
    }

#If (ActiveHwndContext & HwndContextAppChildWindow) && IsActiveAppMenuTime()

$Space::
    HandleAppMenuSpace() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack) && !(Context & AppMenuContextFolderTrack)) {
            TrySelectActiveMenuItem(Menu, "Hide Automation") || TrySelectActiveMenuItem(Menu, "Show Used Automation (Selected Tracks)") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack) && (Context & AppMenuContextFolderTrack)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Folding: Toggle Selected Track"]
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Transport - Locate Selection"]
            return
        }

        SendEvent % "{Blind}{Space}"
    }

$^Space::
    HandleAppMenuCtrlSpace() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack) && !(Context & AppMenuContextFolderTrack)) {
            TrySelectActiveMenuItem(Menu, "Show All Used Automation") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack) && (Context & AppMenuContextFolderTrack)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Folding: Unfold Tracks"]
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Move to Cursor"]
            return
        }

        SendEvent % "{Blind}{Space}"
    }

$+Space::
    HandleAppMenuShiftSpace() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack) && !(Context & AppMenuContextFolderTrack)) {
            TrySelectActiveMenuItem(Menu, "Hide All Automation") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack) && (Context & AppMenuContextFolderTrack)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Folding: Fold Tracks"]
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Transport - Locators to Selection"]
            return
        }

        SendEvent % "{Blind}{Space}"
    }

$Delete::
    HandleAppMenuDelete() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Remove Selected Tracks"]
            return
        }

        if (Context & AppMenuContextInsertSlot) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        if (Context & AppMenuContextSendSlot) {
            TrySelectActiveMenuItem(Menu, "Clear Send") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        SendEvent % "{Blind}{Delete}"
    }

$Backspace::
    HandleAppMenuBackspace() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Remove Selected Tracks"]
            return
        }

        if (Context & AppMenuContextInsertSlot) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        if (Context & AppMenuContextSendSlot) {
            TrySelectActiveMenuItem(Menu, "Clear Send") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        SendEvent % "{Blind}{Backspace}"
    }

$Tab::
    HandleAppMenuTab() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Edit VST Instrument"]
            return
        }

        if (Context & AppMenuContextNonEmptyInsertSlot) {
            CloseActiveMenu()

            LastActiveHwnd := ActiveHwnd

            SendEvent % "{Tab up}{Alt down}{Click}{Alt up}"

            Start := A_TickCount
            while (ActiveHwnd == LastActiveHwnd) {
                if (A_TickCount - Start > 150) {
                    SendEvent % "{Enter}"
                    return
                }
                Sleep % 5
            }

            return
        }

        if (Context & AppMenuContextInsertsRack) {
            CloseActiveMenu()
            SendEvent % "{Up}{Right}+!{Enter}"
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextKeyEditor)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Note Expression - Open/Close Editor"]
            return
        }

        SendEvent % "{Blind}{Tab}"
    }

$+Tab::
    HandleAppMenuShiftTab() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextNonEmptyInsertSlot) {
            CloseActiveMenu()

            LastActiveHwnd := ActiveHwnd

            SendEvent % "{Tab up}{Alt down}{Click}{Alt up}"

            Start := A_TickCount
            while (ActiveHwnd == LastActiveHwnd) {
                if (A_TickCount - Start > 150) {
                    return
                }
                Sleep % 5
            }

            SendEvent % MacroKeys["File - Close"]
            return
        }

        if (Context & AppMenuContextInsertsRack) {
            CloseActiveMenu()
            SendEvent % "{Up}{Right}+{Enter}"
            return
        }

        SendEvent % "{Blind}{Tab}"
    }

$a::
    HandleAppMenuA() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Select All on Tracks"]
            return
        }

        SendEvent % "{Blind}{a}"
    }

$^a::
    HandleAppMenuCtrlA() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) || (Context & AppMenuContextMixConsoleTracks)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Select All Tracks"]
            return
        }

        SendEvent % "{Blind}{a}"
    }

$b::
    HandleAppMenuB() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelectedAudio)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Audio - Bounce"]
            return
        }

        SendEvent % "{Blind}{b}"
    }

$c::
    HandleAppMenuC() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Colorize Selected Tracks"]
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Set Track/Event Color"]
            return
        }

        SendEvent % "{Blind}{c}"
    }

$^c::
    HandleAppMenuCtrlC() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextSendSlot) {
            TrySelectActiveMenuItem(Menu, "Copy Send") || CloseActiveMenu()
            return
        }

        SendEvent % "{Blind}{c}"
    }

$d::
    HandleAppMenuD() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Remove Selected Tracks"]
            return
        }

        if (Context & AppMenuContextInsertSlot) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        if (Context & AppMenuContextSendSlot) {
            TrySelectActiveMenuItem(Menu, "Clear Send") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        SendEvent % "{Blind}{d}"
    }

$^d::
    HandleAppMenuCtrlD() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Duplicate Tracks"]
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Repeat"]
            return
        }

        SendEvent % "{Blind}{d}"
    }

$e::
    HandleAppMenuE() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Audio - Disable/Enable Track"]
            return
        }

        if (Context & AppMenuContextNonEmptyInsertSlot) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Activate/Deactivate"]
            return
        }

        if (Context & AppMenuContextSendSlot) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Activate/Deactivate"]
            return
        }

        if (Context & AppMenuContextRack) {
            TrySelectActiveMenuItem(Menu, "Bypass") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Mute/Unmute Objects"]
            return
        }

        SendEvent % "{Blind}{e}"
    }

$+e::
    HandleAppMenuShiftE() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextNonEmptyInsertSlot) {
            CloseActiveMenu()
            SendEvent % "^!{Enter}"
            return
        }

        SendEvent % "{Blind}{e}"
    }

$f::
    HandleAppMenuF() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Project - Folding: Tracks To Folder"]
            return
        }

        if (Context & AppMenuContextInsertSlot) {
            TrySelectActiveMenuItem(Menu, "Set as last Pre-Fader Slot") || CloseActiveMenu()
            return
        }

        if (Context & AppMenuContextSendSlot) {
            TrySelectActiveMenuItem(Menu, "Move to Pre-Fader") || TrySelectActiveMenuItem(Menu, "Move to Post-Fader") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelectedMidi)) {
            TryOpenActiveSubMenu(Menu, "Functions")
            return
        }

        SendEvent % "{Blind}{f}"
    }

$g::
    HandleAppMenuG() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Mixer - Add Track To Selected: Group Channel"]
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Glue"]
            return
        }

        SendEvent % "{Blind}{g}"
    }

$+g::
    HandleAppMenuShiftG() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Dissolve"]
            return
        }

        SendEvent % "{Blind}{g}"
    }

$h::
    HandleAppMenuH() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Mixer - HideSelected"]
            return
        }

        SendEvent % "{Blind}{h}"
    }

$i::
    HandleAppMenuI() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Editors - Edit In-Place"]
            return
        }

        SendEvent % "{Blind}{i}"
    }

$n::
    HandleAppMenuN() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) || (Context & AppMenuContextMixConsoleTracks)) {
            CloseActiveMenu()

            Text := "
(
(add track)
a = audio
i = instrument
m = midi
s = sampler
f = folder
g = group channel
v = VCA fader
x = FX channel
)"

            ToolTip(Text)
            Hwnd := WinExist("ahk_pid " SelfPid " " ToolTipTitle)
            WinActivate % "ahk_id " Hwnd
            AddTrackHwnd := Hwnd
            return
        }

        SendEvent % "{Blind}{n}"
    }

$^n::
    HandleAppMenuCtrlN() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) || (Context & AppMenuContextMixConsoleTracks)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["AddTrack - From Track Presets"]
            return
        }

        SendEvent % "{Blind}{n}"
    }

$+n::
    HandleAppMenuShiftN() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) || (Context & AppMenuContextMixConsoleTracks)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["AddTrack - OpenDialog"]
            return
        }

        SendEvent % "{Blind}{n}"
    }

$^o::
    HandleAppMenuCtrlO() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            TrySelectActiveMenuItem(Menu, "Load Track Preset...") || CloseActiveMenu()
            return
        }

        if (Context & AppMenuContextInsertsRack) {
            TrySelectActiveMenuItem(Menu, "Load FX Chain Preset...") || CloseActiveMenu()
            return
        }

        SendEvent % "{Blind}{o}"
    }

$p::
    HandleAppMenuP() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelectedAudio)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Audio - Find Selected in Pool"]
            return
        }

        SendEvent % "{Blind}{p}"
    }

$q::
    HandleAppMenuQ() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextNonEmptyInsertSlot) {
            TrySelectActiveMenuItem(Menu, "Switch to A Setting") || TrySelectActiveMenuItem(Menu, "Switch to B Setting") || CloseActiveMenu()
            return
        }

        if (Context & AppMenuContextSendSlot) {
            CloseActiveMenu()
            SendEvent % "{Enter}"

            Start := A_TickCount
            while (ActiveControlClass != "Edit") {
                if (A_TickCount - Start > 1000) {
                    return
                }
                Sleep % 5
            }

            ControlSetText, , % "-oo", % "ahk_id " ActiveControlHwnd
            ControlSend, , % "{Enter}", % "ahk_id " ActiveControlHwnd
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelectedMidi)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["MIDI - Quantize"]
            return
        }

        SendEvent % "{Blind}{q}"
    }

$^q::
    HandleAppMenuCtrlQ() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelectedMidi)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["MIDI - Quantize Ends"]
            return
        }

        SendEvent % "{Blind}{q}"
    }

$+q::
    HandleAppMenuShiftQ() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextNonEmptyInsertSlot) {
            TrySelectActiveMenuItem(Menu, "Apply Current Settings to A and B") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelectedMidi)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["MIDI - Undo Quantize"]
            return
        }

        SendEvent % "{Blind}{q}"
    }

$^+q::
    HandleAppMenuCtrlShiftQ() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelectedMidi)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["MIDI - Quantize Lengths"]
            return
        }

        SendEvent % "{Blind}{q}"
    }

$r::
    HandleAppMenuR() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextTrackList) && (Context & AppMenuContextTrack)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Clear Selected Tracks"]
            return
        }

        if (Context & AppMenuContextSendSlot) {
            TrySelectActiveMenuItem(Menu, "Use Default Send Level") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Render in Place - Render"]
            return
        }

        SendEvent % "{Blind}{r}"
    }

$^r::
    HandleAppMenuCtrlR() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Render in Place - Render Setup..."]
            return
        }

        SendEvent % "{Blind}{r}"
    }

$s::
    HandleAppMenuS() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["FX Channel to Selected Channels..."]
            return
        }

        if (Context & AppMenuContextNonEmptyInsertSlot) {
            TrySelectActiveMenuItem(Menu, "Activate/Deactivate Side-Chaining") || CloseActiveMenu()
            return
        }

        SendEvent % "{Blind}{s}"
    }

$^s::
    HandleAppMenuCtrlS() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            TrySelectActiveMenuItem(Menu, "Save Track Preset...") || CloseActiveMenu()
            return
        }

        if (Context & AppMenuContextInsertsRack) {
            TrySelectActiveMenuItem(Menu, "Save FX Chain Preset...") || CloseActiveMenu()
            return
        }

        if ((Context & AppMenuContextEditor) && !(Context & AppMenuContextKeyEditor) && (Context & AppMenuContextSelectedMidi)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["File - Export MIDI Loop"]
            return
        }

        SendEvent % "{Blind}{s}"
    }

$+s::
    HandleAppMenuShiftS() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - To Real Copy"]
            return
        }

        SendEvent % "{Blind}{s}"
    }

$^+s::
    HandleAppMenuCtrlShiftS() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["File - Export Selected Tracks"]
            return
        }

        SendEvent % "{Blind}{s}"
    }

$v::
    HandleAppMenuV() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextTrack) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Mixer - Add Track To Selected: VCA Fader"]
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelectedMidi)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["MIDI - Legato"]
            return
        }

        SendEvent % "{Blind}{v}"
    }

$^v::
    HandleAppMenuCtrlV() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextSendSlot) {
            TrySelectActiveMenuItem(Menu, "Paste Send") || CloseActiveMenu()
            return
        }

        SendEvent % "{Blind}{v}"
    }

$w::
    HandleAppMenuW() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if (Context & AppMenuContextInsertSlot) {
            CloseActiveMenu()
            SendEvent % "!{Enter}"
            return
        }

        if (Context & AppMenuContextSendSlot) {
            CloseActiveMenu()
            SendEvent % "!{Enter}"
            return
        }

        SendEvent % "{Blind}{w}"
    }

$x::
    HandleAppMenuX() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Split Range"]
            return
        }

        SendEvent % "{Blind}{x}"
    }

$+x::
    HandleAppMenuShiftX() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Edit - Crop Range"]
            return
        }

        SendEvent % "{Blind}{x}"
    }

$z::
    HandleAppMenuZ() {
        if (!WaitActiveAppMenu(Menu, Context)) {
            return
        }

        if ((Context & AppMenuContextEditor) && !(Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Zoom - Zoom Full"]
            return
        }

        if ((Context & AppMenuContextEditor) && (Context & AppMenuContextSelected)) {
            CloseActiveMenu()
            SendEvent % MacroKeys["Zoom - Zoom to Selection Horizontally"]
            return
        }

        SendEvent % "{Blind}{z}"
    }

#If AddTrackHwnd

$Escape::
    HandleAddTrackEscape() {
        WinClose % "ahk_id " AddTrackHwnd
    }

$a::
    HandleAddTrackA() {
        WinClose % "ahk_id " AddTrackHwnd
        SendEvent % MacroKeys["AddTrack - Audio"]
    }

$f::
    HandleAddTrackF() {
        WinClose % "ahk_id " AddTrackHwnd
        SendEvent % MacroKeys["AddTrack - Folder"]
    }

$g::
    HandleAddTrackG() {
        WinClose % "ahk_id " AddTrackHwnd
        SendEvent % MacroKeys["AddTrack - Group Channel"]
    }

$i::
    HandleAddTrackI() {
        WinClose % "ahk_id " AddTrackHwnd
        SendEvent % MacroKeys["AddTrack - Instrument"]
    }

$m::
    HandleAddTrackM() {
        WinClose % "ahk_id " AddTrackHwnd
        SendEvent % MacroKeys["AddTrack - MIDI"]
    }

$s::
    HandleAddTrackS() {
        WinClose % "ahk_id " AddTrackHwnd
        SendEvent % MacroKeys["AddTrack - Sampler"]
    }

$v::
    HandleAddTrackV() {
        WinClose % "ahk_id " AddTrackHwnd
        SendEvent % MacroKeys["AddTrack - VCA Fader"]
    }

$x::
    HandleAddTrackX() {
        WinClose % "ahk_id " AddTrackHwnd
        SendEvent % MacroKeys["AddTrack - FX Channel"]
    }
