local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local lp = Players.LocalPlayer
local unpack = table.unpack or unpack

-- state
local COOLDOWN   = 0.2
local AIM_RANGE  = 200
local atkRange   = 20
local atkInf     = false
local aaOn       = false
local apAtkOn    = false
local camLockP   = false
local camLockM   = false
local aimbotOn   = false
local espOn      = true

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

-- ESP gui
local eGui = Instance.new("ScreenGui")
eGui.Name = "FyZeESP"; eGui.ResetOnSpawn = false; eGui.IgnoreGuiInset = true
safeGUI(eGui)

-- panel gui
local mGui = Instance.new("ScreenGui")
mGui.Name = "FyZePanel"; mGui.ResetOnSpawn = false; mGui.IgnoreGuiInset = true
safeGUI(mGui)

-- ─── ESP LOGIC ───────────────────────────────────────────────────────────────
local espLabels = {}

local function newLabel(key, isPlayer)
	if espLabels[key] then return espLabels[key] end
	local col = isPlayer and Color3.fromRGB(255,60,60) or Color3.fromRGB(60,220,100)
	local f = Instance.new("Frame"); f.Size = UDim2.new(0,140,0,32)
	f.BackgroundColor3 = Color3.fromRGB(8,8,14); f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0; f.AnchorPoint = Vector2.new(0.5,1); f.Parent = eGui
	Instance.new("UICorner",f).CornerRadius = UDim.new(0,6)
	local st = Instance.new("UIStroke",f); st.Color = col; st.Thickness = 1.1
	local n = Instance.new("TextLabel",f)
	n.Size = UDim2.new(1,-4,0.5,0); n.Position = UDim2.new(0,2,0,0)
	n.BackgroundTransparency = 1; n.Font = FB; n.TextSize = 10
	n.TextColor3 = Color3.fromRGB(255,255,255); n.TextXAlignment = Enum.TextXAlignment.Center; n.Text = key
	local i = Instance.new("TextLabel",f)
	i.Size = UDim2.new(1,-4,0.5,0); i.Position = UDim2.new(0,2,0.5,0)
	i.BackgroundTransparency = 1; i.Font = FR; i.TextSize = 9
	i.TextColor3 = Color3.fromRGB(170,170,170); i.TextXAlignment = Enum.TextXAlignment.Center; i.Text = "..."
	local ln = Instance.new("Frame"); ln.Size = UDim2.new(0,1,0,10)
	ln.AnchorPoint = Vector2.new(0.5,0); ln.BackgroundColor3 = col
	ln.BackgroundTransparency = 0.3; ln.BorderSizePixel = 0; ln.Parent = eGui
	espLabels[key] = {f=f,n=n,i=i,ln=ln}
	return espLabels[key]
end

local function killLabel(key)
	if not espLabels[key] then return end
	pcall(function() espLabels[key].f:Destroy() end)
	pcall(function() espLabels[key].ln:Destroy() end)
	espLabels[key] = nil
end

local function showLabel(key, headPos, name, hp, mhp, dist, isPlayer)
	local lb = newLabel(key, isPlayer)
	local ok, sp, vis = pcall(function() return Camera:WorldToViewportPoint(headPos) end)
	if not ok or not vis then lb.f.Visible=false; lb.ln.Visible=false; return end
	lb.n.Text = name
	lb.i.Text = dist.."m  "..hp.."/"..mhp
	lb.f.Visible=true; lb.ln.Visible=true
	lb.f.Position = UDim2.new(0,sp.X,0,sp.Y-4)
	lb.ln.Position = UDim2.new(0,sp.X,0,sp.Y+28)
end

local function hideLabel(key)
	if espLabels[key] then espLabels[key].f.Visible=false; espLabels[key].ln.Visible=false end
end

-- ─── PANEL CONSTRUCTION ──────────────────────────────────────────────────────
local W = 260  
local PANEL_H = 380 -- The fixed height of the visible menu

local mf = Instance.new("Frame",mGui)
mf.Name = "MainFrame"
mf.Size = UDim2.new(0,W,0,PANEL_H)
mf.Position = UDim2.new(0,16,0,50)
mf.BackgroundColor3 = Color3.fromRGB(11,11,16)
mf.BorderSizePixel = 0; mf.ClipsDescendants = true
Instance.new("UICorner",mf).CornerRadius = UDim.new(0,9)
local ms = Instance.new("UIStroke",mf); ms.Color = Color3.fromRGB(65,100,240); ms.Thickness = 1.2

