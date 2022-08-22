#SingleInstance Force
#MenuMaskKey vkFF
#NoEnv

if (!A_IsUnicode || A_PtrSize != 8) {
    ExitApp
}

DetectHiddenWindows On
SetTitleMatchMode RegEx

ReadFileUtf8(Path) {
    FileRead Data, % "*P65001 " Path
    return Data
}

ConsumeFileUtf8(Path) {
    Data := ReadFileUtf8(Path)
    FileDelete % Path
    return Data
}

RemoveToolTip() {
    ToolTip
}

ToolTip(Text, Timeout := 0) {
    ToolTip % Text
    if (Timeout) {
        SetTimer RemoveToolTip, % -Timeout
    }
}

WaitWindowExist(WinTitle, SleepAmount, Timeout) {
    Start := A_TickCount
    while (true) {
        if (Hwnd := WinExist(WinTitle)) {
            return Hwnd
        }

        if (A_TickCount - Start >= Timeout) {
            return
        }

        Sleep % SleepAmount
    }
}

WaitWindowActive(WinTitle, SleepAmount, Timeout) {
    Start := A_TickCount
    while (!WinActive(WinTitle)) {
        Sleep % SleepAmount
        if (A_TickCount - Start > Timeout) {
            return false
        }
    }
    return true
}

WaitWindowNotActive(WinTitle, SleepAmount, Timeout) {
    Start := A_TickCount
    while (WinActive(WinTitle)) {
        Sleep % SleepAmount
        if (A_TickCount - Start > Timeout) {
            return false
        }
    }
    return true
}

GetFocusedControl(WinTitle) {
    ControlGetFocus Focus, % WinTitle
    return Focus
}

WaitFocusedControl(ControlPattern, WinTitle, SleepAmount, Timeout) {
    Start := A_TickCount
    while (true) {
        if ((Focus := GetFocusedControl(WinTitle)) ~= ControlPattern) {
            return Focus
        }

        if (A_TickCount - Start >= Timeout) {
            return
        }

        Sleep % SleepAmount
    }
}

FileDialogActiveGetFolderPath(Hwnd) {
    SendPlay % "^{l}"
    if (!(Focus := WaitFocusedControl("^Edit2$", "ahk_id " Hwnd, 5, 1000))) {
        return
    }
    ControlGetText Path, % Focus, % "ahk_id " Hwnd
    ControlSend % Focus, % "{Escape}", % "ahk_id " Hwnd
    return Path
}

