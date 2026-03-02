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

local function tryFont(n)
	local ok,v = pcall(function() return Enum.Font[n] end)
	return (ok and v) or Enum.Font.SourceSansBold
end
local FB = tryFont("GothamBold")
local FR = tryFont("Gotham")

local function safeGUI(g)
	local ok,h = pcall(function() return gethui() end)
	g.Parent = (ok and h) and h or lp:WaitForChild("PlayerGui")
end

local eGui = Instance.new("ScreenGui")
eGui.Name = "FyZeESP"; eGui.ResetOnSpawn = false; eGui.IgnoreGuiInset = true
safeGUI(eGui)

local mGui = Instance.new("ScreenGui")
mGui.Name = "FyZePanel"; mGui.ResetOnSpawn = false; mGui.IgnoreGuiInset = true
safeGUI(mGui)

local icon = Instance.new("ImageButton", mGui)
icon.Size = UDim2.new(0, 50, 0, 50)
icon.Position = UDim2.new(0, 10, 0, 150)
icon.BackgroundColor3 = Color3.fromRGB(65, 100, 240)
icon.Image = "rbxassetid://6031094678"
Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", icon).Color = Color3.white

local mf = Instance.new("Frame",mGui)
mf.Size = UDim2.new(0,260,0,450)
mf.Position = UDim2.new(0,70,0,50)
mf.BackgroundColor3 = Color3.fromRGB(11,11,16)
mf.BorderSizePixel = 0; mf.ClipsDescendants = true
Instance.new("UICorner",mf).CornerRadius = UDim.new(0,9)
local ms = Instance.new("UIStroke",mf); ms.Color = Color3.fromRGB(65,100,240); ms.Thickness = 1.2

local tb = Instance.new("Frame",mf)
tb.Size = UDim2.new(1,0,0,36); tb.BackgroundColor3 = Color3.fromRGB(18,18,26); tb.BorderSizePixel = 0
Instance.new("UICorner",tb).CornerRadius = UDim.new(0,9)
local tl = Instance.new("TextLabel",tb); tl.Size = UDim2.new(1,-10,1,0); tl.Position = UDim2.new(0,10,0,0)
tl.BackgroundTransparency = 1; tl.Text = "FyZe V2 | Blox Fruits"; tl.TextColor3 = Color3.white; tl.Font = FB; tl.TextSize = 13; tl.TextXAlignment = "Left"

local scrollMain = Instance.new("ScrollingFrame", mf)
scrollMain.Size = UDim2.new(1, 0, 1, -40); scrollMain.Position = UDim2.new(0, 0, 0, 40)
scrollMain.BackgroundTransparency = 1; scrollMain.CanvasSize = UDim2.new(0, 0, 0, 950); scrollMain.ScrollBarThickness = 3
local mainLayout = Instance.new("UIListLayout", scrollMain); mainLayout.Padding = UDim.new(0, 2); mainLayout.HorizontalAlignment = "Center"

local function mkRow(txt)
	local fr = Instance.new("Frame",scrollMain); fr.Size = UDim2.new(0.95,0,0,32)
	fr.BackgroundColor3 = Color3.fromRGB(16,16,24); fr.BorderSizePixel = 0
	local lb = Instance.new("TextLabel",fr); lb.Size = UDim2.new(0.58,0,1,0); lb.Position = UDim2.new(0,10,0,0)
	lb.BackgroundTransparency = 1; lb.Text = txt; lb.TextColor3 = Color3.fromRGB(195,195,195); lb.Font = FB; lb.TextSize = 11; lb.TextXAlignment = "Left"
	local st = Instance.new("TextLabel",fr); st.Size = UDim2.new(0.3,0,1,0); st.Position = UDim2.new(0.60,0,0,0)
	st.BackgroundTransparency = 1; st.Text = "OFF"; st.TextColor3 = Color3.fromRGB(255,65,65); st.Font = FB; st.TextSize = 11; st.TextXAlignment = "Right"
	local btn = Instance.new("TextButton",fr); btn.Size = UDim2.new(0,36,0,20)
	btn.Position = UDim2.new(1,-44,0.5,-10); btn.BackgroundColor3 = Color3.fromRGB(50,50,70); btn.Text = ""
	Instance.new("UICorner",btn).CornerRadius = UDim.new(1,0)
	local dot = Instance.new("Frame",btn); dot.Size = UDim2.new(0,14,0,14); dot.Position = UDim2.new(0,3,0.5,-7)
	dot.BackgroundColor3 = Color3.fromRGB(140,140,140); Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)
	return fr, btn, dot, st
end

local function mkTpBtn(label, col)
	local b = Instance.new("TextButton",scrollMain); b.Size = UDim2.new(0.95,0,0,30)
	b.BackgroundColor3 = col; b.Text = label; b.TextColor3 = Color3.white; b.Font = FB; b.TextSize = 11
	Instance.new("UICorner",b).CornerRadius = UDim.new(0,6); return b
end

