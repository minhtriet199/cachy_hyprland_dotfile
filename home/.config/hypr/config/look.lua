-- Window look saved by Island Settings → Windows (scripts/lookctl.py): opacity, backdrop tint, borders, corner radius, gaps.
-- One "key=value" per line in ~/.local/state/hypr/look. Missing file = the values in decorations.lua stay.
local f = io.open(os.getenv("HOME") .. "/.local/state/hypr/look")
if not f then return end
local v = {}
for line in f:lines() do
    local k, val = line:match("^(%w[%w_]*)=(%S+)$")
    if k then v[k] = val end
end
f:close()

local function int(s, d) local n = tonumber(s); return n and math.floor(n + 0.5) or d end
-- backdrop: dark = dimmed blur behind see-through windows, light = frosted (same numbers as lookctl.py)
local tint = ({ dark = { 0.5, 0.9 }, light = { 1.05, 0.8 } })[v.backdrop or "dark"] or { 0.5, 0.9 }
local function hex(s, d) return (s and s:match("^%x%x%x%x%x%x$")) and ("rgba(" .. s .. "ff)") or d end
hl.config({
    decoration = {
        active_opacity   = tonumber(v.active_opacity) or 0.95,
        inactive_opacity = tonumber(v.inactive_opacity) or 0.90,
        rounding         = int(v.rounding, 10),
        blur             = { brightness = tint[1], contrast = tint[2] },
    },
    general = {
        border_size = int(v.border_size, 2),
        gaps_in     = int(v.gaps_in, 3),
        gaps_out    = int(v.gaps_out, 8),
        col = {
            active_border   = { colors = { hex(v.active1, CACHYLGREEN), hex(v.active2, CACHYDGREEN) }, angle = 45 },
            inactive_border = hex(v.inactive, CACHYGRAY),
        },
    },
})
