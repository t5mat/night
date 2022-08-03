<h1 align="center"><img src="https://user-images.githubusercontent.com/16616463/176883524-74d04926-6f9a-4a40-86ff-681956acc56f.png" width="24" height="23"> night</h1>

<p align="center">
<img src="https://user-images.githubusercontent.com/16616463/174643141-d9a3db07-3d80-4883-9e69-0783432ef096.gif">
</p>

**night** is a program (written in AutoHotkey) that enhances Cubase/Nuendo with new hotkeys & functionality.

It overrides almost none of the assignable keyboard shortcut in Cubase/Nuendo; the goal is to provide stuff you cannot configure in Cubase/Nuendo out-of-the-box.

I made this to address some of the workflow limitations I've encountered as I was learning Cubase. I've actually come to rely on night much more than I expected, so I decided to take a bit of time to package and share it.

Don't expect this to be very maintained; rather, it is encouraged you modify night yourself if you want something changed. The code is relatively easy to follow, and with a bit of AutoHotkey knowledge, you can tweak it to fit your preferences or add new functionality.

**night was built for and tested on Cubase/Nuendo 12.** However, a lot of this stuff should work in older versions too. If you're feeling adventurous, know that the PLE user presets folder has changed, and some features might not work due to context menu changes/certain key commands or PLE features not being available.

</details>

