-- ═══════════════════════════════════════════════════════
--   FyZe Hub | Blox Fruits  v9
--   Upload this file to GitHub, then run in Delta:
--
--   loadstring(game:HttpGet("YOUR_RAW_URL",true))()
--
--   Raw URL format:
--   https://raw.githubusercontent.com/fmakessongs-cmd/aim/main/aim.lua
-- ═══════════════════════════════════════════════════════

-- ── self-contained: no separate loader needed ──────────
-- This file IS the script. Just loadstring the raw URL.
-- Anti-duplicate: destroy any old GUI instances on re-run

-- ── services ────────────────────────────────
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local Camera     = workspace.CurrentCamera
local lp         = Players.LocalPlayer
local mouse      = lp:GetMouse()

-- ── safe wrappers (Delta mobile has none of these) ──
local _mousemoverel = type(mousemoverel)=="function" and mousemoverel or nil
local _getrawmeta   = type(getrawmetatable)=="function" and getrawmetatable or nil
local _setreadonly  = type(setreadonly)=="function" and setreadonly or nil
local _newcc        = type(newcclosure)=="function" and newcclosure or function(f) return f end
local _getnc        = type(getnamecallmethod)=="function" and getnamecallmethod or nil

-- ── task shims (Delta may not have full task lib) ──
local tw  = type(task)=="table" and task.wait  or wait
local ts  = type(task)=="table" and task.spawn or function(f,...) coroutine.wrap(f)(...) end

-- ── GUI parent: CoreGui works on Delta mobile ───────
-- PlayerGui WaitForChild hangs during injection on mobile
local function makeGUI(name)
    -- destroy old instance to prevent duplicates on re-run
    pcall(function()
        local old = game:GetService("CoreGui"):FindFirstChild(name)
        if old then old:Destroy() end
    end)
    pcall(function()
        local old = lp.PlayerGui:FindFirstChild(name)
        if old then old:Destroy() end
    end)
    local g = Instance.new("ScreenGui")
    g.Name = name
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    -- try CoreGui first (works on Delta Android/iOS)
    local ok = pcall(function() g.Parent = game:GetService("CoreGui") end)
    if not ok then
        -- fallback: PlayerGui (PC executors)
        pcall(function() g.Parent = lp.PlayerGui end)
    end
    return g
end

-- ── fonts (Gotham may not render on mobile) ─────────
local FB = Enum.Font.GothamBold  or Enum.Font.SourceSansBold
local FR = Enum.Font.Gotham      or Enum.Font.SourceSans
pcall(function() FB = Enum.Font.GothamBold end)
pcall(function() FR = Enum.Font.Gotham     end)

-- ── state ────────────────────────────────────────────
local AIM_RANGE      = 250
local atkRange       = 20
local atkInf         = false
local aaOn           = false
local apAtkOn        = false
local camLockP       = false
local camLockM       = false
local silentAim      = false
local espOn          = true
local hitboxOn       = false
local hitboxSize     = 15
local dashOn         = false
local DASH_MULT      = 3
local uiOpen         = true
local weaponMode     = 1     -- 1=Kitsune  2=T-Rex
local autoCollect    = false
local proximityAlert = false
local lastAlertTime  = {}
local minimized      = false

-- ═══════════════════════════════════════════
-- ESP GUI
-- ═══════════════════════════════════════════
local eGui = makeGUI("FyZeESP")

local espLabels = {}
local function getLabel(key,isP)
    if espLabels[key] then return espLabels[key] end
    local col = isP and Color3.fromRGB(255,55,55) or Color3.fromRGB(55,220,100)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0,120,0,26)
    f.BackgroundColor3 = Color3.fromRGB(8,8,14)
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel = 0
    f.AnchorPoint = Vector2.new(0.5,1)
    f.Parent = eGui
    pcall(function() Instance.new("UICorner",f).CornerRadius = UDim.new(0,4) end)
    pcall(function()
        local st = Instance.new("UIStroke",f); st.Color=col; st.Thickness=1
    end)
    local n = Instance.new("TextLabel",f)
    n.Size = UDim2.new(1,0,0.5,0); n.Position = UDim2.new(0,0,0,0)
    n.BackgroundTransparency=1; n.Font=FB; n.TextSize=9
    n.TextColor3=Color3.fromRGB(255,255,255)
    n.TextXAlignment=Enum.TextXAlignment.Center; n.Text=key
    local i = Instance.new("TextLabel",f)
    i.Size = UDim2.new(1,0,0.5,0); i.Position = UDim2.new(0,0,0.5,0)
    i.BackgroundTransparency=1; i.Font=FR; i.TextSize=8
    i.TextColor3=Color3.fromRGB(150,150,150)
    i.TextXAlignment=Enum.TextXAlignment.Center; i.Text="..."
    local ln = Instance.new("Frame")
    ln.Size=UDim2.new(0,1,0,7); ln.AnchorPoint=Vector2.new(0.5,0)
    ln.BackgroundColor3=col; ln.BackgroundTransparency=0.3
    ln.BorderSizePixel=0; ln.Parent=eGui
    espLabels[key] = {f=f,n=n,i=i,ln=ln}
    return espLabels[key]
end
local function showESP(key,pos,name,hp,mhp,dist,isP)
    local lb=getLabel(key,isP)
    local ok,sp,vis=pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok or not vis then lb.f.Visible=false; lb.ln.Visible=false; return end
    lb.n.Text=name; lb.i.Text=dist.."m "..hp.."/"..mhp
    lb.f.Visible=true; lb.ln.Visible=true
    lb.f.Position=UDim2.new(0,sp.X,0,sp.Y-2)
    lb.ln.Position=UDim2.new(0,sp.X,0,sp.Y+24)
end
local function hideESP(key)
    if espLabels[key] then espLabels[key].f.Visible=false; espLabels[key].ln.Visible=false end
end

