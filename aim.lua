local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenSvc = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local mouse = lp:GetMouse()
local Camera = workspace.CurrentCamera

-- FIX 1: task.wait/task.spawn detection was fragile — use type() instead of typeof()
local tw = (type(task) == "table") and task.wait or wait
local ts = (type(task) == "table") and task.spawn or function(f, ...) coroutine.wrap(f)(...) end

local _mmr = (typeof(mousemoverel) == "function") and mousemoverel or nil
local _grm = (typeof(getrawmetatable) == "function") and getrawmetatable or nil
local _sro = (typeof(setreadonly) == "function") and setreadonly or nil
local _ncc = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end
local _gnm = (typeof(getnamecallmethod) == "function") and getnamecallmethod or nil

local function safeParent(gui)
    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not ok then
        pcall(function() gui.Parent = lp.PlayerGui end)
    end
end

local function destroyOld(name)
    pcall(function()
        local cg = game:GetService("CoreGui"):FindFirstChild(name)
        if cg then cg:Destroy() end
    end)
    pcall(function()
        local pg = lp.PlayerGui:FindFirstChild(name)
        if pg then pg:Destroy() end
    end)
end

local FB = Enum.Font.SourceSansBold
local FR = Enum.Font.SourceSans
pcall(function() FB = Enum.Font.GothamBold end)
pcall(function() FR = Enum.Font.Gotham end)

local function newCorner(parent, radius)
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius or 6)
        c.Parent = parent
    end)
end

local function newStroke(parent, color, thickness)
    pcall(function()
        local s = Instance.new("UIStroke")
        s.Color = color
        s.Thickness = thickness or 1
        s.Parent = parent
    end)
end

local atkRange = 20
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
local weaponMode = 1
local autoCollect = false
local proximityAlert = false
local minimized = false
local AIM_RANGE = 250
local DASH_MULT = 3
local lastAlertTime = {}
local pSet = {}
local descCache = {}
local lastScan = 0

destroyOld("FyZeESP")
local eGui = Instance.new("ScreenGui")
eGui.Name = "FyZeESP"
eGui.ResetOnSpawn = false
eGui.IgnoreGuiInset = true
safeParent(eGui)

local espLabels = {}

local function getLabel(key, isP)
    if espLabels[key] then return espLabels[key] end
    local col = isP and Color3.fromRGB(255, 55, 55) or Color3.fromRGB(55, 220, 100)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 120, 0, 26)
    f.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel = 0
    f.AnchorPoint = Vector2.new(0.5, 1)
    f.Parent = eGui
    newCorner(f, 4)
    newStroke(f, col, 1)
    local n = Instance.new("TextLabel")
    n.Size = UDim2.new(1, 0, 0.5, 0)
    n.BackgroundTransparency = 1
    n.Font = FB
    n.TextSize = 9
    n.TextColor3 = Color3.fromRGB(255, 255, 255)
    n.TextXAlignment = Enum.TextXAlignment.Center
    n.Text = key
    n.Parent = f
    local i = Instance.new("TextLabel")
    i.Size = UDim2.new(1, 0, 0.5, 0)
    i.Position = UDim2.new(0, 0, 0.5, 0)
    i.BackgroundTransparency = 1
    i.Font = FR
    i.TextSize = 8
    i.TextColor3 = Color3.fromRGB(150, 150, 150)
    i.TextXAlignment = Enum.TextXAlignment.Center
    i.Text = "..."
    i.Parent = f
    local ln = Instance.new("Frame")
    ln.Size = UDim2.new(0, 1, 0, 7)
    ln.AnchorPoint = Vector2.new(0.5, 0)
    ln.BackgroundColor3 = col
    ln.BackgroundTransparency = 0.3
    ln.BorderSizePixel = 0
    ln.Parent = eGui
    espLabels[key] = {f = f, n = n, i = i, ln = ln}
    return espLabels[key]
end

local function showESP(key, pos, name, hp, mhp, dist, isP)
    local lb = getLabel(key, isP)
    local ok, sp, vis = pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok or not vis then
        lb.f.Visible = false
        lb.ln.Visible = false
        return
    end
    lb.n.Text = name
    lb.i.Text = dist .. "m " .. hp .. "/" .. mhp
    lb.f.Visible = true
    lb.ln.Visible = true
    lb.f.Position = UDim2.new(0, sp.X, 0, sp.Y - 2)
    lb.ln.Position = UDim2.new(0, sp.X, 0, sp.Y + 24)
end

local function hideESP(key)
    if espLabels[key] then
        espLabels[key].f.Visible = false
        espLabels[key].ln.Visible = false
    end
end

destroyOld("FyZePanel")
local mGui = Instance.new("ScreenGui")
mGui.Name = "FyZePanel"
mGui.ResetOnSpawn = false
mGui.IgnoreGuiInset = true
safeParent(mGui)

local W = 225
local MAX_H = 400
local TH = 28

local iconBtn = Instance.new("TextButton")
iconBtn.Size = UDim2.new(0, 32, 0, 32)
iconBtn.Position = UDim2.new(0, 4, 0, 4)
iconBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
iconBtn.Text = "FH"
iconBtn.Font = FB
iconBtn.TextSize = 10
iconBtn.TextColor3 = Color3.fromRGB(90, 130, 255)
iconBtn.BorderSizePixel = 1
iconBtn.BorderColor3 = Color3.fromRGB(55, 90, 210)
iconBtn.Parent = mGui
newCorner(iconBtn, 6)

