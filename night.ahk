if (!A_IsUnicode || A_PtrSize != 8) {
    ExitApp
}

DetectHiddenWindows On
SetTitleMatchMode RegEx

GroupAdd CurrentProcess, % "ahk_pid " DllCall("GetCurrentProcessId")
GroupAdd SystemMenu, % "ahk_class ^#32768$"
GroupAdd SystemDialog, % "ahk_class ^#32770$"

ToolTipTimeout(Text, Timeout)
{
    ToolTip % Text
    SetTimer RemoveToolTip, % -Timeout
}

RemoveToolTip()
{
    ToolTip
}

WaitWindowNotActive(WinTitle, SleepAmount, Timeout)
{
    Start := A_TickCount
    while (WinActive(WinTitle)) {
        Sleep % SleepAmount
        if (A_TickCount - Start > Timeout) {
            return false
        }
    }
    return true
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
    return DllCall("GetMenuItemCount", "Ptr", Menu)
}

GetMenuItemName(Menu, Index)
{
    Count := DllCall("GetMenuString", "Ptr", Menu, "UInt", Index, "Ptr", 0, "Int", 0, "UInt", 0x400) + 1
    VarSetCapacity(Name, Count << !!A_IsUnicode)
    DllCall("GetMenuString", "Ptr", Menu, "UInt", Index, "Str", Name, "Int", Count, "UInt", 0x400)
    return Name
}

