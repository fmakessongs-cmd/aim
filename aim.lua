local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local lp = Players.LocalPlayer
local unpack = table.unpack or unpack

local COOLDOWN   = 0.2
local AIM_RANGE  = 999999
local atkRange   = 20
local atkInf     = true
local aaOn       = false
local apAtkOn    = false
local camLockP   = false
local camLockM   = false
local aimbotOn   = false
local espOn      = true
local hbEnabled  = false
local hbSize     = 25
local dashEnabled = false
local dashPower  = 160
local autoM1On   = false

local function safeGUI(g)
    local ok, h = pcall(function() return gethui() end)
    g.Parent = (ok and h) and h or lp:WaitForChild("PlayerGui")
end

local mGui = Instance.new("ScreenGui")
mGui.Name = "FyZe_NoComments"; mGui.ResetOnSpawn = false; mGui.IgnoreGuiInset = true; mGui.DisplayOrder = 999
safeGUI(mGui)

local icon = Instance.new("ImageButton", mGui)
icon.Size = UDim2.new(0, 50, 0, 50); icon.Position = UDim2.new(0, 10, 0, 150)
icon.BackgroundColor3 = Color3.fromRGB(65, 100, 240); icon.Image = "rbxassetid://6031094678"; icon.ZIndex = 10
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", icon).Color = Color3.white

local mf = Instance.new("Frame", mGui)
mf.Size = UDim2.new(0, 260, 0, 500); mf.Position = UDim2.new(0.5, -130, 0.5, -250)
mf.BackgroundColor3 = Color3.fromRGB(11, 11, 16); mf.Visible = true; mf.ClipsDescendants = true
Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 9)
Instance.new("UIStroke", mf).Color = Color3.fromRGB(65, 100, 240)

local scroll = Instance.new("ScrollingFrame", mf)
scroll.Size = UDim2.new(1, 0, 1, -10); scroll.Position = UDim2.new(0, 0, 0, 10)
scroll.BackgroundTransparency = 1; scroll.CanvasSize = UDim2.new(0, 0, 0, 1200); scroll.ScrollBarThickness = 3
local list = Instance.new("UIListLayout", scroll); list.Padding = UDim.new(0, 4); list.HorizontalAlignment = "Center"

local function mkRow(txt)
    local fr = Instance.new("Frame", scroll); fr.Size = UDim2.new(0.95, 0, 0, 34)
    fr.BackgroundColor3 = Color3.fromRGB(18, 18, 28); fr.BorderSizePixel = 0; Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 5)
    local lb = Instance.new("TextLabel", fr); lb.Size = UDim2.new(0.6, 0, 1, 0); lb.Position = UDim2.new(0, 10, 0, 0)
    lb.BackgroundTransparency = 1; lb.Text = txt; lb.TextColor3 = Color3.white; lb.Font = Enum.Font.GothamBold; lb.TextSize = 10; lb.TextXAlignment = "Left"
    local st = Instance.new("TextLabel", fr); st.Size = UDim2.new(0.25, 0, 1, 0); st.Position = UDim2.new(0.55, 0, 0, 0)
    st.BackgroundTransparency = 1; st.Text = "OFF"; st.TextColor3 = Color3.fromRGB(255, 70, 70); st.Font = Enum.Font.GothamBold; st.TextSize = 9; st.TextXAlignment = "Right"
    local btn = Instance.new("TextButton", fr); btn.Size = UDim2.new(0, 38, 0, 20); btn.Position = UDim2.new(1, -45, 0.5, -10)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60); btn.Text = ""; Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local dot = Instance.new("Frame", btn); dot.Size = UDim2.new(0, 14, 0, 14); dot.Position = UDim2.new(0, 3, 0.5, -7)
    dot.BackgroundColor3 = Color3.fromRGB(200, 200, 200); Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    return btn, dot, st
end

local m1B, m1D, m1S = mkRow("Auto Fruit M1")
local abB, abD, abS = mkRow("Silent Aim (No Rot)")
local aaB, aaD, aaS = mkRow("NPC Kill Aura")
local apB, apD, apS = mkRow("Player Kill Aura")
local clmB, clmD, clmS = mkRow("Cam Lock NPCs")
local clpB, clpD, clpS = mkRow("Cam Lock Players")
local hbB, hbD, hbS = mkRow("Hitbox Expander")
local dsB, dsD, dsS = mkRow("Dash Expander")

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
        if target and (self.Name:find("Attack") or self.Name:find("Skill") or self.Name == "RemoteEvent") then
            args[1] = target.HumanoidRootPart.Position
        end
    end
    return old(self, unpack(args))
end)

RunService.RenderStepped:Connect(function()
    if camLockM or camLockP then
        local target = getTgt(camLockM, camLockP, 400)
        if target then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.HumanoidRootPart.Position)
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if hbEnabled then
        for _, v in pairs(workspace.Enemies:GetChildren()) do
            if v:FindFirstChild("HumanoidRootPart") then
                v.HumanoidRootPart.Size = Vector3.new(hbSize, hbSize, hbSize); v.HumanoidRootPart.Transparency = 0.7
            end
        end
    end
    if dashEnabled and lp.Character:FindFirstChild("HumanoidRootPart") then
        local d = lp.Character.HumanoidRootPart:FindFirstChild("Dash") or lp.Character.HumanoidRootPart:FindFirstChild("t")
        if d and d:IsA("BodyVelocity") then d.Velocity = d.Velocity.Unit * dashPower end
    end
end)

local function setT(on, btn, dot, stl)
    btn.BackgroundColor3 = on and Color3.fromRGB(65, 100, 240) or Color3.fromRGB(45, 45, 60)
    dot.Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    stl.Text = on and "ON" or "OFF"; stl.TextColor3 = on and Color3.fromRGB(80, 255, 100) or Color3.fromRGB(255, 70, 70)
end

m1B.MouseButton1Click:Connect(function() autoM1On = not autoM1On; setT(autoM1On, m1B, m1D, m1S) end)
abB.MouseButton1Click:Connect(function() aimbotOn = not aimbotOn; setT(aimbotOn, abB, abD, abS) end)
aaB.MouseButton1Click:Connect(function() aaOn = not aaOn; setT(aaOn, aaB, aaD, aaS) end)
apB.MouseButton1Click:Connect(function() apAtkOn = not apAtkOn; setT(apAtkOn, apB, apD, apS) end)
clmB.MouseButton1Click:Connect(function() camLockM = not camLockM; setT(camLockM, clmB, clmD, clmS) end)
clpB.MouseButton1Click:Connect(function() camLockP = not camLockP; setT(clpB, clpB, clpD, clpS) end)
hbB.MouseButton1Click:Connect(function() hbEnabled = not hbEnabled; setT(hbEnabled, hbB, hbD, hbS) end)
dsB.MouseButton1Click:Connect(function() dashEnabled = not dashEnabled; setT(dashEnabled, dsB, dsD, dsS) end)
icon.MouseButton1Click:Connect(function() mf.Visible = not mf.Visible end)

local drag, start, origin = false, nil, nil
icon.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then drag=true; start=inp.Position; origin=icon.Position end end)
UIS.InputChanged:Connect(function(inp) if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then local d = inp.Position-start; icon.Position = UDim2.new(origin.X.Scale, origin.X.Offset+d.X, origin.Y.Scale, origin.Y.Offset+d.Y) end end)
UIS.InputEnded:Connect(function() drag=false end)
