-- Double-tap Ctrl (left or right, nothing else pressed) → Isla draws rings round the mouse pointer (LocatePointer.qml).
-- A release bind on the Ctrl key alone only fires when no other key/button came in between, so Ctrl+C etc. don't count.
-- non_consuming: apps still see the Ctrl key normally.
local armed = false
local function tap()
    if armed then
        armed = false
        local p = hl.get_cursor_pos()
        if p then hl.exec_cmd(string.format("qs -c isla ipc call isla locate %d %d", math.floor(p.x), math.floor(p.y))) end
        return
    end
    armed = true
    hl.timer(function() armed = false end, { timeout = 400, type = "oneshot" })
end
for _, key in ipairs({ "Control_L", "Control_R" }) do
    hl.bind("CTRL + " .. key, tap, { release = true, non_consuming = true, description = "Find the mouse (double-tap Ctrl)" })
end
