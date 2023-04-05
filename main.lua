if not game:IsLoaded() then
    game.Loaded:Wait()
end

if iniuria then
    return
end

-- globals
local drawlib = Drawing
local pairs = pairs
local tick = tick
local getgenv = getgenv

-- setting up random generator
math.randomseed(tick())
local function randomString(length: number)
	local str = ""
	for _ = 1, length do
		str = str .. string.char(math.random(97, 122))
	end
	return str
end

-- globals
getgenv().update_loop_stepped_name = getgenv().update_loop_stepped_name or randomString(math.random(15, 35))
getgenv().post_sim_loop_name = getgenv().post_sim_loop_name or randomString(math.random(15, 35))
getgenv().iniuria = true

-- services
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

-- values
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera
local DummyPart = Instance.new('Part', nil)
local IgnoredInstances = {}
local LastTick = 0
local StartAim = false
local Debounce = false
local CameraLock = false
local IgnoredPlayers = {}
local BypassH4xeye = {5361853069, 5841467683}

-- raycast
local RaycastParam = RaycastParams.new()
RaycastParam.FilterType = Enum.RaycastFilterType.Blacklist
RaycastParam.IgnoreWater = true

-- drawing lib objects
local aimingDraw = {
    fovCircle = nil
}

local espDraw = {
    box = {
        boxHolder = {},
        boxHealth = {},
        boxName = {},
    },
}

-- character parts
local CharacterParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

-- init drawing lib
drawlib.new('Square').Visible = false

-- ui lib
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/brodaniell/iniuria/main/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = 'Iniuria | v0.1 | alpha'
})

-- legit
local LegitTab = Window:AddTab('Legit')
local LegitTabbox1 = LegitTab:AddLeftGroupbox('Aimbot')
LegitTabbox1:AddSlider('MaxDistance', { Text = "Max Distance", Suffix = "m", Default = 5000, Min = 0, Max = 5000, Rounding = 0})
LegitTabbox1:AddSlider('AimbotFOV', { Text = "Aimbot FOV", Suffix = "m", Default = 10, Min = 0, Max = 10, Rounding = 0})
LegitTabbox1:AddDivider()
LegitTabbox1:AddSlider('AimbotAdj', { Text = "Aim Adjustment", Suffix = "%", Default = 50, Min = 0, Max = 100, Rounding = 0})
LegitTabbox1:AddSlider('AimbotAdjStr', { Text = "Aim Adjustment Strength", Suffix = "x", Default = 5, Min = 0, Max = 5, Rounding = 0})
LegitTabbox1:AddDivider()
LegitTabbox1:AddSlider('AimbotOffsetX', { Text = "Aimbot Offset X", Default = 0, Min = -10, Max = 10, Rounding = 0})
LegitTabbox1:AddSlider('AimbotOffsetY', { Text = "Aimbot Offset Y", Default = 0, Min = -10, Max = 10, Rounding = 0})
LegitTabbox1:AddDivider()
LegitTabbox1:AddSlider('Delay', { Text = "Interval", Default = 0.15, Min = 0.025, Max = 1, Rounding = 3})
LegitTabbox1:AddSlider('Percentage', { Text = "Affects aimbot", Default = 1, Min = 1, Max = 100, Rounding = 1})

local LegitTabbox2 = LegitTab:AddRightGroupbox('Global Aimbot Settings')
LegitTabbox2:AddToggle('VCheck', {Text = 'Visibility Check'})
LegitTabbox2:AddToggle('TCheck', {Text = 'Team Check'})
LegitTabbox2:AddToggle('Camera', {Text = 'Disable when using Camera'})

-- visual
local VisualTab = Window:AddTab('Visual')
local VisualTabbox1 = VisualTab:AddLeftGroupbox('General')
VisualTabbox1:AddToggle('Enabled', {Text = 'Enabled'})
VisualTabbox1:AddDivider()
VisualTabbox1:AddToggle('2D Box', {Text = '2D Box'})
VisualTabbox1:AddToggle('Chams', {Text = 'Chams'})