- [Installation](#installation)
- [Usage](#usage)
  - [Window Management](#window-management)
  - [Scroll Zooming](#scroll-zooming)
  - [Scroll Locating](#scroll-locating)
  - [Automation](#automation)
  - [Lower Zone](#lower-zone)
  - [Context Menu Hotkeys](#context-menu-hotkeys)
    - [Track context menu](#track-context-menu)
    - [Insert slot context menu](#insert-slot-context-menu)
    - [Send slot context menu](#send-slot-context-menu)
    - [Inserts rack context menu](#inserts-rack-context-menu)
    - [Sends rack context menu](#sends-rack-context-menu)
    - [Editor context menu](#editor-context-menu)
  - [File Dialogs](#file-dialogs)
  - [Project Colors Patcher](#project-colors-patcher)
- [Development](#development)

## Installation

[Download](https://github.com/t5mat/night/releases/latest/download/night.zip) and run `night.exe`.

Since night adds macros to your key commands file, it is recommended that you first backup your current key commands configuration as a preset.

On first run, you'll need to provide some information about your Cubase/Nuendo installation -

- Cubase/Nuendo executable, probably `C:\Program Files\Steinberg\Cubase 12\Cubase12.exe`
- Cubase/Nuendo key commands file, probably `C:\Users\<user>\AppData\Roaming\Steinberg\Cubase 12_64\Key Commands.xml`
- Cubase/Nuendo PLE user presets folder, probably `C:\Users\<user>\Documents\Steinberg\Cubase\User Presets\Project Logical Editor`

This configuration and other settings will be stored in `<exe-name>.ini`.

After configuration, night will automatically install itself into Cubase/Nuendo (aka create some macros and PLE presets). You'd then be able to launch Cubase/Nuendo again from night's tray menu.

<details>
<summary>Notes</summary>

**Uninstalling** - You can uninstall night from the tray menu, or by removing all macros (might be faster editing `Key Commands.xml` directly) and PLE presets under "night". *This is what the tray uninstall does, so make sure to not save any macros or PLE presets under "night" as they will be deleted when night is uninstalled!*

**Multiple Cubase/Nuendo installations** - You can run multiple instances of night on different Cubase/Nuendo installations - simply copy and run `night.exe` from a different name (`night-nuendo.exe` for example), so that a different settings file will be used.

</details>

## Usage

### Window Management

- `Escape` is modified to close every window in Cubase (by default, it does not - MixConsole, Pool, Colorize...)
- `Escape` also quits Cubase if pressed when focused on the weird title bar thing
- The Colorize window will be focused and moved to the mouse cursor when activated using one of night's hotkeys. It does not get focused by default, so even with enabling `Escape` for it, you cannot open it and close it without focusing it first.

### Scroll Zooming

- `Alt+Scroll` = zoom in/out vertically
- `Ctrl+Alt+Scroll` = zoom in/out both horizontally and vertically
- *(MixConsole/lower zone MixConsole)* `Ctrl+Alt+Scroll` = zoom horizontally
- `Shift+Scroll` = zoom in/out selected tracks vertically
- `Ctrl+Shift+Alt+Scroll` = zoom in/out waveforms vertically

<details>
<summary>Notes</summary>

Unfortunately, `Ctrl+Alt+Scroll` will horizontally zoom to the cursor/locator, unlike `Ctrl+Scroll` which zooms to the mouse cursor - there is no key command for that.

</details>

### Scroll Locating

- `Ctrl+Shift+Scroll` = locate previous/next event/hitpoint/marker
- `Ctrl+Shift+Mouse3` = toggle locate mode (events/hitpoints/markers)

<details>
<summary>Notes</summary>

#### Auto-Scroll

These hotkeys toggle auto-scroll, locate, then toggle auto-scroll again, so that the cursor always stays in view after locating (depending on auto-scroll being off when these are used).

The ability to toggle between Page Scroll/Stationary Cursor in Cubase is worth noting here.

#### Tool Modifiers

`Ctrl+Shift` is the default modifier combination for `Preferences -> Editing -> Tool Modifiers -> Range Tool -> Select Full Vertical`. This is problematic because it also forces this selection to be not snapped, so I use these settings instead:

- `Range Tool -> Select Full Vertical` = `Alt+Shift`
- `Select Tool -> Set Position` = `Ctrl+Shift`
- `Select Tool -> Edit Velocity` = `Alt+Shift` (needed because you cannot use `Ctrl+Shift` for both `Set Position` and `Edit Velocity`)

With this, `Ctrl+Shift` is used for `Set Position`, so it makes sense to use the same modifiers for scroll locating.

Along with these:

- `Preferences -> Editing -> Select Track on Background Click`
- `Preferences -> Editing -> Track Selection Follows Event Selection`

you can hold `Ctrl+Shift+Click` anywhere in the view to locate, click an event/the background to select a track, then use `Ctrl+Shift+Scroll` to snap the cursor to the event/hitpoint you want to start playing from.

You can also use `Ctrl+a` and quickly scroll through every event/hitpoint in your project.

</details>

### Automation

If you press and hold `Space`, and then press `Mouse1`, write automation will be toggled for all selected tracks. When you release `Space`, write automation will be toggled again and the transport will stop.

This can be used to quickly show automation lanes for parameters (with "reveal on write" activated) - hold `Space`, move a knob, release `Space` and press `Ctrl+z` to undo the automation change. The automation lane will stay revealed. By default, unlike in Ableton or FL Studio for example, in Cubase there's not always a quick way to show an automation lane for the last tweaked parameter.

This hotkey can also be used to quickly record automation - move your cursor somewhere, hold `Space` and tweak your parameters as the transport is playing.

<sup>(it is assumed that you use `Space` for `Transport - StartStop`, which is the default)</sup>

### Lower Zone

These hotkeys provide a more ergonomic way to work with the lower zone.

- `Mouse4` = show lower zone editor (or editor window)
- `Mouse5` = show lower zone MixConsole
  - `Mouse5+Scroll` = move between pages (faders/inserts/sends)

<details>
<summary>Notes</summary>

I mostly use the lower zone MixConsole - you can do multi-channel insert/send management (compared to the Inspector/Channel Settings) without having to use a separate window (MixConsole/Channel Settings).

However, by default, there are a few limitations to working with the lower zone MixConsole:

- There is no key command to show it, only toggle
- Moving between pages (faders/inserts/sends) requires either moving the mouse to the small page icons or a key command (default Page Up/Down)

</details>

### Context Menu Hotkeys

These hotkeys work when certain context menus (right-click) are open.

<details>
<summary>Notes</summary>

Using key commands is much faster than for example moving the mouse to the arrow that toggles automation lanes, or selecting the a menu item. However, having too many key commands can lead to a complicated and hard-to-remember setup.

These context-based keyboard shortcuts provide a nice benefit compared to global ones: you can use 1 hotkey for multiple actions based on what you right-clicked - track/midi note/audio part... You have the whole keyboard free so hotkeys can match their actions (e = enable, c = colorize, g = glue), which makes them easier to remember. Also, you can have most hotkeys on the left side of the keyboard which makes them more ergonomic to use.

They enable assigning keys to actions that are not available as key commands, and can also utilize information provided by the context menu items that cannot be accessed in macros/PLE (for example, whether automation lanes are shown for any of the selected tracks - this is required for implementing toggle).

With all that, using these is almost as fast as triggering regular key commands.

</details>

#### Track context menu

Keep in mind that right-clicking a track in the MixConsole/lower zone MixConsole does not select it.

- `w` = show/hide editor (VST/sampler)
- `d/Delete/Backspace` = delete selected tracks
- `Ctrl+a` = select all tracks
- `Ctrl+d` = duplicate selected tracks
- `e` = toggle selected tracks enabled
- `h` = hide selected tracks
- `c` = colorize selected tracks
- `i` = toggle selected tracks edit in-place
- `f` = move selected tracks to a new folder
- `s` = send selected channels to a new FX channel
- `g` = send selected channels to a new group channel
- `v` = send selected channels to a new VCA fader
- `Ctrl+o` = load track preset
- `Ctrl+s` = save as track preset
- `Ctrl+Shift+s` = save as track archive
- *(track list)* `a` = select all data on track
- *(track list)* `r` = clear selected tracks (deletes all events/parts, automation, versions)
- *(track list, folder tracks)* `Space` = collapse/expand first selected folder track
- *(track list, folder tracks)* `Ctrl+Space` = expand all folder tracks
- *(track list, folder tracks)* `Shift+Space` = collapse all folder tracks
- *(track list, non folder tracks)* `Space` = show used automation/hide automation for all selected tracks
- *(track list, non folder tracks)* `Ctrl+Space` = show all used automation
- *(track list, non folder tracks)* `Shift+Space` = hide all automation

#### Insert slot context menu

Some of these don't work in the Inspector.

- `Space` = open/focus plugin window (will not close if was already open) *does not work if mouse is under the bypass/arrow buttons*
- `Shift+Space` = close plugin window *does not work if mouse is under the bypass/arrow buttons*
- `d/Delete/Backspace` = delete insert
- `Tab` = replace insert
- `e` = toggle insert bypass
- `Shift+e` = toggle insert activated
- `f` = set as last pre-fader slot
- `s` = toggle sidechaining activated
- `q` = switch between A/B settings
- `Shift+q` = apply current settings to A and B

#### Send slot context menu

Some of these don't work in the Inspector.

- `d/Delete/Backspace` = clear send
- `Tab` = replace send
- `Ctrl+c` = copy send
- `Ctrl+v` = paste send
- `e` = toggle send activated
- `f` = move send to pre/post fader
- `r` = use default send level
- `q` = set send level to -oo

#### Inserts rack context menu

- `Space` = open/focus all plugin windows
- `Shift+Space` = close all plugin windows
- `e` = toggle inserts bypass
- `Ctrl+o` = load FX chain preset
- `Ctrl+s` = save as FX chain preset

#### Sends rack context menu

- `e` = toggle sends bypass

#### Editor context menu

These pair well with disabling `Preferences -> Editing -> Tools -> Show Toolbox on Right-Click`.

- *(editor background)* `z` = zoom to view horizontally
- *(events/parts)* `z` = zoom to selection horizontally
- *(events/parts)* `Space` = locate selection start
- *(events/parts)* `Shift+Space` = move left/right locators to selection
- *(events/parts)* `Ctrl+Space` = move selection to cursor
- *(events/parts)* `d/Delete/Backspace` = delete selection
- *(events/parts)* `c` = colorize selection
- *(events/parts)* `e` = toggle selection muted
- *(events/parts)* `Ctrl+d` = repeat selection
- *(events/parts)* `g` = glue selection
- *(events/parts)* `Shift+g` = dissolve selected audio/MIDI parts
- *(events/parts)* `Shift+s` = convert shared to real copies
- *(events/parts)* `r/Ctrl+r` = render in place/render in place (settings)
- *(range tool)* `x` = split selection range
- *(range tool)* `Shift+x` = crop selection range
- *(audio events/parts)* `b` = bounce selection
- *(audio events)* `p` = show selection in pool
- *(MIDI events/parts)* `f` = open functions menu
- *(MIDI events/parts)* `q` = quantize event starts
- *(MIDI events/parts)* `Ctrl+q` = quantize event ends
- *(MIDI events/parts)* `Ctrl+Shift+q` = quantize event lengths
- *(MIDI events/parts)* `Shift+q` = reset quantize
- *(MIDI events/parts)* `v` = legato
- *(MIDI parts)* `Ctrl+s` = export first selected part as MIDI loop (includes track settings)
- *(key editor)* `w` = open/close note expression editor

### File Dialogs

Pressing `F1-F12` in a file dialog inside Cubase will navigate to bookmarked folders.

To set your bookmarked folders, open `night.ini` and add a `[FileDialogPaths]` section. For the following example:

```ini
[FileDialogPaths]
F1 = C:\Users\<user>\Documents\Cubase Projects
F2 = C:\Users\<user>\Documents\Steinberg
F3 = C:\Users\<user>\AppData\Roaming\Steinberg
```

pressing `F1` will navigate to `C:\Users\<user>\Documents\Cubase Projects`, and so on.

<details>
<summary>Notes</summary>

This can be used to quickly navigate to your projects folder in the Open Project dialog, or to your PLE presets folder when saving PLE presets.

Also, track archives, for example, are useful sometimes compared to track presets because they can store whole folder tracks and correct routing information between tracks. However, unlike track presets, track archives are not indexed in the MediaBay - when you import a track archive you get the Windows "Choose a file" dialog. And so, a quick way to navigate to where you store your track archives might be beneficial.

</details>

### Project Colors Patcher

This tool replaces your project's colors to colors provided by a file.

You can use it with one of the included 32-color files generated from [matplotlib colormaps](https://matplotlib.org/stable/tutorials/colors/colormaps.html), or create/generate your own colors files and apply them to your projects without having to manually setup each one in `Project -> Project Colors Setup`.

<details>
<summary>Usage</summary>

Open your project.

Go to `Project -> Project Colors Setup -> Presets` and use `Number of Basic Colors` and `Number of Color Tints` to set the amount of colors you want for your project (click Apply). **Patching works only for projects with colors named "Color 1", "Color 2"...**, so if any of your colors have been renamed, clicking Apply in the Presets tab will also reset their names to default.

Save, close, **AND BACKUP** your project file.

Launch the Project Colors Patcher from the tray menu. Choose your project file and then a colors file. The tool will replace the colors in your project with colors from the colors file (patching a 32-color project with a 64-color file will only use up to 32 colors from the colors file, etc).

When you open your project again, you should now see the new colors.

</details>

## Development

Download [AutoHotkey 1.1](https://www.autohotkey.com/download/).

You can run `night.ahk` directly, or use `rebuild.cmd` to build an `.exe`.

In case [Python](https://www.python.org/) & [matplotlib](https://matplotlib.org/) are installed, `rebuild.cmd` will also run `generate-colors.py` to generate the colors files.

You can reload night by re-running it (`night.ahk`/`night.exe`), or from the tray menu (`night.ahk`).

All the macros and PLE presets installed/used by night are defined in `night.xml`. If `night.xml` is changed, night no longer considers itself as installed, and will require reinstallation.

`night.xml` is bundled into `.exe` builds.

For each macro in `night.xml` that is assigned to `auto`, night will generate a random unicode character and assign it to that macro in Cubase. These assignments are then accessible to night itself as a way to trigger macros inside Cubase.
