local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local lp = Players.LocalPlayer

-- state
local AIM_RANGE  = 200
local atkRange   = 20
local atkInf     = false
local aaOn       = false
local apAtkOn    = false
local camLockP   = false
local camLockM   = false
local aimbotOn   = false
local espOn      = false -- Default Off

-- TP State & Locations
local tpActive   = false
local groundPos  = nil
local skyPos     = nil

local LOCATIONS = {
    SEA_CASTLE = Vector3.new(-5020, 315, -3160), -- Updated coords
    MANSION    = Vector3.new(-12463, 330, -7550) -- Updated coords
}

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

-- GUI Setup
local eGui = Instance.new("ScreenGui"); eGui.Name = "FyZeESP"; eGui.ResetOnSpawn = false; eGui.IgnoreGuiInset = true; safeGUI(eGui)
local mGui = Instance.new("ScreenGui"); mGui.Name = "FyZePanel"; mGui.ResetOnSpawn = false; mGui.IgnoreGuiInset = true; safeGUI(mGui)

-- ─── PANEL CONSTRUCTION ──────────────────────────────────────────────────────
local W = 260  
local PANEL_H = 400 

local mf = Instance.new("Frame",mGui)
mf.Size = UDim2.new(0,W,0,PANEL_H); mf.Position = UDim2.new(0,16,0,50)
mf.BackgroundColor3 = Color3.fromRGB(11,11,16); mf.BorderSizePixel = 0; mf.ClipsDescendants = true
Instance.new("UICorner",mf).CornerRadius = UDim.new(0,9)
local ms = Instance.new("UIStroke",mf); ms.Color = Color3.fromRGB(65,100,240); ms.Thickness = 1.2

-- Title Bar
local tb = Instance.new("Frame",mf)
tb.Size = UDim2.new(1,0,0,36); tb.BackgroundColor3 = Color3.fromRGB(18,18,26); tb.BorderSizePixel = 0; tb.ZIndex = 10
Instance.new("UICorner",tb).CornerRadius = UDim.new(0,9)
local tl = Instance.new("TextLabel",tb); tl.Size = UDim2.new(1,-60,1,0); tl.Position = UDim2.new(0,10,0,0); tl.BackgroundTransparency = 1; tl.Text = "FyZe  |  Blox Fruits"; tl.TextColor3 = Color3.fromRGB(255,255,255); tl.Font = FB; tl.TextSize = 13; tl.TextXAlignment = Enum.TextXAlignment.Left; tl.ZIndex = 11
local minBtn = Instance.new("TextButton",tb); minBtn.Size = UDim2.new(0,28,0,22); minBtn.Position = UDim2.new(1,-34,0.5,-11); minBtn.BackgroundColor3 = Color3.fromRGB(35,35,50); minBtn.Text = "—"; minBtn.TextColor3 = Color3.fromRGB(200,200,200); minBtn.Font = FB; minBtn.TextSize = 12; minBtn.BorderSizePixel = 0; Instance.new("UICorner",minBtn).CornerRadius = UDim.new(0,5); minBtn.ZIndex = 11

-- Main Scroll
local mainScroll = Instance.new("ScrollingFrame", mf)
mainScroll.Size = UDim2.new(1,0,1,-36); mainScroll.Position = UDim2.new(0,0,0,36); mainScroll.BackgroundTransparency = 1; mainScroll.BorderSizePixel = 0; mainScroll.ScrollBarThickness = 3; mainScroll.ScrollBarImageColor3 = Color3.fromRGB(65,100,240); mainScroll.CanvasSize = UDim2.new(0,0,0,850); mainScroll.ZIndex = 1