FileDialogNavigate(Path, Hwnd) {
    SendPlay % "!{n}"
    if (!(Focus := WaitFocusedControl("^Edit1$", "ahk_id " Hwnd, 5, 1000))) {
        return
    }
    ControlSetText % Focus, % """" Path """", % "ahk_id " Hwnd
    SendPlay % "{Enter}{Delete}"
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

GetCurrentMenu() {
    SendMessage 0x1e1, , , , % MenuTitle
    if (ErrorLevel == "FAIL") {
        return false
    }
    return ErrorLevel
}

CloseCurrentMenu() {
    SendMessage 0x1e6, , , , % MenuTitle
}

OpenCurrentSubMenu(Index) {
    SendMessage 0x1ed, % Index, 0, , % MenuTitle
}

SelectCurrentMenuItem(Index) {
    PostMessage 0x1f1, % Index, 0, , % MenuTitle
}

TryOpenCurrentSubMenu(Menu, Name) {
    Index := FindMenuItemIndex(Menu, Name)
    if (Index == -1) {
        return false
    }
    OpenCurrentSubMenu(Index)
    return true
}

TrySelectCurrentMenuItem(Menu, Name) {
    Index := FindMenuItemIndex(Menu, Name)
    if (Index == -1) {
        return false
    }
    SelectCurrentMenuItem(Index)
    return true
}

global DialogTitle := "ahk_class ^#32770$"

GenerateRandomGuid() {
    return ComObjCreate("Scriptlet.TypeLib").GUID
}

CreateTempFilePath() {
    loop {
        Path := A_Temp "\" GenerateRandomGuid()
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
    loop parse, % Fields, % A_Space
    {
        if (DllCall("version\VerQueryValue", "Ptr", &Data, "Str", "\StringFileInfo\" Language "\" A_LoopField, "PtrP", VersionInfo, "PtrP", VersionInfoSize, "Int")) {
            Info[A_LoopField] := StrGet(VersionInfo, VersionInfoSize)
        }
    }
    return Info
}

MapFile(FileHandle, ByRef Address) {
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
            DisplayName := "shell:" Item.Path
            break
        }
    }

    if (!DisplayName) {
        static SpecialFolders := Object("Desktop", "shell:::{b4bfcc3a-db2c-424c-b029-7fe99a87c641}"
            , "Documents", "shell:::{a8cdff1c-4878-43be-b5fd-f8091c1c60d0}"
            , "Downloads", "shell:::{374de290-123f-4565-9164-39c4925e467b}"
            , "Music", "shell:::{1cf1260c-4dd0-4ebb-811f-33c572699fde}"
            , "Pictures", "shell:::{3add1653-eb32-4cb0-bbd7-dfa0abb5acca}"
            , "Public", "shell:::{4336a54d-038b-4685-ab02-99bb52d3fb8b}"
            , "Recycle Bin", "shell:::{645ff040-5081-101b-9f08-00aa002f954e}"
            , "This PC", "shell:::{20d04fe0-3aea-1069-a2d8-08002b30309d}")

        DisplayName := SpecialFolders[Path]
    }

    if (!DisplayName) {
        DisplayName := Path
        if (SubStr(DisplayName, 0, 1) != "\") {
            DisplayName := DisplayName "\"
        }
    }

    DllCall("shell32\SHParseDisplayName", "Str", DisplayName, "Ptr", 0, "Ptr*", Pidl, "UInt", 0, "UInt*", 0)
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
        NumPut(ShellParseDisplayName(Paths[A_Index]), PathsPidls, (A_Index - 1) * A_PtrSize)
    }

    DllCall("shell32\SHOpenFolderAndSelectItems", "Ptr", PathPidl, "UInt", PathsCount, "Ptr", &PathsPidls, "Int", Flags)

    DllCall("ole32\CoTaskMemFree", "Ptr", PathPidl)
    loop % Paths.Count() {
        DllCall("ole32\CoTaskMemFree", "Ptr", NumGet(PathsPidls, (A_Index - 1) * A_PtrSize))
    }
}

global ContextTrack := (1 << 0)
global ContextFolderTrack := (1 << 1)
global ContextTrackListTrack := (1 << 2)
global ContextInsertSlot := (1 << 3)
global ContextNonEmptyInsertSlot := (1 << 4)
global ContextSendSlot := (1 << 5)
global ContextInsertsRack := (1 << 6)
global ContextSendsRack := (1 << 7)
global ContextEditor := (1 << 8)
global ContextKeyEditor := (1 << 9)
global ContextSelected := (1 << 10)
global ContextSelectedAudio := (1 << 11)
global ContextSelectedMidi := (1 << 12)

FindAppMenuContext(Menu) {
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
        if (FindMenuItemIndex(Menu, "Load Preset...") != -1) {
            Context |= ContextNonEmptyInsertSlot
        }
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

    return Context
}

;@Ahk2Exe-Bin Unicode 64-bit.bin

;@Ahk2Exe-SetDescription night
;@Ahk2Exe-SetFileVersion 1.1.1
;@Ahk2Exe-SetInternalName night
;@Ahk2Exe-SetCopyright https://github.com/t5mat/night
;@Ahk2Exe-SetOrigFilename night.exe
;@Ahk2Exe-SetProductName night
;@Ahk2Exe-SetProductVersion 1.1.1

global Version := "1.1.1"
global Url := "https://github.com/t5mat/night"

global MacroPrefix := "~ night - "
global PleFolderName := "night"
global HashMacroPrefix := "~ night "

global LocateModes := ["events", "hitpoints", "markers"]

global SelfTitle := "ahk_pid " DllCall("GetCurrentProcessId", "UInt")

global SettingsPath
global AppExePath
global AppName
global KeyCommandsPath
global PlePath

global AppTitle
global AppTitleBarTitle
global AppWindowTitle
global AppProjectWindowTitle
global AppColorizeWindowTitle

global MacroKeys

global MaxMenuTime := 500
global MenuTime
global Hwnd
global Menu
global Context
global HandleMenuHotkeyTimer

global MixConsolePage := 1
global LocateMode := 1
global InSpace := false
global InSpaceWriteAutomation := false

AutoExec()

return

IsValidKeyCommandsXml(KeyCommandsXml) {
    return KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Categories']") && KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")
}

