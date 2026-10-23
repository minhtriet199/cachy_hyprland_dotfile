-- Mouse / touchpad / keyboard layout / cursor size saved by Island Settings (scripts/inputctl.py).
-- One "key=value" per line in ~/.local/state/hypr/input. Missing file = inputs.lua stays as it is.
local f = io.open(os.getenv("HOME") .. "/.local/state/hypr/input")
if not f then return end
local v = {}
for line in f:lines() do
    local k, val = line:match("^(%w[%w_]*)=(.*)$")
    if k then v[k] = val end
end
f:close()

local function on(k, d) if v[k] == nil then return d end return v[k] == "1" end
hl.config({
    input = {
        kb_layout     = v.kb_layout ~= "" and v.kb_layout or "us",
        kb_options    = v.kb_options or "",
        sensitivity   = tonumber(v.sensitivity) or 0,
        accel_profile = v.accel == "adaptive" and "adaptive" or "flat",
        touchpad = {
            natural_scroll       = on("natural_scroll", false),
            tap_to_click         = on("tap_to_click", true),
            disable_while_typing = on("dwt", true),
            scroll_factor        = tonumber(v.tp_scroll) or 1,
        },
    },
})

local size = tonumber(v.cursor_size)
if size then
    size = math.floor(size + 0.5)
    hl.env("XCURSOR_SIZE", tostring(size))
    hl.env("HYPRCURSOR_SIZE", tostring(size))
end
