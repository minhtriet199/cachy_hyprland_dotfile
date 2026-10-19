-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("~/.config/hypr/scripts/boot-lock-guard.sh")   -- auto-login safety: hyprlock if Isla failed to start
    hl.exec_cmd("env MALLOC_ARENA_MAX=2 qs -c isla")   -- Isla shell; fewer malloc pools = ~25% less RAM (many render threads each kept their own)
    hl.exec_cmd("fcitx5 -d --replace")
    hl.exec_cmd("wl-paste --watch ~/.config/quickshell/isla/tools/clip-store.sh")   -- clipboard history (+ copy times for the phone)
    hl.exec_cmd("xhost +SI:localuser:root")
    hl.exec_cmd("sleep 3; ~/.config/hypr/scripts/mic-level.sh")   -- laptop mic back to clean level (see script)
end)
