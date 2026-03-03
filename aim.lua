-- FyZe Hub | Delta-compatible | Kitsune only
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenSvc     = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")
local lp           = Players.LocalPlayer
local mouse        = lp:GetMouse()
local Camera       = workspace.CurrentCamera

-- Delta exposes task natively; always prefer it
local tw = task.wait
local ts = task.spawn

-- Delta-safe executor function checks
local _mmr = (typeof(mousemoverel) == "function") and mousemoverel or nil
local _grm = (typeof(getrawmetatable) == "function") and getrawmetatable or nil
local _sro = (typeof(setreadonly) == "function") and setreadonly or nil
local _ncc = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end
local _gnm = (typeof(getnamecallmethod) == "function") and getnamecallmethod or nil

-- Delta sometimes can't parent to CoreGui; fall back silently
local function safeParent(gui)
    if not pcall(function() gui.Parent = game:GetService("CoreGui") end) then
        pcall(function() gui.Parent = lp:WaitForChild("PlayerGui") end)
    end
end

local function destroyOld(name)
    pcall(function()
        local g = game:GetService("CoreGui"):FindFirstChild(name)
        if g then g:Destroy() end
    end)
    pcall(function()
        local g = lp.PlayerGui:FindFirstChild(name)
        if g then g:Destroy() end
    end)
end

-- Delta supports GothamBold; fall back safely
local FB = Enum.Font.SourceSansBold
local FR = Enum.Font.SourceSans
pcall(function() FB = Enum.Font.GothamBold end)
pcall(function() FR = Enum.Font.Gotham end)

local function newCorner(parent, radius)
    local ok, c = pcall(Instance.new, "UICorner")
    if ok then c.CornerRadius = UDim.new(0, radius or 6); c.Parent = parent end
end

local function newStroke(parent, color, thickness)
    local ok, s = pcall(Instance.new, "UIStroke")
    if ok then s.Color = color; s.Thickness = thickness or 1; s.Parent = parent end
end

-- State
local atkRange     = 20
local atkInf       = false
local aaOn         = false
local apAtkOn      = false
local camLockP     = false
local camLockM     = false
local silentAim    = false
local espOn        = true
local hitboxOn     = false
local dashOn       = false
local uiOpen       = true
local autoCollect  = false
local proximityAlert = false
local minimized    = false
local AIM_RANGE    = 250
local DASH_MULT    = 3
local lastAlertTime = {}
local pSet         = {}
local descCache    = {}
local lastScan     = 0
local descLock     = false

-- ────────────────────────── ESP GUI ──────────────────────────
destroyOld("FyZeESP")
local eGui = Instance.new("ScreenGui")
eGui.Name            = "FyZeESP"
eGui.ResetOnSpawn    = false
-- Delta: do NOT set IgnoreGuiInset directly on ScreenGui — can error in some builds
pcall(function() eGui.IgnoreGuiInset = true end)
safeParent(eGui)

local espLabels = {}

local function getLabel(key, isP)
    if espLabels[key] then return espLabels[key] end
    local col = isP and Color3.fromRGB(255, 55, 55) or Color3.fromRGB(55, 220, 100)
    local f = Instance.new("Frame")
    f.Size                  = UDim2.new(0, 120, 0, 26)
    f.BackgroundColor3      = Color3.fromRGB(8, 8, 14)
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel       = 0
    f.AnchorPoint           = Vector2.new(0.5, 1)
    f.Parent                = eGui
    newCorner(f, 4)
    newStroke(f, col, 1)
    local n = Instance.new("TextLabel")
    n.Size               = UDim2.new(1, 0, 0.5, 0)
    n.BackgroundTransparency = 1
    n.Font               = FB
    n.TextSize           = 9
    n.TextColor3         = Color3.fromRGB(255, 255, 255)
    n.TextXAlignment     = Enum.TextXAlignment.Center
    n.Text               = key
    n.Parent             = f
    local i = Instance.new("TextLabel")
    i.Size               = UDim2.new(1, 0, 0.5, 0)
    i.Position           = UDim2.new(0, 0, 0.5, 0)
    i.BackgroundTransparency = 1
    i.Font               = FR
    i.TextSize           = 8
    i.TextColor3         = Color3.fromRGB(150, 150, 150)
    i.TextXAlignment     = Enum.TextXAlignment.Center
    i.Text               = "..."
    i.Parent             = f
    local ln = Instance.new("Frame")
    ln.Size              = UDim2.new(0, 1, 0, 7)
    ln.AnchorPoint       = Vector2.new(0.5, 0)
    ln.BackgroundColor3  = col
    ln.BackgroundTransparency = 0.3
    ln.BorderSizePixel   = 0
    ln.Parent            = eGui
    espLabels[key] = {f = f, n = n, i = i, ln = ln}
    return espLabels[key]
end

local function showESP(key, pos, name, hp, mhp, dist, isP)
    local lb = getLabel(key, isP)
    local ok, sp, vis = pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok or not vis then
        lb.f.Visible  = false
        lb.ln.Visible = false
        return
    end
    lb.n.Text  = name
    lb.i.Text  = dist .. "m " .. hp .. "/" .. mhp
    lb.f.Visible  = true
    lb.ln.Visible = true
    lb.f.Position  = UDim2.new(0, sp.X, 0, sp.Y - 2)
    lb.ln.Position = UDim2.new(0, sp.X, 0, sp.Y + 24)