local VisualTabbox2 = VisualTab:AddRightGroupbox('Settings')
VisualTabbox2:AddLabel('Visible Color'):AddColorPicker('ColorPicker', {
    Default = Color3.new(0, 1, 0),
    Title = 'Visible Color',
    Transparency = 0
})
VisualTabbox2:AddLabel('Nonvisible Color'):AddColorPicker('ColorPicker', {
    Default = Color3.new(1, 0, 0),
    Title = 'Nonvisible Color',
    Transparency = 0
})


-- settings
local SettingsTab = Window:AddTab('Settings')
local ThemesTabbox = SettingsTab:AddLeftGroupbox('Themes')
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('iniuria')
SaveManager:SetFolder('iniuria')
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToGroupbox(ThemesTabbox)
Library:OnUnload(function()
    Library.Unloaded = true
end)
SaveManager:LoadAutoloadConfig()

-- esp


-- functions
local function newDrawing(class_name)
    return function(props)
        local inst = drawlib.new(class_name)

        for idx, val in pairs(props) do
            if idx ~= "instance" then
                inst[idx] = val
            end
        end

        return inst
    end
end

local function addOrUpdateInstance(table, child, props)
    local inst = table[child]
    if not inst then
        table[child] = newDrawing(props.instance)(props)
        return inst
    end

    for idx, val in pairs(props) do
        if idx ~= "instance" then
            inst[idx] = val
        end
    end

    return inst
end

local function getCharacter(player: Player)
    local character = game:GetService("Workspace"):FindFirstChild(player.Name) or game:GetService("Workspace"):WaitForChild(player.Name, 1000)
    if not character:IsDescendantOf(game:GetService("Workspace")) then return nil end
    return character
end

local function toViewportPoint(v3: Vector3)
    local screenPos, visible = Camera:WorldToViewportPoint(v3)
    return Vector3.new(screenPos.X, screenPos.Y, screenPos.Z), visible
end