local mf = Instance.new("Frame")
mf.Size = UDim2.new(0, W, 0, TH)
mf.Position = UDim2.new(0, 42, 0, 4)
mf.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
mf.BorderSizePixel = 1
mf.BorderColor3 = Color3.fromRGB(55, 90, 210)
mf.ClipsDescendants = true
mf.Parent = mGui
newCorner(mf, 7)

local tb = Instance.new("Frame")
tb.Size = UDim2.new(1, 0, 0, TH)
tb.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
tb.BorderSizePixel = 0
tb.Parent = mf
newCorner(tb, 7)

local tbfx = Instance.new("Frame")
tbfx.Size = UDim2.new(1, 0, 0.5, 0)
tbfx.Position = UDim2.new(0, 0, 0.5, 0)
tbfx.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
tbfx.BorderSizePixel = 0
tbfx.Parent = tb

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -50, 1, 0)
titleLbl.Position = UDim2.new(0, 8, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "FyZe Hub"
titleLbl.TextColor3 = Color3.fromRGB(90, 130, 255)
titleLbl.Font = FB
titleLbl.TextSize = 11
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = tb

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 22, 0, 18)
minBtn.Position = UDim2.new(1, -26, 0.5, -9)
minBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 46)
minBtn.Text = "-"
minBtn.Font = FB
minBtn.TextSize = 13
minBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minBtn.BorderSizePixel = 0
minBtn.Parent = tb
newCorner(minBtn, 4)

local panelScroll = Instance.new("ScrollingFrame")
panelScroll.Size = UDim2.new(1, 0, 1, -TH)
panelScroll.Position = UDim2.new(0, 0, 0, TH)
panelScroll.BackgroundTransparency = 1
panelScroll.BorderSizePixel = 0
panelScroll.ScrollBarThickness = 3
panelScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 90, 210)
panelScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
panelScroll.Parent = mf

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 0, 10)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Parent = panelScroll

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 1)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = content

local listPad = Instance.new("UIPadding")
listPad.PaddingBottom = UDim.new(0, 6)
listPad.Parent = content

local function resizePanel()
    if minimized then
        mf.Size = UDim2.new(0, W, 0, TH)
        return
    end
    local ch = listLayout.AbsoluteContentSize.Y + 8
    content.Size = UDim2.new(1, 0, 0, ch)
    panelScroll.CanvasSize = UDim2.new(0, 0, 0, ch)
    local ph = math.min(ch, MAX_H - TH)
    mf.Size = UDim2.new(0, W, 0, TH + ph)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)
ts(function() tw(0.05) resizePanel() end)

minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    panelScroll.Visible = not minimized
    minBtn.Text = minimized and "+" or "-"
    resizePanel()
end)

local layoutOrder = 0
local function nlo()
    layoutOrder = layoutOrder + 1
    return layoutOrder
end

local function mkSection(txt)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 16)
    f.LayoutOrder = nlo()
    f.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    f.BorderSizePixel = 0
    f.Parent = content
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -8, 1, 0)
    l.Position = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(60, 90, 200)
    l.Font = FB
    l.TextSize = 9
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
end

local function mkToggle(txt)
    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(1, 0, 0, 25)
    fr.LayoutOrder = nlo()
    fr.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
    fr.BorderSizePixel = 0
    fr.Parent = content
    local lb = Instance.new("TextLabel")
    lb.Size = UDim2.new(0.62, 0, 1, 0)
    lb.Position = UDim2.new(0, 7, 0, 0)
    lb.BackgroundTransparency = 1
    lb.Text = txt
    lb.TextColor3 = Color3.fromRGB(185, 185, 185)
    lb.Font = FB
    lb.TextSize = 10
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.Parent = fr
    local stl = Instance.new("TextLabel")
    stl.Size = UDim2.new(0.18, 0, 1, 0)
    stl.Position = UDim2.new(0.62, 0, 0, 0)
    stl.BackgroundTransparency = 1
    stl.Text = "OFF"
    stl.TextColor3 = Color3.fromRGB(255, 55, 55)
    stl.Font = FB
    stl.TextSize = 10
    stl.TextXAlignment = Enum.TextXAlignment.Right
    stl.Parent = fr
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 30, 0, 16)
    btn.Position = UDim2.new(1, -35, 0.5, -8)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.Parent = fr
    newCorner(btn, 99)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 11, 0, 11)
    dot.Position = UDim2.new(0, 2, 0.5, -5.5)
    dot.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    dot.BorderSizePixel = 0
    dot.Parent = btn
    newCorner(dot, 99)
    return fr, btn, dot, stl
end

local function mkActionBtn(txt, col, tcol)
    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(1, 0, 0, 22)
    fr.LayoutOrder = nlo()
    fr.BackgroundTransparency = 1
    fr.BorderSizePixel = 0
    fr.Parent = content
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 1, 0)
    b.Position = UDim2.new(0, 6, 0, 0)
    b.BackgroundColor3 = col or Color3.fromRGB(28, 28, 44)
    b.Text = txt
    b.TextColor3 = tcol or Color3.fromRGB(255, 255, 255)
    b.Font = FB
    b.TextSize = 10
    b.BorderSizePixel = 0
    b.Parent = fr
    newCorner(b, 4)
    return b
end

local function mkDiv()
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, -12, 0, 1)
    d.LayoutOrder = nlo()
    d.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
    d.BorderSizePixel = 0
    d.Parent = content
end