-- Title Bar (Pinned to top)
local tb = Instance.new("Frame",mf)
tb.Size = UDim2.new(1,0,0,36); tb.BackgroundColor3 = Color3.fromRGB(18,18,26); tb.BorderSizePixel = 0; tb.ZIndex = 10
Instance.new("UICorner",tb).CornerRadius = UDim.new(0,9)
local tbfix = Instance.new("Frame",tb); tbfix.Size = UDim2.new(1,0,0.5,0)
tbfix.Position = UDim2.new(0,0,0.5,0); tbfix.BackgroundColor3 = Color3.fromRGB(18,18,26); tbfix.BorderSizePixel = 0
local tl = Instance.new("TextLabel",tb); tl.Size = UDim2.new(1,-60,1,0); tl.Position = UDim2.new(0,10,0,0)
tl.BackgroundTransparency = 1; tl.Text = "FyZe  |  Blox Fruits"; tl.ZIndex = 11
tl.TextColor3 = Color3.fromRGB(255,255,255); tl.Font = FB; tl.TextSize = 13; tl.TextXAlignment = Enum.TextXAlignment.Left
local minBtn = Instance.new("TextButton",tb); minBtn.Size = UDim2.new(0,28,0,22)
minBtn.Position = UDim2.new(1,-34,0.5,-11); minBtn.BackgroundColor3 = Color3.fromRGB(35,35,50); minBtn.ZIndex = 11
minBtn.Text = "—"; minBtn.TextColor3 = Color3.fromRGB(200,200,200); minBtn.Font = FB; minBtn.TextSize = 12
minBtn.BorderSizePixel = 0; Instance.new("UICorner",minBtn).CornerRadius = UDim.new(0,5)

-- THE MAIN SCROLLING CONTAINER
local mainScroll = Instance.new("ScrollingFrame", mf)
mainScroll.Name = "ContentScroll"
mainScroll.Size = UDim2.new(1,0,1,-36)
mainScroll.Position = UDim2.new(0,0,0,36)
mainScroll.BackgroundTransparency = 1
mainScroll.BorderSizePixel = 0
mainScroll.ScrollBarThickness = 3
mainScroll.ScrollBarImageColor3 = Color3.fromRGB(65,100,240)
mainScroll.CanvasSize = UDim2.new(0,0,0,850) -- Adjusted to fit everything

-- Helper Row Builder
local ROW_H = 32
local function mkRow(yp, txt)
	local fr = Instance.new("Frame",mainScroll); fr.Size = UDim2.new(1,0,0,ROW_H)
	fr.Position = UDim2.new(0,0,0,yp); fr.BackgroundColor3 = Color3.fromRGB(16,16,24); fr.BorderSizePixel = 0
	local lb = Instance.new("TextLabel",fr); lb.Size = UDim2.new(0.58,0,1,0); lb.Position = UDim2.new(0,10,0,0)
	lb.BackgroundTransparency = 1; lb.Text = txt; lb.TextColor3 = Color3.fromRGB(195,195,195)
	lb.Font = FB; lb.TextSize = 11; lb.TextXAlignment = Enum.TextXAlignment.Left
	local st = Instance.new("TextLabel",fr); st.Size = UDim2.new(0.3,0,1,0); st.Position = UDim2.new(0.60,0,0,0)
	st.BackgroundTransparency = 1; st.Text = "OFF"; st.TextColor3 = Color3.fromRGB(255,65,65)
	st.Font = FB; st.TextSize = 11; st.TextXAlignment = Enum.TextXAlignment.Right
	local btn = Instance.new("TextButton",fr); btn.Size = UDim2.new(0,36,0,20)
	btn.Position = UDim2.new(1,-44,0.5,-10); btn.BackgroundColor3 = Color3.fromRGB(50,50,70)
	btn.Text = ""; btn.BorderSizePixel = 0; Instance.new("UICorner",btn).CornerRadius = UDim.new(1,0)
	local dot = Instance.new("Frame",btn); dot.Size = UDim2.new(0,14,0,14)
	dot.Position = UDim2.new(0,3,0.5,-7); dot.BackgroundColor3 = Color3.fromRGB(140,140,140)
	dot.BorderSizePixel = 0; Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)
	return fr, btn, dot, st