-- Helpers
local function mkRow(yp, txt)
	local fr = Instance.new("Frame",mainScroll); fr.Size = UDim2.new(1,0,0,32); fr.Position = UDim2.new(0,0,0,yp); fr.BackgroundColor3 = Color3.fromRGB(16,16,24); fr.BorderSizePixel = 0; fr.ZIndex = 2
	local lb = Instance.new("TextLabel",fr); lb.Size = UDim2.new(0.58,0,1,0); lb.Position = UDim2.new(0,10,0,0); lb.BackgroundTransparency = 1; lb.Text = txt; lb.TextColor3 = Color3.fromRGB(195,195,195); lb.Font = FB; lb.TextSize = 11; lb.TextXAlignment = Enum.TextXAlignment.Left; lb.ZIndex = 3
	local st = Instance.new("TextLabel",fr); st.Size = UDim2.new(0.3,0,1,0); st.Position = UDim2.new(0.60,0,0,0); st.BackgroundTransparency = 1; st.Text = "OFF"; st.TextColor3 = Color3.fromRGB(255,65,65); st.Font = FB; st.TextSize = 11; st.TextXAlignment = Enum.TextXAlignment.Right; st.ZIndex = 3
	local btn = Instance.new("TextButton",fr); btn.Size = UDim2.new(0,36,0,20); btn.Position = UDim2.new(1,-44,0.5,-10); btn.BackgroundColor3 = Color3.fromRGB(50,50,70); btn.Text = ""; btn.BorderSizePixel = 0; Instance.new("UICorner",btn).CornerRadius = UDim.new(1,0); btn.ZIndex = 4
	local dot = Instance.new("Frame",btn); dot.Size = UDim2.new(0,14,0,14); dot.Position = UDim2.new(0,3,0.5,-7); dot.BackgroundColor3 = Color3.fromRGB(140,140,140); dot.BorderSizePixel = 0; Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0); dot.ZIndex = 5
	return fr, btn, dot, st
end

local function mkLabel(yp, txt, col)
	local l = Instance.new("TextLabel",mainScroll); l.Size = UDim2.new(1,-12,0,18); l.Position = UDim2.new(0,10,0,yp); l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = col or Color3.fromRGB(90,110,200); l.Font = FB; l.TextSize = 10; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 2
	return l
end

local function mkTpBtn(yp, label, col, tcol)
	local fr = Instance.new("Frame",mainScroll); fr.Size = UDim2.new(1,-16,0,26); fr.Position = UDim2.new(0,8,0,yp); fr.BackgroundColor3 = col; fr.BorderSizePixel = 0; Instance.new("UICorner",fr).CornerRadius = UDim.new(0,6); fr.ZIndex = 2
	local b = Instance.new("TextButton",fr); b.Size = UDim2.new(1,0,1,0); b.BackgroundTransparency = 1; b.Text = label; b.TextColor3 = tcol or Color3.fromRGB(255,255,255); b.Font = FB; b.TextSize = 11; b.BorderSizePixel = 0; b.ZIndex = 4
	return fr, b
end

-- Layout
local Y = 10
mkLabel(Y, "COMBAT"); Y+=16
local espFr,espB,espD,espSt = mkRow(Y,"Player ESP"); Y+=32
local aaFr,aaB,aaD,aaSt = mkRow(Y,"Kill Aura NPCs"); Y+=32
local apAtkFr,apAtkB,apAtkD,apAtkSt = mkRow(Y,"Kill Aura Players"); Y+=32

Y+=10; mkLabel(Y, "AIM"); Y+=16
local clpFr,clpB,clpD,clpSt = mkRow(Y,"Cam Lock Players"); Y+=32
local clmFr,clmB,clmD,clmSt = mkRow(Y,"Cam Lock Mobs"); Y+=32
local abFr,abB,abD,abSt = mkRow(Y,"Silent Aimbot"); Y+=32

Y+=10; mkLabel(Y, "TELEPORT"); Y+=16
local tpSkyFr, tpSkyBtn = mkTpBtn(Y, "⬆  TP to Sky", Color3.fromRGB(50,25,100), Color3.fromRGB(210,170,255)); Y+=30
local tpGndFr, tpGndBtn = mkTpBtn(Y, "⬇  Return to Ground", Color3.fromRGB(25,60,30), Color3.fromRGB(130,230,130)); Y+=30
local tpSCFr, tpSCBtn = mkTpBtn(Y, "🏰  Sea Castle", Color3.fromRGB(30,50,90), Color3.fromRGB(130,170,255)); Y+=30
local tpManFr, tpManBtn = mkTpBtn(Y, "🏠  Mansion", Color3.fromRGB(70,40,20), Color3.fromRGB(230,180,100)); Y+=30

