-- boot background = Isla's scene-change cover colour (Isla writes it to ~/.local/state/hypr/cover), so the login screen,
-- this Hyprland and Isla's first frame are one colour
-- a colour string: a bare number like 0xFFF4E0 means alpha 0 = transparent = black
local cover = "rgb(fff4e0)"
local cf = io.open(os.getenv("HOME") .. "/.local/state/hypr/cover")
if cf then
    local hex = (cf:read("l") or ""):match("^#(%x%x%x%x%x%x)$")
    if hex then cover = "rgb(" .. hex .. ")" end
    cf:close()
end

hl.config({
    dwindle = {
        preserve_split = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
    misc = {
        col = {
            splash = CACHYLGREEN,
        },
        middle_click_paste = false,
        enable_swallow = true,
        focus_on_activate = true, -- let apps focus their window (e.g. when you click their notification)
        swallow_regex = "(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)",
        vrr = 3,
        disable_hyprland_logo = true,      -- no Hyprland mascot wallpaper before Isla draws its own
        disable_splash_rendering = true,
        background_color = cover,          -- same as Isla's scene-change cover
        allow_session_lock_restore = true, -- if the lock screen (Isla) crashes, a new one can take over instead of a stuck red screen
    },
    render = {
        direct_scanout = 2,
        -- Use the option below if you find games constantly black screening for a couple seconds whenever direct scanout enables/disables
        -- non_shader_cm = 0,
    },
    xwayland = {
        force_zero_scaling = true
    },
})