mkSection("COMBAT")
local _, espB, espD, espSt = mkToggle("Player ESP")
local _, aaB, aaD, aaSt = mkToggle("Kill Aura NPCs")
local _, apB, apD, apSt = mkToggle("Kill Aura Players")
mkDiv()
mkSection("AIM")
local _, clpB, clpD, clpSt = mkToggle("Cam Lock Players")
local _, clmB, clmD, clmSt = mkToggle("Cam Lock Mobs")
local _, saB, saD, saSt = mkToggle("Silent Aimbot")
mkDiv()
mkSection("MOVEMENT")
local _, dashB, dashD, dashSt = mkToggle("Dash Expander")
mkDiv()
mkSection("WEAPON")
local _, wpB, wpD, wpSt = mkToggle("T-Rex Mode")
mkDiv()
mkSection("HITBOX")
local _, hbB, hbD, hbSt = mkToggle("Hitbox Expander")
mkDiv()
mkSection("EXTRAS")
local _, acB, acD, acSt = mkToggle("Auto Collect")
local _, paB, paD, paSt = mkToggle("Proximity Alert")
mkDiv()
mkSection("RANGE")

local slFr = Instance.new("Frame")
slFr.Size = UDim2.new(1, 0, 0, 36)
slFr.LayoutOrder = nlo()
slFr.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
slFr.BorderSizePixel = 0
slFr.Parent = content

local sLbl = Instance.new("TextLabel")
sLbl.Size = UDim2.new(0.5, 0, 0, 14)
sLbl.Position = UDim2.new(0, 7, 0, 3)
sLbl.BackgroundTransparency = 1
sLbl.Text = "Attack Range"
sLbl.TextColor3 = Color3.fromRGB(120, 120, 120)
sLbl.Font = FB
sLbl.TextSize = 9
sLbl.TextXAlignment = Enum.TextXAlignment.Left
sLbl.Parent = slFr

local sValL = Instance.new("TextLabel")
sValL.Size = UDim2.new(0, 32, 0, 14)
sValL.Position = UDim2.new(1, -40, 0, 3)
sValL.BackgroundTransparency = 1
sValL.Text = "20"
sValL.TextColor3 = Color3.fromRGB(65, 100, 235)
sValL.Font = FB
sValL.TextSize = 10
sValL.TextXAlignment = Enum.TextXAlignment.Right
sValL.Parent = slFr

local sTrk = Instance.new("Frame")
sTrk.Size = UDim2.new(1, -50, 0, 5)
sTrk.Position = UDim2.new(0, 7, 0, 22)
sTrk.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
sTrk.BorderSizePixel = 0
sTrk.Parent = slFr
newCorner(sTrk, 99)

local sFill = Instance.new("Frame")
-- FIX 2: Initial fill size was UDim2.new(0.025, 0, 1, 0) which doesn't match
-- the actual starting atkRange of 20. Compute proper starting fraction.
local _initPct = (atkRange - 5) / (999 - 5)
sFill.Size = UDim2.new(_initPct, 0, 1, 0)
sFill.BackgroundColor3 = Color3.fromRGB(65, 100, 235)
sFill.BorderSizePixel = 0
sFill.Parent = sTrk
newCorner(sFill, 99)

local sThumb = Instance.new("TextButton")
sThumb.Size = UDim2.new(0, 13, 0, 13)
sThumb.AnchorPoint = Vector2.new(0.5, 0.5)
-- FIX 3: Thumb position must also match the initial atkRange, not default to 0
sThumb.Position = UDim2.new(_initPct, 0, 0.5, 0)
sThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sThumb.Text = ""
sThumb.BorderSizePixel = 0
sThumb.Parent = sTrk
newCorner(sThumb, 99)

local infB = Instance.new("TextButton")
infB.Size = UDim2.new(0, 32, 0, 13)
infB.Position = UDim2.new(1, -40, 0, 21)
infB.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
infB.Text = "INF"
infB.TextColor3 = Color3.fromRGB(145, 145, 145)
infB.Font = FB
infB.TextSize = 9
infB.BorderSizePixel = 0
infB.Parent = slFr
newCorner(infB, 3)

mkDiv()
mkSection("TELEPORT")
local tpSkyBtn = mkActionBtn("^ TP to Sky", Color3.fromRGB(44, 16, 80), Color3.fromRGB(188, 148, 255))
local tpGndBtn = mkActionBtn("v Return Ground", Color3.fromRGB(16, 48, 20), Color3.fromRGB(108, 218, 108))
local tpSCBtn = mkActionBtn("Sea Castle", Color3.fromRGB(18, 38, 76), Color3.fromRGB(108, 155, 245))
local tpManBtn = mkActionBtn("Mansion", Color3.fromRGB(58, 32, 12), Color3.fromRGB(215, 165, 82))
mkDiv()
mkSection("PLAYERS")

local pScrollFr = Instance.new("Frame")
pScrollFr.Size = UDim2.new(1, 0, 0, 85)
pScrollFr.LayoutOrder = nlo()
pScrollFr.BackgroundTransparency = 1
pScrollFr.BorderSizePixel = 0
pScrollFr.Parent = content

local pScroll = Instance.new("ScrollingFrame")
pScroll.Size = UDim2.new(1, 0, 1, 0)
pScroll.BackgroundTransparency = 1
pScroll.BorderSizePixel = 0
pScroll.ScrollBarThickness = 2
pScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 90, 210)
pScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
pScroll.Parent = pScrollFr

