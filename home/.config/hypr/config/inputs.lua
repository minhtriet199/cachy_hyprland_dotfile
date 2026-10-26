-- Input configuration

hl.config({
    input = {
        -- sensitivity = -0.25,
        accel_profile = "flat",
    },
    -- gpu-pick.sh made the 6700S primary: eDP on the 680M shows the hardware cursor as a black square
    cursor = {
        no_hardware_cursors = os.getenv("AQ_DRM_DEVICES") and 1 or 2,
    },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
-- 3 fingers sideways = back / forward in any app that knows the Back/Forward keys (browsers, Dolphin…); was "left = float"
hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "XF86Back" })) end })
hl.gesture({ fingers = 3, direction = "left",  action = function() hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "XF86Forward" })) end })
