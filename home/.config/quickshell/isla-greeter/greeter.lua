-- Hyprland for the Isla login screen (greetd runs it as the "greeter" user via isla-greeter-session).
-- Only shows the greeter; quits when the greeter quits, then greetd starts your real session.
local share = os.getenv("ISLA_GREETER_SHARE") or "/usr/local/share/isla-greeter"
local data  = os.getenv("ISLA_GREETER_DATA") or "/var/lib/isla-greeter"

-- a colour string: a bare number like 0xFFF4E0 means alpha 0 = transparent = black
local cover = "rgb(fff4e0)"
local cf = io.open(data .. "/cover")
if cf then
    local hex = (cf:read("l") or ""):match("^#(%x%x%x%x%x%x)$")
    if hex then cover = "rgb(" .. hex .. ")" end
    cf:close()
end

hl.config({
    ecosystem = { no_update_news = true, no_donation_nag = true },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = cover,      -- Isla's scene-change cover colour (copied by isla-greeter-sync)
        disable_watchdog_warning = true, -- plain Hyprland on purpose: a crash must end it so isla-greeter-session falls back to the text login
    },
    input = { accel_profile = "flat" },
})

-- same screen layout as your desktop (copied from ~/.local/state/hypr/screens by isla-greeter-sync), no HDR
local f = io.open(data .. "/screens")
if f then
    for line in f:lines() do
        local desc, rest = line:match("^([^\t]+)\t(.*)$")
        if desc then
            local s = {}
            for k, v in rest:gmatch("(%w+)=(%S+)") do s[k] = v end
            if s.mode then
                hl.monitor({ output = "desc:" .. desc, mode = s.mode, position = s.pos or "auto", scale = s.scale or "auto" })
            end
        end
    end
    f:close()
end

hl.on("hyprland.start", function ()
    hl.exec_cmd(share .. "/run-greeter")
end)