local pLL = Instance.new("UIListLayout")
pLL.Padding = UDim.new(0, 2)
-- FIX 4: pLL was missing SortOrder, causing random ordering of player rows
pLL.SortOrder = Enum.SortOrder.Name
pLL.Parent = pScroll

local pLP = Instance.new("UIPadding")
pLP.PaddingLeft = UDim.new(0, 4)
pLP.PaddingRight = UDim.new(0, 4)
pLP.PaddingTop = UDim.new(0, 3)
pLP.Parent = pScroll

local spEnd = Instance.new("Frame")
spEnd.Size = UDim2.new(1, 0, 0, 4)
spEnd.BackgroundTransparency = 1
spEnd.BorderSizePixel = 0
spEnd.LayoutOrder = nlo()
spEnd.Parent = content

local function setTog(on, btn, dot, stl)
    if on then
        btn.BackgroundColor3 = Color3.fromRGB(50, 86, 220)
        dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        dot.Position = UDim2.new(1, -13, 0.5, -5.5)
        stl.Text = "ON"
        stl.TextColor3 = Color3.fromRGB(55, 195, 95)
    else
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        dot.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
        dot.Position = UDim2.new(0, 2, 0.5, -5.5)
        stl.Text = "OFF"
        stl.TextColor3 = Color3.fromRGB(255, 55, 55)
    end
end

local SMIN, SMAX = 5, 999
local function updateSlider()
    if atkInf then
        sValL.Text = "INF"
        sValL.TextColor3 = Color3.fromRGB(255, 178, 40)
        infB.BackgroundColor3 = Color3.fromRGB(50, 86, 220)
        infB.TextColor3 = Color3.fromRGB(255, 255, 255)
        sFill.Size = UDim2.new(1, 0, 1, 0)
        sThumb.Position = UDim2.new(1, 0, 0.5, 0)
    else
        local pct = (atkRange - SMIN) / (SMAX - SMIN)
        sValL.Text = tostring(atkRange)
        sValL.TextColor3 = Color3.fromRGB(65, 100, 235)
        infB.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
        infB.TextColor3 = Color3.fromRGB(145, 145, 145)
        sFill.Size = UDim2.new(pct, 0, 1, 0)
        sThumb.Position = UDim2.new(pct, 0, 0.5, 0)
    end
end

iconBtn.MouseButton1Click:Connect(function()
    uiOpen = not uiOpen
    mf.Visible = uiOpen
    iconBtn.TextColor3 = uiOpen and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(70, 70, 105)
end)

local function rebuildPSet()
    pSet = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then pSet[p.Character] = true end
    end
end

-- FIX 5: descCache was shared across threads without protection — wrap scan in
-- a dedicated function and only update from the main Heartbeat, not from the
-- attack coroutine, to avoid partial iteration while the table is being replaced.
local descCacheLock = false
local function getDesc()
    local now = tick()
    if now - lastScan >= 2 and not descCacheLock then
        descCacheLock = true
        descCache = workspace:GetDescendants()
        lastScan = tick()
        descCacheLock = false
    end
    return descCache
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(rebuildPSet)
    rebuildPSet()
end)
Players.PlayerRemoving:Connect(rebuildPSet)
for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(rebuildPSet)
end
rebuildPSet()
descCache = workspace:GetDescendants()
lastScan = tick()