end

local function hideESP(key)
    if espLabels[key] then
        espLabels[key].f.Visible  = false
        espLabels[key].ln.Visible = false
    end
end

-- ────────────────────────── MAIN PANEL ──────────────────────────
destroyOld("FyZePanel")
local mGui = Instance.new("ScreenGui")
mGui.Name         = "FyZePanel"
mGui.ResetOnSpawn = false
pcall(function() mGui.IgnoreGuiInset = true end)
safeParent(mGui)

local W     = 225
local MAX_H = 400
local TH    = 28

-- Small icon button (top-left toggle)
local iconBtn = Instance.new("TextButton")
iconBtn.Size            = UDim2.new(0, 32, 0, 32)
iconBtn.Position        = UDim2.new(0, 4, 0, 4)
iconBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
iconBtn.Text            = "FH"
iconBtn.Font            = FB
iconBtn.TextSize        = 10
iconBtn.TextColor3      = Color3.fromRGB(90, 130, 255)
iconBtn.BorderSizePixel = 0          -- Delta: BorderSizePixel on buttons can glitch
iconBtn.Parent          = mGui
newCorner(iconBtn, 6)
newStroke(iconBtn, Color3.fromRGB(55, 90, 210), 1)

-- Main frame
local mf = Instance.new("Frame")
mf.Size             = UDim2.new(0, W, 0, TH)
mf.Position         = UDim2.new(0, 42, 0, 4)
mf.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
mf.BorderSizePixel  = 0
mf.ClipsDescendants = true
mf.Parent           = mGui
newCorner(mf, 7)
newStroke(mf, Color3.fromRGB(55, 90, 210), 1)

-- Title bar
local tb = Instance.new("Frame")
tb.Size             = UDim2.new(1, 0, 0, TH)
tb.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
tb.BorderSizePixel  = 0
tb.Parent           = mf
newCorner(tb, 7)

-- Square filler so rounded top doesn't show gap
local tbfx = Instance.new("Frame")
tbfx.Size             = UDim2.new(1, 0, 0.5, 0)
tbfx.Position         = UDim2.new(0, 0, 0.5, 0)
tbfx.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
tbfx.BorderSizePixel  = 0
tbfx.Parent           = tb

local titleLbl = Instance.new("TextLabel")
titleLbl.Size            = UDim2.new(1, -50, 1, 0)
titleLbl.Position        = UDim2.new(0, 8, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text            = "FyZe Hub"
titleLbl.TextColor3      = Color3.fromRGB(90, 130, 255)
titleLbl.Font            = FB
titleLbl.TextSize        = 11
titleLbl.TextXAlignment  = Enum.TextXAlignment.Left
titleLbl.Parent          = tb

local minBtn = Instance.new("TextButton")
minBtn.Size             = UDim2.new(0, 22, 0, 18)
minBtn.Position         = UDim2.new(1, -26, 0.5, -9)
minBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 46)
minBtn.Text             = "-"
minBtn.Font             = FB
minBtn.TextSize         = 13
minBtn.TextColor3       = Color3.fromRGB(200, 200, 200)
minBtn.BorderSizePixel  = 0
minBtn.Parent           = tb
newCorner(minBtn, 4)

-- Scroll area
local panelScroll = Instance.new("ScrollingFrame")
panelScroll.Size            = UDim2.new(1, 0, 1, -TH)
panelScroll.Position        = UDim2.new(0, 0, 0, TH)
panelScroll.BackgroundTransparency = 1
panelScroll.BorderSizePixel = 0
panelScroll.ScrollBarThickness = 3
-- Delta: ScrollBarImageColor3 can crash older Delta builds — wrap it
pcall(function() panelScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 90, 210) end)
panelScroll.CanvasSize      = UDim2.new(0, 0, 0, 0)
panelScroll.Parent          = mf

local content = Instance.new("Frame")
content.Size                = UDim2.new(1, 0, 0, 10)
content.BackgroundTransparency = 1
content.BorderSizePixel     = 0
content.Parent              = panelScroll

local listLayout = Instance.new("UIListLayout")
listLayout.Padding    = UDim.new(0, 1)
listLayout.SortOrder  = Enum.SortOrder.LayoutOrder
listLayout.Parent     = content

local listPad = Instance.new("UIPadding")
listPad.PaddingBottom = UDim.new(0, 6)
listPad.Parent        = content

local function resizePanel()
    if minimized then
        mf.Size = UDim2.new(0, W, 0, TH)
        return
    end
    local ch = listLayout.AbsoluteContentSize.Y + 8
    content.Size            = UDim2.new(1, 0, 0, ch)
    panelScroll.CanvasSize  = UDim2.new(0, 0, 0, ch)
    mf.Size                 = UDim2.new(0, W, 0, TH + math.min(ch, MAX_H - TH))
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)
ts(function() tw(0.05); resizePanel() end)

