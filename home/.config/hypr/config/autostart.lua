-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("noctalia")
    hl.exec_cmd("fcitx5 -d --replace")
    hl.exec_cmd("wl-paste --watch cliphist store")   -- clipboard history for Super+V when Noctalia is off
    hl.exec_cmd("xhost +SI:localuser:root")
end)