local function canHit(originPosition: Vector3, target: Vector3)
    if not Toggles.VCheck.Value then
        return true
    end

    local ignoreList = {Camera, getCharacter(LocalPlayer)}
    for _, v in pairs(IgnoredInstances) do
        ignoreList[#ignoreList + 1] = v
    end

    RaycastParam.FilterDescendantsInstances = ignoreList
    local raycast = workspace:Raycast(originPosition, (target.Position - originPosition).Unit * Options.MaxDistance.Value, RaycastParam)
    local resultPart = ((raycast and raycast.Instance) or DummyPart)
    if resultPart ~= DummyPart then
        if resultPart.Transparency >= 0.3 then -- ignore low transparency
        IgnoredInstances[#IgnoredInstances + 1] = resultPart
        end

        if resultPart.Material == Enum.Material.Glass then -- ignore glass
        IgnoredInstances[#IgnoredInstances + 1] = resultPart
        end
    end

    return resultPart:IsDescendantOf(target.Parent)
end

local function sameTeam(character)
    if not Toggles.TCheck.Value then
        return false
    end

    if Players:GetPlayerFromCharacter(character) then
        local target = Players:GetPlayerFromCharacter(character)
        if target.Team == LocalPlayer.Team then
            return true
        end
    end

    return false
end

local function hasHealth(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if character and humanoid then
        if humanoid.Health > 0 then
            return true
        end
    end

    return false
end

local function isInsideFOV(target)
    return ((target.X - aimingDraw.fovCircle.Position.X) ^ 2 + (target.Y - aimingDraw.fovCircle.Position.Y) ^ 2 <= aimingDraw.fovCircle.Radius ^ 2)
end

local function getClosestObjectFromMouse()
	local closest = {Distance = Options.MaxDistance.Value * 2, Character = nil}
	local mousePos = UserInputService:GetMouseLocation()

    for _, char in pairs(game:GetService("Workspace"):GetChildren()) do
        if not (char or char:IsA("Model")) then continue end
        if char.Name:match(LocalPlayer.Character.Name) then continue end
        local hRP = char:FindFirstChild("HumanoidRootPart")
        if hRP then
            local position, _ = toViewportPoint(hRP.Position)
            local distance = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
            if (distance > closest.Distance) then
                continue
            end
            closest = {Distance = distance, Character = char}
        end
    end
	return closest
end

local function getClosestPartFromMouse()
    local target = getClosestObjectFromMouse().Character
    local mousePos = UserInputService:GetMouseLocation()
    local closest = {Part = nil, Distance = Options.MaxDistance.Value * 2}
    if not target then return end
    for _, parts in pairs(target:GetChildren()) do
        if not table.find(CharacterParts, parts.Name) then continue end
        local position, _ = toViewportPoint(parts.Position)
        local distance = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
        if (distance > closest.Distance) then
            continue
        end
        closest = {Part = parts, Distance = distance}
    end

    return closest
end

local function aimbot(mouseSens, t)
    local closestHitbox = getClosestPartFromMouse()
    local target = getClosestObjectFromMouse().Character
    local headPos = getCharacter(LocalPlayer):FindFirstChild("Head") or getCharacter(LocalPlayer):WaitForChild("Head", 1000)
    local mousePos = UserInputService:GetMouseLocation()
    if not headPos then return end
    if not closestHitbox then return end
    if closestHitbox.Part and target and not IgnoredPlayers[target] then
        local position, visible = toViewportPoint(closestHitbox.Part.Position)
        if position and canHit(headPos.Position, closestHitbox.Part) and visible and isInsideFOV(position) then
            if hasHealth(target) and not sameTeam(target) then
                local offsetX = Options.AimbotOffsetX.Value
                local offsetY = Options.AimbotOffsetY.Value
                local relativeMousePosition = Vector2.new(position.X + offsetX, position.Y + offsetY) - mousePos
                local aimbotStrength = math.clamp(Options.AimbotAdjStr.Value, 0, 10)
                local aimbotAdjustment = math.clamp(Options.AimbotAdj.Value, 0, 100)
                local debug = math.clamp(Options.Percentage.Value, 1, 100)
                local stabilize = ((aimbotAdjustment / 100) * (aimbotStrength * 2)) / debug
                if stabilize <= 0 then return end
                -- 0.3, 120
                local endX = (relativeMousePosition.X * stabilize) + (mouseSens * t)
                local endY = (relativeMousePosition.Y * stabilize) + (mouseSens * t)
                mousemoverel(endX, endY)
            end
        end
    end
end

local function removePlayersFromIgnore()
    -- Character
    for _, v in pairs(IgnoredPlayers) do
        local hRP = v:FindFirstChild("HumanoidRootPart")
        if hRP then
            local position, _ = toViewportPoint(hRP.Position)
            if not isInsideFOV(position) then
                IgnoredPlayers[v] = nil
            end
        else
            IgnoredPlayers[v] = nil
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    --if gameProcessedEvent then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        StartAim = true
    end

    if Toggles.Camera.Value and input.UserInputType == Enum.UserInputType.MouseButton2 then
        CameraLock = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
    --if gameProcessedEvent then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        StartAim = false
    end

    if Toggles.Camera.Value and input.UserInputType == Enum.UserInputType.MouseButton2 then
        CameraLock = false
    end
end)

local function bypassAC()
    local gameId = game.GameId
    if not BypassH4xeye[gameId] then
        return
    end

    local oldMethod;
    oldMethod = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(event, ...)
        local args = {...}
        print(event)
        for _, v in pairs(args) do
            print(v)
        end
        return oldMethod(event, ...)
    end))
end
bypassAC()

local function stepped()
    if (tick() - LastTick) > (10 / 1000) then
        LastTick = tick()

        removePlayersFromIgnore()

        -- fov circle
        addOrUpdateInstance(aimingDraw, "fovCircle", {
            Thickness = 1,
            Position = UserInputService:GetMouseLocation(),
            Radius = (Options.AimbotFOV.Value * 5),
            Visible = false,
            instance = "Circle";
        })
    end
end

Mouse.Move:Connect(function()
    local target = Mouse.Target
    if target and target.Parent:FindFirstChild("Humanoid") then
        if not IgnoredPlayers[target.Parent] then
            IgnoredPlayers[target.Parent] = target.Parent
        end
    end
end)

post_sim_loop_name = RunService.PostSimulation:Connect(function(t)
    Mouse.Move:Wait()
    if StartAim and iswindowactive() and not CameraLock then
        if not Debounce then
            Debounce = true
            aimbot(UserSettings().GameSettings.MouseSensitivity, t)
            local delay = math.clamp(Options.Delay.Value, 0.025, 1)
            task.wait(delay)
            Debounce = false
        end
    end
end)

RunService:BindToRenderStep(update_loop_stepped_name, 199, stepped)