end

local function mkDiv(yp)
	local d = Instance.new("Frame",mainScroll); d.Size = UDim2.new(1,-12,0,1)
	d.Position = UDim2.new(0,6,0,yp); d.BackgroundColor3 = Color3.fromRGB(35,35,55); d.BorderSizePixel = 0
end

local function mkLabel(yp, txt, col)
	local l = Instance.new("TextLabel",mainScroll); l.Size = UDim2.new(1,-12,0,18)
	l.Position = UDim2.new(0,10,0,yp); l.BackgroundTransparency = 1
	l.Text = txt; l.TextColor3 = col or Color3.fromRGB(90,110,200)
	l.Font = FB; l.TextSize = 10; l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

local function mkTpBtn(yp, label, col, tcol)
	local fr = Instance.new("Frame",mainScroll); fr.Size = UDim2.new(1,-16,0,26)
	fr.Position = UDim2.new(0,8,0,yp); fr.BackgroundColor3 = col; fr.BorderSizePixel = 0
	Instance.new("UICorner",fr).CornerRadius = UDim.new(0,6)
	local b = Instance.new("TextButton",fr); b.Size = UDim2.new(1,0,1,0)
	b.BackgroundTransparency = 1; b.Text = label; b.TextColor3 = tcol or Color3.fromRGB(255,255,255)
	b.Font = FB; b.TextSize = 11; b.BorderSizePixel = 0
	return fr, b
end

-- Populate Scroll Content
local Y = 10
mkLabel(Y, "COMBAT", Color3.fromRGB(80,105,220)); Y = Y + 16
local espFr,espB,espD,espSt       = mkRow(Y,"Player ESP");       Y=Y+ROW_H
local aaFr,aaB,aaD,aaSt           = mkRow(Y,"Kill Aura NPCs");   Y=Y+ROW_H
local apAtkFr,apAtkB,apAtkD,apAtkSt = mkRow(Y,"Kill Aura Players"); Y=Y+ROW_H
mkDiv(Y); Y=Y+6

mkLabel(Y, "AIM", Color3.fromRGB(80,105,220)); Y=Y+16
local clpFr,clpB,clpD,clpSt = mkRow(Y,"Cam Lock Players"); Y=Y+ROW_H
local clmFr,clmB,clmD,clmSt = mkRow(Y,"Cam Lock Mobs");    Y=Y+ROW_H
local abFr,abB,abD,abSt      = mkRow(Y,"Silent Aimbot");    Y=Y+ROW_H
mkDiv(Y); Y=Y+6

mkLabel(Y, "ATTACK RANGE", Color3.fromRGB(80,105,220)); Y=Y+16
local sSec = Instance.new("Frame",mainScroll); sSec.Size = UDim2.new(1,0,0,46)
sSec.Position = UDim2.new(0,0,0,Y); sSec.BackgroundTransparency = 1; Y=Y+46
local sValL = Instance.new("TextLabel",sSec); sValL.Size = UDim2.new(0,40,0,18); sValL.Position = UDim2.new(1,-48,0,0)
sValL.BackgroundTransparency = 1; sValL.Text = "20"; sValL.TextColor3 = Color3.fromRGB(65,100,240); sValL.Font = FB; sValL.TextSize = 11; sValL.TextXAlignment = Enum.TextXAlignment.Right
local sTrk = Instance.new("Frame",sSec); sTrk.Size = UDim2.new(1,-60,0,6); sTrk.Position = UDim2.new(0,8,0,20); sTrk.BackgroundColor3 = Color3.fromRGB(35,35,55); sTrk.BorderSizePixel = 0; Instance.new("UICorner",sTrk).CornerRadius = UDim.new(1,0)
local sFill = Instance.new("Frame",sTrk); sFill.Size = UDim2.new(0.025,0,1,0); sFill.BackgroundColor3 = Color3.fromRGB(65,100,240); sFill.BorderSizePixel = 0; Instance.new("UICorner",sFill).CornerRadius = UDim.new(1,0)
local sThumb = Instance.new("TextButton",sTrk); sThumb.Size = UDim2.new(0,16,0,16); sThumb.AnchorPoint = Vector2.new(0.5,0.5); sThumb.Position = UDim2.new(0,0,0.5,0); sThumb.BackgroundColor3 = Color3.fromRGB(255,255,255); sThumb.Text = ""; sThumb.BorderSizePixel = 0; Instance.new("UICorner",sThumb).CornerRadius = UDim.new(1,0)
local infB = Instance.new("TextButton",sSec); infB.Size = UDim2.new(0,42,0,20); infB.Position = UDim2.new(1,-50,0,16); infB.BackgroundColor3 = Color3.fromRGB(35,35,50); infB.Text = "INF"; infB.TextColor3 = Color3.fromRGB(180,180,180); infB.Font = FB; infB.TextSize = 10; infB.BorderSizePixel = 0; Instance.new("UICorner",infB).CornerRadius = UDim.new(0,5)
mkDiv(Y); Y=Y+6