minBtn.MouseButton1Click:Connect(function()
    minimized             = not minimized
    panelScroll.Visible   = not minimized
    minBtn.Text           = minimized and "+" or "-"
    resizePanel()
end)

-- Layout helpers
local layoutOrder = 0
local function nlo() layoutOrder = layoutOrder + 1; return layoutOrder end

local function mkSection(txt)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, 16)
    f.LayoutOrder      = nlo()
    f.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    f.BorderSizePixel  = 0
    f.Parent           = content
    local l = Instance.new("TextLabel")
    l.Size            = UDim2.new(1, -8, 1, 0)
    l.Position        = UDim2.new(0, 8, 0, 0)
    l.BackgroundTransparency = 1
    l.Text            = txt
    l.TextColor3      = Color3.fromRGB(60, 90, 200)
    l.Font            = FB
    l.TextSize        = 9
    l.TextXAlignment  = Enum.TextXAlignment.Left
    l.Parent          = f
end

local function mkToggle(txt)
    local fr = Instance.new("Frame")
    fr.Size             = UDim2.new(1, 0, 0, 25)
    fr.LayoutOrder      = nlo()
    fr.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
    fr.BorderSizePixel  = 0
    fr.Parent           = content
    local lb = Instance.new("TextLabel")
    lb.Size            = UDim2.new(0.62, 0, 1, 0)
    lb.Position        = UDim2.new(0, 7, 0, 0)
    lb.BackgroundTransparency = 1
    lb.Text            = txt
    lb.TextColor3      = Color3.fromRGB(185, 185, 185)
    lb.Font            = FB
    lb.TextSize        = 10
    lb.TextXAlignment  = Enum.TextXAlignment.Left
    lb.Parent          = fr
    local stl = Instance.new("TextLabel")
    stl.Size           = UDim2.new(0.18, 0, 1, 0)
    stl.Position       = UDim2.new(0.62, 0, 0, 0)
    stl.BackgroundTransparency = 1
    stl.Text           = "OFF"
    stl.TextColor3     = Color3.fromRGB(255, 55, 55)
    stl.Font           = FB
    stl.TextSize       = 10
    stl.TextXAlignment = Enum.TextXAlignment.Right
    stl.Parent         = fr
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 30, 0, 16)
    btn.Position         = UDim2.new(1, -35, 0.5, -8)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.Text             = ""
    btn.BorderSizePixel  = 0
    btn.Parent           = fr
    newCorner(btn, 99)
    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 11, 0, 11)
    dot.Position         = UDim2.new(0, 2, 0.5, -5.5)
    dot.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    dot.BorderSizePixel  = 0
    dot.Parent           = btn
    newCorner(dot, 99)
    return fr, btn, dot, stl
end

local function mkActionBtn(txt, col, tcol)
    local fr = Instance.new("Frame")
    fr.Size            = UDim2.new(1, 0, 0, 22)
    fr.LayoutOrder     = nlo()
    fr.BackgroundTransparency = 1
    fr.BorderSizePixel = 0
    fr.Parent          = content
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(1, -12, 1, 0)
    b.Position         = UDim2.new(0, 6, 0, 0)
    b.BackgroundColor3 = col or Color3.fromRGB(28, 28, 44)
    b.Text             = txt
    b.TextColor3       = tcol or Color3.fromRGB(255, 255, 255)
    b.Font             = FB
    b.TextSize         = 10
    b.BorderSizePixel  = 0
    b.Parent           = fr
    newCorner(b, 4)
    return b
end

local function mkDiv()
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(1, -12, 0, 1)
    d.LayoutOrder      = nlo()
    d.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
    d.BorderSizePixel  = 0
    d.Parent           = content
end

-- Build UI sections
mkSection("COMBAT")
local _, espB,  espD,  espSt  = mkToggle("Player ESP")
local _, aaB,   aaD,   aaSt   = mkToggle("Kill Aura NPCs")
local _, apB,   apD,   apSt   = mkToggle("Kill Aura Players")
mkDiv()
mkSection("AIM")
local _, clpB,  clpD,  clpSt  = mkToggle("Cam Lock Players")
local _, clmB,  clmD,  clmSt  = mkToggle("Cam Lock Mobs")
local _, saB,   saD,   saSt   = mkToggle("Silent Aimbot")
mkDiv()
mkSection("MOVEMENT")
local _, dashB, dashD, dashSt = mkToggle("Dash Expander")
mkDiv()
mkSection("HITBOX")
local _, hbB,   hbD,   hbSt   = mkToggle("Hitbox Expander")
mkDiv()
mkSection("EXTRAS")
local _, acB,   acD,   acSt   = mkToggle("Auto Collect")
local _, paB,   paD,   paSt   = mkToggle("Proximity Alert")
mkDiv()
mkSection("RANGE")

-- Slider
local slFr = Instance.new("Frame")
slFr.Size             = UDim2.new(1, 0, 0, 36)
slFr.LayoutOrder      = nlo()
slFr.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
slFr.BorderSizePixel  = 0
slFr.Parent           = content

