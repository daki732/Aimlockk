-- MM2 Murderer Aim Lock V2 (Optimized + Prediction)
local shared = odh_shared_plugins
local my_section = shared.AddSection("MM2 Aim Lock V2")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

-- Settings
local AimLockEnabled = false
local TargetPart = "HumanoidRootPart" -- Изменено на корректное системное имя
local TargetPlayer = nil
local WallCheckEnabled = false
local ShowBindableButton = true
local ButtonLocked = false

-- Aim Settings (Настройки аимбота)
local PredictionLevel = 0.145 -- Упреждение (Lead)
local Smoothness = 0.65 -- Сглаживание (чем меньше, тем плавнее)

local AimButton = nil
local ButtonGui = nil
local LastSearchTime = 0

-- Массив названий оружия убийцы для точного детектирования
local MurdererWeapons = {
    "knife", "blade", "dagger", "saw", "slasher", "axe", "scythe", 
    "peppermint", "cookie", "edge", "batwing", "icewing", "bone", "hallow", "vampire"
}

-- Menu
my_section:AddLabel("Credits: @anya_bts | Upgraded V2")
my_section:AddParagraph("MM2 Aim Lock V2", "Added Prediction & Smoothness")
my_section:AddToggle("Enable Aim Lock", function(b)
    AimLockEnabled = b
    UpdateButtonState()
    if b and not IsLobby() then TargetPlayer = FindMurderer() end
end)
my_section:AddToggle("Show Bindable Button", function(b)
    ShowBindableButton = b
    ToggleBindableVisibility()
end)
my_section:AddToggle("Lock Button Position", function(b)
    ButtonLocked = b
    shared.Notify("Button "..(b and "Locked" or "Unlocked"), 1.5)
end)
my_section:AddToggle("Wall Check", function(b)
    WallCheckEnabled = b
    shared.Notify("Wall Check: "..(b and "On" or "Off"), 2)
end)

-- Исправлен маппинг частей тела
my_section:AddDropdown("Target Part", {"Head", "Torso (Root)"}, function(s) 
    if s == "Head" then
        TargetPart = "Head"
    else
        TargetPart = "HumanoidRootPart"
    end
end)

-- Выбор уровня упреждения (Prediction)
my_section:AddDropdown("Prediction Level", {"Low", "Medium (Best)", "High", "None"}, function(s)
    if s == "Low" then PredictionLevel = 0.08
    elseif s == "Medium (Best)" then PredictionLevel = 0.145
    elseif s == "High" then PredictionLevel = 0.2
    else PredictionLevel = 0 end
end)

my_section:AddKeybind("Toggle Key", "T", function()
    AimLockEnabled = not AimLockEnabled
    UpdateButtonState()
    if AimLockEnabled and not IsLobby() then
        TargetPlayer = FindMurderer()
    else
        TargetPlayer = nil
    end
end)

-- Lobby Check
function IsLobby()
    local c = LocalPlayer.Character
    if not c then return true end
    local r = c:FindFirstChild("HumanoidRootPart")
    return not (r and r.Position.Y >= 180 and r.Position.Y <= 380)
end

-- Visibility Check
function IsVisible(target)
    if not target or not target.Character then return false end
    local p = target.Character:FindFirstChild(TargetPart)
    if not p then return false end
    local pr = RaycastParams.new()
    pr.FilterDescendantsInstances = {LocalPlayer.Character}
    pr.FilterType = Enum.RaycastFilterType.Blacklist
    local res = workspace:Raycast(Camera.CFrame.Position, p.Position - Camera.CFrame.Position, pr)
    return not res or res.Instance:IsDescendantOf(target.Character)
end

-- Advanced Murderer Check
function CheckForKnife(container)
    if not container then return false end
    for _, item in ipairs(container:GetChildren()) do
        if item:IsA("Tool") then
            local name = item.Name:lower()
            for _, weaponName in ipairs(MurdererWeapons) do
                if name:find(weaponName) then
                    return true
                end
            end
        end
    end
    return false
end

-- Find Murderer
function FindMurderer()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local hum = pl.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local hasKnife = CheckForKnife(pl.Character) or CheckForKnife(pl:FindFirstChild("Backpack"))
                
                if hasKnife and (not WallCheckEnabled or IsVisible(pl)) then
                    return pl
                end
            end
        end
    end
    return nil
end

