-- Games open on the screen you launched them from, on a new workspace after your last one there.
--   * "Launched from" = the screen the Steam window was on when you last used it (within 10 min),
--     otherwise the screen you're focused on.
--   * New workspace: per-screen numbering from scripts/ws.sh (ASUS 1-9, laptop 11-19 shown as 1-9).
--     With workspaces 1-3 open on that screen, the game gets 4.
--   * If you're on the other screen (e.g. watching YouTube), the game appears on its own screen
--     without taking focus away from you.
--   * Every window of the same game (splash, launcher, main window) goes to the same workspace.

-- A game = anything Steam launched (its process carries SteamAppId), so native Linux games
-- (e.g. "Desperados III.x86_64") count too, not only Proton's steam_app_* windows.
-- Found classes go to ~/.cache/island/game-classes so Island's Performance switch knows them.
local classesFile = os.getenv("HOME") .. "/.cache/island/game-classes"
local gameClass = {} -- class -> true (game) / false (checked, not a game)
do
    local f = io.open(classesFile)
    if f then for l in f:lines() do if l ~= "" then gameClass[l] = true end end f:close() end
end

local function steamLaunched(pid)
    local f = pid and io.open("/proc/" .. pid .. "/environ")
    if not f then return false end
    local env = f:read("a") or ""
    f:close()
    return env:match("%zSteamAppId=[1-9]") ~= nil or env:match("^SteamAppId=[1-9]") ~= nil
end

local function isGame(w)
    local c = w.class or ""
    if c:match("^steam_app_%d+") or c == "gamescope" then return true end
    if gameClass[c] ~= nil then return gameClass[c] end
    local yes = steamLaunched(w.pid)
    if c ~= "" then
        gameClass[c] = yes
        if yes then
            os.execute("mkdir -p '" .. classesFile:match("(.*)/") .. "'")
            local f = io.open(classesFile, "a")
            if f then f:write(c, "\n") f:close() end
        end
    end
    return yes
end

-- first workspace id - 1 for each screen (scripts/ws.sh numbering)
local function wsBase(monName)
    if not monName then return nil end
    if monName:match("^eDP") then return 10 end
    return 0 -- any external screen (HDMI, DisplayPort, USB-C), whatever the brand
end

local lastSteam = { mon = nil, t = 0 }
local lastUser = nil -- last focused non-game window, to give focus back to
local playing = false -- a game window has focus right now
local gameWs = {}    -- game class -> workspace id

hl.on("window.active", function(w)
    pcall(function()
        if not w then return end
        if w.class == "steam" and w.monitor then
            lastSteam.mon, lastSteam.t = w.monitor.name, os.time()
        end
        if not isGame(w) then lastUser = w end
        -- While a game has focus, only a click moves focus (follow_mouse 2): the pointer wandering onto
        -- the other screen no longer pulls keyboard focus / EN-VI away from the game. Normal again after.
        if isGame(w) ~= playing then
            playing = isGame(w)
            hl.config({ input = { follow_mouse = playing and 2 or 1 } })
        end
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
        -- (not when you're already playing: a game opening its next window must keep focus)
        if not playing and you and youMon and youMon ~= monName then
            local addr = you.address
            -- Hyprland focuses new windows after this handler, so hand focus back a moment later
            hl.timer(function()
                pcall(function() hl.dispatch(hl.dsp.focus({ window = "address:" .. addr })) end)
            end, { timeout = 250, type = "oneshot" })
        end
    end)
end)

-- Proton games often open their main window with NO title. windowrules.lua treats an untitled steam_app window as a
-- splash / launcher popup (float, not fullscreen), and rules only run when a window opens — so such a game stayed a
-- floating window (Slay the Spire 2, 2026-10-26). When an untitled game window gets its title and is big (at least half
-- its screen), it's the real game: make it fullscreen. Small popups (launcher, "Launching...") are left floating.
local titledFs = {} -- address -> true once handled
hl.on("window.title", function(w)
    pcall(function()
        if not w or titledFs[w.address] or w.initial_title ~= "" or w.title == "" then return end
        if not w.floating or w.fullscreen ~= 0 or not w.monitor or not isGame(w) then return end
        local m, s = w.monitor, w.size
        local ww, wh = s.x or s[1] or 0, s.y or s[2] or 0
        if ww < m.width / m.scale * 0.5 or wh < m.height / m.scale * 0.5 then return end
        titledFs[w.address] = true
        hl.dispatch(hl.dsp.window.fullscreen({ mode = 0, window = "address:" .. w.address }))
    end)
end)
hl.on("window.destroy", function(w) pcall(function() if w and w.address then titledFs[w.address] = nil end end) end)
