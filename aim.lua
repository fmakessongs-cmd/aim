-- FyZe Hub | Optimized for Delta/Mobile
local Players    = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenSvc     = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")
local lp           = Players.LocalPlayer
local mouse        = lp:GetMouse()
local Camera       = workspace.CurrentCamera

local tw = task.wait
local ts = task.spawn

-- UI Safety Functions
local function safeParent(gui)
    local success = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not success then
        gui.Parent = lp:WaitForChild("PlayerGui")
    end
end

local function destroyOld(name)
    pcall(function()
        local g1 = game:GetService("CoreGui"):FindFirstChild(name)
        if g1 then g1:Destroy() end
        local g2 = lp.PlayerGui:FindFirstChild(name)
        if g2 then g2:Destroy() end
    end)
end

-- State Variables
local atkRange = 60
local atkInf = false
local aaOn = false
local apAtkOn = false
local camLockP = false
local camLockM = false
local silentAim = false
local espOn = true
local hitboxOn = false
local dashOn = false
local uiOpen = true
local autoCollect = false
local minimized = false

-- Font Config
local FB = Enum.Font.SourceSansBold
local FR = Enum.Font.SourceSans
pcall(function() FB = Enum.Font.GothamBold; FR = Enum.Font.Gotham end)

-- UI Helper: Corners & Strokes
local function addUI(ins, rad, col, thk)
    if rad then
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, rad)
        c.Parent = ins
    end
    if col then
        local s = Instance.new("UIStroke")
        s.Color = col
        s.Thickness = thk or 1
        s.Parent = ins
    end
end

-- ────────────────────────── MAIN UI ──────────────────────────
destroyOld("FyZePanel")
local mGui = Instance.new("ScreenGui")
mGui.Name = "FyZePanel"
mGui.ResetOnSpawn = false
safeParent(mGui)

local mf = Instance.new("Frame")
mf.Name = "MainFrame"
mf.Size = UDim2.new(0, 225, 0, 350)
mf.Position = UDim2.new(0.5, -112, 0.4, -175)
mf.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
mf.ClipsDescendants = true
mf.Visible = true -- Forced visible
mf.Active = true
mf.Draggable = true -- Delta supports legacy drag
mf.Parent = mGui
addUI(mf, 8, Color3.fromRGB(60, 90, 255), 1)

local tb = Instance.new("Frame")
tb.Size = UDim2.new(1, 0, 0, 30)
tb.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
tb.Parent = mf
addUI(tb, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -10, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FYZE HUB | KITSUNE"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = FB
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = tb

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, -35)
scroll.Position = UDim2.new(0, 0, 0, 35)
scroll.BackgroundTransparency = 1
scroll.CanvasSize = UDim2.new(0, 0, 0, 600)
scroll.ScrollBarThickness = 2
scroll.Parent = mf

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 5)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Parent = scroll

-- ────────────────────────── FUNCTIONS ──────────────────────────

-- Toggle Builder
local function createToggle(name, default, callback)
    local state = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 200, 0, 30)
    btn.BackgroundColor3 = state and Color3.fromRGB(40, 150, 80) or Color3.fromRGB(40, 40, 50)
    btn.Text = name .. ": " .. (state and "ON" or "OFF")
    btn.Font = FR
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Parent = scroll
    addUI(btn, 6)

    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(40, 150, 80) or Color3.fromRGB(40, 40, 50)
        btn.Text = name .. ": " .. (state and "ON" or "OFF")
        callback(state)
    end)
end

-- Kitsune Kill Aura Logic
local function getKitsuneRemote()
    local tool = lp.Character and lp.Character:FindFirstChild("Kitsune-Kitsune")
    return tool and tool:FindFirstChild("LeftClickRemote")
end

ts(function()
    while true do
        if aaOn or apAtkOn then
            local remote = getKitsuneRemote()
            if remote then
                for _, enemy in ipairs(workspace.Enemies:GetChildren()) do
                    local hum = enemy:FindFirstChild("Humanoid")
                    local root = enemy:FindFirstChild("HumanoidRootPart")
                    if hum and root and hum.Health > 0 then
                        local dist = (lp.Character.HumanoidRootPart.Position - root.Position).Magnitude
                        if dist <= atkRange or atkInf then
                            remote:FireServer(root.Position)
                            tw(0.1)
                        end
                    end
                end
            end
        end
        tw(0.5)
    end
end)

-- ────────────────────────── WIRING ──────────────────────────

createToggle("Kill Aura (NPC)", false, function(v) aaOn = v end)
createToggle("Player ESP", true, function(v) espOn = v end)
createToggle("Hitbox Expander", false, function(v) 
    hitboxOn = v 
    if v then
        ts(function()
            while hitboxOn do
                for _, e in ipairs(workspace.Enemies:GetChildren()) do
                    if e:FindFirstChild("HumanoidRootPart") then
                        e.HumanoidRootPart.Size = Vector3.new(20, 20, 20)
                        e.HumanoidRootPart.Transparency = 0.8
                    end
                end
                tw(1)
            end
        end)
    end
end)

createToggle("Infinite Range", false, function(v) atkInf = v end)

-- Close Button (Internal Toggle)
UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
        uiOpen = not uiOpen
        mf.Visible = uiOpen
    end
end)

-- Float/Sky TP Feature
local skyBtn = Instance.new("TextButton")
skyBtn.Size = UDim2.new(0, 200, 0, 30)
skyBtn.Text = "Teleport to Sky (Safe Farm)"
skyBtn.Parent = scroll
addUI(skyBtn, 6)
skyBtn.MouseButton1Click:Connect(function()
    local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = hrp.CFrame * CFrame.new(0, 500, 0)
    end
end)

print("FyZe Hub Loaded Successfully")