-- ═══════════════════════════════════════════
-- PANEL GUI
-- ═══════════════════════════════════════════
local mGui = makeGUI("FyZePanel")

local W = 225   -- panel width
local MAX_H = 400  -- max panel height (scrolls inside)
local TH = 28   -- title bar height

-- icon button (always visible)
local iconBtn = Instance.new("TextButton", mGui)
iconBtn.Size = UDim2.new(0,32,0,32)
iconBtn.Position = UDim2.new(0,4,0,4)
iconBtn.BackgroundColor3 = Color3.fromRGB(14,14,24)
iconBtn.Text = "FH"  -- "FyZe Hub" — no emoji, Delta renders badly
iconBtn.Font = FB; iconBtn.TextSize = 10
iconBtn.TextColor3 = Color3.fromRGB(90,130,255)
iconBtn.BorderSizePixel = 1
iconBtn.BorderColor3 = Color3.fromRGB(55,90,210)
pcall(function() Instance.new("UICorner",iconBtn).CornerRadius=UDim.new(0,6) end)

-- main panel
local mf = Instance.new("Frame", mGui)
mf.Size = UDim2.new(0,W,0,TH)
mf.Position = UDim2.new(0,42,0,4)
mf.BackgroundColor3 = Color3.fromRGB(10,10,16)
mf.BorderSizePixel = 1
mf.BorderColor3 = Color3.fromRGB(55,90,210)
mf.ClipsDescendants = true
pcall(function() Instance.new("UICorner",mf).CornerRadius=UDim.new(0,7) end)

-- title bar
local tb = Instance.new("Frame", mf)
tb.Size = UDim2.new(1,0,0,TH)
tb.BackgroundColor3 = Color3.fromRGB(14,14,22)
tb.BorderSizePixel = 0
pcall(function() Instance.new("UICorner",tb).CornerRadius=UDim.new(0,7) end)
-- cover bottom corners of titlebar
local tbfx = Instance.new("Frame",tb)
tbfx.Size=UDim2.new(1,0,0.5,0); tbfx.Position=UDim2.new(0,0,0.5,0)
tbfx.BackgroundColor3=Color3.fromRGB(14,14,22); tbfx.BorderSizePixel=0

local titleLbl = Instance.new("TextLabel", tb)
titleLbl.Size = UDim2.new(1,-50,1,0)
titleLbl.Position = UDim2.new(0,8,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "FyZe Hub"
titleLbl.TextColor3 = Color3.fromRGB(90,130,255)
titleLbl.Font = FB; titleLbl.TextSize = 11
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton", tb)
minBtn.Size = UDim2.new(0,22,0,18)
minBtn.Position = UDim2.new(1,-26,0.5,-9)
minBtn.BackgroundColor3 = Color3.fromRGB(28,28,46)
minBtn.Text = "-"; minBtn.Font = FB; minBtn.TextSize = 13
minBtn.TextColor3 = Color3.fromRGB(200,200,200)
minBtn.BorderSizePixel = 0
pcall(function() Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,4) end)

-- scrolling content area (NO AutomaticCanvasSize — Delta crashes)
local panelScroll = Instance.new("ScrollingFrame", mf)
panelScroll.Size = UDim2.new(1,0,1,-TH)
panelScroll.Position = UDim2.new(0,0,0,TH)
panelScroll.BackgroundTransparency = 1
panelScroll.BorderSizePixel = 0
panelScroll.ScrollBarThickness = 3
panelScroll.ScrollBarImageColor3 = Color3.fromRGB(55,90,210)
panelScroll.CanvasSize = UDim2.new(0,0,0,0)
-- DO NOT set AutomaticCanvasSize or ScrollingDirection — Delta doesn't support them

local content = Instance.new("Frame", panelScroll)
content.Size = UDim2.new(1,0,0,10)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0

local listLayout = Instance.new("UIListLayout", content)
listLayout.Padding = UDim.new(0,1)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
local listPad = Instance.new("UIPadding", content)
listPad.PaddingBottom = UDim.new(0,6)

-- manually resize panel each time layout changes
local function resizePanel()
    if minimized then
        mf.Size = UDim2.new(0,W,0,TH)
        return
    end
    local ch = listLayout.AbsoluteContentSize.Y + 8
    content.Size = UDim2.new(1,0,0,ch)
    panelScroll.CanvasSize = UDim2.new(0,0,0,ch)
    local ph = math.min(ch, MAX_H - TH)
    mf.Size = UDim2.new(0,W,0,TH + ph)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)
-- defer to ensure layout has computed sizes first
ts(function() tw(0.05); resizePanel() end)

-- minimize
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    panelScroll.Visible = not minimized
    minBtn.Text = minimized and "+" or "-"
    resizePanel()
end)

-- ── UI builder helpers ────────────────────────────────
local lo = 0
local function nlo() lo=lo+1; return lo end
local ROW = 25

local function mkSection(txt)
    local f = Instance.new("Frame",content)
    f.Size = UDim2.new(1,0,0,16); f.LayoutOrder=nlo()
    f.BackgroundColor3 = Color3.fromRGB(18,18,30); f.BorderSizePixel=0
    local l = Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,-8,1,0); l.Position=UDim2.new(0,8,0,0)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=Color3.fromRGB(60,90,200); l.Font=FB; l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left
end