mkLabel(Y, "TELEPORT", Color3.fromRGB(80,105,220)); Y=Y+16
local tpSkyFr, tpSkyBtn   = mkTpBtn(Y, "⬆  TP to Sky",        Color3.fromRGB(50,25,100),  Color3.fromRGB(210,170,255)); Y=Y+30
local tpGndFr, tpGndBtn   = mkTpBtn(Y, "⬇  Return to Ground",  Color3.fromRGB(25,60,30),   Color3.fromRGB(130,230,130)); Y=Y+30
local tpSCFr,  tpSCBtn    = mkTpBtn(Y, "🏰  Sea Castle",        Color3.fromRGB(30,50,90),   Color3.fromRGB(130,170,255)); Y=Y+30
local tpManFr, tpManBtn   = mkTpBtn(Y, "🏠  Mansion",           Color3.fromRGB(70,40,20),   Color3.fromRGB(230,180,100)); Y=Y+30
mkDiv(Y); Y=Y+6

mkLabel(Y, "PLAYERS", Color3.fromRGB(80,105,220)); Y=Y+16
local pScroll = Instance.new("ScrollingFrame", mainScroll)
pScroll.Size = UDim2.new(1,-12,0,200)
pScroll.Position = UDim2.new(0,6,0,Y)
pScroll.BackgroundTransparency = 0.9; pScroll.BackgroundColor3 = Color3.fromRGB(0,0,0)
pScroll.BorderSizePixel = 0; pScroll.ScrollBarThickness = 2
local listL = Instance.new("UIListLayout",pScroll); listL.Padding = UDim.new(0,3)
local listP = Instance.new("UIPadding",pScroll); listP.PaddingTop = UDim.new(0,4); listP.PaddingLeft = UDim.new(0,4); listP.PaddingRight = UDim.new(0,4)
Y = Y + 210
mainScroll.CanvasSize = UDim2.new(0,0,0,Y)

-- ─── LOGIC & HELPERS ─────────────────────────────────────────────────────────

local function setTog(on, btn, dot, stl)
	if on then
		btn.BackgroundColor3 = Color3.fromRGB(65,100,240); dot.BackgroundColor3 = Color3.fromRGB(255,255,255); dot.Position = UDim2.new(1,-17,0.5,-7); stl.Text = "ON"; stl.TextColor3 = Color3.fromRGB(70,200,110)
	else
		btn.BackgroundColor3 = Color3.fromRGB(50,50,70); dot.BackgroundColor3 = Color3.fromRGB(140,140,140); dot.Position = UDim2.new(0,3,0.5,-7); stl.Text = "OFF"; stl.TextColor3 = Color3.fromRGB(255,65,65)
	end
end

local SMIN,SMAX = 5,999
local function updateSlider()
	if atkInf then
		sValL.Text = "INF"; sValL.TextColor3 = Color3.fromRGB(255,190,50); infB.BackgroundColor3 = Color3.fromRGB(65,100,240); infB.TextColor3 = Color3.fromRGB(255,255,255); sFill.Size = UDim2.new(1,0,1,0); sThumb.Position = UDim2.new(1,0,0.5,0)
	else
		local pct = (atkRange-SMIN)/(SMAX-SMIN); sValL.Text = tostring(atkRange); sValL.TextColor3 = Color3.fromRGB(65,100,240); infB.BackgroundColor3 = Color3.fromRGB(35,35,50); infB.TextColor3 = Color3.fromRGB(180,180,180); sFill.Size = UDim2.new(pct,0,1,0); sThumb.Position = UDim2.new(pct,0,0.5,0)
	end
