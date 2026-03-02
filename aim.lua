local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local lp = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local COOLDOWN   = 0.2
local AIM_RANGE  = 999999
local atkRange   = 20
local atkInf     = true
local aaOn       = false
local apAtkOn    = false
local camLockP   = false
local camLockM   = false
local aimbotOn   = false
local hbEnabled  = false
local hbSize     = 25
local dashEnabled = false
local dashPower  = 160
local autoM1On   = false

for _, v in pairs(CoreGui:GetChildren()) do
    if v.Name == "FyZe_Delta_Permanent" then
        v:Destroy()
    end
end

local mGui = Instance.new("ScreenGui")
mGui.Name = "FyZe_Delta_Permanent"
mGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
mGui.DisplayOrder = 999999999
mGui.ResetOnSpawn = false
mGui.Parent = CoreGui

local icon = Instance.new("ImageButton", mGui)
icon.Name = "ToggleIcon"
icon.Size = UDim2.new(0, 55, 0, 55)
icon.Position = UDim2.new(0, 20, 0, 200)
icon.BackgroundColor3 = Color3.fromRGB(65, 100, 240)
icon.Image = "rbxassetid://6031094678"
icon.ZIndex = 1000000000
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
local iStroke = Instance.new("UIStroke", icon)
iStroke.Color = Color3.new(1,1,1)
iStroke.Thickness = 2

local mf = Instance.new("Frame", mGui)
mf.Name = "MainFrame"
mf.Size = UDim2.new(0, 260, 0, 450)
mf.Position = UDim2.new(0.5, -130, 0.5, -225)
mf.BackgroundColor3 = Color3.fromRGB(11, 11, 16)
mf.BorderSizePixel = 0
mf.Visible = true 
mf.ZIndex = 999999998
Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 10)
local mStroke = Instance.new("UIStroke", mf)
mStroke.Color = Color3.fromRGB(65, 100, 240)
mStroke.Thickness = 2

local scroll = Instance.new("ScrollingFrame", mf)
scroll.Size = UDim2.new(1, 0, 1, -20)
scroll.Position = UDim2.new(0, 0, 0, 10)
scroll.BackgroundTransparency = 1
scroll.CanvasSize = UDim2.new(0, 0, 0, 1100)
scroll.ScrollBarThickness = 2
scroll.ZIndex = 999999999
local list = Instance.new("UIListLayout", scroll)
list.Padding = UDim.new(0, 6)
list.HorizontalAlignment = "Center"

local function mkRow(txt)
    local fr = Instance.new("Frame", scroll)
    fr.Size = UDim2.new(0.92, 0, 0, 38)
    fr.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    fr.ZIndex = 999999999
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
    
    local lb = Instance.new("TextLabel", fr)
    lb.Size = UDim2.new(0.6, 0, 1, 0)
    lb.Position = UDim2.new(0, 12, 0, 0)
    lb.Text = txt
    lb.TextColor3 = Color3.white
    lb.Font = Enum.Font.GothamBold
    lb.TextSize = 11
    lb.BackgroundTransparency = 1
    lb.TextXAlignment = "Left"
    lb.ZIndex = 1000000000

    local btn = Instance.new("TextButton", fr)
    btn.Size = UDim2.new(0, 42, 0, 22)
    btn.Position = UDim2.new(1, -50, 0.5, -11)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    btn.Text = ""
    btn.ZIndex = 1000000000
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    
    local dot = Instance.new("Frame", btn)
    dot.Size = UDim2.new(0, 16, 0, 16)
    dot.Position = UDim2.new(0, 3, 0.5, -8)
    dot.BackgroundColor3 = Color3.white
    dot.ZIndex = 1000000001
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    
    return btn, dot
end

local m1B, m1D = mkRow("Auto M1")
local abB, abD = mkRow("Silent Aim")
local aaB, aaD = mkRow("NPC Aura")
local apB, apD = mkRow("Player Aura")
local clmB, clmD = mkRow("Lock NPCs")
local clpB, clpD = mkRow("Lock Players")
local hbB, hbD = mkRow("Hitbox")
local dsB, dsD = mkRow("Dash Boost")