-- Main Aim Loop (Optimized with Prediction & Lerp)
RunService.RenderStepped:Connect(function()
    if not AimLockEnabled or IsLobby() then return end
    
    local valid = TargetPlayer and TargetPlayer.Character and TargetPlayer.Character:FindFirstChild("Humanoid") and TargetPlayer.Character.Humanoid.Health > 0
    
    if WallCheckEnabled and valid and not IsVisible(TargetPlayer) then
        valid = false
    end
    
    -- Оптимизация: ищем убийцу не каждый кадр, а раз в 0.5 секунд, чтобы не сажать FPS
    if not valid then 
        TargetPlayer = nil
        local currentTime = os.clock()
        if currentTime - LastSearchTime > 0.5 then
            TargetPlayer = FindMurderer()
            LastSearchTime = currentTime
        end
    end
    
    if TargetPlayer and TargetPlayer.Character then
        local targetNode = TargetPlayer.Character:FindFirstChild(TargetPart)
        
        if targetNode then
            -- Высчитываем скорость для упреждения
            local targetVelocity = targetNode.AssemblyLinearVelocity
            -- Слегка занижаем Y упреждение, чтобы прицел не улетал в космос при прыжке
            local predictedPos = targetNode.Position + Vector3.new(targetVelocity.X, targetVelocity.Y * 0.5, targetVelocity.Z) * PredictionLevel
            
            local targetCFrame = CFrame.new(Camera.CFrame.Position, predictedPos)
            
            -- Плавная наводка (Lerp)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Smoothness)
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    TargetPlayer = nil
    AimLockEnabled = false
    UpdateButtonState()
end)

-- ==============================================
-- SMALLER CIRCLE BUTTON
-- ==============================================
local function CreateBindableButton()
    ButtonGui = Instance.new("ScreenGui")
    ButtonGui.Name = "AimLockToggle"
    ButtonGui.ResetOnSpawn = false
    ButtonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ButtonGui.Parent = CoreGui

    AimButton = Instance.new("TextButton")
    AimButton.Name = "CircleToggle"
    AimButton.Size = UDim2.new(0, 52, 0, 52)
    AimButton.Position = UDim2.new(0.05,0,0.5,0)
    AimButton.BackgroundTransparency = 0.4
    AimButton.BackgroundColor3 = Color3.fromRGB(30,30,30)
    AimButton.Text = "OFF"
    AimButton.TextColor3 = Color3.fromRGB(180,180,180)
    AimButton.Font = Enum.Font.GothamMedium
    AimButton.TextSize = 11
    AimButton.AutoButtonColor = false
    AimButton.ClipsDescendants = true
    AimButton.Active = true
    AimButton.Parent = ButtonGui

    Instance.new("UICorner", AimButton).CornerRadius = UDim.new(1,0)

    local Border = Instance.new("UIStroke")
    Border.Name = "Glow"
    Border.Thickness = 2
    Border.Transparency = 0.2
    Border.Color = Color3.fromRGB(70,200,120)
    Border.Parent = AimButton

    local dragging = false
    local startPos, startMouse = nil, nil
    local clickThreshold = 6

    AimButton.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = AimButton.Position
            startMouse = i.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(i)
        if dragging and not ButtonLocked and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startMouse
            AimButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragging and startMouse then
                if (i.Position - startMouse).Magnitude <= clickThreshold then
                    AimLockEnabled = not AimLockEnabled
                    UpdateButtonState()
                    if AimLockEnabled and not IsLobby() then TargetPlayer = FindMurderer() else TargetPlayer = nil end
                end
            end
            dragging, startPos, startMouse = false, nil, nil
        end
    end)
end

function ToggleBindableVisibility()
    if ButtonGui then ButtonGui.Enabled = ShowBindableButton end
end

function UpdateButtonState()
    if not AimButton then return end
    local border = AimButton:FindFirstChild("Glow")
    if AimLockEnabled then
        AimButton.Text = "ON"
        AimButton.TextColor3 = Color3.new(1,1,1)
        if border then border.Color = Color3.fromRGB(80,220,140) end
    else
        AimButton.Text = "OFF"
        AimButton.TextColor3 = Color3.fromRGB(170,170,170)
        if border then border.Color = Color3.fromRGB(70,160,110) end
    end
end

CreateBindableButton()
ToggleBindableVisibility()

print("MM2 Aim Lock V2 Loaded - Prediction Engine Active")