IsInstalled(Hash, KeyCommandsXml) {
    return !!KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']/item/string[@name='Name' and @value='" HashMacroPrefix Hash "']")
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
    FileCreateDir % PlePath "\" PleFolderName

    for Ple in Xml.selectNodes("/night/ple/item") {
        Name := Ple.selectSingleNode("string[@name='Name']").getAttribute("value")
        Path := PlePath "\" PleFolderName "\" Name ".xml"

        Data := Ple.selectSingleNode("Project_Logical_EditorPreset").xml

        FileDelete % Path
        FileAppend % Data, % Path
    }
}

InstallHashMacro(Hash, KeyCommandsXml) {
    Name := KeyCommandsXml.createElement("string")
    Name.setAttribute("name", "Name")
    Name.setAttribute("value", HashMacroPrefix Hash)

    Item := KeyCommandsXml.createElement("item")
    Item.appendChild(Name)

    Macros := KeyCommandsXml.selectSingleNode("/KeyCommands/list[@name='Macros']")
    Macros.appendChild(Item)
}

Uninstall(KeyCommandsPath, PlePath) {
    KeyCommandsData := ReadFileUtf8(KeyCommandsPath)

    if ((KeyCommandsXml := LoadXml(KeyCommandsData))) {
        UninstallKeyCommands(KeyCommandsXml)

        FileDelete % KeyCommandsPath
        FileAppend % KeyCommandsXml.xml, % KeyCommandsPath
    }

    UninstallPle(PlePath)
}

