#!/usr/bin/env python3
# Make Windows Godot games in every Steam library start on Vulkan instead of DirectX 12
# (D3D12 under Proton gives a black screen, e.g. Slay the Spire 2).
# Godot reads override.cfg next to the game's .exe at startup, so dropping one there does the
# same as the launch option "--rendering-driver vulkan", for every Godot game, with no Steam edits.
# Run by the godot-vulkan-fix.path/.service user units whenever a Steam library changes.
#   godot-vulkan-fix.py           fix all games, print what changed
#   godot-vulkan-fix.py --undo    remove the files this script added
import glob, os, re, sys

MARK = "; added by ~/.config/hypr/scripts/godot-vulkan-fix.py"
OVERRIDE = f"""{MARK}
[rendering]
rendering_device/driver="vulkan"
rendering_device/driver.windows="vulkan"
"""


def libraries():
    steam = os.path.expanduser("~/.local/share/Steam")
    roots = {steam}
    try:
        vdf = open(os.path.join(steam, "steamapps", "libraryfolders.vdf")).read()
        roots |= set(re.findall(r'"path"\s+"([^"]+)"', vdf))
    except OSError:
        pass
    return [os.path.join(r, "steamapps", "common") for r in roots if os.path.isdir(os.path.join(r, "steamapps", "common"))]


def godot_dirs(game):
    """Folders inside a game that hold a Windows Godot build: Foo.exe next to Foo.pck."""
    for pck in glob.glob(os.path.join(glob.escape(game), "**", "*.pck"), recursive=True):
        base = pck[:-4]
        if os.path.exists(base + ".exe"):
            yield os.path.dirname(pck)


def main():
    undo = "--undo" in sys.argv
    for common in libraries():
        for game in sorted(glob.glob(os.path.join(glob.escape(common), "*"))):
            for d in godot_dirs(game):
                cfg = os.path.join(d, "override.cfg")
                ours = os.path.exists(cfg) and open(cfg, errors="replace").read().startswith(MARK)
                if undo:
                    if ours:
                        os.remove(cfg)
                        print("removed", cfg)
                elif not os.path.exists(cfg):  # never touch an override.cfg the game ships itself
                    with open(cfg, "w") as f:
                        f.write(OVERRIDE)
                    print("fixed", os.path.basename(game))


if __name__ == "__main__":
    main()