local function mkToggle(txt)
    local fr = Instance.new("Frame",content)
    fr.Size=UDim2.new(1,0,0,ROW); fr.LayoutOrder=nlo()
    fr.BackgroundColor3=Color3.fromRGB(12,12,20); fr.BorderSizePixel=0
    local lb = Instance.new("TextLabel",fr)
    lb.Size=UDim2.new(0.62,0,1,0); lb.Position=UDim2.new(0,7,0,0)
    lb.BackgroundTransparency=1; lb.Text=txt
    lb.TextColor3=Color3.fromRGB(185,185,185); lb.Font=FB; lb.TextSize=10
    lb.TextXAlignment=Enum.TextXAlignment.Left
    local stl = Instance.new("TextLabel",fr)
    stl.Size=UDim2.new(0.18,0,1,0); stl.Position=UDim2.new(0.62,0,0,0)
    stl.BackgroundTransparency=1; stl.Text="OFF"
    stl.TextColor3=Color3.fromRGB(255,55,55); stl.Font=FB; stl.TextSize=10
    stl.TextXAlignment=Enum.TextXAlignment.Right
    local btn = Instance.new("TextButton",fr)
    btn.Size=UDim2.new(0,30,0,16); btn.Position=UDim2.new(1,-35,0.5,-8)
    btn.BackgroundColor3=Color3.fromRGB(40,40,60); btn.Text=""; btn.BorderSizePixel=0
    pcall(function() Instance.new("UICorner",btn).CornerRadius=UDim.new(1,0) end)
    local dot = Instance.new("Frame",btn)
    dot.Size=UDim2.new(0,11,0,11); dot.Position=UDim2.new(0,2,0.5,-5.5)
    dot.BackgroundColor3=Color3.fromRGB(120,120,120); dot.BorderSizePixel=0
    pcall(function() Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0) end)
    return fr,btn,dot,stl
end

local function mkActionBtn(txt,col,tcol)
    local fr = Instance.new("Frame",content)
    fr.Size=UDim2.new(1,0,0,22); fr.LayoutOrder=nlo()
    fr.BackgroundTransparency=1; fr.BorderSizePixel=0
    local b = Instance.new("TextButton",fr)
    b.Size=UDim2.new(1,-12,1,0); b.Position=UDim2.new(0,6,0,0)
    b.BackgroundColor3=col or Color3.fromRGB(28,28,44)
    b.Text=txt; b.TextColor3=tcol or Color3.fromRGB(255,255,255)
    b.Font=FB; b.TextSize=10; b.BorderSizePixel=0
    pcall(function() Instance.new("UICorner",b).CornerRadius=UDim.new(0,4) end)
    return b
end

local function mkDiv()
    local d=Instance.new("Frame",content)
    d.Size=UDim2.new(1,-12,0,1); d.LayoutOrder=nlo()
    d.BackgroundColor3=Color3.fromRGB(26,26,44); d.BorderSizePixel=0
end

-- ── build all rows ────────────────────────────────────
mkSection(" COMBAT")
local _,espB,espD,espSt    = mkToggle("Player ESP")
local _,aaB,aaD,aaSt       = mkToggle("Kill Aura NPCs")
local _,apB,apD,apSt       = mkToggle("Kill Aura Players")
mkDiv()
mkSection(" AIM")
local _,clpB,clpD,clpSt    = mkToggle("Cam Lock Players")
local _,clmB,clmD,clmSt    = mkToggle("Cam Lock Mobs")
local _,saB,saD,saSt       = mkToggle("Silent Aimbot")
mkDiv()
mkSection(" MOVEMENT")
local _,dashB,dashD,dashSt = mkToggle("Dash Expander")
mkDiv()
mkSection(" WEAPON")
local _,wpB,wpD,wpSt       = mkToggle("T-Rex Mode")
mkDiv()
mkSection(" HITBOX")
local _,hbB,hbD,hbSt       = mkToggle("Hitbox Expander")
mkDiv()
mkSection(" EXTRAS")
local _,acB,acD,acSt       = mkToggle("Auto Collect")
local _,paB,paD,paSt       = mkToggle("Proximity Alert")
mkDiv()
mkSection(" RANGE")
-- slider row (no AutomaticSize — fixed 36px)
local slFr = Instance.new("Frame",content)
slFr.Size=UDim2.new(1,0,0,36); slFr.LayoutOrder=nlo()
slFr.BackgroundColor3=Color3.fromRGB(12,12,20); slFr.BorderSizePixel=0
local sLbl=Instance.new("TextLabel",slFr)
sLbl.Size=UDim2.new(0.5,0,0,14); sLbl.Position=UDim2.new(0,7,0,3)
sLbl.BackgroundTransparency=1; sLbl.Text="Attack Range"
sLbl.TextColor3=Color3.fromRGB(120,120,120); sLbl.Font=FB; sLbl.TextSize=9
sLbl.TextXAlignment=Enum.TextXAlignment.Left
local sValL=Instance.new("TextLabel",slFr)
sValL.Size=UDim2.new(0,32,0,14); sValL.Position=UDim2.new(1,-40,0,3)
sValL.BackgroundTransparency=1; sValL.Text="20"
sValL.TextColor3=Color3.fromRGB(65,100,235); sValL.Font=FB; sValL.TextSize=10
sValL.TextXAlignment=Enum.TextXAlignment.Right
local sTrk=Instance.new("Frame",slFr)
sTrk.Size=UDim2.new(1,-50,0,5); sTrk.Position=UDim2.new(0,7,0,22)
sTrk.BackgroundColor3=Color3.fromRGB(26,26,44); sTrk.BorderSizePixel=0
pcall(function() Instance.new("UICorner",sTrk).CornerRadius=UDim.new(1,0) end)
local sFill=Instance.new("Frame",sTrk)
sFill.Size=UDim2.new(0.025,0,1,0); sFill.BackgroundColor3=Color3.fromRGB(65,100,235); sFill.BorderSizePixel=0
pcall(function() Instance.new("UICorner",sFill).CornerRadius=UDim.new(1,0) end)
local sThumb=Instance.new("TextButton",sTrk)
sThumb.Size=UDim2.new(0,13,0,13); sThumb.AnchorPoint=Vector2.new(0.5,0.5)
sThumb.Position=UDim2.new(0,0,0.5,0); sThumb.BackgroundColor3=Color3.fromRGB(255,255,255)
sThumb.Text=""; sThumb.BorderSizePixel=0
pcall(function() Instance.new("UICorner",sThumb).CornerRadius=UDim.new(1,0) end)
local infB=Instance.new("TextButton",slFr)
infB.Size=UDim2.new(0,32,0,13); infB.Position=UDim2.new(1,-40,0,21)
infB.BackgroundColor3=Color3.fromRGB(26,26,44); infB.Text="INF"
infB.TextColor3=Color3.fromRGB(145,145,145); infB.Font=FB; infB.TextSize=9
infB.BorderSizePixel=0
pcall(function() Instance.new("UICorner",infB).CornerRadius=UDim.new(0,3) end)
mkDiv()
mkSection(" TELEPORT")
local tpSkyBtn = mkActionBtn("^ TP to Sky",     Color3.fromRGB(44,16,80),  Color3.fromRGB(188,148,255))
local tpGndBtn = mkActionBtn("v Return Ground",  Color3.fromRGB(16,48,20),  Color3.fromRGB(108,218,108))
local tpSCBtn  = mkActionBtn("Sea Castle",       Color3.fromRGB(18,38,76),  Color3.fromRGB(108,155,245))
local tpManBtn = mkActionBtn("Mansion",          Color3.fromRGB(58,32,12),  Color3.fromRGB(215,165,82))
mkDiv()
mkSection(" PLAYERS")
local pScrollFr=Instance.new("Frame",content)
pScrollFr.Size=UDim2.new(1,0,0,85); pScrollFr.LayoutOrder=nlo()
pScrollFr.BackgroundTransparency=1; pScrollFr.BorderSizePixel=0
local pScroll=Instance.new("ScrollingFrame",pScrollFr)
pScroll.Size=UDim2.new(1,0,1,0)
pScroll.BackgroundTransparency=1; pScroll.BorderSizePixel=0
pScroll.ScrollBarThickness=2; pScroll.ScrollBarImageColor3=Color3.fromRGB(55,90,210)
pScroll.CanvasSize=UDim2.new(0,0,0,0)
local pLL=Instance.new("UIListLayout",pScroll); pLL.Padding=UDim.new(0,2)
local pLP=Instance.new("UIPadding",pScroll)
pLP.PaddingLeft=UDim.new(0,4); pLP.PaddingRight=UDim.new(0,4); pLP.PaddingTop=UDim.new(0,3)
-- end spacer
local spEnd=Instance.new("Frame",content)
spEnd.Size=UDim2.new(1,0,0,4); spEnd.BackgroundTransparency=1
spEnd.BorderSizePixel=0; spEnd.LayoutOrder=nlo()

