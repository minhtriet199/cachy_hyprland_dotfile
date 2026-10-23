-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

-- Auto-login (greetd initial_session → island-session autologin): Island starts locked and no shortcut works until the
-- first unlock (scripts/after-unlock.sh leaves this submap), so nothing can be opened in the moment before the lock.
hl.define_submap("bootlock", function()
    hl.bind("SUPER + CONTROL + ALT + F12", hl.dsp.exec_cmd("true"))   -- does nothing: a submap with no binds isn't registered
end)

hl.on("hyprland.start", function ()
    local m = io.open((os.getenv("XDG_RUNTIME_DIR") or "") .. "/isla-autologin")
    if m then m:close(); hl.dispatch(hl.dsp.submap("bootlock")) end
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("~/.config/hypr/scripts/boot-lock-guard.sh")   -- auto-login safety: hyprlock if Island failed to start
    hl.exec_cmd("env MALLOC_ARENA_MAX=2 qs -c island")   -- Island shell; fewer malloc pools = ~25% less RAM (many render threads each kept their own)
    hl.exec_cmd("fcitx5 -d --replace")
    hl.exec_cmd("wl-paste --watch ~/.config/quickshell/island/tools/clip-store.sh")   -- clipboard history (+ copy times for the phone)
    hl.exec_cmd("xhost +SI:localuser:root")
    hl.exec_cmd("sleep 3; ~/.config/hypr/scripts/mic-level.sh")   -- laptop mic back to clean level (see script)
end)