local function getTgt(mobs, players, range)
    local t, d = nil, range or AIM_RANGE
    local pool = {}
    if mobs then for _, v in pairs(workspace.Enemies:GetChildren()) do table.insert(pool, v) end end
    if players then for _, p in pairs(Players:GetPlayers()) do if p ~= lp and p.Character then table.insert(pool, p.Character) end end end
    for _, v in pairs(pool) do
        if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            local dist = (lp.Character.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
            if dist < d then d = dist; t = v end
        end
    end
    return t
end

task.spawn(function()
    while true do
        if autoM1On or aaOn or apAtkOn then
            local target = getTgt(aaOn or autoM1On, apAtkOn, atkInf and 999999 or atkRange)
            if target then
                pcall(function()
                    local t = lp.Character:FindFirstChildOfClass("Tool")
                    local r = t and (t:FindFirstChild("LeftClickRemote") or t:FindFirstChild("RemoteEvent"))
                    if r then r:FireServer(target.HumanoidRootPart.Position, 1, true) end
                end)
            end
        end
        task.wait(COOLDOWN)
    end
end)

local old; old = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if aimbotOn and (method == "FireServer" or method == "InvokeServer") then
        local target = getTgt(true, true, AIM_RANGE)
        if target and (self.Name:find("Attack") or self.Name:find("Skill")) then
            args[1] = target.HumanoidRootPart.Position
        end
    end
    return old(self, unpack(args))
end)

RunService.RenderStepped:Connect(function()
    if camLockM or camLockP then
        local target = getTgt(camLockM, camLockP, 400)
        if target then Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.HumanoidRootPart.Position) end
    end
end)

RunService.Heartbeat:Connect(function()
    if hbEnabled then
        for _, v in pairs(workspace.Enemies:GetChildren()) do
            if v:FindFirstChild("HumanoidRootPart") then v.HumanoidRootPart.Size = Vector3.new(hbSize, hbSize, hbSize) end
        end
    end
    if dashEnabled and lp.Character:FindFirstChild("HumanoidRootPart") then
        local d = lp.Character.HumanoidRootPart:FindFirstChild("Dash") or lp.Character.HumanoidRootPart:FindFirstChild("t")
        if d and d:IsA("BodyVelocity") then d.Velocity = d.Velocity.Unit * dashPower end
    end
end)

local function toggle(on, btn, dot)
    btn.BackgroundColor3 = on and Color3.fromRGB(65, 100, 240) or Color3.fromRGB(45, 45, 60)
    dot:TweenPosition(on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8), "Out", "Quad", 0.15, true)
end

m1B.MouseButton1Click:Connect(function() autoM1On = not autoM1On; toggle(autoM1On, m1B, m1D) end)
abB.MouseButton1Click:Connect(function() aimbotOn = not aimbotOn; toggle(aimbotOn, abB, abD) end)
aaB.MouseButton1Click:Connect(function() aaOn = not aaOn; toggle(aaOn, aaB, aaD) end)
apB.MouseButton1Click:Connect(function() apAtkOn = not apAtkOn; toggle(apAtkOn, apB, apD) end)
clmB.MouseButton1Click:Connect(function() camLockM = not camLockM; toggle(camLockM, clmB, clmD) end)
clpB.MouseButton1Click:Connect(function() camLockP = not camLockP; toggle(camLockP, clpB, clpD) end)
hbB.MouseButton1Click:Connect(function() hbEnabled = not hbEnabled; toggle(hbEnabled, hbB, hbD) end)
dsB.MouseButton1Click:Connect(function() dashEnabled = not dashEnabled; toggle(dashEnabled, dsB, dsD) end)

icon.MouseButton1Click:Connect(function() 
    mf.Visible = not mf.Visible 
end)

local drag, start, origin = false, nil, nil
icon.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then drag=true; start=inp.Position; origin=icon.Position end end)
UIS.InputChanged:Connect(function(inp) if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then local d = inp.Position-start; icon.Position = UDim2.new(origin.X.Scale, origin.X.Offset+d.X, origin.Y.Scale, origin.Y.Offset+d.Y) end end)
UIS.InputEnded:Connect(function() drag=false end)