UninstallKeyCommands(KeyCommandsXml) {
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

UninstallPle(PlePath) {
    FileRemoveDir % PlePath "\" PleFolderName, true
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

WaitFocusColorizeWindow() {
    if (!(Hwnd := WaitWindowExist(AppColorizeWindowTitle, 5, 1000))) {
        return
    }

    WinActivate % "ahk_id " Hwnd
    if (!WaitWindowActive("ahk_id " Hwnd, 5, 1000)) {
        return
    }

    WinGetPos, , , Width, Height, % "ahk_id " Hwnd
    if (!Width) {
        return
    }

    CoordMode Mouse, Screen
    MouseGetPos X, Y

    Padding = 50
    X := Max(Padding, Min(A_ScreenWidth - Padding - Width, X - Width // 2))
    Y := Max(Padding, Min(A_ScreenHeight - Padding - Height, Y - 5))

    WinMove % "ahk_id " Hwnd, , % X, % Y
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

OpenNightUrl() {
    Run % Url
}

ShowUninstall() {
    if (WinActive(AppTitle)) {
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

OpenApp() {
    Run % AppExePath
}

OpenAppProgramFiles() {
    SplitPath AppExePath, , Path
    ShellOpenFolderAndSelect(Path, [AppExePath], 0)
}

OpenAppAppData() {
    SplitPath KeyCommandsPath, , Path
    ShellOpenFolderAndSelect(Path, [Path], 0)
}

OpenAppDocuments() {
    SplitPath PlePath, , Path
    ShellOpenFolderAndSelect(Path, [Path], 0)
}

ShowProjectColorsPatcher() {
    if (WinExist(AppProjectWindowTitle)) {
        MsgBox % (0x0 | 0x30 | 0x40000), % "Project Colors Patcher", % "Please close all " AppName " projects before using the Project Colors Patcher."
        return
    }

    FileSelectFile ProjectPaths, M3, , % "Project Colors Patcher - select project files (BACK THEM UP FIRST)", % "Cubase/Nuendo Project Files (*.cpr; *.npr)"
    if (ErrorLevel != 0) {
        return
    }

    FileSelectFile ColorsPath, 3, % A_ScriptDir "\colors", % "Project Colors Patcher - select a colors file", % "Colors Files (*.ini)"
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

TrayMenuStub() {
}

AutoExec() {
    SetControlDelay -1
    SetWinDelay -1
    SetBatchLines -1

    if (!A_IsCompiled) {
        XmlPath := A_ScriptDir "\night.xml"

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
    SettingsPath := A_ScriptDir "\" SettingsFileName ".ini"

    IniRead AppExePath, % SettingsPath, % "night", % "AppExePath", % A_Space
    if (AppExePath == A_Space || !FileExist(AppExePath)) {
        FileSelectFile AppExePath, 3, % A_ProgramFiles "\Steinberg", % "Select your Cubase.exe/Nuendo.exe file", % "Executable Files (*.exe)"
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

    IniRead KeyCommandsPath, % SettingsPath, % "night", % "KeyCommandsPath", % A_Space
    if (KeyCommandsPath == A_Space || !FileExist(KeyCommandsPath)) {
        Path := A_AppData "\Steinberg"
        loop files, % Path "\*", D
        {
            if (InStr(A_LoopFileName, ExeVersionInfo.FileDescription)) {
                Path := A_LoopFilePath "\Key Commands.xml"
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
        FileSelectFolder PlePath, % "*" A_MyDocuments "\Steinberg\" AppName "\User Presets\", 2, % "Select your Project Logical Editor user presets folder"
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

    AppTitle := "ahk_exe i)^\Q" AppExePath "\E$"
    AppTitleBarTitle := AppTitle " ahk_class ^SmtgMain"
    AppWindowTitle := AppTitle " ahk_class ^SteinbergWindowClass$"
    AppProjectWindowTitle := "^" AppName "( .*?)? Project - .*$ " AppTitle
    AppColorizeWindowTitle := "^Colorize$ " AppTitle

    if (!IsInstalled(XmlHash, KeyCommandsXml)) {
        if (WinActive(AppTitle)) {
            MsgBox % (0x0 | 0x30 | 0x40000), % "night", % "night is not installed. Please close " AppName " and run night again to install."
            ExitApp
        }

        Uninstall(KeyCommandsPath, PlePath)

        KeyCommandsData := ReadFileUtf8(KeyCommandsPath)
        KeyCommandsXml := LoadXml(KeyCommandsData)

        InstallKeyCommands(Xml, KeyCommandsXml)
        InstallPle(Xml, PlePath)
        InstallHashMacro(XmlHash, KeyCommandsXml)

        FileDelete % KeyCommandsPath
        FileAppend % KeyCommandsXml.xml, % KeyCommandsPath

        MsgBox % (0x0 | 0x40 | 0x40000), % "night", % "night has been installed!`n`n" KeyCommandsPath "`n`n" PlePath
    }

    MacroKeys := LoadMacroKeys(KeyCommandsXml)

    Menu, Tray, NoStandard
    Menu, Tray, Add, % "night " Version, OpenNightUrl
    Menu, Tray, Add, % "Uninstall", ShowUninstall
    Menu, Tray, Add
    Menu, Tray, Add, % AppName " " ExeVersionInfo.FileVersion, OpenApp
    Menu, Tray, Add, % AppName " Program Files", OpenAppProgramFiles
    Menu, Tray, Add, % AppName " AppData", OpenAppAppData
    Menu, Tray, Add, % AppName " Documents", OpenAppDocuments
    Menu, Tray, Add
    Menu, Tray, Add, % "Project Colors Patcher", ShowProjectColorsPatcher
    Menu, Tray, Add
    Menu, Tray, Add, % "AutoHotkey " A_AhkVersion, TrayMenuStub
    Menu, Tray, Disable, % "AutoHotkey " A_AhkVersion
    Menu, Tray, Standard
}

IsContextMenuTime() {
    return (MenuTime && A_TickCount - MenuTime <= MaxMenuTime)
}

IsContextMenu(Directive) {
    return ((Menu := GetCurrentMenu()) || (Directive && IsContextMenuTime()))
}

HandleMenuHotkeyTimerTick(TestFunc, HandleFunc, MenuTime) {
    if (%TestFunc%(false)) {
        SetTimer % HandleMenuHotkeyTimer, Off
        HandleMenuHotkeyTimer :=
        %HandleFunc%()
        return
    }

    if (A_TickCount - MenuTime > 1000) {
        SetTimer % HandleMenuHotkeyTimer, Off
        HandleMenuHotkeyTimer :=
        return
    }
}

HandleMenuHotkey(TestFunc, HandleFunc) {
    if (HandleMenuHotkeyTimer) {
        SetTimer % HandleMenuHotkeyTimer, Off
        HandleMenuHotkeyTimer :=
    }

    if (Menu) {
        return true
    }

    HandleMenuHotkeyTimer := Func("HandleMenuHotkeyTimerTick").Bind(TestFunc, HandleFunc, MenuTime)
    SetTimer % HandleMenuHotkeyTimer, 5
}

IsActiveAppWindow() {
    return WinExist("ahk_id " (Hwnd := WinExist("A")) " " AppWindowTitle)
}

IsActiveLowerZoneMixConsole() {
    return WinExist("ahk_id " (Hwnd := WinExist("A")) " " AppProjectWindowTitle) && GetKeyState("XButton2", "P")
}

IsActiveAppNotMenu() {
    return WinExist("ahk_id " (Hwnd := WinExist("A")) " " AppTitle) && !GetCurrentMenu()
}

IsActiveDialog() {
    Hwnd := WinExist("A")
    return (WinExist("ahk_id " Hwnd " " AppTitle) || WinExist("ahk_id " Hwnd " " SelfTitle)) && WinExist("ahk_id " Hwnd " " DialogTitle)
}

IsActiveAppMenu(Directive := true) {
    return WinExist("ahk_id " (Hwnd := WinExist("A")) " " AppTitle) && IsContextMenu(Directive)
}

#If IsActiveAppWindow()

~*RButton::
    MenuTime := A_TickCount

~*AppsKey::
    MenuTime := A_TickCount

$XButton1::
    if (!(Hwnd := WinExist(AppProjectWindowTitle))) {
        return
    }

    WinActivate % "ahk_id " Hwnd
    if (!WaitWindowActive("ahk_id " Hwnd, 5, 1000)) {
        return
    }

    SendEvent % MacroKeys["Show Lower Zone MixConsole Page " MixConsolePage] MacroKeys["Edit - Open/Close Editor"]
    return

$XButton2::
    if (!(Hwnd := WinExist(AppProjectWindowTitle))) {
        return
    }

    WinActivate % "ahk_id " Hwnd
    if (!WaitWindowActive("ahk_id " Hwnd, 5, 1000)) {
        return
    }

    SendEvent % MacroKeys["Show Lower Zone MixConsole Page " MixConsolePage]
    return

#If IsActiveLowerZoneMixConsole()

$WheelDown::
    if (MixConsolePage < 3) {
        MixConsolePage += 1
    }
    SendEvent % MacroKeys["Window Zones - Show Next Page"]
    return

$WheelUp::
    if (MixConsolePage > 1) {
        MixConsolePage -= 1
    }
    SendEvent % MacroKeys["Window Zones - Show Previous Page"]
    return

#If IsActiveAppWindow()

$!WheelDown::
    SendEvent % MacroKeys["Zoom - Zoom Out Vertically"]
    return

$!WheelUp::
    SendEvent % MacroKeys["Zoom - Zoom In Vertically"]
    return

$^!WheelDown::
    SendEvent % MacroKeys["Zoom Out Horizontally and Vertically"]
    return

$^!WheelUp::
    SendEvent % MacroKeys["Zoom In Horizontally and Vertically"]
    return

$+WheelDown::
    SendEvent % MacroKeys["Zoom - Zoom Out Tracks"]
    return

$+WheelUp::
    SendEvent % MacroKeys["Zoom - Zoom In Tracks"]
    return

$^+!WheelDown::
    SendEvent % MacroKeys["Zoom - Zoom Out Of Waveform Vertically"]
    return

$^+!WheelUp::
    SendEvent % MacroKeys["Zoom - Zoom In On Waveform Vertically"]
    return

$^+MButton::
    LocateMode := Mod(LocateMode, 3) + 1
    ToolTip("locate mode: " LocateModes[LocateMode], 1250)
    return

$^+WheelDown::
    switch (LocateMode) {
    case 1:
        SendEvent % MacroKeys["Locate Next Event"]
    case 2:
        SendEvent % MacroKeys["Locate Next Hitpoint"]
    case 3:
        SendEvent % MacroKeys["Locate Next Marker"]
    }
    return

$^+WheelUp::
    switch (LocateMode) {
    case 1:
        SendEvent % MacroKeys["Locate Previous Event"]
    case 2:
        SendEvent % MacroKeys["Locate Previous Hitpoint"]
    case 3:
        SendEvent % MacroKeys["Locate Previous Marker"]
    }
    return

#If IsActiveAppNotMenu()

$Escape::
    if (WinActive(AppProjectWindowTitle) || WinActive(AppTitleBarTitle) && WinExist(AppProjectWindowTitle)) {
        return
    }

    if (WinActive(AppTitleBarTitle) || WinActive(AppColorizeWindowTitle)) {
        WinClose A
        return
    }

    SendEvent % "{Escape down}"
    KeyWait % "Escape"
    SendEvent % "{Escape up}"
    return

$Space::
    InSpace := true
    SendEvent % "{Space}"
    KeyWait % "Space"
    InSpace := false

    if (InSpaceWriteAutomation) {
        InSpaceWriteAutomation := false
        SendEvent % "{Space}" MacroKeys["Automation - Toggle Write Enable All Tracks"]
    }

    return

~*LButton::
    if (InSpace && !InSpaceWriteAutomation) {
        InSpaceWriteAutomation := true
        SendEvent % MacroKeys["Automation - Toggle Write Enable All Tracks"]
    }

    return

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

        FileDialogNavigate(Path, Hwnd)
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
        Path := FileDialogActiveGetFolderPath(Hwnd)
        IniWrite % Path, % SettingsPath, % "FileDialogPaths", % SubStr(A_ThisHotkey, 3)
    }

#If IsActiveAppMenu()

$Space::
    HandleAppMenuSpace() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextTrackListTrack) && !(Context & ContextFolderTrack)) {
            TrySelectCurrentMenuItem(Menu, "Hide Automation") || TrySelectCurrentMenuItem(Menu, "Show Used Automation (Selected Tracks)") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextTrackListTrack) && (Context & ContextFolderTrack)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Folding: Toggle Selected Track"]
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Transport - Locate Selection"]
            return
        }

        SendEvent % "{Blind}{Space}"
    }

$^Space::
    HandleAppMenuCtrlSpace() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextTrackListTrack) && !(Context & ContextFolderTrack)) {
            TrySelectCurrentMenuItem(Menu, "Show All Used Automation") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextTrackListTrack) && (Context & ContextFolderTrack)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Folding: Unfold Tracks"]
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Move to Cursor"]
            return
        }

        SendEvent % "{Blind}{Space}"
    }

$+Space::
    HandleAppMenuShiftSpace() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextTrackListTrack) && !(Context & ContextFolderTrack)) {
            TrySelectCurrentMenuItem(Menu, "Hide All Automation") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextTrackListTrack) && (Context & ContextFolderTrack)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Folding: Fold Tracks"]
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Transport - Locators to Selection"]
            return
        }

        SendEvent % "{Blind}{Space}"
    }

