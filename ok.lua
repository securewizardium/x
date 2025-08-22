local getinfo = getinfo or debug.getinfo
local DEBUG = false
local Hooked = {}

local Detected, Kill

setthreadidentity(2)

for i, v in getgc(true) do
    if typeof(v) == 'table' then
        local DetectFunc = rawget(v, 'Detected')
        local KillFunc = rawget(v, 'Kill')

        if typeof(DetectFunc) == 'function' and not Detected then
            Detected = DetectFunc

            local Old
            Old = hookfunction(Detected, function(Action, Info, NoCrash)
                if Action ~= '_' then
                    if DEBUG then
                        warn(
                            `Adonis AntiCheat flagged\nMethod: {Action}\nInfo: {Info}`
                        )
                    end
                end

                return true
            end)

            table.insert(Hooked, Detected)
        end

        if
            rawget(v, 'Variables')
            and rawget(v, 'Process')
            and typeof(KillFunc) == 'function'
            and not Kill
        then
            Kill = KillFunc
            local Old
            Old = hookfunction(Kill, function(Info)
                if DEBUG then
                    warn(`Adonis AntiCheat tried to kill (fallback): {Info}`)
                end
            end)

            table.insert(Hooked, Kill)
        end
    end
end

local Old
Old = hookfunction(
    getrenv().debug.info,
    newcclosure(function(...)
        local LevelOrFunc, Info = ...

        if Detected and LevelOrFunc == Detected then
            if DEBUG then
                warn(`Adonis AntiCheat sanity check detected and broken`)
            end

            return coroutine.yield(coroutine.running())
        end

        return Old(...)
    end)
)
-- setthreadidentity(9)
setthreadidentity(7)

if game:GetService('ReplicatedStorage'):FindFirstChild('SyncSound', true) then
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == 'FireServer' and self.Name == 'SyncSound' then
            return
        end
        return oldNamecall(self, ...)
    end)

    setreadonly(mt, true)
end

if game.PlaceId == 8502861227 then
    local plr = game.Players.LocalPlayer
    local gui = plr.PlayerGui
    local topbarFrame = gui.TopbarStandard.Holders.Left

    plr.CharacterAdded:Connect(function()
        task.wait(1)
        if #topbarFrame:GetChildren() > 3 then
            for _, v in pairs(topbarFrame:GetChildren()) do
                if
                    v:IsA('Frame')
                    and v.Name == 'Widget'
                    and v.AbsolutePosition ~= Vector2.new(176, -46)
                    and v.AbsolutePosition ~= Vector2.new(232, -46)
                then
                    v:Destroy()
                    break
                end
            end
        end
    end)
end

local function disableHumanoidRootPartSizeConnections(character)
    local humanoidRootPart = character:WaitForChild('HumanoidRootPart')
    for _, connection in
        pairs(getconnections(humanoidRootPart:GetPropertyChangedSignal('Size')))
    do
        connection:Disable()
    end
end

for _, player in ipairs(game.Players:GetPlayers()) do
    if player.Character then
        disableHumanoidRootPartSizeConnections(player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        disableHumanoidRootPartSizeConnections(character)
    end)
end

game.Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        disableHumanoidRootPartSizeConnections(character)
    end)
end)

local KEY = Enum.KeyCode
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local StarterGui = game:GetService('StarterGui')

local localPlayer = Players.LocalPlayer

local Settings = {
    Keybinds = {
        ['INCREASE'] = KEY.U,
        ['DECREASE'] = KEY.J,
        ['TOGGLE'] = KEY.LeftControl,
        ['INCREASE_HRP'] = KEY.Nine,
        ['DECREASE_HRP'] = KEY.Eight,
        ['TOGGLE_TEAMMATES'] = KEY.T,
    },
    Values = {
        ['radius'] = 10,
        ['enabled'] = true,
        ['hrpSize'] = 5,
        ['ignoreTeammates'] = false,
    },
    RADIUS_INCREMENT = 1,
    HRP_INCREMENT = 0.5,
    HRP_MIN = 1,
    HRP_MAX = 15,
}

local function notify(text)
    StarterGui:SetCore('SendNotification', {
        Title = 'Reach Script',
        Text = text,
        Duration = 2,
    })
end

local reachedPlayers = {}

local function areTeammates(plr1, plr2)
    if plr1.Team ~= nil and plr2.Team ~= nil then
        return plr1.Team == plr2.Team
    end
    if plr1.TeamColor and plr2.TeamColor then
        return plr1.TeamColor == plr2.TeamColor
    end
    return false
end

local function resetPlayerHitbox(player)
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if hrp then
            hrp.Size = Vector3.new(2, 2, 1)
            hrp.CanCollide = false
            hrp.Transparency = 1
        end
    end
end

local function forceNoCollideHRP(player)
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild('HumanoidRootPart')
        if hrp then
            hrp.CanCollide = false
        end
    end
end

local function instantResetHRPOnDeath(character)
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local hrp = character:FindFirstChild('HumanoidRootPart')
    if humanoid and hrp then
        if humanoid.Health <= 0 then
            hrp.Size = Vector3.new(2, 2, 1)
            hrp.CanCollide = false
            hrp.Transparency = 1
        end
        humanoid.Died:Connect(function()
            if hrp then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.CanCollide = false
                hrp.Transparency = 1
            end
        end)
    end
end

