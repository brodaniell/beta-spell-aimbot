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
local VisibleColor = Color3.new(1, 1, 1)
local NotvisibleColor = Color3.new(1, 1, 1)

-- raycast
local RaycastParam = RaycastParams.new()
RaycastParam.FilterType = Enum.RaycastFilterType.Blacklist
RaycastParam.IgnoreWater = true

-- drawing lib objects
local aimingDraw = {
    fovCircle = nil
}

-- character parts
local CharacterParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

-- init drawing lib
drawlib.new('Square').Visible = false

--#region UI
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/brodaniell/iniuria/main/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = 'Iniuria | v0.1 | alpha'
})

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
LegitTabbox1:AddSlider('Percentage', { Text = "Divider", Default = 1, Min = 1, Max = 100, Rounding = 1})

local LegitTabbox2 = LegitTab:AddRightGroupbox('Global Aimbot Settings')
LegitTabbox2:AddToggle('VCheck', {Text = 'Visibility Check'})
LegitTabbox2:AddToggle('TCheck', {Text = 'Team Check'})
LegitTabbox2:AddToggle('Camera', {Text = 'Disable when using Camera'})

local VisualTab = Window:AddTab('Visual')
local VisualTabbox1 = VisualTab:AddLeftGroupbox('General')
VisualTabbox1:AddToggle('ESP', {Text = 'ESP enabled'})
VisualTabbox1:AddDivider()
VisualTabbox1:AddToggle('Box', {Text = '2D Box'})
VisualTabbox1:AddToggle('Chams', {Text = 'Chams'})

local VisualTabbox2 = VisualTab:AddRightGroupbox('Settings')
VisualTabbox2:AddLabel('Visible Color'):AddColorPicker('VisibleColor', {
    Default = Color3.new(0, 1, 0),
    Title = 'Visible Color',
    Transparency = 0,

    Callback = function(value)
        VisibleColor = value
    end
})
VisualTabbox2:AddLabel('Nonvisible Color'):AddColorPicker('NotvisibleColor', {
    Default = Color3.new(1, 0, 0),
    Title = 'Nonvisible Color',
    Transparency = 0,

    Callback = function(value)
        NotvisibleColor = value
    end
})
VisualTabbox2:AddSlider('FillOpacity', { Text = "Fill Opacity", Default = 0.5, Min = 0, Max = 1, Rounding = 1})
VisualTabbox2:AddSlider('OutlineOpacity', { Text = "Outline Opacity", Default = 1, Min = 0, Max = 1, Rounding = 1})

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
--#endregion

--#region Aimbot
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

local function getPlayers()
    return game:GetService("Players"):GetPlayers()
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
--#endregion

--#region ESP
local function createQuad(color, opacity)
    local quad = drawlib.new("Quad")
    quad.Visible = false
    quad.PointA = Vector2.new(0, 0)
    quad.PointB = Vector2.new(0, 0)
    quad.PointC = Vector2.new(0, 0)
    quad.PointD = Vector2.new(0, 0)
    quad.Color = color
    quad.Filled = true
    quad.Thickness = 1
    quad.Transparency = opacity
    return quad
end

local function colorize(color, t)
    for _, v in pairs(t) do
        v.Color = color
    end
end