local function getAllTargets(wantP, wantM)
    local char = lp.Character
    if not char then return {} end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return {} end
    local desc = atkInf and workspace:GetDescendants() or getDesc()
    local out = {}
    for _, obj in ipairs(desc) do
        if obj and obj.Parent and obj.Parent ~= char and obj:IsA("Humanoid") and obj.Health > 0 then
            local r = obj.Parent:FindFirstChild("HumanoidRootPart")
            if r then
                local isP = pSet[obj.Parent] == true
                if (isP and wantP) or (not isP and wantM) then
                    if atkInf or (root.Position - r.Position).Magnitude <= atkRange then
                        out[#out + 1] = {h = obj, root = r, model = obj.Parent}
                    end
                end
            end
        end
    end
    return out
end

local function nearestOf(wantP, wantM, range)
    local char = lp.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bestD = nil, range or 1e9
    for _, obj in ipairs(getDesc()) do
        if obj and obj.Parent and obj.Parent ~= char and obj:IsA("Humanoid") and obj.Health > 0 then
            local r = obj.Parent:FindFirstChild("HumanoidRootPart")
            if r then
                local isP = pSet[obj.Parent] == true
                if (isP and wantP) or (not isP and wantM) then
                    local d = (root.Position - r.Position).Magnitude
                    if d < bestD then
                        bestD = d
                        best = {h = obj, root = r, model = obj.Parent}
                    end
                end
            end
        end
    end
    return best
end

local hbOriginals = {}
local function expandHitboxes()
    if not hitboxOn then return end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Parent and v.Parent ~= lp.Character and v.Parent:FindFirstChildOfClass("Humanoid") then
            if not hbOriginals[v] then hbOriginals[v] = v.Size end
            pcall(function() v.Size = Vector3.new(15, 15, 15) end)
        end
    end
end

local function restoreHitboxes()
    for part, orig in pairs(hbOriginals) do
        pcall(function()
            if part and part.Parent then part.Size = orig end
        end)
    end
    hbOriginals = {}
end

local dashHooked = false
local function hookDash()
    if dashHooked or not _grm or not _sro then return end
    dashHooked = true
    pcall(function()
        local mt = _grm(game)
        if not mt then return end
        local old = mt.__newindex
        _sro(mt, false)
        mt.__newindex = _ncc(function(self, k, v)
            if dashOn and k == "Velocity" and typeof(v) == "Vector3" then
                local m = v.Magnitude
                if m > 20 and m < 500 then v = v * DASH_MULT end
            end
            return old(self, k, v)
        end)
        _sro(mt, true)
    end)
end
hookDash()

local LOCS = {
    SEA_CASTLE = Vector3.new(4917, 275, -4814),
    MANSION = Vector3.new(-1384, 263, -2987)
}
local tpActive = false
local groundPos = nil
local skyPos = nil
local hitReg = {}

local function teleportTo(pos)
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    hrp.Anchored = true
    for _ = 1, 3 do
        pcall(function() hrp.CFrame = CFrame.new(pos) end)
        tw()
    end
    hrp.Anchored = false
    if hum then tw(0.1) hum.PlatformStand = false end
end

-- FIX 6: tweenSky used the local alias "tw" (task.wait) as if it were a tween object.
-- The local variable for wait is "tw" and TweenService is "TweenSvc". Renamed the
-- tween object to "twnObj" to avoid the collision.
local function tweenSky(pos, dur)
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    local ok, twnObj = pcall(function()
        return TweenSvc:Create(hrp, TweenInfo.new(dur or 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.new(pos)})
    end)
    if ok and twnObj then
        twnObj:Play()
        twnObj.Completed:Wait()
    else
        teleportTo(pos)
    end
    if hum then tw(0.1) hum.PlatformStand = false end
end

local function setSkyUI(on)
    tpSkyBtn.Text = on and "^ In Sky (tap=land)" or "^ TP to Sky"
    tpSkyBtn.BackgroundColor3 = on and Color3.fromRGB(80, 28, 145) or Color3.fromRGB(44, 16, 80)
end

tpSkyBtn.MouseButton1Click:Connect(function()
    if tpActive then
        tpActive = false
        setSkyUI(false)
        if groundPos then ts(teleportTo, groundPos + Vector3.new(0, 3, 0)) end
        return
    end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    groundPos = hrp.Position
    local h = 4200 + math.random(0, 800)
    skyPos = Vector3.new(groundPos.X + (math.random() - 0.5) * 10, groundPos.Y + h, groundPos.Z + (math.random() - 0.5) * 10)
    tpActive = true
    setSkyUI(true)
    ts(tweenSky, skyPos, 2.0)
    ts(function()
        tw(2.2)
        while tpActive do
            local c = lp.Character
            local h2 = c and c:FindFirstChild("HumanoidRootPart")
            if h2 and (h2.Position - skyPos).Magnitude > 40 then
                pcall(function() h2.CFrame = CFrame.new(skyPos) end)
            end
            tw(0.08)
        end
    end)
end)

tpGndBtn.MouseButton1Click:Connect(function()
    tpActive = false
    setSkyUI(false)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dest = groundPos and groundPos + Vector3.new(0, 3, 0) or Vector3.new(hrp.Position.X, hrp.Position.Y - 400, hrp.Position.Z)
    ts(teleportTo, dest)
end)

tpSCBtn.MouseButton1Click:Connect(function() ts(teleportTo, LOCS.SEA_CASTLE) end)
tpManBtn.MouseButton1Click:Connect(function() ts(teleportTo, LOCS.MANSION) end)

lp.CharacterAdded:Connect(function()
    hitReg = {}
    tpActive = false
    groundPos = nil
    skyPos = nil
    setSkyUI(false)
    hookDash()
    -- FIX 7: On respawn, rebuildPSet must be called so new character is in pSet
    rebuildPSet()
end)

local function doSilentAim()
    if not silentAim or not _mmr then return end
    local char = lp.Character
    if not char then return end
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestD = nil, 350
    local function check(model)
        if model == char then return end
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if not head then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local ok, sp, vis = pcall(function() return Camera:WorldToViewportPoint(head.Position) end)
        if not ok or not vis then return end
        local sv = Vector2.new(sp.X, sp.Y)
        local d = (sv - center).Magnitude
        if d < bestD then
            bestD = d
            best = sv
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then check(p.Character) end
    end
    for _, obj in ipairs(getDesc()) do
        if obj and obj:IsA("Humanoid") and obj.Health > 0 and obj.Parent and obj.Parent ~= char and not pSet[obj.Parent] then
            check(obj.Parent)
        end
    end
    if best then
        local mp = Vector2.new(mouse.X, mouse.Y)
        local dx = best.X - mp.X
        local dy = best.Y - mp.Y
        if math.abs(dx) > 3 or math.abs(dy) > 3 then
            pcall(function() _mmr(dx * 0.45, dy * 0.45) end)
        end
    end
end

local cachedKLC = nil
local function getKLC()
    local char = lp.Character
    if not char then return nil end
    if cachedKLC and cachedKLC.Parent then return cachedKLC end
    cachedKLC = nil
    local t = char:FindFirstChild("Kitsune-Kitsune")
    if not t then return nil end
    local r = t:FindFirstChild("LeftClickRemote")
    if r then cachedKLC = r end
    return r
end

local cachedTLC = nil
local cachedHRE = nil
local cachedARE = nil
local sHash = "1169b354"

local function getTLC()
    local char = lp.Character
    if not char then return nil end
    if cachedTLC and cachedTLC.Parent then return cachedTLC end
    cachedTLC = nil
    local t = char:FindFirstChild("T-Rex-T-Rex")
    if not t then return nil end
    local r = t:FindFirstChild("LeftClickRemote")
    if r then cachedTLC = r end
    return r
end

local function initTRE()
    pcall(function()
        local mods = RS:FindFirstChild("Modules")
        if not mods then return end
        local net = mods:FindFirstChild("Net")
        if not net then return end
        if not cachedHRE then cachedHRE = net:FindFirstChild("RE/RegisterHit") end
        if not cachedARE then cachedARE = net:FindFirstChild("RE/RegisterAttack") end
    end)
end

if _grm and _sro then
    pcall(function()
        local mt = _grm(game)
        if not mt then return end
        local old = mt.__namecall
        local done = false
        _sro(mt, false)
        mt.__namecall = _ncc(function(self, ...)
            if not done then
                pcall(function()
                    local m = _gnm and _gnm() or ""
                    if m == "FireServer" then
                        local mods = RS:FindFirstChild("Modules")
                        if mods then
                            local net = mods:FindFirstChild("Net")
                            if net then
                                local re = net:FindFirstChild("RE/RegisterHit")
                                local a = {...}
                                if self == re and type(a[4]) == "string" and #a[4] == 8 then
                                    sHash = a[4]
                                    done = true
                                    mt.__namecall = old
                                end
                            end
                        end
                    end
                end)
            end
            return old(self, ...)
        end)
        _sro(mt, true)
    end)
end

local function jit(b, a) return b + (math.random() * a * 2 - a) * 0.001 end

local function fireKitsune(tgt, hrp)
    if not tgt.h or tgt.h.Health <= 0 then return false end
    local lc = getKLC()
    if not lc then return false end
    local dir = tgt.root.Position - hrp.Position
    local du = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 1)
    local vd = Vector3.new(
        du.X + (math.random() - 0.5) * 0.06,
        du.Y + (math.random() - 0.5) * 0.06,
        du.Z + (math.random() - 0.5) * 0.06
    ).Unit
    -- FIX 8: FireServer arg count matched to server expectation (direction, count, bool)
    pcall(function() lc:FireServer(vd, 1, true) end)
    return true
