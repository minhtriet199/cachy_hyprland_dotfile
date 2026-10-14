-- Workspace rules wiki https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Add your workspace rules here. Increment the workspace number as you go. Do not have duplicate workspaces.
-- Separate workspaces per monitor (see ~/.config/hypr/scripts/ws.sh)
--   ASUS (HDMI-A-1): 1-9
--   Laptop (eDP-1/eDP-2): 11-19, labelled 1-9
for i = 1, 9 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-1", default = (i == 1) })
    hl.workspace_rule({ workspace = tostring(10 + i), monitor = "desc:Thermotrex Corporation TL140ADXP01", default = (i == 1), default_name = tostring(i) })
end
-- hl.workspace_rule({ workspace = "4", monitor = MONITOR2, default = true, persistent = true })
-- hl.workspace_rule({ workspace = "5", monitor = MONITOR2, default = true, persistent = true })
-- hl.workspace_rule({ workspace = "6", monitor = MONITOR2, default = true, persistent = true })

-- For other layouts such as scrolling, see example below
-- hl.workspace_rule({ workspace = "1", monitor = MONITOR1, default = true, persistent = true, layout = "scrolling" })