end

setTog(true, espB, espD, espSt)
espB.MouseButton1Click:Connect(function() espOn = not espOn; setTog(espOn,espB,espD,espSt) if not espOn then for k,lb in pairs(espLabels) do lb.f.Visible=false; lb.ln.Visible=false end end end)
clpB.MouseButton1Click:Connect(function() camLockP = not camLockP; setTog(camLockP,clpB,clpD,clpSt) end)
clmB.MouseButton1Click:Connect(function() camLockM = not camLockM; setTog(camLockM,clmB,clmD,clmSt) end)
abB.MouseButton1Click:Connect(function() aimbotOn = not aimbotOn; setTog(aimbotOn,abB,abD,abSt) end)
infB.MouseButton1Click:Connect(function() atkInf = not atkInf; updateSlider() end)

-- Minimize logic
local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	mf.Size = minimized and UDim2.new(0,W,0,36) or UDim2.new(0,W,0,PANEL_H)
	minBtn.Text = minimized and "+" or "—"
	mainScroll.Visible = not minimized
end)

-- Drag Logic
local dragging, dragStart, dragOrigin = false, nil, nil
tb.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging=true; dragStart=inp.Position; dragOrigin=mf.Position end end)
local sliding = false
sTrk.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then sliding=true end end)
sThumb.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then sliding=true end end)
UIS.InputChanged:Connect(function(inp)
	if dragging then local d = inp.Position - dragStart; mf.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset+d.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset+d.Y) end
	if sliding then local ax = sTrk.AbsolutePosition.X; local aw = sTrk.AbsoluteSize.X; if aw > 0 then atkRange = math.floor(SMIN + math.clamp((inp.Position.X-ax)/aw,0,1)*(SMAX-SMIN)); atkInf = false; updateSlider() end end
end)
UIS.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false; sliding=false end end)

-- ─── COMBAT & TARGETING ──────────────────────────────────────────────────────
local pSet = {}
local descCache = {}
local lastScan = 0

local function rebuildPSet() pSet = {} for _,p in ipairs(Players:GetPlayers()) do if p.Character then pSet[p.Character] = true end end end
local function getDesc() local now = tick(); if now - lastScan >= 2 then descCache = workspace:GetDescendants(); lastScan = now end return descCache end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(rebuildPSet); rebuildPSet() end)
Players.PlayerRemoving:Connect(rebuildPSet); rebuildPSet()

local function getAllTargets(wantP, wantM)
	local char = lp.Character; if not char then return {} end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return {} end
	local maxDist = atkInf and math.huge or atkRange
	local results = {}
	local desc = getDesc()
	for i=1,#desc do
		local obj = desc[i]
		if obj and obj.Parent and obj.Parent ~= char and obj:IsA("Humanoid") and obj.Health > 0 then
			local r = obj.Parent:FindFirstChild("HumanoidRootPart")
			if r then
				local isP = pSet[obj.Parent] == true
				if (isP and wantP) or (not isP and wantM) then
					if atkInf or (root.Position - r.Position).Magnitude <= maxDist then table.insert(results, {h=obj,root=r,model=obj.Parent}) end
				end
			end
		end
	end
	return results
end

local function nearestTarget(wantP, wantM, range)
	local char = lp.Character; if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
	local best, bestD = nil, range or math.huge
	local desc = getDesc()
	for i=1,#desc do
		local obj = desc[i]
		if obj and obj.Parent and obj.Parent ~= char and obj:IsA("Humanoid") and obj.Health > 0 then
			local r = obj.Parent:FindFirstChild("HumanoidRootPart")
			if r then
				local isP = pSet[obj.Parent] == true
				if (isP and wantP) or (not isP and wantM) then
					local d = (root.Position - r.Position).Magnitude
					if d < bestD then bestD=d; best={h=obj,root=r,model=obj.Parent} end
				end
			end
		end
	end
	return best
end

local function fireAttack(tgt)
	local char = lp.Character; if not char then return end
	local lc = char:FindFirstChild("Kitsune-Kitsune") and char["Kitsune-Kitsune"]:FindFirstChild("LeftClickRemote")
	if not lc then return end
	local dir = (tgt.root.Position - char.HumanoidRootPart.Position).Unit
	pcall(function() lc:FireServer(dir,1,true) end)
