-- Window look saved by Island Settings → Windows (scripts/lookctl.py): opacity, backdrop, borders, corners, gaps, blur,
-- shadow, dim, animations. lookctl writes the exact Lua it applied live (and Hyprland accepted) to
-- ~/.local/state/hypr/look.lua; this just runs it. Missing / broken file = decorations.lua + animations.lua stay.
local path = os.getenv("HOME") .. "/.local/state/hypr/look.lua"
local f = io.open(path)
if not f then return end
f:close()
local ok, err = pcall(dofile, path)
if not ok then io.stderr:write("look.lua: " .. tostring(err) .. "\n") end
