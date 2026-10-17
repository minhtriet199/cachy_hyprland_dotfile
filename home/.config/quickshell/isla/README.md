# Isla Shell — Part 1

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

`~/.config/quickshell/isla/` — start it with `qs -c isla`

## Change things

Open `Services.qml`. At the top there is a block called **YOUR SETTINGS**:
city for weather, 24-hour clock, main monitor, dock apps, phone apps, actions.

Phone settings (dock on/off, bar style, shell size, wallpaper) are saved in
`~/.local/state/isla/prefs.json`.

Wallpapers: Isla uses the picture end-4 was using. The picker shows the pictures
in the same folder (or `~/Pictures/Wallpapers`).

## Keys (add them later, after you test)

Hyprland Lua lines:

```lua
hl.bind("SUPER + space", hl.dsp.global("quickshell:islaPhone"))
hl.bind("SUPER + Tab",   hl.dsp.global("quickshell:islaIslands"))
hl.bind("SUPER + I",     hl.dsp.global("quickshell:islaSettings"))
```

Other names: `islaSearch`, `islaQuick`, `islaWallpapers`.

From a terminal: `qs -c isla ipc call isla phone home` (home · search · quick · islands · settings · wallpapers)

## Fonts

Fredoka, Nunito and Titan One (SIL Open Font License) are inside `fonts/`.
Isla loads them by itself. You do not need to install them.