local sLbl = Instance.new("TextLabel")
sLbl.Size            = UDim2.new(0.5, 0, 0, 14)
sLbl.Position        = UDim2.new(0, 7, 0, 3)
sLbl.BackgroundTransparency = 1
sLbl.Text            = "Attack Range"
sLbl.TextColor3      = Color3.fromRGB(120, 120, 120)
sLbl.Font            = FB
sLbl.TextSize        = 9
sLbl.TextXAlignment  = Enum.TextXAlignment.Left
sLbl.Parent          = slFr

local sValL = Instance.new("TextLabel")
sValL.Size           = UDim2.new(0, 32, 0, 14)
sValL.Position       = UDim2.new(1, -40, 0, 3)
sValL.BackgroundTransparency = 1
sValL.Text           = tostring(atkRange)
sValL.TextColor3     = Color3.fromRGB(65, 100, 235)
sValL.Font           = FB
sValL.TextSize       = 10
sValL.TextXAlignment = Enum.TextXAlignment.Right
sValL.Parent         = slFr

local sTrk = Instance.new("Frame")
sTrk.Size             = UDim2.new(1, -50, 0, 5)
sTrk.Position         = UDim2.new(0, 7, 0, 22)
sTrk.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
sTrk.BorderSizePixel  = 0
sTrk.Parent           = slFr
newCorner(sTrk, 99)

local SMIN, SMAX   = 5, 999
local _initPct     = (atkRange - SMIN) / (SMAX - SMIN)

local sFill = Instance.new("Frame")
sFill.Size             = UDim2.new(_initPct, 0, 1, 0)
sFill.BackgroundColor3 = Color3.fromRGB(65, 100, 235)
sFill.BorderSizePixel  = 0
sFill.Parent           = sTrk
newCorner(sFill, 99)

local sThumb = Instance.new("TextButton")
sThumb.Size             = UDim2.new(0, 13, 0, 13)
sThumb.AnchorPoint      = Vector2.new(0.5, 0.5)
sThumb.Position         = UDim2.new(_initPct, 0, 0.5, 0)
sThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sThumb.Text             = ""
sThumb.BorderSizePixel  = 0
sThumb.Parent           = sTrk
newCorner(sThumb, 99)

local infB = Instance.new("TextButton")
infB.Size             = UDim2.new(0, 32, 0, 13)
infB.Position         = UDim2.new(1, -40, 0, 21)
infB.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
infB.Text             = "INF"
infB.TextColor3       = Color3.fromRGB(145, 145, 145)
infB.Font             = FB
infB.TextSize         = 9
infB.BorderSizePixel  = 0
infB.Parent           = slFr
newCorner(infB, 3)

mkDiv()
mkSection("TELEPORT")
local tpSkyBtn = mkActionBtn("^ TP to Sky",      Color3.fromRGB(44, 16, 80),  Color3.fromRGB(188, 148, 255))
local tpGndBtn = mkActionBtn("v Return Ground",  Color3.fromRGB(16, 48, 20),  Color3.fromRGB(108, 218, 108))
local tpSCBtn  = mkActionBtn("Sea Castle",       Color3.fromRGB(18, 38, 76),  Color3.fromRGB(108, 155, 245))
local tpManBtn = mkActionBtn("Mansion",          Color3.fromRGB(58, 32, 12),  Color3.fromRGB(215, 165, 82))
mkDiv()
mkSection("PLAYERS")

local pScrollFr = Instance.new("Frame")
pScrollFr.Size            = UDim2.new(1, 0, 0, 85)
pScrollFr.LayoutOrder     = nlo()
pScrollFr.BackgroundTransparency = 1
pScrollFr.BorderSizePixel = 0
pScrollFr.Parent          = content

local pScroll = Instance.new("ScrollingFrame")
pScroll.Size              = UDim2.new(1, 0, 1, 0)
pScroll.BackgroundTransparency = 1
pScroll.BorderSizePixel   = 0
pScroll.ScrollBarThickness = 2
pcall(function() pScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 90, 210) end)
pScroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
pScroll.Parent            = pScrollFr

local pLL = Instance.new("UIListLayout")
pLL.Padding   = UDim.new(0, 2)
pLL.SortOrder = Enum.SortOrder.Name
pLL.Parent    = pScroll

local pLP = Instance.new("UIPadding")
pLP.PaddingLeft  = UDim.new(0, 4)
pLP.PaddingRight = UDim.new(0, 4)
pLP.PaddingTop   = UDim.new(0, 3)
pLP.Parent       = pScroll

-- Spacer at bottom
local spEnd = Instance.new("Frame")
spEnd.Size            = UDim2.new(1, 0, 0, 4)
spEnd.BackgroundTransparency = 1
spEnd.BorderSizePixel = 0
spEnd.LayoutOrder     = nlo()
spEnd.Parent          = content

-- ────────────────────────── TOGGLE HELPER ──────────────────────────
local function setTog(on, btn, dot, stl)
    if on then
        btn.BackgroundColor3 = Color3.fromRGB(50, 86, 220)
        dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        dot.Position         = UDim2.new(1, -13, 0.5, -5.5)
        stl.Text             = "ON"
        stl.TextColor3       = Color3.fromRGB(55, 195, 95)
    else
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        dot.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
        dot.Position         = UDim2.new(0, 2, 0.5, -5.5)
        stl.Text             = "OFF"
        stl.TextColor3       = Color3.fromRGB(255, 55, 55)
    end