GetMenuItemState(Menu, Index)
{
    return DllCall("GetMenuState", "Ptr", Menu, "UInt", Index, "UInt", 0x400)
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

GenerateRandomGuid()
{
    return ComObjCreate("Scriptlet.TypeLib").GUID
}

CreateTempFilePath()
{
    loop {
        Path := A_Temp "\" GenerateRandomGuid()
        if (!FileExist(Path)) {
            return Path
        }
    }
}

HashFile(Path, Algorithm)
{
    OutputPath := CreateTempFilePath()
    Shell := ComObjCreate("WScript.Shell")
    Shell.Run("cmd /c certutil -hashfile """ Path """ " Algorithm " >" OutputPath, 0, true)
    FileRead Output, % "*P65001 " OutputPath
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

;@Ahk2Exe-Bin Unicode 64-bit.bin

;@Ahk2Exe-SetDescription night
;@Ahk2Exe-SetFileVersion 1.0.2
;@Ahk2Exe-SetInternalName night
;@Ahk2Exe-SetCopyright https://github.com/t5mat/night
;@Ahk2Exe-SetOrigFilename night.exe
;@Ahk2Exe-SetProductName night
;@Ahk2Exe-SetProductVersion 1.0.2

global Version := "1.0.2"
global Url := "https://github.com/t5mat/night"

#SingleInstance Force

#MenuMaskKey vkFF

SetWinDelay -1 ; uh oh
SendMode Event

global MacroPrefix := "~ night - "
global PleFolderName := "night"
global HashMacroPrefix := "~ night "

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
    FileRead KeyCommandsData, % "*P65001 " KeyCommandsPath

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

FindContextFromMenu(Menu)
{
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

CloseCurrentMenuAndSend(Keys)
{
    CloseCurrentMenu()
    Send % Keys
}

WaitFocusColorizeWindow()
{
    WinWait % "ahk_group AppColorizeWindow"
    WinActivate % "ahk_group AppColorizeWindow"

    WinGetPos, , , Width, Height, % "ahk_group AppColorizeWindow"
    if (!Width) {
        return
    }

    CoordMode Mouse, Screen
    MouseGetPos X, Y

    Padding = 50
    X := Max(Padding, Min(A_ScreenWidth - Padding - Width, X - Width // 2))
    Y := Max(Padding, Min(A_ScreenHeight - Padding - Height, Y - 5))

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

global LocateModes := ["events", "hitpoints", "markers"]

global SettingsPath
global AppExePath
global AppName
global KeyCommandsPath
global PlePath
global MacroKeys
global MixConsolePage
global LocateMode

AutoExec()
{
    if (!A_IsCompiled) {
        XmlPath := A_ScriptDir "\night.xml"

        FileRead XmlData, % "*P65001 " XmlPath
        XmlHash := HashFile(XmlPath, "MD5")
    } else {
        XmlPath := CreateTempFilePath()
        FileInstall night.xml, % XmlPath, true

        FileRead XmlData, % "*P65001 " XmlPath
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

    AppExe := "ahk_exe i)^\Q" AppExePath "\E$"
    GroupAdd AppExe, % AppExe
    GroupAdd AppTitleBar, % AppExe " ahk_class ^SmtgMain " App
    GroupAdd AppWindow, % AppExe " ahk_class ^SteinbergWindowClass$"
    GroupAdd AppProjectWindow, % "^" AppName "( .*?)? Project - .*$ " AppExe
    GroupAdd AppColorizeWindow, % "^Colorize$ " AppExe

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

    FileRead KeyCommandsData, % "*P65001 " KeyCommandsPath

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

        FileRead KeyCommandsData, % "*P65001 " KeyCommandsPath
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

OpenApp()
{
    Run % AppExePath
}

OpenAppProgramFiles()
{
    Run % "explorer.exe /select,""" AppExePath """"
}

OpenAppAppData()
{
    SplitPath KeyCommandsPath, , Path
    Run % Path
}

OpenAppDocuments()
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

TrayMenuStub()
{
}

AutoExec()

return

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

$!WheelDown::Send % MacroKeys["Zoom - Zoom Out Vertically"]
$!WheelUp::Send % MacroKeys["Zoom - Zoom In Vertically"]
$^!WheelDown::Send % MacroKeys["Zoom Out Horizontally and Vertically"]
$^!WheelUp::Send % MacroKeys["Zoom In Horizontally and Vertically"]
$+WheelDown::Send % MacroKeys["Zoom - Zoom Out Tracks"]
$+WheelUp::Send % MacroKeys["Zoom - Zoom In Tracks"]
$^+!WheelDown::Send % MacroKeys["Zoom - Zoom Out Of Waveform Vertically"]
$^+!WheelUp::Send % MacroKeys["Zoom - Zoom In On Waveform Vertically"]

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
    KeyWait % "Escape"
    Send % "{Escape up}"
    return

global InSpace := false
global InSpaceWriteAutomation := false

$Space::
    InSpace := true
    Send % "{Space}"
    KeyWait % "Space"
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
    IniRead Path, % SettingsPath, % "FileDialogPaths", % SubStr(A_ThisHotkey, 2), % A_Space
    if (Path != A_Space && InStr(FileExist(Path), "D")) {
        TryFileDialogNavigate(Path, "A")
    }
    return

#If

global CurrentMenu
global CurrentContext

PopulateAppExeCurrentMenuContext()
{
    if (!WinActive("ahk_group AppExe")) {
        CurrentMenu :=
        CurrentContext := 0
        return
    }

    CurrentMenu := GetCurrentMenu()
    if (!CurrentMenu) {
        CurrentContext := 0
        return
    }

    CurrentContext := FindContextFromMenu(CurrentMenu)
}

IsMenuContextTrack()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextTrack)
}

#If IsMenuContextTrack()

$^a::CloseCurrentMenuAndSend(MacroKeys["Select All Tracks"])

$c::
    CloseCurrentMenuAndSend(MacroKeys["Colorize Selected Tracks"])
    WaitFocusColorizeWindow()
    return

$d::CloseCurrentMenuAndSend(MacroKeys["Project - Remove Selected Tracks"])
$Delete::CloseCurrentMenuAndSend(MacroKeys["Project - Remove Selected Tracks"])
$Backspace::CloseCurrentMenuAndSend(MacroKeys["Project - Remove Selected Tracks"])
$^d::CloseCurrentMenuAndSend(MacroKeys["Project - Duplicate Tracks"])
$e::CloseCurrentMenuAndSend(MacroKeys["Audio - Disable/Enable Track"])
$g::CloseCurrentMenuAndSend(MacroKeys["Mixer - Add Track To Selected: Group Channel"])
$h::CloseCurrentMenuAndSend(MacroKeys["Mixer - HideSelected"])
$^o::TrySelectCurrentMenuItem(CurrentMenu, "Load Track Preset...")
$s::CloseCurrentMenuAndSend(MacroKeys["FX Channel to Selected Channels..."])
$^s::TrySelectCurrentMenuItem(CurrentMenu, "Save Track Preset...")
$^+s::CloseCurrentMenuAndSend(MacroKeys["File - Export Selected Tracks"])
$v::CloseCurrentMenuAndSend(MacroKeys["Mixer - Add Track To Selected: VCA Fader"])
$w::CloseCurrentMenuAndSend(MacroKeys["Edit - Edit VST Instrument"])

#If

IsMenuContextTrackListTrack()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextTrackListTrack)
}

#If IsMenuContextTrackListTrack()

$a::CloseCurrentMenuAndSend(MacroKeys["Edit - Select All on Tracks"])
$f::CloseCurrentMenuAndSend(MacroKeys["Project - Folding: Tracks To Folder"])
$i::CloseCurrentMenuAndSend(MacroKeys["Editors - Edit In-Place"])
$r::CloseCurrentMenuAndSend(MacroKeys["Clear Selected Tracks"])

#If

IsMenuContextTrackListFolderTrack()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextTrackListTrack) && !!(CurrentContext & ContextFolderTrack)
}

#If IsMenuContextTrackListFolderTrack()

$Space::CloseCurrentMenuAndSend(MacroKeys["Project - Folding: Toggle Selected Track"])
$+Space::CloseCurrentMenuAndSend(MacroKeys["Project - Folding: Fold Tracks"])
$^Space::CloseCurrentMenuAndSend(MacroKeys["Project - Folding: Unfold Tracks"])

#If

IsMenuContextTrackListNonFolderTrack()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextTrackListTrack) && !(CurrentContext & ContextFolderTrack)
}

#If IsMenuContextTrackListNonFolderTrack()

$Space::TrySelectCurrentMenuItem(CurrentMenu, "Hide Automation") || TrySelectCurrentMenuItem(CurrentMenu, "Show Used Automation (Selected Tracks)")
$+Space::TrySelectCurrentMenuItem(CurrentMenu, "Hide All Automation")
$^Space::TrySelectCurrentMenuItem(CurrentMenu, "Show All Used Automation")

#If

IsMenuContextInsertSlot()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextInsertSlot)
}

#If IsMenuContextInsertSlot()

$d::CloseCurrentMenuAndSend(MacroKeys["Edit - Delete"])
$Delete::CloseCurrentMenuAndSend(MacroKeys["Edit - Delete"])
$Backspace::CloseCurrentMenuAndSend(MacroKeys["Edit - Delete"])
$f::TrySelectCurrentMenuItem(CurrentMenu, "Set as last Pre-Fader Slot")
$Tab::CloseCurrentMenuAndSend("!{Enter}")

#If

IsMenuContextNonEmptyInsertSlot()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextNonEmptyInsertSlot)
}

#If IsMenuContextNonEmptyInsertSlot()

$e::CloseCurrentMenuAndSend(MacroKeys["Edit - Activate/Deactivate"])
$+e::CloseCurrentMenuAndSend("^!{Enter}")
$s::TrySelectCurrentMenuItem(CurrentMenu, "Activate/Deactivate Side-Chaining")
$q::TrySelectCurrentMenuItem(CurrentMenu, "Switch to A Setting") || TrySelectCurrentMenuItem(CurrentMenu, "Switch to B Setting")
$+q::TrySelectCurrentMenuItem(CurrentMenu, "Apply Current Settings to A and B")

$Space::
    WinGet Active, ID, A
    CloseCurrentMenuAndSend("{Space up}{Alt down}{Click}{Alt up}")
    if (!WaitWindowNotActive("ahk_id " Active, 10, 150)) {
        Send % "{Enter}"
    }
    return

$+Space::
    WinGet Active, ID, A
    CloseCurrentMenuAndSend("{Space up}{Alt down}{Click}{Alt up}")
    if (WaitWindowNotActive("ahk_id " Active, 10, 150)) {
        Send % MacroKeys["File - Close"]
    }
    return

#If

IsMenuContextSendSlot()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextSendSlot)
}

#If IsMenuContextSendSlot()

$^c::TrySelectCurrentMenuItem(CurrentMenu, "Copy Send")
$d::TrySelectCurrentMenuItem(CurrentMenu, "Clear Send")
$Delete::TrySelectCurrentMenuItem(CurrentMenu, "Clear Send")
$Backspace::TrySelectCurrentMenuItem(CurrentMenu, "Clear Send")
$e::CloseCurrentMenuAndSend(MacroKeys["Edit - Activate/Deactivate"])
$f::TrySelectCurrentMenuItem(CurrentMenu, "Move to Pre-Fader") || TrySelectCurrentMenuItem(CurrentMenu, "Move to Post-Fader")

$q::
    CloseCurrentMenuAndSend("{Enter}")
    ControlSetText Edit1, % "-oo", A
    ControlSend Edit1, % "{Enter}", A
    return

$r::TrySelectCurrentMenuItem(CurrentMenu, "Use Default Send Level")
$^v::TrySelectCurrentMenuItem(CurrentMenu, "Paste Send")
$Tab::CloseCurrentMenuAndSend("!{Enter}")

#If

IsMenuContextInsertsRack()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextInsertsRack)
}

#If IsMenuContextInsertsRack()

$e::TrySelectCurrentMenuItem(CurrentMenu, "Bypass")
$^o::TrySelectCurrentMenuItem(CurrentMenu, "Load FX Chain Preset...")
$^s::TrySelectCurrentMenuItem(CurrentMenu, "Save FX Chain Preset...")
$Space::CloseCurrentMenuAndSend("{Up}{Right}+!{Enter}")
$+Space::CloseCurrentMenuAndSend("{Up}{Right}+{Enter}")

#If

IsMenuContextSendsRack()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextSendsRack)
}

#If IsMenuContextSendsRack()

$e::TrySelectCurrentMenuItem(CurrentMenu, "Bypass")

#If

IsMenuContextKeyEditor()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextEditor) && !!(CurrentContext & ContextKeyEditor)
}

#If IsMenuContextKeyEditor()

$w::CloseCurrentMenuAndSend(MacroKeys["Note Expression - Open/Close Editor"])

#If

IsMenuContextEditorNotSelected()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextEditor) && !(CurrentContext & ContextSelected)
}

#If IsMenuContextEditorNotSelected()

$z::CloseCurrentMenuAndSend(MacroKeys["Zoom - Zoom Full"])

#If

IsMenuContextEditorSelected()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextEditor) && !!(CurrentContext & ContextSelected)
}

#If IsMenuContextEditorSelected()

$c::
    CloseCurrentMenuAndSend(MacroKeys["Project - Set Track/Event Color"])
    WaitFocusColorizeWindow()
    return

$e::CloseCurrentMenuAndSend(MacroKeys["Edit - Mute/Unmute Objects"])
$d::CloseCurrentMenuAndSend(MacroKeys["Edit - Delete"])
$Delete::CloseCurrentMenuAndSend(MacroKeys["Edit - Delete"])
$Backspace::CloseCurrentMenuAndSend(MacroKeys["Edit - Delete"])
$^d::CloseCurrentMenuAndSend(MacroKeys["Edit - Repeat"])
$g::CloseCurrentMenuAndSend(MacroKeys["Edit - Glue"])
$+g::CloseCurrentMenuAndSend(MacroKeys["Dissolve"])
$r::CloseCurrentMenuAndSend(MacroKeys["Render in Place - Render"])
$^r::CloseCurrentMenuAndSend(MacroKeys["Render in Place - Render Setup..."])
$+s::CloseCurrentMenuAndSend(MacroKeys["Edit - To Real Copy"])
$x::CloseCurrentMenuAndSend(MacroKeys["Edit - Split Range"])
$+x::CloseCurrentMenuAndSend(MacroKeys["Edit - Crop Range"])
$z::CloseCurrentMenuAndSend(MacroKeys["Zoom - Zoom to Selection Horizontally"])
$Space::CloseCurrentMenuAndSend(MacroKeys["Transport - Locate Selection"])
$^Space::CloseCurrentMenuAndSend(MacroKeys["Edit - Move to Cursor"])
$+Space::CloseCurrentMenuAndSend(MacroKeys["Transport - Locators to Selection"])

#If

IsMenuContextEditorSelectedAudio()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextEditor) && !!(CurrentContext & ContextSelectedAudio)
}

#If IsMenuContextEditorSelectedAudio()

$b::CloseCurrentMenuAndSend(MacroKeys["Audio - Bounce"])
$p::CloseCurrentMenuAndSend(MacroKeys["Audio - Find Selected in Pool"])

#If

IsMenuContextEditorSelectedMidi()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextEditor) && !!(CurrentContext & ContextSelectedMidi)
}

#If IsMenuContextEditorSelectedMidi()

$f::TryOpenCurrentSubMenu(CurrentMenu, "Functions")
$q::CloseCurrentMenuAndSend(MacroKeys["MIDI - Quantize"])
$^q::CloseCurrentMenuAndSend(MacroKeys["MIDI - Quantize Ends"])
$+q::CloseCurrentMenuAndSend(MacroKeys["MIDI - Undo Quantize"])
$^+q::CloseCurrentMenuAndSend(MacroKeys["MIDI - Quantize Lengths"])
$v::CloseCurrentMenuAndSend(MacroKeys["MIDI - Legato"])

#If

IsMenuContextNotKeyEditorSelectedMidi()
{
    PopulateAppExeCurrentMenuContext()
    return !!(CurrentContext & ContextEditor) && !(CurrentContext & ContextKeyEditor) && !!(CurrentContext & ContextSelectedMidi)
}

#If IsMenuContextNotKeyEditorSelectedMidi()

$^s::CloseCurrentMenuAndSend(MacroKeys["File - Export MIDI Loop"])

#If