local m1Fr,m1B,m1D,m1St = mkRow("Auto Fruit M1")
local abFr,abB,abD,abSt = mkRow("Inf Silent Aim")
local hbFr,hbB,hbD,hbSt = mkRow("Hitbox Expander")
local dsFr,dsB,dsD,dsSt = mkRow("Dash Expander")
local jmpB = mkTpBtn("⚡ EXTERNAL JUMP", Color3.fromRGB(150, 120, 30))
local tpSCBtn = mkTpBtn("🏰 Sea Castle", Color3.fromRGB(30,50,90))
local tpManBtn = mkTpBtn("🏠 Mansion", Color3.fromRGB(70,40,20))

local function jitter(base, amt) return base + (math.random()*amt*2-amt)*0.001 end

local function getKitsuneLC()
	local char = lp.Character; if not char then return nil end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool then
		return tool:FindFirstChild("LeftClickRemote") or tool:FindFirstChild("RemoteEvent")
	end
	return nil
end

task.spawn(function()
	while true do
		if autoM1On then
			local lc = getKitsuneLC()
			if lc then pcall(function() lc:FireServer(Vector3.new(0,0,0), 1, true) end) end
		end
		task.wait(jitter(0.12, 15))
	end
end)

local function nearestTarget(range)
	local char = lp.Character; if not char then return nil end
	local best, bestD = nil, range or math.huge
	local targets = {}
	for _, v in pairs(workspace.Enemies:GetChildren()) do table.insert(targets, v) end
	for _, v in pairs(Players:GetPlayers()) do if v ~= lp and v.Character then table.insert(targets, v.Character) end end
	
	for _, v in pairs(targets) do
		if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
			local d = (char.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
			if d < bestD then bestD = d; best = v end
		end
	end
	return best
end

local oldHook
oldHook = hookmetamethod(game, "__namecall", function(self, ...)
	local method = getnamecallmethod()
	local args = {...}
	if aimbotOn and (method == "FireServer" or method == "InvokeServer") then
		local t = nearestTarget(AIM_RANGE)
		if t and t:FindFirstChild("HumanoidRootPart") then
			if self.Name:find("Attack") or self.Name:find("Skill") or self.Name == "RemoteEvent" then
				args[1] = t.HumanoidRootPart.Position
			end
		end
	end
	return oldHook(self, unpack(args))
end)

RunService.Heartbeat:Connect(function()
	if hbEnabled then
		for _, v in pairs(workspace.Enemies:GetChildren()) do
			if v:FindFirstChild("HumanoidRootPart") then
				v.HumanoidRootPart.Size = Vector3.new(hbSize, hbSize, hbSize)
				v.HumanoidRootPart.Transparency = 0.7; v.HumanoidRootPart.CanCollide = false
			end
		end
	end
	if dashEnabled and lp.Character:FindFirstChild("HumanoidRootPart") then
		local hrp = lp.Character.HumanoidRootPart
		local d = hrp:FindFirstChild("Dash") or hrp:FindFirstChild("t")
		if d and d:IsA("BodyVelocity") then
			d.MaxForce = Vector3.new(1e6, 1e6, 1e6); d.Velocity = d.Velocity.Unit * dashPower
		end
	end
end)

local function setTog(on, btn, dot, stl)
	btn.BackgroundColor3 = on and Color3.fromRGB(65,100,240) or Color3.fromRGB(50,50,70)
	dot.Position = on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
	stl.Text = on and "ON" or "OFF"; stl.TextColor3 = on and Color3.fromRGB(70,200,110) or Color3.fromRGB(255,65,65)
end

m1B.MouseButton1Click:Connect(function() autoM1On = not autoM1On; setTog(autoM1On, m1B, m1D, m1St) end)
abB.MouseButton1Click:Connect(function() aimbotOn = not aimbotOn; setTog(aimbotOn, abB, abD, abSt) end)
hbB.MouseButton1Click:Connect(function() hbEnabled = not hbEnabled; setTog(hbEnabled, hbB, hbD, hbSt) end)
dsB.MouseButton1Click:Connect(function() dashEnabled = not dashEnabled; setTog(dashEnabled, dsB, dsD, dsSt) end)
jmpB.MouseButton1Click:Connect(function() if lp.Character.Humanoid then lp.Character.Humanoid:ChangeState(3) end end)
tpSCBtn.MouseButton1Click:Connect(function() lp.Character.HumanoidRootPart.CFrame = CFrame.new(-5497, 314, -2822) end)
tpManBtn.MouseButton1Click:Connect(function() lp.Character.HumanoidRootPart.CFrame = CFrame.new(-12463, 331, -7549) end)
icon.MouseButton1Click:Connect(function() mf.Visible = not mf.Visible end)

local dragging, dragStart, dragOrigin = false, nil, nil
icon.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
		dragging=true; dragStart=inp.Position; dragOrigin=icon.Position
	end
end)
UIS.InputChanged:Connect(function(inp)
	if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
		local d = inp.Position - dragStart
		icon.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset+d.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset+d.Y)
	end
end)
UIS.InputEnded:Connect(function() dragging=false end)