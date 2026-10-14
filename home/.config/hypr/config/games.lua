-- Games open on the screen you launched them from, on a new workspace after your last one there.
--   * "Launched from" = the screen the Steam window was on when you last used it (within 10 min),
--     otherwise the screen you're focused on.
--   * New workspace: per-screen numbering from scripts/ws.sh (ASUS 1-9, laptop 11-19 shown as 1-9).
--     With workspaces 1-3 open on that screen, the game gets 4.
--   * If you're on the other screen (e.g. watching YouTube), the game appears on its own screen
--     without taking focus away from you.
--   * Every window of the same game (splash, launcher, main window) goes to the same workspace.

local function isGame(w)
    local c = w.class or ""
    return c:match("^steam_app_%d+") ~= nil or c == "gamescope"
end

-- first workspace id - 1 for each screen (scripts/ws.sh numbering)
local function wsBase(monName)
    if not monName then return nil end
    if monName:match("^eDP") then return 10 end
    if monName == "HDMI-A-1" then return 0 end
    return nil
end

local lastSteam = { mon = nil, t = 0 }
local lastUser = nil -- last focused non-game window, to give focus back to
local gameWs = {}    -- game class -> workspace id

hl.on("window.active", function(w)
    pcall(function()
        if not w then return end
        if w.class == "steam" and w.monitor then
            lastSteam.mon, lastSteam.t = w.monitor.name, os.time()
        end
        if not isGame(w) then lastUser = w end
    end)
end)

local function launchMonitor()
    if lastSteam.mon and os.time() - lastSteam.t < 600 and hl.get_monitor(lastSteam.mon) then
        return lastSteam.mon
    end
    local m = hl.get_active_monitor()
    return m and m.name
end

local function newWorkspace(monName)
    local base = wsBase(monName)
    if not base then return nil end
    local used, top = {}, base
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > base and ws.id <= base + 9 then
            used[ws.id] = true
            if ws.id > top then top = ws.id end
        end
    end
    if top < base + 9 then return top + 1 end
    for i = base + 1, base + 9 do -- all 9 taken at the top: use the first gap
        if not used[i] then return i end
    end
    return nil
end

hl.on("window.open", function(w)
    pcall(function()
        if not w or not isGame(w) then return end

        local target = gameWs[w.class]
        local existing = target and hl.get_workspace(target)
        local monName
        if existing and existing.monitor then
            monName = existing.monitor.name
        else
            monName = launchMonitor()
            target = newWorkspace(monName)
            if not target then
                -- a screen without per-screen numbering: just put the game on it
                if monName then hl.dispatch(hl.dsp.window.move({ monitor = monName, window = w, follow = false })) end
                return
            end
            gameWs[w.class] = target
        end

        hl.dispatch(hl.dsp.window.move({ workspace = target, window = w, follow = false }))

        -- show it on its screen; if you were busy on the other screen, give focus back to you
        local you = lastUser
        local youMon = you and you.monitor and you.monitor.name
        hl.dispatch(hl.dsp.focus({ workspace = target }))
        if you and youMon and youMon ~= monName then
            local addr = you.address
            -- Hyprland focuses new windows after this handler, so hand focus back a moment later
            hl.timer(function()
                pcall(function() hl.dispatch(hl.dsp.focus({ window = "address:" .. addr })) end)
            end, { timeout = 250, type = "oneshot" })
        end
    end)
end)
