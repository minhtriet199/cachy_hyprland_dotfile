-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Example: output can be found with hyprctl monitors. Edit variables.lua for the monitor outputs instead of here directly
-- hl.monitor({
--     output    = MONITOR1,
--     mode      = "1920x1080@60",
--     position  = "0x0",
--     scale     = "1",
-- })

-- Per-screen settings written by scripts/screenctl.py (Screen Settings app, Super+Ctrl+H,
-- Super+Alt+Up/Down). One line per screen, keyed by its description:
--   "<description>\tmode=2560x1440@120 pos=0x0 scale=1 hdr=1 nits=250 ..."
local screens = {}
local f = io.open(os.getenv("HOME") .. "/.local/state/hypr/screens")
if f then
    for line in f:lines() do
        local desc, rest = line:match("^([^\t]+)\t(.*)$")
        if desc then
            local s = {}
            for k, v in rest:gmatch("(%w+)=(%S+)") do s[k] = v end
            screens[desc] = s
        end
    end
    f:close()
end

-- Defaults when Screen Settings hasn't saved anything for these screens yet
local defaults = {
    -- ASUS VG27AQ5A (HDMI) on the left, capped at 120 Hz
    ["ASUSTek COMPUTER INC VG27AQ5A TBLMQS017743"] = { mode = "2560x1440@120", pos = "0x0", scale = "1" },
    -- Laptop panel on the right, 125% zoom (like Windows). It is eDP-2 in Hybrid GPU mode, eDP-1 in Ultimate
    ["Thermotrex Corporation TL140ADXP01"]         = { mode = "2560x1600@120", pos = "2560x0", scale = "1.25" },
}

local function screenSpec(desc, s, d)
    d = d or {}
    local spec = {
        output   = "desc:" .. desc,
        mode     = s.mode  or d.mode  or "preferred",
        position = s.pos   or d.pos   or "auto",
        scale    = s.scale or d.scale or "auto",
    }
    if s.transform and s.transform ~= "0" then spec.transform = tonumber(s.transform) end
    if s.mirror and s.mirror ~= "" then spec.mirror = s.mirror end
    if s.off == "1" then spec.disabled = true end
    -- HDR10. Monitors lock their own brightness in HDR, so desktop brightness is sdr_max_luminance instead.
    if s.hdr == "1" then
        spec.bitdepth          = 10
        spec.cm                = "hdr"
        spec.sdr_max_luminance = tonumber(s.nits) or 200
    end
    return spec
end

for desc, s in pairs(screens) do
    hl.monitor(screenSpec(desc, s, defaults[desc]))
end
for desc, d in pairs(defaults) do
    if not screens[desc] then hl.monitor(screenSpec(desc, {}, d)) end
end

-- Fallback for any other monitor
hl.monitor({
    output    = MONITOR1,
    mode      = "preferred",
    position  = "auto",
    scale     = "auto",
})
