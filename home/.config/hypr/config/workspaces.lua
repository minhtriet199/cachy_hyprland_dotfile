-- Workspace rules wiki https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Add your workspace rules here. Increment the workspace number as you go. Do not have duplicate workspaces.
-- Separate workspaces per monitor (see ~/.config/hypr/scripts/ws.sh)
--   External screen (any port: HDMI, DisplayPort, USB-C): 1-9
--   Laptop (eDP-1/eDP-2): 11-19, labelled 1-9
for i = 1, 9 do
    hl.workspace_rule({ workspace = tostring(10 + i), monitor = "desc:Thermotrex Corporation TL140ADXP01", default = (i == 1), default_name = tostring(i) })
end
-- 1-9 follow whichever external screen is plugged in (the first one if several). Re-done when screens come and go;
-- the old rules are switched off first so they don't pile up.
local extRules, extName = {}, nil
local function pinExternal()
    local ext = nil
    for _, m in ipairs(hl.get_monitors() or {}) do
        if not m.name:match("^eDP") then ext = m.name; break end
    end
    if ext == extName then return end
    for _, r in ipairs(extRules) do r:set_enabled(false) end
    extRules, extName = {}, ext
    if not ext then return end
    for i = 1, 9 do
        extRules[i] = hl.workspace_rule({ workspace = tostring(i), monitor = ext, default = (i == 1) })
    end
end
pcall(pinExternal)   -- (at the very first start there may be no screens yet: hyprland.start does it then)
for _, e in ipairs({ "hyprland.start", "monitor.added", "monitor.removed" }) do
    hl.on(e, function() pcall(pinExternal) end)
end
-- hl.workspace_rule({ workspace = "4", monitor = MONITOR2, default = true, persistent = true })
-- hl.workspace_rule({ workspace = "5", monitor = MONITOR2, default = true, persistent = true })
-- hl.workspace_rule({ workspace = "6", monitor = MONITOR2, default = true, persistent = true })

-- For other layouts such as scrolling, see example below
-- hl.workspace_rule({ workspace = "1", monitor = MONITOR1, default = true, persistent = true, layout = "scrolling" })