-- ── toggle helper ─────────────────────────────────────
local function setTog(on,btn,dot,stl)
    if on then
        btn.BackgroundColor3=Color3.fromRGB(50,86,220)
        dot.BackgroundColor3=Color3.fromRGB(255,255,255)
        dot.Position=UDim2.new(1,-13,0.5,-5.5)
        stl.Text="ON"; stl.TextColor3=Color3.fromRGB(55,195,95)
    else
        btn.BackgroundColor3=Color3.fromRGB(40,40,60)
        dot.BackgroundColor3=Color3.fromRGB(120,120,120)
        dot.Position=UDim2.new(0,2,0.5,-5.5)
        stl.Text="OFF"; stl.TextColor3=Color3.fromRGB(255,55,55)
    end
end

-- ── slider ────────────────────────────────────────────
local SMIN,SMAX=5,999
local function updateSlider()
    if atkInf then
        sValL.Text="INF"; sValL.TextColor3=Color3.fromRGB(255,178,40)
        infB.BackgroundColor3=Color3.fromRGB(50,86,220); infB.TextColor3=Color3.fromRGB(255,255,255)
        sFill.Size=UDim2.new(1,0,1,0); sThumb.Position=UDim2.new(1,0,0.5,0)
    else
        local pct=(atkRange-SMIN)/(SMAX-SMIN)
        sValL.Text=tostring(atkRange); sValL.TextColor3=Color3.fromRGB(65,100,235)
        infB.BackgroundColor3=Color3.fromRGB(26,26,44); infB.TextColor3=Color3.fromRGB(145,145,145)
        sFill.Size=UDim2.new(pct,0,1,0); sThumb.Position=UDim2.new(pct,0,0.5,0)
    end
end

-- ── icon / panel visibility ───────────────────────────
iconBtn.MouseButton1Click:Connect(function()
    uiOpen=not uiOpen; mf.Visible=uiOpen
    iconBtn.TextColor3=uiOpen and Color3.fromRGB(90,130,255) or Color3.fromRGB(70,70,105)
end)

-- ── wire all toggles ──────────────────────────────────
setTog(true,espB,espD,espSt)
espB.MouseButton1Click:Connect(function()
    espOn=not espOn; setTog(espOn,espB,espD,espSt)
    if not espOn then for _,lb in pairs(espLabels) do lb.f.Visible=false; lb.ln.Visible=false end end
end)
aaB.MouseButton1Click:Connect(function()
    aaOn=not aaOn; setTog(aaOn,aaB,aaD,aaSt); if aaOn then startAtkLoop() end
end)
apB.MouseButton1Click:Connect(function()
    apAtkOn=not apAtkOn; setTog(apAtkOn,apB,apD,apSt); if apAtkOn then startAtkLoop() end
end)
clpB.MouseButton1Click:Connect(function() camLockP=not camLockP; setTog(camLockP,clpB,clpD,clpSt) end)
clmB.MouseButton1Click:Connect(function() camLockM=not camLockM; setTog(camLockM,clmB,clmD,clmSt) end)
saB.MouseButton1Click:Connect(function() silentAim=not silentAim; setTog(silentAim,saB,saD,saSt) end)
dashB.MouseButton1Click:Connect(function() dashOn=not dashOn; setTog(dashOn,dashB,dashD,dashSt) end)
wpB.MouseButton1Click:Connect(function()
    weaponMode=weaponMode==1 and 2 or 1
    local on=weaponMode==2; setTog(on,wpB,wpD,wpSt)
    wpSt.Text=on and "T-Rex" or "Kit"
end)
hbB.MouseButton1Click:Connect(function()
    hitboxOn=not hitboxOn; setTog(hitboxOn,hbB,hbD,hbSt)
    if not hitboxOn then restoreHitboxes() end
end)
acB.MouseButton1Click:Connect(function() autoCollect=not autoCollect; setTog(autoCollect,acB,acD,acSt) end)
paB.MouseButton1Click:Connect(function() proximityAlert=not proximityAlert; setTog(proximityAlert,paB,paD,paSt) end)
infB.MouseButton1Click:Connect(function()
    atkInf=not atkInf; updateSlider()
end)
updateSlider()

