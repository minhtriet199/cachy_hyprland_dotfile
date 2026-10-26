-- Nested Hyprland test window (class aquamarine, used for testing Island): with 2+ screens it opens on a screen
-- you're NOT on and focus goes straight back to you, so a test never covers what you're doing. One screen: yours.
-- (size / float / opaque come from windowrules.lua)

hl.on("window.open", function(w)
    pcall(function()
        if not w or w.class ~= "aquamarine" then return end
        local here = hl.get_active_monitor()
        if not here then return end
        local other = nil
        for _, m in ipairs(hl.get_monitors() or {}) do
            if m.name ~= here.name and m.active_workspace then other = m; break end
        end
        if not other then return end
        local you = hl.get_active_window()         -- still your window: Hyprland focuses the new one after this
        hl.dispatch(hl.dsp.window.move({ workspace = other.active_workspace.id, window = w, follow = false }))
        local addr, mon = you and you.address, here.name
        hl.timer(function()
            pcall(function()
                if addr then hl.dispatch(hl.dsp.focus({ window = "address:" .. addr }))
                else hl.dispatch(hl.dsp.focus({ monitor = mon })) end
            end)
        end, { timeout = 250, type = "oneshot" })
    end)
end)
