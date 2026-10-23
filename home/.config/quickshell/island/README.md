# Island Shell — Part 1

A cozy Animal Crossing style desktop for Hyprland, made with Quickshell.
It runs **next to end-4**. end-4 is not changed or removed.

## What is in Part 1

- Top bar, dock, big sticker clock, notification bubbles, wallpaper
- The Pixel phone: Home, Search, Quick panel, Islands (workspaces)
- Settings (landscape phone): Settings menu, Quick settings, Wallpapers
- Sized for your 2K ASUS screen. The laptop screen scales by itself.

Coming in Part 2: Calculator, web search, clipboard, power menu, bar dropdowns,
Edit Desktop, lock screen, extra widgets, side bar (left/right).

## Folder

`~/.config/quickshell/island/` — start it with `qs -c island`

## Change things

Open `Services.qml`. At the top there is a block called **YOUR SETTINGS**:
city for weather, 24-hour clock, main monitor, dock apps, phone apps, actions.

Phone settings (dock on/off, bar style, shell size, wallpaper) are saved in
`~/.local/state/island/prefs.json`.

Wallpapers: Island uses the picture end-4 was using. The picker shows the pictures
in the same folder (or `~/Pictures/Wallpapers`).

## Keys (add them later, after you test)

Hyprland Lua lines:

```lua
hl.bind("SUPER + space", hl.dsp.global("quickshell:islandPhone"))
hl.bind("SUPER + Tab",   hl.dsp.global("quickshell:islandIslands"))
hl.bind("SUPER + I",     hl.dsp.global("quickshell:islandSettings"))
```

Other names: `islandSearch`, `islandQuick`, `islandWallpapers`.

From a terminal: `qs -c island ipc call island phone home` (home · search · quick · islands · settings · wallpapers)

## Fonts

Fredoka, Nunito and Titan One (SIL Open Font License) are inside `fonts/`.
Island loads them by itself. You do not need to install them.