end

local function updateSlider()
    if atkInf then
        sValL.Text             = "INF"
        sValL.TextColor3       = Color3.fromRGB(255, 178, 40)
        infB.BackgroundColor3  = Color3.fromRGB(50, 86, 220)
        infB.TextColor3        = Color3.fromRGB(255, 255, 255)
        sFill.Size             = UDim2.new(1, 0, 1, 0)
        sThumb.Position        = UDim2.new(1, 0, 0.5, 0)
    else
        local pct              = (atkRange - SMIN) / (SMAX - SMIN)
        sValL.Text             = tostring(atkRange)
        sValL.TextColor3       = Color3.fromRGB(65, 100, 235)
        infB.BackgroundColor3  = Color3.fromRGB(26, 26, 44)
        infB.TextColor3        = Color3.fromRGB(145, 145, 145)
        sFill.Size             = UDim2.new(pct, 0, 1, 0)
        sThumb.Position        = UDim2.new(pct, 0, 0.5, 0)
    end
end

-- ────────────────────────── PLAYER SET ──────────────────────────
local function rebuildPSet()
    pSet = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then pSet[p.Character] = true end
    end
end

local function getDesc()
    local now = tick()
    if now - lastScan >= 2 and not descLock then
        descLock  = true
        descCache = workspace:GetDescendants()
        lastScan  = tick()
        descLock  = false
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
lastScan  = tick()

-- ────────────────────────── TARGET FINDERS ──────────────────────────
-- BF stores NPCs in workspace.Enemies; scan it directly for mobs (faster + more reliable
-- after the update that restructured the workspace hierarchy).
local Enemies = workspace:WaitForChild("Enemies", 10)