-- ── panel drag ────────────────────────────────────────
local dragging,dragStart,dragOrigin=false,nil,nil
tb.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=inp.Position; dragOrigin=mf.Position
    end
end)
local sliding=false
sTrk.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then sliding=true end
end)
sThumb.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then sliding=true end
end)
UIS.InputChanged:Connect(function(inp)
    if inp.UserInputType~=Enum.UserInputType.MouseMovement
    and inp.UserInputType~=Enum.UserInputType.Touch then return end
    if dragging and dragStart then
        local d=inp.Position-dragStart
        mf.Position=UDim2.new(
            dragOrigin.X.Scale, dragOrigin.X.Offset+d.X,
            dragOrigin.Y.Scale, dragOrigin.Y.Offset+d.Y)
    end
    if sliding then
        local ax=sTrk.AbsolutePosition.X; local aw=sTrk.AbsoluteSize.X
        if aw>0 then
            atkRange=math.floor(SMIN+math.clamp((inp.Position.X-ax)/aw,0,1)*(SMAX-SMIN))
            atkInf=false; updateSlider()
        end
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        dragging=false; sliding=false; dragStart=nil; dragOrigin=nil
    end
end)

-- ═══════════════════════════════════════════
-- FLOATING JUMP BUTTON
-- ═══════════════════════════════════════════
local jGui = makeGUI("FyZeJump")

local jBtn=Instance.new("TextButton",jGui)
jBtn.Size=UDim2.new(0,50,0,50)
jBtn.Position=UDim2.new(0,560,0,500)   -- initial position; user can drag
jBtn.BackgroundColor3=Color3.fromRGB(12,12,22)
jBtn.Text="^"; jBtn.Font=FB; jBtn.TextSize=22
jBtn.TextColor3=Color3.fromRGB(100,195,100)
jBtn.BorderSizePixel=1; jBtn.BorderColor3=Color3.fromRGB(45,150,70)
pcall(function() Instance.new("UICorner",jBtn).CornerRadius=UDim.new(1,0) end)

-- drag — only responds to input that BEGINS on jBtn
local jDrag=false; local jDS=nil; local jDO=nil; local jMoved=0
jBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        jDrag=true; jMoved=0
        jDS=Vector2.new(inp.Position.X,inp.Position.Y)
        jDO=Vector2.new(
            jBtn.AbsolutePosition.X+jBtn.AbsoluteSize.X*0.5,
            jBtn.AbsolutePosition.Y+jBtn.AbsoluteSize.Y*0.5)
    end
end)
jBtn.InputChanged:Connect(function(inp)
    if not jDrag then return end
    if inp.UserInputType~=Enum.UserInputType.MouseMovement
    and inp.UserInputType~=Enum.UserInputType.Touch then return end
    local dx=inp.Position.X-jDS.X; local dy=inp.Position.Y-jDS.Y
    jMoved=math.sqrt(dx*dx+dy*dy)
    jBtn.Position=UDim2.new(0,jDO.X+dx,0,jDO.Y+dy)
end)
jBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        jDrag=false
    end
end)
jBtn.MouseButton1Click:Connect(function()
    if jMoved>6 then jMoved=0; return end   -- was a drag, not a tap
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        tw()   -- wait one frame
        -- try modern API, fall back to legacy
        if not pcall(function()
            hrp.AssemblyLinearVelocity=Vector3.new(hrp.AssemblyLinearVelocity.X,130,hrp.AssemblyLinearVelocity.Z)
        end) then
            hrp.Velocity=Vector3.new(hrp.Velocity.X,130,hrp.Velocity.Z)
        end
    end)
end)

-- ═══════════════════════════════════════════
-- PLAYER LIST
-- ═══════════════════════════════════════════
local pLabels={}
local function createPLabel(player)
    local row=Instance.new("Frame",pScroll); row.Name=player.Name
    row.Size=UDim2.new(1,0,0,23); row.BackgroundColor3=Color3.fromRGB(14,14,22)
    row.BorderSizePixel=0
    pcall(function() Instance.new("UICorner",row).CornerRadius=UDim.new(0,3) end)
    local nl=Instance.new("TextLabel",row)
    nl.Size=UDim2.new(1,-4,0.5,0); nl.Position=UDim2.new(0,5,0,0)
    nl.BackgroundTransparency=1; nl.Text=player.Name
    nl.TextColor3=Color3.fromRGB(255,255,255); nl.Font=FB; nl.TextSize=9
    nl.TextXAlignment=Enum.TextXAlignment.Left
    local il=Instance.new("TextLabel",row)
    il.Size=UDim2.new(1,-4,0.5,0); il.Position=UDim2.new(0,5,0.5,0)
    il.BackgroundTransparency=1; il.Text="..."
    il.TextColor3=Color3.fromRGB(115,115,115); il.Font=FR; il.TextSize=8
    il.TextXAlignment=Enum.TextXAlignment.Left
    pLabels[player]={nl=nl,il=il}