$Delete::
    HandleAppMenuDelete() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Remove Selected Tracks"]
            return
        }

        if (Context & ContextInsertSlot) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        if (Context & ContextSendSlot) {
            TrySelectCurrentMenuItem(Menu, "Clear Send") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        SendEvent % "{Blind}{Delete}"
    }

$Backspace::
    HandleAppMenuBackspace() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Remove Selected Tracks"]
            return
        }

        if (Context & ContextInsertSlot) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        if (Context & ContextSendSlot) {
            TrySelectCurrentMenuItem(Menu, "Clear Send") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        SendEvent % "{Blind}{Backspace}"
    }

$Tab::
    HandleAppMenuTab() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Edit VST Instrument"]
            return
        }

        if (Context & ContextNonEmptyInsertSlot) {
            CloseCurrentMenu()
            SendEvent % "{Tab up}{Alt down}{Click}{Alt up}"
            if (WaitWindowNotActive("ahk_id " Hwnd, 5, 150)) {
                return
            }
            SendEvent % "{Enter}"
            return
        }

        if (Context & ContextInsertsRack) {
            CloseCurrentMenu()
            SendEvent % "{Up}{Right}+!{Enter}"
            return
        }

        if ((Context & ContextEditor) && (Context & ContextKeyEditor)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Note Expression - Open/Close Editor"]
            return
        }

        SendEvent % "{Blind}{Tab}"
    }