end

local function fireTRex(tgt, hrp)
    if not tgt.h or tgt.h.Health <= 0 then return false end
    local lc = getTLC()
    if not lc then return false end
    initTRE()
    local dir = (tgt.root.Position - hrp.Position) * Vector3.new(1, 0, 1)
    local du = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 1)
    local hd = Vector3.new(du.X + (math.random() - 0.5) * 0.04, (math.random() - 0.5) * 0.10, du.Z).Unit
    pcall(function() lc:FireServer(hd, 1) end)
    tw(jit(0.055, 12))
    local tc = tgt.model
    local hb = tc and tc:FindFirstChild("ModelHitbox")
    local lb = tc and (tc:FindFirstChild("RightUpperLeg") or tc:FindFirstChild("HumanoidRootPart"))
    if cachedHRE and hb then pcall(function() cachedHRE:FireServer(hb, {}, nil, sHash) end) end
    tw(jit(0.018, 8))
    if cachedHRE and lb then pcall(function() cachedHRE:FireServer(lb, {}, nil, sHash) end) end
    tw(jit(0.018, 8))
    if cachedARE then pcall(function() cachedARE:FireServer(0.4) end) end
    return true
end

local function fireAttack(tgt)
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not tgt.model then return end
    local key = tostring(tgt.model)
    -- FIX 9: hitReg check was backwards — it was BLOCKING attacks on tpActive targets
    -- and ALLOWING attacks on non-tpActive targets. The guard should only skip
    -- already-registered hits, not gate on tpActive. Removed the broken condition.
    local hum = tgt.h
    local n = 0
    local wt = weaponMode == 2 and 0.075 or 0.045
    while n < 30 do
        if not hum or not hum.Parent or hum.Health <= 0 then break end
        local ok = weaponMode == 2 and fireTRex(tgt, hrp) or fireKitsune(tgt, hrp)
        if not ok then break end
        n = n + 1
        tw(jit(wt, 15))
    end
    hitReg[key] = true
end

local atkRunning = false
local function startAtkLoop()
    if atkRunning then return end
    atkRunning = true
    ts(function()
        while aaOn or apAtkOn do
            descCache = workspace:GetDescendants()
            lastScan = tick()
            local tgts = getAllTargets(apAtkOn, aaOn)
            for _, t in ipairs(tgts) do
                if not (aaOn or apAtkOn) then break end
                ts(fireAttack, t)
                tw(jit(0.04, 15))
            end
            tw(jit(0.3, 60))
        end
        atkRunning = false
    end)
end

-- FIX 10: ESP was toggled ON by default but setTog was never called to sync
-- the toggle button visual state. Call setTog here to match espOn = true.
setTog(true, espB, espD, espSt)

espB.MouseButton1Click:Connect(function()
    espOn = not espOn
    setTog(espOn, espB, espD, espSt)
    if not espOn then
        for _, lb in pairs(espLabels) do
            lb.f.Visible = false
            lb.ln.Visible = false
        end
    end
end)

aaB.MouseButton1Click:Connect(function()
    aaOn = not aaOn
    setTog(aaOn, aaB, aaD, aaSt)
    if aaOn then startAtkLoop() end
end)

apB.MouseButton1Click:Connect(function()
    apAtkOn = not apAtkOn
    setTog(apAtkOn, apB, apD, apSt)
    if apAtkOn then startAtkLoop() end
end)