local function setupDeathReset(player)
    local function connectDeath(character)
        instantResetHRPOnDeath(character)
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if humanoid then
            humanoid.Died:Connect(function()
                if reachedPlayers[player] then
                    resetPlayerHitbox(player)
                    reachedPlayers[player] = nil
                end

                local hrp = character:FindFirstChild('HumanoidRootPart')
                if hrp then
                    hrp.CanCollide = false
                end
            end)
        end

        local hrp = character:FindFirstChild('HumanoidRootPart')
        if hrp and humanoid and humanoid.Health <= 0 then
            hrp.Size = Vector3.new(2, 2, 1)
            hrp.CanCollide = false
            hrp.Transparency = 1
        end
    end
    if player.Character then
        connectDeath(player.Character)
    end
    player.CharacterAdded:Connect(connectDeath)
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= localPlayer then
        setupDeathReset(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= localPlayer then
        setupDeathReset(player)
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    local key = input.KeyCode
    if key == Settings.Keybinds.INCREASE then
        Settings.Values.radius = math.clamp(
            Settings.Values.radius + Settings.RADIUS_INCREMENT,
            1,
            50
        )
        notify('Radius: ' .. tostring(Settings.Values.radius))
    elseif key == Settings.Keybinds.DECREASE then
        Settings.Values.radius = math.clamp(
            Settings.Values.radius - Settings.RADIUS_INCREMENT,
            1,
            50
        )
        notify('Radius: ' .. tostring(Settings.Values.radius))
    elseif key == Settings.Keybinds.TOGGLE then
        Settings.Values.enabled = not Settings.Values.enabled
        notify(
            'Reach ' .. (Settings.Values.enabled and 'Enabled' or 'Disabled')
        )
        if not Settings.Values.enabled then
            for player, _ in pairs(reachedPlayers) do
                resetPlayerHitbox(player)
            end
            reachedPlayers = {}
        end
    elseif key == Settings.Keybinds.INCREASE_HRP then
        Settings.Values.hrpSize = math.clamp(
            Settings.Values.hrpSize + Settings.HRP_INCREMENT,
            Settings.HRP_MIN,
            Settings.HRP_MAX
        )
        notify('HRP Size: ' .. tostring(Settings.Values.hrpSize))
    elseif key == Settings.Keybinds.DECREASE_HRP then
        Settings.Values.hrpSize = math.clamp(
            Settings.Values.hrpSize - Settings.HRP_INCREMENT,
            Settings.HRP_MIN,
            Settings.HRP_MAX
        )
        notify('HRP Size: ' .. tostring(Settings.Values.hrpSize))
    elseif key == Settings.Keybinds.TOGGLE_TEAMMATES then
        Settings.Values.ignoreTeammates = not Settings.Values.ignoreTeammates
        notify(
            'Ignore Teammates: '
                .. (Settings.Values.ignoreTeammates and 'ON' or 'OFF')
        )
        if Settings.Values.ignoreTeammates then
            for player, _ in pairs(reachedPlayers) do
                if areTeammates(localPlayer, player) then
                    resetPlayerHitbox(player)
                    reachedPlayers[player] = nil
                end
            end
        end
    end
end)

local function forceNoCollideAndResetAllDeadPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChildOfClass('Humanoid')
                local hrp = char:FindFirstChild('HumanoidRootPart')
                if humanoid and hrp and humanoid.Health <= 0 then
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.CanCollide = false
                    hrp.Transparency = 1
                end
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    if not Settings.Values.enabled then
        return
    end

    local char = localPlayer.Character
    if not char then
        return
    end
    local hrp = char:FindFirstChild('HumanoidRootPart')
    if not hrp then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if
                Settings.Values.ignoreTeammates
                and areTeammates(localPlayer, player)
            then
                if reachedPlayers[player] then
                    resetPlayerHitbox(player)
                    reachedPlayers[player] = nil
                end
                continue
            end

            local pchar = player.Character
            local phrp = pchar and pchar:FindFirstChild('HumanoidRootPart')
            local phumanoid = pchar and pchar:FindFirstChildOfClass('Humanoid')
            if phrp then
                -- Always force HRP to be non-collidable when HBE is on, even if alive
                -- Also, always force CanCollide false for all reached players
                if reachedPlayers[player] then
                    phrp.CanCollide = false
                end

                -- Always force dead players' HRP to be non-collidable and reset size
                if phumanoid and phumanoid.Health <= 0 then
                    phrp.Size = Vector3.new(2, 2, 1)
                    phrp.CanCollide = false
                    phrp.Transparency = 1
                end

                local dist = (hrp.Position - phrp.Position).Magnitude
                if
                    dist <= Settings.Values.radius
                    and (not phumanoid or phumanoid.Health > 0)
                then
                    if not reachedPlayers[player] then
                        local size = Settings.Values.hrpSize
                        phrp.Size = Vector3.new(size, size, size)
                        phrp.CanCollide = false
                        phrp.Transparency = 1
                        reachedPlayers[player] = true
                    else
                        local size = Settings.Values.hrpSize
                        if
                            phrp.Size.X ~= size
                            or phrp.Size.Y ~= size
                            or phrp.Size.Z ~= size
                        then
                            phrp.Size = Vector3.new(size, size, size)
                        end
                        -- Always force CanCollide false while HBE is on
                        phrp.CanCollide = false
                    end
                else
                    if reachedPlayers[player] then
                        resetPlayerHitbox(player)
                        reachedPlayers[player] = nil
                    end
                end
            end
        end
    end

    for trackedPlayer, _ in pairs(reachedPlayers) do
        if not Players:FindFirstChild(trackedPlayer.Name) then
            reachedPlayers[trackedPlayer] = nil
        end
    end
    forceNoCollideAndResetAllDeadPlayers()
end)

notify(
    'Left Control to toggle, U/J to change radius, 9/8 to change HRP size, T to toggle teammate ignore.'
)