$+Tab::
    HandleAppMenuShiftTab() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextNonEmptyInsertSlot) {
            CloseCurrentMenu()
            SendEvent % "{Tab up}{Alt down}{Click}{Alt up}"
            if (!WaitWindowNotActive("ahk_id " Hwnd, 5, 150)) {
                return
            }
            SendEvent % MacroKeys["File - Close"]
            return
        }

        if (Context & ContextInsertsRack) {
            CloseCurrentMenu()
            SendEvent % "{Up}{Right}+{Enter}"
            return
        }

        SendEvent % "{Blind}{Tab}"
    }

$a::
    HandleAppMenuA() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrackListTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Select All on Tracks"]
            return
        }

        SendEvent % "{Blind}{a}"
    }

$^a::
    HandleAppMenuCtrlA() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Select All Tracks"]
            return
        }

        SendEvent % "{Blind}{a}"
    }

$b::
    HandleAppMenuB() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelectedAudio)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Audio - Bounce"]
            return
        }

        SendEvent % "{Blind}{b}"
    }

$c::
    HandleAppMenuC() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Colorize Selected Tracks"]
            WaitFocusColorizeWindow()
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Set Track/Event Color"]
            WaitFocusColorizeWindow()
            return
        }

        SendEvent % "{Blind}{c}"
    }

