-- Input configuration

hl.config({
    input = {
        -- sensitivity = -0.25,
        accel_profile = "flat",
    },
    -- Hybrid: a screen on the other GPU than the one drawing (eDP on the 680M, HDMI on the 6700S) shows the hardware
    -- cursor as a black square. Can't key it off gpu-pick: the HDMI often links up after login, so the pick is skipped.
    cursor = {
        no_hardware_cursors = 1,
    },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
-- 3 fingers sideways = back / forward in any app that knows the Back/Forward keys (browsers, Dolphin…); was "left = float"
hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "XF86Back" })) end })
hl.gesture({ fingers = 3, direction = "left",  action = function() hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "XF86Forward" })) end })