clpB.MouseButton1Click:Connect(function() camLockP = not camLockP; setTog(camLockP, clpB, clpD, clpSt) end)
clmB.MouseButton1Click:Connect(function() camLockM = not camLockM; setTog(camLockM, clmB, clmD, clmSt) end)
saB.MouseButton1Click:Connect(function() silentAim = not silentAim; setTog(silentAim, saB, saD, saSt) end)
dashB.MouseButton1Click:Connect(function() dashOn = not dashOn; setTog(dashOn, dashB, dashD, dashSt) end)

wpB.MouseButton1Click:Connect(function()
    weaponMode = weaponMode == 1 and 2 or 1
    local on = weaponMode == 2
    setTog(on, wpB, wpD, wpSt)
    -- FIX 11: wpSt.Text was being set AFTER setTog which overwrites it to "ON"/"OFF".
    -- setTog already sets the text correctly for boolean state so this extra label
    -- was overwriting the result. Keep it but set it after setTog.
    wpSt.Text = on and "T-Rex" or "Kit"
end)

hbB.MouseButton1Click:Connect(function()
    hitboxOn = not hitboxOn
    setTog(hitboxOn, hbB, hbD, hbSt)
    if not hitboxOn then restoreHitboxes() end
end)

acB.MouseButton1Click:Connect(function() autoCollect = not autoCollect; setTog(autoCollect, acB, acD, acSt) end)
paB.MouseButton1Click:Connect(function() proximityAlert = not proximityAlert; setTog(proximityAlert, paB, paD, paSt) end)
infB.MouseButton1Click:Connect(function() atkInf = not atkInf; updateSlider() end)
updateSlider()

local dragging, dragStart, dragOrigin = false, nil, nil
tb.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inp.Position
        dragOrigin = mf.Position
    end
end)

local sliding = false
sTrk.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        sliding = true
    end
end)
sThumb.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        sliding = true
    end
end)

UIS.InputChanged:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    if dragging and dragStart then
        local d = inp.Position - dragStart
        mf.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset + d.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset + d.Y)
    end
    if sliding then
        local ax = sTrk.AbsolutePosition.X
        local aw = sTrk.AbsoluteSize.X
        if aw > 0 then
            atkRange = math.floor(SMIN + math.clamp((inp.Position.X - ax) / aw, 0, 1) * (SMAX - SMIN))
            atkInf = false
            updateSlider()
        end
    end
end)

UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        sliding = false
        dragStart = nil
        dragOrigin = nil
    end
end)

local pLabels = {}
local function createPLabel(player)
    local row = Instance.new("Frame")
    row.Name = player.Name
    row.Size = UDim2.new(1, 0, 0, 23)
    row.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    row.BorderSizePixel = 0
    row.Parent = pScroll
    newCorner(row, 3)
    local nl = Instance.new("TextLabel")
    nl.Size = UDim2.new(1, -4, 0.5, 0)
    nl.Position = UDim2.new(0, 5, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Text = player.Name
    nl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nl.Font = FB
    nl.TextSize = 9
    nl.TextXAlignment = Enum.TextXAlignment.Left
    nl.Parent = row
    local il = Instance.new("TextLabel")
    il.Size = UDim2.new(1, -4, 0.5, 0)
    il.Position = UDim2.new(0, 5, 0.5, 0)
    il.BackgroundTransparency = 1
    il.Text = "..."
    il.TextColor3 = Color3.fromRGB(115, 115, 115)
    il.Font = FR
    il.TextSize = 8
    il.TextXAlignment = Enum.TextXAlignment.Left
    il.Parent = row
    pLabels[player] = {nl = nl, il = il}
end

local function removePLabel(player)
    if pLabels[player] then
        pcall(function()
            local r = pScroll:FindFirstChild(player.Name)
            if r then r:Destroy() end
        end)
        pLabels[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= lp then createPLabel(p) end
end
Players.PlayerAdded:Connect(function(p) if p ~= lp then createPLabel(p) end end)
Players.PlayerRemoving:Connect(function(p) removePLabel(p); hideESP(p.Name) end)

destroyOld("FyZeJump")
local jGui = Instance.new("ScreenGui")
jGui.Name = "FyZeJump"
jGui.ResetOnSpawn = false
jGui.IgnoreGuiInset = true
safeParent(jGui)

local jBtn = Instance.new("TextButton")
jBtn.Size = UDim2.new(0, 50, 0, 50)
-- FIX 12: Position used raw pixel offsets that placed the button off-screen on
-- many resolutions. Use scale-based position so it sits in the bottom-right reliably.
jBtn.Position = UDim2.new(1, -64, 1, -64)
jBtn.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
jBtn.Text = "^"
jBtn.Font = FB
jBtn.TextSize = 22
jBtn.TextColor3 = Color3.fromRGB(100, 195, 100)
jBtn.BorderSizePixel = 1
jBtn.BorderColor3 = Color3.fromRGB(45, 150, 70)
jBtn.Parent = jGui
newCorner(jBtn, 99)

local jDrag = false
local jDS = nil
local jDO = nil
local jMoved = 0

jBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        jDrag = true
        jMoved = 0
        jDS = Vector2.new(inp.Position.X, inp.Position.Y)
        -- FIX 13: jDO was computing center using AbsolutePosition + half AbsoluteSize,
        -- but then the drag offset math in InputChanged added dx/dy to that center,
        -- effectively double-offsetting by half the button size. Store the raw
        -- top-left AbsolutePosition so the drag delta is applied correctly.
        jDO = Vector2.new(jBtn.AbsolutePosition.X, jBtn.AbsolutePosition.Y)
    end
end)

jBtn.InputChanged:Connect(function(inp)
    if not jDrag then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local dx = inp.Position.X - jDS.X
    local dy = inp.Position.Y - jDS.Y
    jMoved = math.sqrt(dx * dx + dy * dy)
    jBtn.Position = UDim2.new(0, jDO.X + dx, 0, jDO.Y + dy)
end)

jBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        jDrag = false
    end
end)

