<h1 align="center"><img src="https://user-images.githubusercontent.com/16616463/176883524-74d04926-6f9a-4a40-86ff-681956acc56f.png" width="24" height="23"> night</h1>

<p align="center">
<img src="https://user-images.githubusercontent.com/16616463/174643141-d9a3db07-3d80-4883-9e69-0783432ef096.gif">
</p>

**night** is a program (written in AutoHotkey) that enhances Cubase/Nuendo with new hotkeys & functionality.

It overrides almost none of the assignable keyboard shortcut in Cubase/Nuendo; the goal is to provide stuff you cannot configure in Cubase/Nuendo out-of-the-box.

I made this to address some of the workflow limitations I've encountered as I was learning Cubase. I've actually come to rely on night much more than I expected, so I decided to take a bit of time to package and share it.

**night was built for and tested on Cubase/Nuendo 12**, although most features should work in earlier versions too.

With basic AutoHotkey knowledge, you can tweak existing hotkeys or add new ones relatively easily - see the [Development](#development) section for more info.

</details>

- [Installation](#installation)
- [Usage](#usage)
  - [Window Management](#window-management)
  - [Scroll Zooming](#scroll-zooming)
  - [Scroll Locating](#scroll-locating)
  - [Automation](#automation)
  - [Lower Zone](#lower-zone)
  - [Context Menus](#context-menus)
  - [File Dialogs](#file-dialogs)
  - [Project Colors Patcher](#project-colors-patcher)
- [Development](#development)

## Installation

[Download](https://github.com/t5mat/night/releases/latest/download/night.zip) and run `night.exe`.

Since night adds macros to your key commands file, it is recommended that you first backup your current key commands configuration as a preset.

On first run, you'll need to provide some information about your Cubase/Nuendo installation -

- **Cubase/Nuendo executable**
  - `C:\Program Files\Steinberg\Cubase 12\Cubase12.exe` (Cubase 12)
  - `C:\Program Files\Steinberg\Cubase 11\Cubase11.exe` (Cubase 11)
- **Cubase/Nuendo key commands file**
  - `C:\Users\<user>\AppData\Roaming\Steinberg\Cubase 12_64\Key Commands.xml` (Cubase 12)
  - `C:\Users\<user>\AppData\Roaming\Steinberg\Cubase 11_64\Key Commands.xml` (Cubase 11)
- **Cubase/Nuendo PLE user presets folder**
  - `C:\Users\<user>\Documents\Steinberg\Cubase\User Presets\Project Logical Editor` (Cubase 12)
  - `C:\Users\<user>\AppData\Roaming\Steinberg\Cubase 11_64\Presets\Project Logical Editor` (Cubase 11)

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
- Fix the weird title bar thing getting focus instead of the Project window after some windows are closed (MixConsole...)
- The Colorize window is focused and moved to the mouse cursor when opened (by default, you can't `Escape` immediately after opening it without focusing it by mouse clicking first)
- The Colorize window is hidden when it loses focus

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

This can be used to quickly show automation lanes for parameters (with "reveal on write" activated) - hold `Space`, move a knob, release `Space` and press `Ctrl+z` to undo the automation change. The automation lane will stay revealed. By default, unlike in Ableton or FL Studio for example, in Cubase there isn't always a quick way to show an automation lane for the last tweaked parameter.

This hotkey can also be used to quickly record automation - move your cursor somewhere, hold `Space` and tweak your parameters as the transport is playing.

<p>
<sup>(it is assumed that you use <code>Space</code> for <code>Transport - StartStop</code>, which is the default)</sup>
</p>

### Lower Zone

These hotkeys provide a more ergonomic way to work with the lower zone.

- `Mouse4` = show lower zone editor (or editor window)
- `Mouse5` = show lower zone MixConsole
  - `Mouse5+Scroll` = move between pages (faders/inserts/sends)
  - `Mouse5+1` = show faders page
  - `Mouse5+2` = show inserts page
  - `Mouse5+3` = show sends page

<details>
<summary>Notes</summary>

I mostly use the lower zone MixConsole - you can do multi-channel insert/send management (compared to the Inspector/Channel Settings) without having to use a separate window (MixConsole/Channel Settings).

However, by default, there are a few limitations to working with the lower zone MixConsole:

- There is no key command to show it, only toggle
- Moving between pages (faders/inserts/sends) is not very ergonomic - it requires either moving the mouse to the small page icons or pressing `PageUp`/`PageDown`

</details>

### Context Menus

New hotkeys are available when certain context menus are open (track, insert/send slot/rack, editor).

Info about available hotkeys will be shown when relevant context menus are open.

<p>
<sup>
(the editor hotkeys go well with disabling <code>Preferences -> Editing -> Tools -> Show Toolbox on Right-Click</code>)
<br>
(some hotkeys don't work when used in the Inspector)
</sup>
</p>

<details>
<summary>Notes</summary>

Using key commands is much faster than for example moving the mouse to the arrow that toggles automation lanes, or selecting the a menu item. However, having too many key commands can lead to a complicated and hard-to-remember setup.

These context-based hotkeys provide a nice benefit compared to global ones: you can use 1 hotkey for multiple actions based on what you right-clicked - track/midi note/audio part... You have the whole keyboard free so hotkeys can match their actions (e = enable, c = colorize, g = glue), which makes them easier to remember. Also, you can have most hotkeys on the left side of the keyboard which makes them more ergonomic to use.

They enable assigning keys to actions that are not available as key commands, and can also utilize information provided by the context menu items that cannot be accessed in macros/PLE (for example, whether automation lanes are shown for any of the selected tracks - this is required for implementing toggle).

With all that, using these is almost as fast as triggering regular key commands.

</details>

### File Dialogs

In file dialogs, you can quickly navigate to your favorite folders using `F1-12`.

To save the current folder as a favorite, use `Shift+F1-12`.

<details>
<summary>Notes</summary>

This can be used to quickly navigate to your projects folder in the Open Project dialog, or to your PLE presets folder when saving PLE presets.

Also, track archives, for example, are useful sometimes compared to track presets because they can store whole folder tracks and correct routing information between tracks. However, unlike track presets, track archives are not indexed in the MediaBay - when you import a track archive you get the Windows "Choose a file" dialog. And so a quick way to navigate to where you store your track archives might be beneficial.

</details>

### Project Colors Patcher

This tool replaces your project's colors to colors provided by a file.

You can use it with one of the included 32-color files (generated from [matplotlib colormaps](https://matplotlib.org/stable/tutorials/colors/colormaps.html)), or create/generate your own colors files and apply them to your projects without having to manually setup each one in `Project -> Project Colors Setup`.

<details>
<summary>Usage</summary>

1. Open your project.

2. Go to `Project -> Project Colors Setup -> Presets` and use `Number of Basic Colors` and `Number of Color Tints` to set the amount of colors you want for your project (click Apply). **Patching works only for projects with colors named "Color 1", "Color 2"...**, so if any of your colors have been renamed, clicking Apply in the Presets tab will also reset their names to default.

3. Save, close, **AND BACKUP** your project file.

4. Launch the Project Colors Patcher from the tray menu. Choose your project file and then a colors file. The tool will replace the colors in your project with colors from the colors file (patching a 32-color project with a 64-color file will only use up to 32 colors from the colors file, etc).

5. Open your project again to see the new colors.

</details>

## Development

Download [AutoHotkey 1.1](https://www.autohotkey.com/download/).

You can run `night.ahk` directly, or use `rebuild.cmd` to build an `.exe`.

In case [Python](https://www.python.org/) & [matplotlib](https://matplotlib.org/) are installed, `rebuild.cmd` will also run `generate-colors.py` to generate the colors files.

You can reload night by re-running it (`night.ahk`/`night.exe`), or from the tray menu (`night.ahk`).

All the macros and PLE presets installed/used by night are defined in `night.xml`. If `night.xml` is changed, night no longer considers itself as installed, and will require reinstallation.

`night.xml` is bundled into `.exe` builds.

For each macro in `night.xml` that is assigned to `auto`, night will generate a random unicode character and assign it to that macro in Cubase. These assignments are then accessible to night itself as a way to trigger macros inside Cubase.

The last sections of code in `night.ahk` are the most relevant for adding/modifying hotkeys (code is ordered from most library code to most app-specific code). Looking at the diff of a commit that adds a new hotkey can also help.