end
local function removePLabel(player)
    if pLabels[player] then
        pcall(function()
            local r=pScroll:FindFirstChild(player.Name); if r then r:Destroy() end
        end)
        pLabels[player]=nil
    end
end
for _,p in ipairs(Players:GetPlayers()) do if p~=lp then createPLabel(p) end end
Players.PlayerAdded:Connect(function(p) if p~=lp then createPLabel(p) end end)
Players.PlayerRemoving:Connect(function(p) removePLabel(p); hideESP(p.Name) end)

-- ═══════════════════════════════════════════
-- GAME DATA
-- ═══════════════════════════════════════════
local pSet={}; local descCache={}; local lastScan=0
local function rebuildPSet()
    pSet={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Character then pSet[p.Character]=true end
    end
end
local function getDesc()
    local now=tick()
    if now-lastScan>=2 then descCache=workspace:GetDescendants(); lastScan=now end
    return descCache
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(rebuildPSet); rebuildPSet() end)
Players.PlayerRemoving:Connect(rebuildPSet)
for _,p in ipairs(Players:GetPlayers()) do p.CharacterAdded:Connect(rebuildPSet) end
rebuildPSet(); descCache=workspace:GetDescendants(); lastScan=tick()

local function getAllTargets(wantP,wantM)
    local char=lp.Character; if not char then return {} end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return {} end
    local desc=atkInf and workspace:GetDescendants() or getDesc()
    local out={}
    for _,obj in ipairs(desc) do
        if obj and obj.Parent and obj.Parent~=char
        and obj:IsA("Humanoid") and obj.Health>0 then
            local r=obj.Parent:FindFirstChild("HumanoidRootPart")
            if r then
                local isP=pSet[obj.Parent]==true
                if (isP and wantP) or (not isP and wantM) then
                    if atkInf or (root.Position-r.Position).Magnitude<=(atkInf and 1e9 or atkRange) then
                        out[#out+1]={h=obj,root=r,model=obj.Parent}
                    end
                end
            end
        end
    end
    return out
end

local function nearestOf(wantP,wantM,range)
    local char=lp.Character; if not char then return nil end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    local best,bestD=nil,range or 1e9
    for _,obj in ipairs(getDesc()) do
        if obj and obj.Parent and obj.Parent~=char
        and obj:IsA("Humanoid") and obj.Health>0 then
            local r=obj.Parent:FindFirstChild("HumanoidRootPart")
            if r then
                local isP=pSet[obj.Parent]==true
                if (isP and wantP) or (not isP and wantM) then
                    local d=(root.Position-r.Position).Magnitude
                    if d<bestD then bestD=d; best={h=obj,root=r,model=obj.Parent} end
                end
            end
        end
    end
    return best
end

-- ═══════════════════════════════════════════
-- HITBOX EXPANDER
-- ═══════════════════════════════════════════
local hbOriginals={}
local function expandHitboxes()
    if not hitboxOn then return end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Parent and v.Parent~=lp.Character
        and v.Parent:FindFirstChildOfClass("Humanoid") then
            if not hbOriginals[v] then hbOriginals[v]=v.Size end
            pcall(function() v.Size=Vector3.new(hitboxSize,hitboxSize,hitboxSize) end)
        end
    end
end
function restoreHitboxes()
    for part,orig in pairs(hbOriginals) do
        pcall(function() if part and part.Parent then part.Size=orig end end)
    end
    hbOriginals={}
end

-- ═══════════════════════════════════════════
-- DASH EXPANDER (skipped on Delta — no getrawmetatable)
-- ═══════════════════════════════════════════
local dashHooked=false
local function hookDash()
    if dashHooked or not _getrawmeta or not _setreadonly then return end
    dashHooked=true
    pcall(function()
        local mt=_getrawmeta(game); if not mt then return end
        local old=mt.__newindex; _setreadonly(mt,false)
        mt.__newindex=_newcc(function(self,k,v)
            if dashOn and k=="Velocity" and typeof(v)=="Vector3" then
                local m=v.Magnitude
                if m>20 and m<500 then v=v*DASH_MULT end
            end
            return old(self,k,v)
        end)
        _setreadonly(mt,true)
    end)
end
hookDash()

-- ═══════════════════════════════════════════
-- TELEPORT
-- ═══════════════════════════════════════════
local LOCS={
    SEA_CASTLE=Vector3.new(4917,275,-4814),
    MANSION=Vector3.new(-1384,263,-2987)
}
local tpActive=false; local groundPos=nil; local skyPos=nil; local hitReg={}

local function teleportTo(pos)
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand=true end
    hrp.Anchored=true
    for _=1,3 do pcall(function() hrp.CFrame=CFrame.new(pos) end); tw() end
    hrp.Anchored=false
    if hum then tw(0.1); hum.PlatformStand=false end
end

local function tweenSky(pos,dur)
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand=true end
    local ok,tw2=pcall(function()
        return TweenSvc:Create(hrp,
            TweenInfo.new(dur or 2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {CFrame=CFrame.new(pos)})
    end)
    if ok and tw2 then tw2:Play(); tw2.Completed:Wait()
    else teleportTo(pos) end
    if hum then tw(0.1); hum.PlatformStand=false end
end

local function setSkyUI(on)
    tpSkyBtn.Text=on and "^ In Sky (tap=land)" or "^ TP to Sky"
    tpSkyBtn.BackgroundColor3=on and Color3.fromRGB(80,28,145) or Color3.fromRGB(44,16,80)
end

tpSkyBtn.MouseButton1Click:Connect(function()
    if tpActive then
        tpActive=false; setSkyUI(false)
        if groundPos then ts(teleportTo,groundPos+Vector3.new(0,3,0)) end; return
    end
    local char=lp.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    groundPos=hrp.Position
    local h=4200+math.random(0,800)
    skyPos=Vector3.new(groundPos.X+(math.random()-0.5)*10,groundPos.Y+h,groundPos.Z+(math.random()-0.5)*10)
    tpActive=true; setSkyUI(true); ts(tweenSky,skyPos,2.0)
    ts(function()
        tw(2.2)
        while tpActive do
            local c=lp.Character; local h2=c and c:FindFirstChild("HumanoidRootPart")
            if h2 and (h2.Position-skyPos).Magnitude>40 then
                pcall(function() h2.CFrame=CFrame.new(skyPos) end)
            end
            tw(0.08)
        end
    end)
end)
tpGndBtn.MouseButton1Click:Connect(function()
    tpActive=false; setSkyUI(false)
    local char=lp.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local dest=groundPos and groundPos+Vector3.new(0,3,0)
        or Vector3.new(hrp.Position.X,hrp.Position.Y-400,hrp.Position.Z)
    ts(teleportTo,dest)
end)
tpSCBtn.MouseButton1Click:Connect(function() ts(teleportTo,LOCS.SEA_CASTLE) end)
tpManBtn.MouseButton1Click:Connect(function() ts(teleportTo,LOCS.MANSION) end)

lp.CharacterAdded:Connect(function()
    hitReg={}; tpActive=false; groundPos=nil; skyPos=nil; setSkyUI(false); hookDash()
end)

-- ═══════════════════════════════════════════
-- SILENT AIMBOT
-- ═══════════════════════════════════════════
local SFOV=350; local SSMOOTH=0.45
local function doSilentAim()
    if not silentAim or not _mousemoverel then return end
    local char=lp.Character; if not char then return end
    local vp=Camera.ViewportSize; local center=Vector2.new(vp.X/2,vp.Y/2)
    local best,bestD=nil,SFOV
    local function check(model)
        if model==char then return end
        local head=model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart"); if not head then return end
        local hum=model:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
        local ok,sp,vis=pcall(function() return Camera:WorldToViewportPoint(head.Position) end)
        if not ok or not vis then return end
        local sv=Vector2.new(sp.X,sp.Y)
        local d=(sv-center).Magnitude
        if d<bestD then bestD=d; best=sv end
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=lp and p.Character then check(p.Character) end
    end
    local desc=getDesc()
    for _,obj in ipairs(desc) do
        if obj and obj:IsA("Humanoid") and obj.Health>0 and obj.Parent and obj.Parent~=lp.Character and not pSet[obj.Parent] then
            check(obj.Parent)
        end
    end
    if best then
        local mp=Vector2.new(mouse.X,mouse.Y)
        local dx=best.X-mp.X; local dy=best.Y-mp.Y
        if math.abs(dx)>3 or math.abs(dy)>3 then
            pcall(function() _mousemoverel(dx*SSMOOTH,dy*SSMOOTH) end)
        end
    end
end

-- ═══════════════════════════════════════════
-- WEAPONS
-- ═══════════════════════════════════════════
local RS=game:GetService("ReplicatedStorage")

local cachedKLC=nil
local function getKLC()
    local char=lp.Character; if not char then return nil end
    if cachedKLC and cachedKLC.Parent then return cachedKLC end
    cachedKLC=nil
    local t=char:FindFirstChild("Kitsune-Kitsune"); if not t then return nil end
    local r=t:FindFirstChild("LeftClickRemote"); if r then cachedKLC=r end; return r
end

local cachedTLC=nil; local cachedHRE=nil; local cachedARE=nil
local sHash="1169b354"

local function getTLC()
    local char=lp.Character; if not char then return nil end
    if cachedTLC and cachedTLC.Parent then return cachedTLC end
    cachedTLC=nil
    local t=char:FindFirstChild("T-Rex-T-Rex"); if not t then return nil end
    local r=t:FindFirstChild("LeftClickRemote"); if r then cachedTLC=r end; return r
end
local function initTRE()
    pcall(function()
        if not cachedHRE then
            local net=RS.Modules and RS.Modules:FindFirstChild("Net")
            if net then cachedHRE=net:FindFirstChild("RE/RegisterHit") end
        end
        if not cachedARE then
            local net=RS.Modules and RS.Modules:FindFirstChild("Net")
            if net then cachedARE=net:FindFirstChild("RE/RegisterAttack") end
        end
    end)
end

if _getrawmeta and _setreadonly then
    pcall(function()
        local mt=_getrawmeta(game); if not mt then return end
        local old=mt.__namecall; local done=false
        _setreadonly(mt,false)
        mt.__namecall=_newcc(function(self,...)
            if not done then pcall(function()
                local m=_getnc and _getnc() or ""
                if m=="FireServer" then
                    local net=RS.Modules and RS.Modules:FindFirstChild("Net")
                    if net then
                        local re=net:FindFirstChild("RE/RegisterHit"); local a={...}
                        if self==re and type(a[4])=="string" and #a[4]==8 then
                            sHash=a[4]; done=true; mt.__namecall=old
                        end
                    end
                end
            end) end
            return old(self,...)
        end)
        _setreadonly(mt,true)
    end)
end

local function jit(b,a) return b+(math.random()*a*2-a)*0.001 end

local function fireKitsune(tgt,hrp)
    if not tgt.h or tgt.h.Health<=0 then return false end
    local lc=getKLC(); if not lc then return false end
    local dir=tgt.root.Position-hrp.Position
    local du=dir.Magnitude>0 and dir.Unit or Vector3.new(0,0,1)
    local vd=Vector3.new(du.X+(math.random()-0.5)*0.06,du.Y+(math.random()-0.5)*0.06,du.Z+(math.random()-0.5)*0.06).Unit
    pcall(function() lc:FireServer(vd,1,true) end)
    return true
end

local function fireTRex(tgt,hrp)
    if not tgt.h or tgt.h.Health<=0 then return false end
    local lc=getTLC(); if not lc then return false end
    initTRE()
    local dir=(tgt.root.Position-hrp.Position)*Vector3.new(1,0,1)
    local du=dir.Magnitude>0 and dir.Unit or Vector3.new(0,0,1)
    local hd=Vector3.new(du.X+(math.random()-0.5)*0.04,(math.random()-0.5)*0.10,du.Z).Unit
    pcall(function() lc:FireServer(hd,1) end)
    tw(jit(0.055,12))
    local tc=tgt.model
    local hb=tc and tc:FindFirstChild("ModelHitbox")
    local lb=tc and (tc:FindFirstChild("RightUpperLeg") or tc:FindFirstChild("HumanoidRootPart"))
    if cachedHRE and hb  then pcall(function() cachedHRE:FireServer(hb,{},nil,sHash) end) end
    tw(jit(0.018,8))
    if cachedHRE and lb  then pcall(function() cachedHRE:FireServer(lb,{},nil,sHash) end) end
    tw(jit(0.018,8))
    if cachedARE then pcall(function() cachedARE:FireServer(0.4) end) end
    return true
end

local function fireAttack(tgt)
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if not tgt.model then return end
    local key=tostring(tgt.model)
    if tpActive and not hitReg[key] then return end
    local hum=tgt.h; local n=0; local wt=weaponMode==2 and 0.075 or 0.045
    while n<30 do
        if not hum or not hum.Parent or hum.Health<=0 then break end
        local ok=weaponMode==2 and fireTRex(tgt,hrp) or fireKitsune(tgt,hrp)
        if not ok then break end
        n=n+1; tw(jit(wt,15))
    end
    hitReg[key]=true
end

local atkRunning=false
function startAtkLoop()
    if atkRunning then return end; atkRunning=true
    ts(function()
        while aaOn or apAtkOn do
            descCache=workspace:GetDescendants(); lastScan=tick()
            local tgts=getAllTargets(apAtkOn,aaOn)
            for _,t in ipairs(tgts) do
                if not(aaOn or apAtkOn) then break end
                ts(fireAttack,t); tw(jit(0.04,15))
            end
            tw(jit(0.3,60))
        end
        atkRunning=false
    end)
end

-- ═══════════════════════════════════════════
-- HEARTBEAT
-- ═══════════════════════════════════════════
local frame=0; local lastCount=-1
RunService.Heartbeat:Connect(function()
    frame=frame+1
    if hitboxOn and frame%30==0 then expandHitboxes() end
    if frame%2~=0 then return end

    local char=lp.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")

    if silentAim then doSilentAim() end

    if camLockP then
        local t=nearestOf(true,false,AIM_RANGE)
        if t then pcall(function()
            Camera.CFrame=CFrame.new(Camera.CFrame.Position,t.root.Position+Vector3.new(0,2,0))
        end) end
    end
    if camLockM then
        local t=nearestOf(false,true,AIM_RANGE)
        if t then pcall(function()
            Camera.CFrame=CFrame.new(Camera.CFrame.Position,t.root.Position+Vector3.new(0,2,0))
        end) end
    end

    -- player ESP + list
    local count=0
    for player,data in pairs(pLabels) do
        count=count+1
        local c=player.Character
        local r2=c and c:FindFirstChild("HumanoidRootPart")
        local hd=c and c:FindFirstChild("Head")
        if root and r2 then
            local dist=math.floor((root.Position-r2.Position).Magnitude)
            local hm=c:FindFirstChildOfClass("Humanoid")
            local hp=hm and math.floor(hm.Health) or 0
            local mhp=hm and math.floor(hm.MaxHealth) or 100
            data.il.Text=dist.."m  "..hp.."/"..mhp
            local col=hp<=0 and Color3.fromRGB(90,90,90)
                or dist<20 and Color3.fromRGB(255,55,55)
                or dist<60 and Color3.fromRGB(255,185,0)
                or Color3.fromRGB(255,255,255)
            data.nl.TextColor3=col
            data.il.TextColor3=hp<=0 and Color3.fromRGB(90,90,90) or Color3.fromRGB(85,180,85)
            if espOn and hd then
                showESP(player.Name,hd.Position+Vector3.new(0,2.5,0),player.Name,hp,mhp,dist,true)
            elseif not espOn then hideESP(player.Name) end
        else
            data.il.Text="offline"
            data.nl.TextColor3=Color3.fromRGB(115,115,115)
            data.il.TextColor3=Color3.fromRGB(70,70,70)
            hideESP(player.Name)
        end
    end
    if count~=lastCount then
        pScroll.CanvasSize=UDim2.new(0,0,0,count*25+6); lastCount=count
    end

    -- auto collect
    if autoCollect and root and frame%15==0 then
        pcall(function()
            for _,v in ipairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and
                (v.Name=="Collectible" or v.Name=="Coin" or v.Name=="Chest" or v.Name=="Drop" or v.Name=="SeaFruit") then
                    if (root.Position-v.Position).Magnitude<120 then
                        local hrp2=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                        if hrp2 then hrp2.CFrame=CFrame.new(v.Position+Vector3.new(0,2,0)) end; break
                    end
                end
            end
        end)
    end

    -- proximity alert
    if proximityAlert and root and frame%6==0 then
        for player,_ in pairs(pLabels) do
            if player~=lp then
                local c2=player.Character; local r3=c2 and c2:FindFirstChild("HumanoidRootPart")
                if r3 and (root.Position-r3.Position).Magnitude<60 then
                    local now2=tick()
                    if not lastAlertTime[player] or now2-lastAlertTime[player]>5 then
                        lastAlertTime[player]=now2
                        ts(function()
                            local lb2=espLabels[player.Name]
                            if not lb2 then return end
                            local st2=lb2.f:FindFirstChildOfClass("UIStroke"); if not st2 then return end
                            local oc=st2.Color
                            for _=1,4 do
                                st2.Color=Color3.fromRGB(255,28,28); tw(0.12)
                                st2.Color=oc; tw(0.12)
                            end
                        end)
                    end
                end
            end
        end
    end
end)
