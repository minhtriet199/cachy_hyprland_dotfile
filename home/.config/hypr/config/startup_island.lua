-- Startup apps added in Island Settings → Apps (tools/apps.py). One "on|name|command" per line in
-- ~/.local/state/hypr/startup; only lines starting with 1 are started, once, when Hyprland starts.
-- Auto-login: held until the first unlock instead (scripts/after-unlock.sh starts them), so nothing opens behind the lock.
hl.on("hyprland.start", function ()
    local m = io.open((os.getenv("XDG_RUNTIME_DIR") or "") .. "/isla-autologin")
    if m then m:close(); return end
    local f = io.open(os.getenv("HOME") .. "/.local/state/hypr/startup")
    if not f then return end
    for line in f:lines() do
        local on, cmd = line:match("^([01])|[^|]*|(.+)$")
        if on == "1" and cmd then hl.exec_cmd(cmd) end
    end
    f:close()
end)
