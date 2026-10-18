-- Window look saved by Isla Settings → Windows (scripts/lookctl.py): opacity, borders, corner radius, gaps.
-- One "key=value" per line in ~/.local/state/hypr/look. Missing file = the values in decorations.lua stay.
local f = io.open(os.getenv("HOME") .. "/.local/state/hypr/look")
if not f then return end
local v = {}
for line in f:lines() do
    local k, val = line:match("^(%w[%w_]*)=(%S+)$")
    if k then v[k] = val end
end
f:close()

local function hex(s, d) return (s and s:match("^%x%x%x%x%x%x$")) and ("rgba(" .. s .. "ff)") or d end
hl.config({
    decoration = {
        active_opacity   = tonumber(v.active_opacity) or 0.95,
        inactive_opacity = tonumber(v.inactive_opacity) or 0.90,
        rounding         = tonumber(v.rounding) or 10,
    },
    general = {
        border_size = tonumber(v.border_size) or 2,
        gaps_in     = tonumber(v.gaps_in) or 3,
        gaps_out    = tonumber(v.gaps_out) or 8,
        col = {
            active_border   = { colors = { hex(v.active1, CACHYLGREEN), hex(v.active2, CACHYDGREEN) }, angle = 45 },
            inactive_border = hex(v.inactive, CACHYGRAY),
        },
    },
})