Y+=10; mainScroll.CanvasSize = UDim2.new(0,0,0,Y+20)

-- ─── LOGIC CORE ──────────────────────────────────────────────────────────────

local function setTog(on, btn, dot, stl)
	if on then 
        btn.BackgroundColor3 = Color3.fromRGB(65,100,240); dot.Position = UDim2.new(1,-17,0.5,-7); stl.Text = "ON"; stl.TextColor3 = Color3.fromRGB(70,200,110)
	else 
        btn.BackgroundColor3 = Color3.fromRGB(50,50,70); dot.Position = UDim2.new(0,3,0.5,-7); stl.Text = "OFF"; stl.TextColor3 = Color3.fromRGB(255,65,65) 
    end
end

-- Toggles
espB.MouseButton1Click:Connect(function() espOn = not espOn; setTog(espOn,espB,espD,espSt) end)
aaB.MouseButton1Click:Connect(function() aaOn = not aaOn; setTog(aaOn,aaB,aaD,aaSt) end)
apAtkB.MouseButton1Click:Connect(function() apAtkOn = not apAtkOn; setTog(apAtkOn,apAtkB,apAtkD,apAtkSt) end)
clpB.MouseButton1Click:Connect(function() camLockP = not camLockP; setTog(camLockP,clpB,clpD,clpSt) end)
clmB.MouseButton1Click:Connect(function() camLockM = not camLockM; setTog(camLockM,clmB,clmD,clmSt) end)
abB.MouseButton1Click:Connect(function() aimbotOn = not aimbotOn; setTog(aimbotOn,abB,abD,abSt) end)

-- TP Logic
local function tweenTo(pos)
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dist = (hrp.Position - pos).Magnitude
    local tw = TweenService:Create(hrp, TweenInfo.new(dist/350, Enum.EasingStyle.Linear), {CFrame = CFrame.new(pos)})
    tw:Play(); return tw
end

tpSkyBtn.MouseButton1Click:Connect(function()
    if tpActive then 
        tpActive = false; tpSkyBtn.Text = "⬆  TP to Sky"
        if groundPos then tweenTo(groundPos) end
    else
        groundPos = lp.Character.HumanoidRootPart.Position
        skyPos = groundPos + Vector3.new(0, 4000, 0)
        tpActive = true; tpSkyBtn.Text = "⬆  In Sky (Cancel)"
        tweenTo(skyPos)
        task.spawn(function()
            while tpActive do
                pcall(function() lp.Character.HumanoidRootPart.CFrame = CFrame.new(skyPos) end)
                task.wait(0.1)
            end
        end)
    end
end)

tpGndBtn.MouseButton1Click:Connect(function()
    tpActive = false; tpSkyBtn.Text = "⬆  TP to Sky"
    if groundPos then tweenTo(groundPos) end
end)

tpSCBtn.MouseButton1Click:Connect(function()
    tpActive = false; tpSkyBtn.Text = "⬆  TP to Sky"
    tweenTo(LOCATIONS.SEA_CASTLE)
end)

tpManBtn.MouseButton1Click:Connect(function()
    tpActive = false; tpSkyBtn.Text = "⬆  TP to Sky"
    tweenTo(LOCATIONS.MANSION)
end)

-- Minimal Draggable
local dragging, dragStart, dragOrigin
tb.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=true; dragStart=i.Position; dragOrigin=mf.Position end end)
UIS.InputChanged:Connect(function(i) 
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then 
        local d = i.Position - dragStart; mf.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset+d.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset+d.Y) 
    end 
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end end)

minBtn.MouseButton1Click:Connect(function()
	mf.Size = (mf.Size.Y.Offset > 50) and UDim2.new(0,W,0,36) or UDim2.new(0,W,0,PANEL_H)
    minBtn.Text = (mf.Size.Y.Offset > 50) and "—" or "+"
end)

print("FyZe Final Fix Loaded")