local function iterTargets(wantP, wantM, root, rangeLimit)
    local out = {}
    -- NPC pass: use workspace.Enemies when available, fall back to full desc scan
    if wantM then
        local src = Enemies or workspace
        for _, model in ipairs(src:GetChildren()) do
            if model ~= lp.Character and not pSet[model] then
                local hum = model:FindFirstChildOfClass("Humanoid")
                local r   = model:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and r then
                    local d = (root.Position - r.Position).Magnitude
                    if atkInf or d <= (rangeLimit or atkRange) then
                        out[#out + 1] = {h = hum, root = r, model = model, dist = d}
                    end
                end
            end
        end
    end
    -- Player pass: walk player list directly (no desc scan needed)
    if wantP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local r   = p.Character:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and r then
                    local d = (root.Position - r.Position).Magnitude
                    if atkInf or d <= (rangeLimit or atkRange) then
                        out[#out + 1] = {h = hum, root = r, model = p.Character, dist = d}
                    end
                end
            end
        end
    end
    return out
end

local function getAllTargets(wantP, wantM)
    local char = lp.Character
    if not char then return {} end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return {} end
    return iterTargets(wantP, wantM, root)
end

local function nearestOf(wantP, wantM, range)
    local char = lp.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local tgts = iterTargets(wantP, wantM, root, range or 1e9)
    local best, bestD = nil, range or 1e9
    for _, t in ipairs(tgts) do
        if t.dist < bestD then bestD = t.dist; best = t end
    end
    return best
end

-- ────────────────────────── HITBOX ──────────────────────────
local hbOriginals = {}
local function expandHitboxes()
    if not hitboxOn then return end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Parent and v.Parent ~= lp.Character
            and v.Parent:FindFirstChildOfClass("Humanoid") then
            if not hbOriginals[v] then hbOriginals[v] = v.Size end
            pcall(function() v.Size = Vector3.new(15, 15, 15) end)
        end
    end
end

local function restoreHitboxes()
    for part, orig in pairs(hbOriginals) do
        pcall(function() if part and part.Parent then part.Size = orig end end)
    end
    hbOriginals = {}
end

-- ────────────────────────── DASH HOOK ──────────────────────────
local dashHooked = false
local function hookDash()
    if dashHooked or not _grm or not _sro then return end
    dashHooked = true
    pcall(function()
        local mt  = _grm(game)
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

-- ────────────────────────── TELEPORT ──────────────────────────
local LOCS = {
    SEA_CASTLE = Vector3.new(4917, 275, -4814),
    MANSION    = Vector3.new(-1384, 263, -2987),
}
local tpActive  = false
local groundPos = nil
local skyPos    = nil
local hitReg    = {}

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
    if hum then tw(0.1); hum.PlatformStand = false end
end

local function tweenSky(pos, dur)
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    local ok, twnObj = pcall(function()
        return TweenSvc:Create(hrp,
            TweenInfo.new(dur or 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {CFrame = CFrame.new(pos)})
    end)
    if ok and twnObj then
        twnObj:Play()
        twnObj.Completed:Wait()
    else
        teleportTo(pos)
    end
    if hum then tw(0.1); hum.PlatformStand = false end
end

local function setSkyUI(on)
    tpSkyBtn.Text             = on and "^ In Sky (tap=land)" or "^ TP to Sky"
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
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    groundPos  = hrp.Position
    local h    = 4200 + math.random(0, 800)
    skyPos     = Vector3.new(
        groundPos.X + (math.random() - 0.5) * 10,
        groundPos.Y + h,
        groundPos.Z + (math.random() - 0.5) * 10)
    tpActive   = true
    setSkyUI(true)
    ts(tweenSky, skyPos, 2.0)
    ts(function()
        tw(2.2)
        while tpActive do
            local c  = lp.Character
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
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local dest = groundPos and groundPos + Vector3.new(0, 3, 0)
        or Vector3.new(hrp.Position.X, hrp.Position.Y - 400, hrp.Position.Z)
    ts(teleportTo, dest)
end)

tpSCBtn.MouseButton1Click:Connect(function()  ts(teleportTo, LOCS.SEA_CASTLE) end)
tpManBtn.MouseButton1Click:Connect(function() ts(teleportTo, LOCS.MANSION)    end)

lp.CharacterAdded:Connect(function()
    hitReg    = {}
    tpActive  = false
    groundPos = nil
    skyPos    = nil
    setSkyUI(false)
    hookDash()
    rebuildPSet()
    -- Reset all cached remotes so they re-resolve in the new character/session
    cachedKLC = nil
    RE_Atk    = nil
    RE_Hit    = nil
end)

-- ────────────────────────── SILENT AIM ──────────────────────────
local function doSilentAim()
    if not silentAim or not _mmr then return end
    local char = lp.Character
    if not char then return end
    local vp     = Camera.ViewportSize
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
        local d  = (sv - center).Magnitude
        if d < bestD then bestD = d; best = sv end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then check(p.Character) end
    end
    -- Check NPCs from workspace.Enemies (faster than full desc scan)
    local enemySrc = Enemies or workspace
    for _, model in ipairs(enemySrc:GetChildren()) do
        if model ~= char and not pSet[model] then check(model) end
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

-- ────────────────────────── KITSUNE ATTACK (updated for BF post-upd30) ──────────────────────────
-- Remote paths confirmed working post-update:
--   RS.Modules.Net["RE/RegisterAttack"]  – fires the M1 swing animation / damage registration
--   RS.Modules.Net["RE/RegisterHit"]     – registers a hit on a specific HumanoidRootPart
-- The old LeftClickRemote + sHash approach broke when BF moved damage validation server-side.
-- We now fire RegisterAttack first, then RegisterHit for each target part, matching what the
-- legitimate game client sends during a normal M1 combo.

local Net = RS:WaitForChild("Modules", 10)
Net = Net and Net:WaitForChild("Net", 10)

local RE_Atk  = Net and Net:FindFirstChild("RE/RegisterAttack")
local RE_Hit  = Net and Net:FindFirstChild("RE/RegisterHit")

-- Refresh remotes if they weren't ready at load time (can happen right after join)
local function ensureRemotes()
    if RE_Atk and RE_Hit then return true end
    local mods = RS:FindFirstChild("Modules")
    local net  = mods and mods:FindFirstChild("Net")
    if not net then return false end
    RE_Atk = RE_Atk or net:FindFirstChild("RE/RegisterAttack")
    RE_Hit = RE_Hit or net:FindFirstChild("RE/RegisterHit")
    return RE_Atk ~= nil and RE_Hit ~= nil
end

-- cachedKLC kept for the Kitsune fruit LeftClickRemote (still used to trigger the swing VFX)
local cachedKLC = nil
local function getKLC()
    local char = lp.Character
    if not char then return nil end
    if cachedKLC and cachedKLC.Parent then return cachedKLC end
    cachedKLC = nil
    -- Tool name is still "Kitsune-Kitsune" in the character
    local t = char:FindFirstChild("Kitsune-Kitsune")
    if not t then return nil end
    local r = t:FindFirstChild("LeftClickRemote")
    if r then cachedKLC = r end
    return r
end

local function jit(b, a) return b + (math.random() * a * 2 - a) * 0.001 end

local function fireKitsune(tgt, hrp)
    if not tgt.h or tgt.h.Health <= 0 then return false end
    if not ensureRemotes() then return false end

    local dir = tgt.root.Position - hrp.Position
    local du  = dir.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 1)

    -- 1. Fire the swing via LeftClickRemote (VFX / animation trigger)
    local lc = getKLC()
    if lc then
        local vd = Vector3.new(
            du.X + (math.random() - 0.5) * 0.06,
            du.Y + (math.random() - 0.5) * 0.06,
            du.Z + (math.random() - 0.5) * 0.06
        ).Unit
        pcall(function() lc:FireServer(vd, 1, true) end)
    end

    -- 2. Register the attack tick (tells server an M1 happened)
    pcall(function() RE_Atk:FireServer(0.4) end)
    tw(jit(0.03, 8))

    -- 3. Register the hit on the target's HumanoidRootPart
    --    Also try ModelHitbox if present (larger NPCs use it)
    local hitParts = {}
    local hb = tgt.model:FindFirstChild("ModelHitbox")
    if hb then hitParts[#hitParts + 1] = hb end
    hitParts[#hitParts + 1] = tgt.root   -- HumanoidRootPart always last

    for _, part in ipairs(hitParts) do
        pcall(function() RE_Hit:FireServer(part, {}, nil) end)
        tw(jit(0.018, 6))
    end

    return true
end

local function fireAttack(tgt)
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not tgt.model then return end
    local hum = tgt.h
    local n   = 0
    while n < 30 do
        if not hum or not hum.Parent or hum.Health <= 0 then break end
        if not fireKitsune(tgt, hrp) then break end
        n = n + 1
        tw(jit(0.045, 15))
    end
end

-- ────────────────────────── ATTACK LOOP ──────────────────────────
local atkRunning = false
local function startAtkLoop()
    if atkRunning then return end
    atkRunning = true
    ts(function()
        while aaOn or apAtkOn do
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

-- (hash sniffer removed – BF post-upd30 validates hits server-side; no client hash needed)

-- ────────────────────────── BUTTON WIRING ──────────────────────────
iconBtn.MouseButton1Click:Connect(function()
    uiOpen = not uiOpen
    mf.Visible       = uiOpen
    iconBtn.TextColor3 = uiOpen and Color3.fromRGB(90, 130, 255) or Color3.fromRGB(70, 70, 105)
end)

setTog(true, espB, espD, espSt)   -- ESP on by default; sync visual state

espB.MouseButton1Click:Connect(function()
    espOn = not espOn
    setTog(espOn, espB, espD, espSt)
    if not espOn then
        for _, lb in pairs(espLabels) do
            lb.f.Visible  = false
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

clpB.MouseButton1Click:Connect(function()  camLockP  = not camLockP;  setTog(camLockP,  clpB, clpD, clpSt)  end)
clmB.MouseButton1Click:Connect(function()  camLockM  = not camLockM;  setTog(camLockM,  clmB, clmD, clmSt)  end)
saB.MouseButton1Click:Connect(function()   silentAim = not silentAim; setTog(silentAim, saB,  saD,  saSt)   end)
dashB.MouseButton1Click:Connect(function() dashOn    = not dashOn;    setTog(dashOn,    dashB,dashD,dashSt)  end)
hbB.MouseButton1Click:Connect(function()
    hitboxOn = not hitboxOn
    setTog(hitboxOn, hbB, hbD, hbSt)
    if not hitboxOn then restoreHitboxes() end
end)
acB.MouseButton1Click:Connect(function()  autoCollect   = not autoCollect;   setTog(autoCollect,   acB, acD, acSt)  end)
paB.MouseButton1Click:Connect(function()  proximityAlert = not proximityAlert; setTog(proximityAlert, paB, paD, paSt) end)
infB.MouseButton1Click:Connect(function() atkInf = not atkInf; updateSlider() end)
updateSlider()

-- ────────────────────────── DRAG (panel) ──────────────────────────
local dragging, dragStart, dragOrigin = false, nil, nil
tb.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        dragging   = true
        dragStart  = inp.Position
        dragOrigin = mf.Position
    end
end)

local sliding = false
sTrk.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        sliding = true
    end
end)
sThumb.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        sliding = true
    end
end)

UIS.InputChanged:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    if dragging and dragStart then
        local d  = inp.Position - dragStart
        mf.Position = UDim2.new(
            dragOrigin.X.Scale, dragOrigin.X.Offset + d.X,
            dragOrigin.Y.Scale, dragOrigin.Y.Offset + d.Y)
    end
    if sliding then
        local ax = sTrk.AbsolutePosition.X
        local aw = sTrk.AbsoluteSize.X
        if aw > 0 then
            atkRange = math.floor(SMIN + math.clamp((inp.Position.X - ax) / aw, 0, 1) * (SMAX - SMIN))
            atkInf   = false
            updateSlider()
        end
    end
end)

UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        dragging   = false
        sliding    = false
        dragStart  = nil
        dragOrigin = nil
    end
end)

-- ────────────────────────── PLAYER LIST ──────────────────────────
local pLabels = {}

local function createPLabel(player)
    local row = Instance.new("Frame")
    row.Name            = player.Name
    row.Size            = UDim2.new(1, 0, 0, 23)
    row.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    row.BorderSizePixel = 0
    row.Parent          = pScroll
    newCorner(row, 3)
    local nl = Instance.new("TextLabel")
    nl.Size            = UDim2.new(1, -4, 0.5, 0)
    nl.Position        = UDim2.new(0, 5, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Text            = player.Name
    nl.TextColor3      = Color3.fromRGB(255, 255, 255)
    nl.Font            = FB
    nl.TextSize        = 9
    nl.TextXAlignment  = Enum.TextXAlignment.Left
    nl.Parent          = row
    local il = Instance.new("TextLabel")
    il.Size            = UDim2.new(1, -4, 0.5, 0)
    il.Position        = UDim2.new(0, 5, 0.5, 0)
    il.BackgroundTransparency = 1
    il.Text            = "..."
    il.TextColor3      = Color3.fromRGB(115, 115, 115)
    il.Font            = FR
    il.TextSize        = 8
    il.TextXAlignment  = Enum.TextXAlignment.Left
    il.Parent          = row
    pLabels[player]    = {nl = nl, il = il}
end

local function removePLabel(player)
    if not pLabels[player] then return end
    pcall(function()
        local r = pScroll:FindFirstChild(player.Name)
        if r then r:Destroy() end
    end)
    pLabels[player] = nil
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= lp then createPLabel(p) end
end
Players.PlayerAdded:Connect(function(p)   if p ~= lp then createPLabel(p) end end)
Players.PlayerRemoving:Connect(function(p) removePLabel(p); hideESP(p.Name) end)

-- ────────────────────────── JUMP BUTTON ──────────────────────────
destroyOld("FyZeJump")
local jGui = Instance.new("ScreenGui")
jGui.Name         = "FyZeJump"
jGui.ResetOnSpawn = false
pcall(function() jGui.IgnoreGuiInset = true end)
safeParent(jGui)

local jBtn = Instance.new("TextButton")
jBtn.Size             = UDim2.new(0, 50, 0, 50)
jBtn.Position         = UDim2.new(1, -64, 1, -64)   -- bottom-right, scale-safe
jBtn.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
jBtn.Text             = "^"
jBtn.Font             = FB
jBtn.TextSize         = 22
jBtn.TextColor3       = Color3.fromRGB(100, 195, 100)
jBtn.BorderSizePixel  = 0
jBtn.Parent           = jGui
newCorner(jBtn, 99)
newStroke(jBtn, Color3.fromRGB(45, 150, 70), 1)

local jDrag  = false
local jDS    = nil
local jDO    = nil
local jMoved = 0

jBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        jDrag  = true
        jMoved = 0
        jDS    = Vector2.new(inp.Position.X, inp.Position.Y)
        jDO    = Vector2.new(jBtn.AbsolutePosition.X, jBtn.AbsolutePosition.Y)
    end
end)

jBtn.InputChanged:Connect(function(inp)
    if not jDrag then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local dx = inp.Position.X - jDS.X
    local dy = inp.Position.Y - jDS.Y
    jMoved   = math.sqrt(dx * dx + dy * dy)
    jBtn.Position = UDim2.new(0, jDO.X + dx, 0, jDO.Y + dy)
end)

jBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
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
        if not pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(
                hrp.AssemblyLinearVelocity.X, 130, hrp.AssemblyLinearVelocity.Z)
        end) then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, 130, hrp.Velocity.Z)
        end
    end)
