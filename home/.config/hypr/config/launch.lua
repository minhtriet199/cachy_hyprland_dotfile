-- Apps started from Isla search open on the screen you launched them from, even if you move focus
-- to the other screen while they load. Isla calls IslaLaunch("<monitor>") just before starting the app;
-- the next new window (within 10 s) goes to that screen's current workspace.
--   * Games (steam_app_*, gamescope) are left to games.lua.
--   * One launch = one window, so later windows open normally.

local pending = nil -- { mon = name, t = os.time() }

function IslaLaunch(mon)
    pending = { mon = mon, t = os.time() }
end

hl.on("window.open", function(w)
    pcall(function()
        if not pending or not w then return end
        local c = w.class or ""
        if c:match("^steam_app_%d+") or c == "gamescope" then return end
        local p = pending
        pending = nil
        if os.time() - p.t > 10 then return end
        local m = hl.get_monitor(p.mon)
        local ws = m and m.active_workspace
        if not ws or (w.monitor and w.monitor.name == p.mon) then return end
        hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = w, follow = false }))
    end)
end)
