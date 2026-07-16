-- Might not be working in todays meta

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "D4Aim",
    LoadingTitle = "D4Aim",
    LoadingSubtitle = "Clean & Reliable",
    Icon = 4483362458,
    ToggleUIKeybind = Enum.KeyCode.LeftAlt,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "D4Aim",
        FileName = "D4AimConfig"
    }
})

local CombatTab = Window:CreateTab("Combat", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local MiscTab = Window:CreateTab("Misc", 4483362458)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ==================== SETTINGS ====================
local AimSettings = {
    Enabled = false,
    AutoLock = false,
    ToggleLock = false,
    IsFFA = false,
    HoldKey = Enum.KeyCode.Q,
    WallCheck = true,
    Smoothness = 0.28,
    FOV = 180,
    TargetPart = "Head",
    Prediction = false,
    PredictionAmount = 0.13,
    LockStickiness = 0.65,        -- Lowered = easier to switch targets
}

local ESPSettings = {
    Enabled = false,
    EnemyHighlight = true,
    TeammateHighlight = false,
    HighlightColor = Color3.fromRGB(0, 255, 130),
    TeammateColor = Color3.fromRGB(80, 255, 180),
    UseBoxes = true,
    UseTracers = true,
    ShowNames = true,
    ShowHealth = true,
    TextSize = 15,
    BoxThickness = 1.6,
}

local CurrentTarget = nil
local isAiming = false
local espObjects = { Highlights = {}, Boxes = {}, Tracers = {}, NameTags = {}, HealthBars = {} }
local FOVCircle = Drawing.new("Circle")

FOVCircle.Thickness = 2
FOVCircle.Color = Color3.fromRGB(255, 70, 70)
FOVCircle.Transparency = 0.65
FOVCircle.Visible = false

-- ==================== HELPERS ====================
local function GetMyTeamSize()
    if not LocalPlayer.Team then return 1 end
    return #LocalPlayer.Team:GetPlayers()
end

local function IsOnSameTeam(player)
    if AimSettings.IsFFA then return false end
    if player == LocalPlayer then return true end
    if not LocalPlayer.Team or not player.Team then return false end
    if GetMyTeamSize() <= 1 then return false end
    return LocalPlayer.Team == player.Team
end

local function IsEnemy(player)
    return not IsOnSameTeam(player)
end

local function GetTargetPart(char)
    return char:FindFirstChild(AimSettings.TargetPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function IsValidTarget(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return IsEnemy(player)
end

local function GetClosestPlayer()
    local closest = nil
    local shortest = AimSettings.FOV + 12
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if not IsValidTarget(player) then continue end

        local char = player.Character
        local targetPart = GetTargetPart(char)
        if not targetPart then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist >= shortest then continue end

        if AimSettings.WallCheck then
            local origin = Camera.CFrame.Position
            local direction = (targetPart.Position - origin).Unit * 4000
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {LocalPlayer.Character}
            params.FilterType = Enum.RaycastFilterType.Exclude

            local result = workspace:Raycast(origin, direction, params)
            if not result or result.Instance:IsDescendantOf(char) then
                shortest = dist
                closest = player
            end
        else
            shortest = dist
            closest = player
        end
    end
    return closest
end

-- ==================== AIMBOT LOOP ====================
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Radius = AimSettings.FOV
    FOVCircle.Visible = AimSettings.Enabled

    if not AimSettings.Enabled then
        CurrentTarget = nil
        return
    end

    local shouldAim = AimSettings.AutoLock or isAiming

    if shouldAim then
        if not CurrentTarget or not IsValidTarget(CurrentTarget) then
            CurrentTarget = GetClosestPlayer()
        else
            local targetPart = GetTargetPart(CurrentTarget.Character)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist > AimSettings.FOV * AimSettings.LockStickiness then
                        CurrentTarget = GetClosestPlayer()
                    end
                else
                    CurrentTarget = GetClosestPlayer()
                end
            end
        end

        if CurrentTarget and CurrentTarget.Character then
            local targetPart = GetTargetPart(CurrentTarget.Character)
            if targetPart then
                local targetPos = targetPart.Position
                if AimSettings.Prediction then
                    local root = CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
                    if root and root.Velocity then
                        targetPos = targetPos + root.Velocity * AimSettings.PredictionAmount
                    end
                end

                local current = Camera.CFrame
                local targetCF = CFrame.lookAt(current.Position, targetPos)
                Camera.CFrame = current:Lerp(targetCF, AimSettings.Smoothness)
            end
        end
    else
        CurrentTarget = nil
    end
end)

-- ==================== ESP ====================
local function ClearAllESP()
    for _, tbl in pairs(espObjects) do
        for player, obj in pairs(tbl) do
            pcall(function()
                if obj and typeof(obj) == "Instance" then obj:Destroy()
                elseif obj and obj.Remove then obj:Remove() end
            end)
        end
        tbl = {}
    end
end

local function RefreshHighlight(player)
    if espObjects.Highlights[player] then
        pcall(function() espObjects.Highlights[player]:Destroy() end)
    end
    if not player.Character then return end

    local hl = Instance.new("Highlight")
    hl.Name = "D4AimHighlight"
    hl.FillTransparency = 1
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = player.Character
    espObjects.Highlights[player] = hl
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    RefreshHighlight(player)

    local box = Drawing.new("Square")
    box.Thickness = ESPSettings.BoxThickness
    box.Filled = false
    box.Transparency = 1
    espObjects.Boxes[player] = box

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1.5
    tracer.Transparency = 0.75
    espObjects.Tracers[player] = tracer

    local nameTag = Drawing.new("Text")
    nameTag.Size = ESPSettings.TextSize
    nameTag.Outline = true
    nameTag.Center = true
    nameTag.Transparency = 1
    espObjects.NameTags[player] = nameTag

    local healthBar = Drawing.new("Square")
    healthBar.Thickness = 1
    healthBar.Filled = true
    healthBar.Transparency = 1
    espObjects.HealthBars[player] = healthBar
end

local function UpdateESP()
    -- Highlights
    for player, hl in pairs(espObjects.Highlights) do
        if not hl then continue end
        local shouldShow = ESPSettings.Enabled and player.Character
        if shouldShow then
            local isEnemyPlr = IsEnemy(player)
            hl.Enabled = (isEnemyPlr and ESPSettings.EnemyHighlight) or (not isEnemyPlr and ESPSettings.TeammateHighlight)
            hl.OutlineColor = isEnemyPlr and ESPSettings.HighlightColor or ESPSettings.TeammateColor
        else
            hl.Enabled = false
        end
    end

    -- Boxes
    for player, box in pairs(espObjects.Boxes) do
        local char = player.Character
        if not char or not ESPSettings.Enabled or not ESPSettings.UseBoxes then
            box.Visible = false
            continue
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then box.Visible = false; continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local isEnemyPlr = IsEnemy(player)
            if (isEnemyPlr and ESPSettings.EnemyHighlight) or (not isEnemyPlr and ESPSettings.TeammateHighlight) then
                box.Visible = true
                box.Color = isEnemyPlr and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 255, 100)
                box.Position = Vector2.new(screenPos.X - 38, screenPos.Y - 70)
                box.Size = Vector2.new(76, 135)
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end

    -- Tracers + Names + Health (same pattern)
    for player, tracer in pairs(espObjects.Tracers) do
        local char = player.Character
        if not char or not ESPSettings.Enabled or not ESPSettings.UseTracers then
            tracer.Visible = false
            continue
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then tracer.Visible = false; continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local isEnemyPlr = IsEnemy(player)
            if (isEnemyPlr and ESPSettings.EnemyHighlight) or (not isEnemyPlr and ESPSettings.TeammateHighlight) then
                tracer.Visible = true
                tracer.Color = isEnemyPlr and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 255, 120)
                tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 25)
                tracer.To = Vector2.new(screenPos.X, screenPos.Y)
            else
                tracer.Visible = false
            end
        else
            tracer.Visible = false
        end
    end

    for player, nameTag in pairs(espObjects.NameTags) do
        local char = player.Character
        if not char or not ESPSettings.Enabled or not ESPSettings.ShowNames then
            nameTag.Visible = false
            continue
        end
        local head = char:FindFirstChild("Head")
        if not head then nameTag.Visible = false; continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 2.8, 0))
        if onScreen then
            local isEnemyPlr = IsEnemy(player)
            if (isEnemyPlr and ESPSettings.EnemyHighlight) or (not isEnemyPlr and ESPSettings.TeammateHighlight) then
                local dist = 0
                local lproot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if lproot then dist = math.floor((lproot.Position - head.Position).Magnitude) end

                nameTag.Visible = true
                nameTag.Text = player.Name .. " [" .. dist .. "]"
                nameTag.Color = isEnemyPlr and Color3.fromRGB(255, 110, 110) or Color3.fromRGB(110, 255, 110)
                nameTag.Position = Vector2.new(screenPos.X, screenPos.Y - 28)
            else
                nameTag.Visible = false
            end
        else
            nameTag.Visible = false
        end
    end

    for player, bar in pairs(espObjects.HealthBars) do
        local char = player.Character
        if not char or not ESPSettings.Enabled or not ESPSettings.ShowHealth then
            bar.Visible = false
            continue
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not root or not hum then bar.Visible = false; continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local isEnemyPlr = IsEnemy(player)
            if (isEnemyPlr and ESPSettings.EnemyHighlight) or (not isEnemyPlr and ESPSettings.TeammateHighlight) then
                local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                bar.Visible = true
                bar.Color = Color3.fromRGB(255 - (255 * healthPercent), 255 * healthPercent, 0)
                bar.Position = Vector2.new(screenPos.X - 42, screenPos.Y - 70 + (135 * (1 - healthPercent)))
                bar.Size = Vector2.new(4, 135 * healthPercent)
            else
                bar.Visible = false
            end
        else
            bar.Visible = false
        end
    end