end)

-- ────────────────────────── HEARTBEAT ──────────────────────────
local frame     = 0
local lastCount = -1

RunService.Heartbeat:Connect(function()
    frame = frame + 1
    if hitboxOn  and frame % 30 == 0 then expandHitboxes() end
    if frame % 2 ~= 0 then return end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if silentAim then doSilentAim() end

    if camLockP then
        local t = nearestOf(true, false, AIM_RANGE)
        if t then
            pcall(function()
                Camera.CFrame = CFrame.new(Camera.CFrame.Position,
                    t.root.Position + Vector3.new(0, 2, 0))
            end)
        end
    end

    if camLockM then
        local t = nearestOf(false, true, AIM_RANGE)
        if t then
            pcall(function()
                Camera.CFrame = CFrame.new(Camera.CFrame.Position,
                    t.root.Position + Vector3.new(0, 2, 0))
            end)
        end
    end

    local count = 0
    for player, data in pairs(pLabels) do
        count = count + 1
        local c  = player.Character
        local r2 = c and c:FindFirstChild("HumanoidRootPart")
        local hd = c and c:FindFirstChild("Head")
        if root and r2 then
            local dist = math.floor((root.Position - r2.Position).Magnitude)
            local hm   = c:FindFirstChildOfClass("Humanoid")
            local hp   = hm and math.floor(hm.Health)    or 0
            local mhp  = hm and math.floor(hm.MaxHealth) or 100
            data.il.Text = dist .. "m " .. hp .. "/" .. mhp
            data.nl.TextColor3 = hp <= 0  and Color3.fromRGB(90,  90,  90)
                or dist < 20              and Color3.fromRGB(255, 55,  55)
                or dist < 60              and Color3.fromRGB(255, 185, 0)
                or                            Color3.fromRGB(255, 255, 255)
            data.il.TextColor3 = hp <= 0 and Color3.fromRGB(90, 90, 90)
                or Color3.fromRGB(85, 180, 85)
            if espOn and hd then
                showESP(player.Name, hd.Position + Vector3.new(0, 2.5, 0),
                    player.Name, hp, mhp, dist, true)
            elseif not espOn then
                hideESP(player.Name)
            end
        else
            data.il.Text       = "offline"
            data.nl.TextColor3 = Color3.fromRGB(115, 115, 115)
            data.il.TextColor3 = Color3.fromRGB(70,  70,  70)
            hideESP(player.Name)
        end
    end

    if count ~= lastCount then
        pScroll.CanvasSize = UDim2.new(0, 0, 0, count * 25 + 6)
        lastCount = count
    end

    if autoCollect and root and frame % 15 == 0 then
        pcall(function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") then
                    local n = v.Name
                    if n == "Collectible" or n == "Coin" or n == "Chest"
                        or n == "Drop" or n == "SeaFruit" then
                        if (root.Position - v.Position).Magnitude < 120 then
                            local h2 = lp.Character
                                and lp.Character:FindFirstChild("HumanoidRootPart")
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