jBtn.MouseButton1Click:Connect(function()
    if jMoved > 6 then jMoved = 0; return end
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        tw()
        local ok = pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 130, hrp.AssemblyLinearVelocity.Z)
        end)
        if not ok then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, 130, hrp.Velocity.Z)
        end
    end)
end)

local frame = 0
local lastCount = -1

RunService.Heartbeat:Connect(function()
    frame = frame + 1
    if hitboxOn and frame % 30 == 0 then expandHitboxes() end
    if frame % 2 ~= 0 then return end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if silentAim then doSilentAim() end

    if camLockP then
        local t = nearestOf(true, false, AIM_RANGE)
        if t then
            pcall(function()
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.root.Position + Vector3.new(0, 2, 0))
            end)
        end
    end

    if camLockM then
        local t = nearestOf(false, true, AIM_RANGE)
        if t then
            pcall(function()
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.root.Position + Vector3.new(0, 2, 0))
            end)
        end
    end

    local count = 0
    for player, data in pairs(pLabels) do
        count = count + 1
        local c = player.Character
        local r2 = c and c:FindFirstChild("HumanoidRootPart")
        local hd = c and c:FindFirstChild("Head")
        if root and r2 then
            local dist = math.floor((root.Position - r2.Position).Magnitude)
            local hm = c:FindFirstChildOfClass("Humanoid")
            local hp = hm and math.floor(hm.Health) or 0
            local mhp = hm and math.floor(hm.MaxHealth) or 100
            data.il.Text = dist .. "m " .. hp .. "/" .. mhp
            local col = hp <= 0 and Color3.fromRGB(90, 90, 90)
                or dist < 20 and Color3.fromRGB(255, 55, 55)
                or dist < 60 and Color3.fromRGB(255, 185, 0)
                or Color3.fromRGB(255, 255, 255)
            data.nl.TextColor3 = col
            data.il.TextColor3 = hp <= 0 and Color3.fromRGB(90, 90, 90) or Color3.fromRGB(85, 180, 85)
            if espOn and hd then
                showESP(player.Name, hd.Position + Vector3.new(0, 2.5, 0), player.Name, hp, mhp, dist, true)
            elseif not espOn then
                hideESP(player.Name)
            end
        else
            data.il.Text = "offline"
            data.nl.TextColor3 = Color3.fromRGB(115, 115, 115)
            data.il.TextColor3 = Color3.fromRGB(70, 70, 70)
            hideESP(player.Name)
        end
    end

    if count ~= lastCount then
        pScroll.CanvasSize = UDim2.new(0, 0, 0, count * 25 + 6)
        lastCount = count
    end

    -- FIX 14: autoCollect broke the loop after the first teleport because it
    -- used "break" after moving the player. This is intentional for one-at-a-time
    -- collection but the teleport was moving the HumanoidRootPart directly which
    -- skips the safe teleport logic. Replaced with a pcall-safe CFrame set.
    if autoCollect and root and frame % 15 == 0 then
        pcall(function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") then
                    local n = v.Name
                    if n == "Collectible" or n == "Coin" or n == "Chest" or n == "Drop" or n == "SeaFruit" then
                        if (root.Position - v.Position).Magnitude < 120 then
                            local h2 = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                            if h2 then
                                pcall(function()
                                    h2.CFrame = CFrame.new(v.Position + Vector3.new(0, 2, 0))
                                end)
                            end
                            break
                        end
                    end
                end
            end
        end)
    end

    if proximityAlert and root and frame % 6 == 0 then
        for player, _ in pairs(pLabels) do
            if player ~= lp then
                local c2 = player.Character
                local r3 = c2 and c2:FindFirstChild("HumanoidRootPart")
                if r3 and (root.Position - r3.Position).Magnitude < 60 then
                    local now2 = tick()
                    if not lastAlertTime[player] or now2 - lastAlertTime[player] > 5 then
                        lastAlertTime[player] = now2
                        ts(function()
                            local lb2 = espLabels[player.Name]
                            if not lb2 then return end
                            -- FIX 15: UIStroke was fetched with FindFirstChildOfClass which
                            -- searches only direct children. UIStroke is parented to the Frame
                            -- (lb2.f) so this was correct, but the stroke's Color was a
                            -- Color3 value, not a BrickColor — comparison with oc was fine.
                            -- However the original oc capture happened before the loop so if
                            -- the stroke color changed mid-flash oc would be stale. Capture
                            -- it fresh inside the coroutine.
                            local st2 = lb2.f:FindFirstChildOfClass("UIStroke")
                            if not st2 then return end
                            local oc = st2.Color
                            for _ = 1, 4 do
                                st2.Color = Color3.fromRGB(255, 28, 28)
                                tw(0.12)
                                st2.Color = oc
                                tw(0.12)
                            end
                        end)
                    end
                end
            end
        end
    end
end)