end

RunService.RenderStepped:Connect(UpdateESP)

-- Periodic ESP Cleanup + Refresh (every 30 seconds)
task.spawn(function()
    while true do
        task.wait(30)
        ClearAllESP()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateESP(player)
            end
        end
    end
end)

-- ==================== INPUT ====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == AimSettings.HoldKey and AimSettings.ToggleLock then
        isAiming = not isAiming
        Rayfield:Notify({Title = "D4Aim", Content = isAiming and "AIM LOCKED ON" or "AIM LOCKED OFF", Duration = 2})
    end
end)

-- ==================== PLAYER HANDLING ====================
for _, plr in ipairs(Players:GetPlayers()) do CreateESP(plr) end

Players.PlayerAdded:Connect(CreateESP)

Players.PlayerRemoving:Connect(function(plr)
    pcall(function()
        if espObjects.Highlights[plr] then espObjects.Highlights[plr]:Destroy() end
        if espObjects.Boxes[plr] then espObjects.Boxes[plr]:Remove() end
        if espObjects.Tracers[plr] then espObjects.Tracers[plr]:Remove() end
        if espObjects.NameTags[plr] then espObjects.NameTags[plr]:Remove() end
        if espObjects.HealthBars[plr] then espObjects.HealthBars[plr]:Remove() end
    end)
end)

LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    task.wait(0.6)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then RefreshHighlight(plr) end
    end
end)

-- ==================== UI ====================
CombatTab:CreateSection("Aimbot Core")
CombatTab:CreateToggle({Name = "Aimbot Enabled", CurrentValue = false, Callback = function(v) AimSettings.Enabled = v end})
CombatTab:CreateToggle({Name = "Auto Lock", CurrentValue = false, Callback = function(v) AimSettings.AutoLock = v end})
CombatTab:CreateToggle({Name = "Toggle Lock (Press Q)", CurrentValue = false, Callback = function(v) AimSettings.ToggleLock = v end})
CombatTab:CreateToggle({Name = "Free For All Mode", CurrentValue = false, Callback = function(v) AimSettings.IsFFA = v end})
CombatTab:CreateToggle({Name = "Wall Check", CurrentValue = true, Callback = function(v) AimSettings.WallCheck = v end})
CombatTab:CreateToggle({Name = "Prediction", CurrentValue = false, Callback = function(v) AimSettings.Prediction = v end})

CombatTab:CreateSection("Aim Tuning")
CombatTab:CreateSlider({Name = "FOV", Range = {40, 700}, Increment = 5, CurrentValue = 180, Callback = function(v) AimSettings.FOV = v end})
CombatTab:CreateSlider({Name = "Smoothness", Range = {0.05, 0.65}, Increment = 0.01, CurrentValue = 0.28, Callback = function(v) AimSettings.Smoothness = v end})
CombatTab:CreateSlider({Name = "Prediction Strength", Range = {0, 0.4}, Increment = 0.01, CurrentValue = 0.13, Callback = function(v) AimSettings.PredictionAmount = v end})
CombatTab:CreateSlider({Name = "Lock Stickiness", Range = {0.3, 1}, Increment = 0.05, CurrentValue = 0.65, Callback = function(v) AimSettings.LockStickiness = v end})