local function createESP(character)
    local headPos = getCharacter(LocalPlayer):FindFirstChild("Head")
    if not headPos then return end

    local hRP = character:FindFirstChild("HumanoidRootPart")
    if not hRP then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    for _, v in pairs(character:GetChildren()) do
        if not (v:IsA("MeshPart") or v.Name == "Head" or v.Name == "Left Arm" or v.Name == "Right Arm" or v.Name == "Right Leg" or v.Name == "Left Leg" or v.Name == "Torso") then continue end
        local quads = {
            quad1 = createQuad(Options.VisibleColor.Value, math.clamp(Options.FillOpacity.Value, 0, 1)),
            quad2 = createQuad(Options.VisibleColor.Value, math.clamp(Options.FillOpacity.Value, 0, 1)),
            quad3 = createQuad(Options.VisibleColor.Value, math.clamp(Options.FillOpacity.Value, 0, 1)),
            quad4 = createQuad(Options.VisibleColor.Value, math.clamp(Options.FillOpacity.Value, 0, 1)),
            quad5 = createQuad(Options.VisibleColor.Value, math.clamp(Options.FillOpacity.Value, 0, 1)),
            quad6 = createQuad(Options.VisibleColor.Value, math.clamp(Options.FillOpacity.Value, 0, 1)),
        }
        
        local _, visible = toViewportPoint(v.Position)
        if visible and canHit(headPos.Position, v.Position) then
            local size_X = v.Size.X/2
            local size_Y = v.Size.X/2
            local size_Z = v.Size.X/2

            local top1 = toViewportPoint((v.CFrame * CFrame.new(-size_X, size_Y, -size_Z)).p)
            local top2 = toViewportPoint((v.CFrame * CFrame.new(-size_X, size_Y, size_Z)).p)
            local top3 = toViewportPoint((v.CFrame * CFrame.new(size_X, size_Y, size_Z)).p)
            local top4 = toViewportPoint((v.CFrame * CFrame.new(size_X, size_Y, -size_Z)).p)
            local bottom1 = toViewportPoint((v.CFrame * CFrame.new(-size_X, -size_Y, -size_Z)).p)
            local bottom2 = toViewportPoint((v.CFrame * CFrame.new(-size_X, -size_Y, size_Z)).p)
            local bottom3 = toViewportPoint((v.CFrame * CFrame.new(size_X, -size_Y, size_Z)).p)
            local bottom4 = toViewportPoint((v.CFrame * CFrame.new(size_X, -size_Y, -size_Z)).p)
            
            -- Top
            quads.quad1.PointA = Vector2.new(top1.X, top1.Y)
            quads.quad1.PointB = Vector2.new(top2.X, top2.Y)
            quads.quad1.PointC = Vector2.new(top3.X, top3.Y)
            quads.quad1.PointD = Vector2.new(top4.X, top4.Y)

            -- Bottom
            quads.quad2.PointA = Vector2.new(bottom1.X, bottom1.Y)
            quads.quad2.PointB = Vector2.new(bottom2.X, bottom2.Y)
            quads.quad2.PointC = Vector2.new(bottom3.X, bottom3.Y)
            quads.quad2.PointD = Vector2.new(bottom4.X, bottom4.Y)

            -- Sides
            quads.quad3.PointA = Vector2.new(top1.X, top1.Y)
            quads.quad3.PointB = Vector2.new(top2.X, top2.Y)
            quads.quad3.PointC = Vector2.new(bottom2.X, bottom2.Y)
            quads.quad3.PointD = Vector2.new(bottom1.X, bottom1.Y)
            
            quads.quad4.PointA = Vector2.new(top2.X, top2.Y)
            quads.quad4.PointB = Vector2.new(top3.X, top3.Y)
            quads.quad4.PointC = Vector2.new(bottom3.X, bottom3.Y)
            quads.quad4.PointD = Vector2.new(bottom2.X, bottom2.Y)
            
            quads.quad5.PointA = Vector2.new(top3.X, top3.Y)
            quads.quad5.PointB = Vector2.new(top4.X, top4.Y)
            quads.quad5.PointC = Vector2.new(bottom4.X, bottom4.Y)
            quads.quad5.PointD = Vector2.new(bottom3.X, bottom3.Y)

            quads.quad6.PointA = Vector2.new(top4.X, top4.Y)
            quads.quad6.PointB = Vector2.new(top1.X, top1.Y)
            quads.quad6.PointC = Vector2.new(bottom1.X, bottom1.Y)
            quads.quad6.PointD = Vector2.new(bottom4.X, bottom4.Y)

            colorize(VisibleColor, quads)
        else
            colorize(NotvisibleColor, quads)
        end

        for _, v in pairs(quads) do
            if (Toggles.ESP.Value) then
                v.Visible = Toggles.Chams.Value
            else
                v.Visible = false
            end
        end
    end
end

for _, v in pairs(getPlayers()) do
    if v ~= LocalPlayer then
        coroutine.wrap(createESP)(getCharacter(v))
    end
end

game:GetService("Players").PlayerAdded:Connect(function(v)
    if v ~= LocalPlayer then
        coroutine.wrap(createESP)(getCharacter(v))
    end
end)
--#endregion

--#region RenderStep
local function stepped()
    if (tick() - LastTick) > (10 / 1000) then
        LastTick = tick()

        removePlayersFromIgnore()

        for _, v in pairs(getPlayers()) do
            if v ~= LocalPlayer then
                coroutine.wrap(createESP)(getCharacter(v))
            end
        end

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
--#endregion

RunService:BindToRenderStep(update_loop_stepped_name, 199, stepped)