end

local atkLoopRunning = false
local function startAtkLoop()
	if atkLoopRunning then return end
	atkLoopRunning = true
	task.spawn(function()
		while aaOn or apAtkOn do
			local targets = getAllTargets(apAtkOn, aaOn)
			for _,t in ipairs(targets) do if not (aaOn or apAtkOn) then break end fireAttack(t) task.wait(0.05) end
			task.wait(0.2)
		end
		atkLoopRunning = false
	end)
end

aaB.MouseButton1Click:Connect(function() aaOn = not aaOn; setTog(aaOn,aaB,aaD,aaSt) if aaOn then startAtkLoop() end end)
apAtkB.MouseButton1Click:Connect(function() apAtkOn = not apAtkOn; setTog(apAtkOn,apAtkB,apAtkD,apAtkSt) if apAtkOn then startAtkLoop() end end)

-- ─── PLAYER LIST UPDATER ─────────────────────────────────────────────────────
local pLabels = {}
local function createPLabel(player)
	local row = Instance.new("Frame",pScroll); row.Name = player.Name
	row.Size = UDim2.new(1,0,0,32); row.BackgroundColor3 = Color3.fromRGB(18,18,26); row.BorderSizePixel = 0; Instance.new("UICorner",row).CornerRadius = UDim.new(0,5)
	local nl = Instance.new("TextLabel",row); nl.Size = UDim2.new(1,-8,0.5,0); nl.Position = UDim2.new(0,8,0,0); nl.BackgroundTransparency = 1; nl.Text = player.Name; nl.TextColor3 = Color3.fromRGB(255,255,255); nl.Font = FB; nl.TextSize = 11; nl.TextXAlignment = Enum.TextXAlignment.Left
	local il = Instance.new("TextLabel",row); il.Size = UDim2.new(1,-8,0.5,0); il.Position = UDim2.new(0,8,0.5,0); il.BackgroundTransparency = 1; il.Text = "..."; il.TextColor3 = Color3.fromRGB(140,140,140); il.Font = FR; il.TextSize = 10; il.TextXAlignment = Enum.TextXAlignment.Left
	pLabels[player] = {nl=nl,il=il}
end
local function removePLabel(player) if pLabels[player] then pcall(function() pScroll:FindFirstChild(player.Name):Destroy() end) end pLabels[player] = nil end
for _,p in ipairs(Players:GetPlayers()) do if p ~= lp then createPLabel(p) end end
Players.PlayerAdded:Connect(function(p) if p ~= lp then createPLabel(p) end end)
Players.PlayerRemoving:Connect(function(p) removePLabel(p); killLabel(p.Name) end)

-- ─── RUNSERVICE HEARTBEAT ────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
	local char = lp.Character; local root = char and char:FindFirstChild("HumanoidRootPart")
	if camLockP then local t = nearestTarget(true,false,AIM_RANGE) if t then Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.root.Position) end end
	if camLockM then local t = nearestTarget(false,true,AIM_RANGE) if t then Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.root.Position) end end
	if aimbotOn and root then local t = nearestTarget(true,true,AIM_RANGE) if t then local dir = (t.root.Position - root.Position) * Vector3.new(1,0,1) if dir.Magnitude > 0.1 then root.CFrame = CFrame.new(root.Position, root.Position + dir) end end end
	
	for player, data in pairs(pLabels) do
		local c = player.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
		if root and r then
			local dist = math.floor((root.Position - r.Position).Magnitude)
			local hum = c:FindFirstChildOfClass("Humanoid")
			local hp = hum and math.floor(hum.Health) or 0
			data.il.Text = dist.."m  HP:"..hp; data.nl.TextColor3 = (dist < 30) and Color3.fromRGB(255,65,65) or Color3.fromRGB(255,255,255)
			if espOn and c:FindFirstChild("Head") then showLabel(player.Name, c.Head.Position+Vector3.new(0,2,0), player.Name, hp, 100, dist, true) else hideLabel(player.Name) end
		else data.il.Text = "not spawned"; hideLabel(player.Name) end
	end
	pScroll.CanvasSize = UDim2.new(0,0,0, #Players:GetPlayers() * 35)
end)

updateSlider()