$^c::
    HandleAppMenuCtrlC() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextSendSlot) {
            TrySelectCurrentMenuItem(Menu, "Copy Send") || CloseCurrentMenu()
            return
        }

        SendEvent % "{Blind}{c}"
    }

$d::
    HandleAppMenuD() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Remove Selected Tracks"]
            return
        }

        if (Context & ContextInsertSlot) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        if (Context & ContextSendSlot) {
            TrySelectCurrentMenuItem(Menu, "Clear Send") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Delete"]
            return
        }

        SendEvent % "{Blind}{d}"
    }

$^d::
    HandleAppMenuCtrlD() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Duplicate Tracks"]
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Repeat"]
            return
        }

        SendEvent % "{Blind}{d}"
    }

$e::
    HandleAppMenuE() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Audio - Disable/Enable Track"]
            return
        }

        if (Context & ContextNonEmptyInsertSlot) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Activate/Deactivate"]
            return
        }

        if (Context & ContextSendSlot) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Activate/Deactivate"]
            return
        }

        if (Context & ContextInsertsRack) {
            TrySelectCurrentMenuItem(Menu, "Bypass") || CloseCurrentMenu()
            return
        }

        if (Context & ContextSendsRack) {
            TrySelectCurrentMenuItem(Menu, "Bypass") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Mute/Unmute Objects"]
            return
        }

        SendEvent % "{Blind}{e}"
    }

$+e::
    HandleAppMenuShiftE() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextNonEmptyInsertSlot) {
            CloseCurrentMenu()
            SendEvent % "^!{Enter}"
            return
        }

        SendEvent % "{Blind}{e}"
    }

$f::
    HandleAppMenuF() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrackListTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Project - Folding: Tracks To Folder"]
            return
        }

        if (Context & ContextInsertSlot) {
            TrySelectCurrentMenuItem(Menu, "Set as last Pre-Fader Slot") || CloseCurrentMenu()
            return
        }

        if (Context & ContextSendSlot) {
            TrySelectCurrentMenuItem(Menu, "Move to Pre-Fader") || TrySelectCurrentMenuItem(Menu, "Move to Post-Fader") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelectedMidi)) {
            TryOpenCurrentSubMenu(Menu, "Functions")
            return
        }

        SendEvent % "{Blind}{f}"
    }

$g::
    HandleAppMenuG() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Mixer - Add Track To Selected: Group Channel"]
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Glue"]
            return
        }

        SendEvent % "{Blind}{g}"
    }

$+g::
    HandleAppMenuShiftG() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Dissolve"]
            return
        }

        SendEvent % "{Blind}{g}"
    }

$h::
    HandleAppMenuH() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Mixer - HideSelected"]
            return
        }

        SendEvent % "{Blind}{h}"
    }

$i::
    HandleAppMenuI() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrackListTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Editors - Edit In-Place"]
            return
        }

        SendEvent % "{Blind}{i}"
    }

$^o::
    HandleAppMenuCtrlO() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            TrySelectCurrentMenuItem(Menu, "Load Track Preset...") || CloseCurrentMenu()
            return
        }

        if (Context & ContextInsertsRack) {
            TrySelectCurrentMenuItem(Menu, "Load FX Chain Preset...") || CloseCurrentMenu()
            return
        }

        SendEvent % "{Blind}{o}"
    }

$p::
    HandleAppMenuP() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelectedAudio)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Audio - Find Selected in Pool"]
            return
        }

        SendEvent % "{Blind}{p}"
    }

$q::
    HandleAppMenuQ() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextNonEmptyInsertSlot) {
            TrySelectCurrentMenuItem(Menu, "Switch to A Setting") || TrySelectCurrentMenuItem(Menu, "Switch to B Setting") || CloseCurrentMenu()
            return
        }

        if (Context & ContextSendSlot) {
            CloseCurrentMenu()
            SendEvent % "{Enter}"
            if (!(Focus := WaitFocusedControl("^Edit1$", "ahk_id " Hwnd, 5, 1000))) {
                return
            }
            ControlSetText % Focus, % "-oo", % "ahk_id " Hwnd
            ControlSend % Focus, % "{Enter}", % "ahk_id " Hwnd
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelectedMidi)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["MIDI - Quantize"]
            return
        }

        SendEvent % "{Blind}{q}"
    }