CombatTab:CreateSection("Keybinds")
CombatTab:CreateKeybind({Name = "Aim Toggle Key", CurrentKeybind = "Q", Callback = function(k) AimSettings.HoldKey = k end})

VisualsTab:CreateSection("ESP")
VisualsTab:CreateToggle({Name = "ESP Enabled", CurrentValue = false, Callback = function(v) ESPSettings.Enabled = v end})
VisualsTab:CreateToggle({Name = "Enemy Highlights", CurrentValue = true, Callback = function(v) ESPSettings.EnemyHighlight = v end})
VisualsTab:CreateToggle({Name = "Teammate Highlights", CurrentValue = false, Callback = function(v) ESPSettings.TeammateHighlight = v end})

VisualsTab:CreateSection("ESP Elements")
VisualsTab:CreateToggle({Name = "2D Boxes", CurrentValue = true, Callback = function(v) ESPSettings.UseBoxes = v end})
VisualsTab:CreateToggle({Name = "Tracers", CurrentValue = true, Callback = function(v) ESPSettings.UseTracers = v end})
VisualsTab:CreateToggle({Name = "Names + Distance", CurrentValue = true, Callback = function(v) ESPSettings.ShowNames = v end})
VisualsTab:CreateToggle({Name = "Health Bars", CurrentValue = true, Callback = function(v) ESPSettings.ShowHealth = v end})

VisualsTab:CreateSection("Colors")
VisualsTab:CreateColorPicker({Name = "Enemy Highlight Color", Color = ESPSettings.HighlightColor, Callback = function(c) ESPSettings.HighlightColor = c end})
VisualsTab:CreateColorPicker({Name = "Teammate Highlight Color", Color = ESPSettings.TeammateColor, Callback = function(c) ESPSettings.TeammateColor = c end})

MiscTab:CreateSection("Info")
MiscTab:CreateParagraph({Title = "Controls", Content = "Left Alt = Menu\nQ = Toggle Aim\n\nLower Stickiness = easier to switch targets\nESP cleans itself every 30 seconds"})
MiscTab:CreateButton({Name = "Unload D4Aim", Callback = function()
    Rayfield:Destroy()
    FOVCircle:Remove()
    ClearAllESP()
end})

task.wait(0.8)
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title = "D4Aim",
    Content = "Loaded\nESP now cleans every 30s\nStickiness lowered for easier switching",
    Duration = 6
})