$^q::
    HandleAppMenuCtrlQ() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelectedMidi)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["MIDI - Quantize Ends"]
            return
        }

        SendEvent % "{Blind}{q}"
    }

$+q::
    HandleAppMenuShiftQ() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextNonEmptyInsertSlot) {
            TrySelectCurrentMenuItem(Menu, "Apply Current Settings to A and B") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelectedMidi)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["MIDI - Undo Quantize"]
            return
        }

        SendEvent % "{Blind}{q}"
    }

$^+q::
    HandleAppMenuCtrlShiftQ() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelectedMidi)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["MIDI - Quantize Lengths"]
            return
        }

        SendEvent % "{Blind}{q}"
    }

$r::
    HandleAppMenuR() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrackListTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Clear Selected Tracks"]
            return
        }

        if (Context & ContextSendSlot) {
            TrySelectCurrentMenuItem(Menu, "Use Default Send Level") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Render in Place - Render"]
            return
        }

        SendEvent % "{Blind}{r}"
    }

$^r::
    HandleAppMenuCtrlR() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Render in Place - Render Setup..."]
            return
        }

        SendEvent % "{Blind}{r}"
    }

$s::
    HandleAppMenuS() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["FX Channel to Selected Channels..."]
            return
        }

        if (Context & ContextNonEmptyInsertSlot) {
            TrySelectCurrentMenuItem(Menu, "Activate/Deactivate Side-Chaining") || CloseCurrentMenu()
            return
        }

        SendEvent % "{Blind}{s}"
    }

$^s::
    HandleAppMenuCtrlS() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            TrySelectCurrentMenuItem(Menu, "Save Track Preset...") || CloseCurrentMenu()
            return
        }

        if (Context & ContextInsertsRack) {
            TrySelectCurrentMenuItem(Menu, "Save FX Chain Preset...") || CloseCurrentMenu()
            return
        }

        if ((Context & ContextEditor) && !(Context & ContextKeyEditor) && (Context & ContextSelectedMidi)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["File - Export MIDI Loop"]
            return
        }

        SendEvent % "{Blind}{s}"
    }

$+s::
    HandleAppMenuShiftS() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - To Real Copy"]
            return
        }

        SendEvent % "{Blind}{s}"
    }

$^+s::
    HandleAppMenuCtrlShiftS() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["File - Export Selected Tracks"]
            return
        }

        SendEvent % "{Blind}{s}"
    }

$v::
    HandleAppMenuV() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextTrack) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Mixer - Add Track To Selected: VCA Fader"]
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelectedMidi)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["MIDI - Legato"]
            return
        }

        SendEvent % "{Blind}{v}"
    }

$^v::
    HandleAppMenuCtrlV() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextSendSlot) {
            TrySelectCurrentMenuItem(Menu, "Paste Send") || CloseCurrentMenu()
            return
        }

        SendEvent % "{Blind}{v}"
    }

$w::
    HandleAppMenuW() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if (Context & ContextInsertSlot) {
            CloseCurrentMenu()
            SendEvent % "!{Enter}"
            return
        }

        if (Context & ContextSendSlot) {
            CloseCurrentMenu()
            SendEvent % "!{Enter}"
            return
        }

        SendEvent % "{Blind}{w}"
    }

$x::
    HandleAppMenuX() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Split Range"]
            return
        }

        SendEvent % "{Blind}{x}"
    }

$+x::
    HandleAppMenuShiftX() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Edit - Crop Range"]
            return
        }

        SendEvent % "{Blind}{x}"
    }

$z::
    HandleAppMenuZ() {
        if (!HandleMenuHotkey("IsActiveAppMenu", A_ThisFunc)) {
            return
        }

        Context := FindAppMenuContext(Menu)

        if ((Context & ContextEditor) && !(Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Zoom - Zoom Full"]
            return
        }

        if ((Context & ContextEditor) && (Context & ContextSelected)) {
            CloseCurrentMenu()
            SendEvent % MacroKeys["Zoom - Zoom to Selection Horizontally"]
            return
        }

        SendEvent % "{Blind}{z}"
    }
