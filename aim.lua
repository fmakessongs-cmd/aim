-- ═══════════════════════════════════════════
--   FyZe Hub | Blox Fruits  v6
-- ═══════════════════════════════════════════
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local Camera     = workspace.CurrentCamera
local lp         = Players.LocalPlayer
local unpack     = table.unpack or unpack
local mouse      = lp:GetMouse()

-- ── state ───────────────────────────────────────────────────
local AIM_RANGE  = 250
local atkRange   = 20
local atkInf     = false
local aaOn       = false
local apAtkOn    = false
local camLockP   = false
local camLockM   = false
local silentAim  = false
local espOn      = true
local hitboxOn   = false
local hitboxSize = 15
local dashOn     = false
local DASH_MULT  = 3
local uiOpen     = true

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

-- ═══════════════════════════════════════════
-- ESP GUI
-- ═══════════════════════════════════════════
local eGui = Instance.new("ScreenGui")
eGui.Name="FyZeESP"; eGui.ResetOnSpawn=false; eGui.IgnoreGuiInset=true
safeGUI(eGui)

local espLabels = {}
local function getLabel(key,isP)
    if espLabels[key] then return espLabels[key] end
    local col = isP and Color3.fromRGB(255,55,55) or Color3.fromRGB(55,220,100)
    local f=Instance.new("Frame"); f.Size=UDim2.new(0,130,0,28)
    f.BackgroundColor3=Color3.fromRGB(6,6,12); f.BackgroundTransparency=0.1
    f.BorderSizePixel=0; f.AnchorPoint=Vector2.new(0.5,1); f.Parent=eGui
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,5)
    local st=Instance.new("UIStroke",f); st.Color=col; st.Thickness=1
    local n=Instance.new("TextLabel",f); n.Size=UDim2.new(1,-4,0.5,0)
    n.Position=UDim2.new(0,2,0,0); n.BackgroundTransparency=1
    n.Font=FB; n.TextSize=9; n.TextColor3=Color3.fromRGB(255,255,255)
    n.TextXAlignment=Enum.TextXAlignment.Center; n.Text=key
    local i=Instance.new("TextLabel",f); i.Size=UDim2.new(1,-4,0.5,0)
    i.Position=UDim2.new(0,2,0.5,0); i.BackgroundTransparency=1
    i.Font=FR; i.TextSize=8; i.TextColor3=Color3.fromRGB(160,160,160)
    i.TextXAlignment=Enum.TextXAlignment.Center; i.Text="..."
    local ln=Instance.new("Frame"); ln.Size=UDim2.new(0,1,0,8)
    ln.AnchorPoint=Vector2.new(0.5,0); ln.BackgroundColor3=col
    ln.BackgroundTransparency=0.3; ln.BorderSizePixel=0; ln.Parent=eGui
    espLabels[key]={f=f,n=n,i=i,ln=ln}
    return espLabels[key]
end
local function showESP(key,pos,name,hp,mhp,dist,isP)
    local lb=getLabel(key,isP)
    local ok,sp,vis=pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok or not vis then lb.f.Visible=false; lb.ln.Visible=false; return end
    lb.n.Text=name; lb.i.Text=dist.."m "..hp.."/"..mhp
    lb.f.Visible=true; lb.ln.Visible=true
    lb.f.Position=UDim2.new(0,sp.X,0,sp.Y-3)
    lb.ln.Position=UDim2.new(0,sp.X,0,sp.Y+25)
end
local function hideESP(key)
    if espLabels[key] then espLabels[key].f.Visible=false; espLabels[key].ln.Visible=false end
end

-- ═══════════════════════════════════════════
-- PANEL GUI
-- ═══════════════════════════════════════════
local mGui = Instance.new("ScreenGui")
mGui.Name="FyZePanel"; mGui.ResetOnSpawn=false; mGui.IgnoreGuiInset=true
safeGUI(mGui)

local W          = 230   -- panel width
local MAX_H      = 420   -- max visible height before scrolling kicks in
local TITLE_H    = 30
local MINI_H     = TITLE_H

-- ── icon button (always visible, top-left) ──────────────────
local iconBtn = Instance.new("TextButton", mGui)
iconBtn.Size = UDim2.new(0,34,0,34)
iconBtn.Position = UDim2.new(0,6,0,6)
iconBtn.BackgroundColor3 = Color3.fromRGB(16,16,28)
iconBtn.Text = "⚔"
iconBtn.TextColor3 = Color3.fromRGB(90,130,255)
iconBtn.Font = FB; iconBtn.TextSize = 16
iconBtn.BorderSizePixel = 0
Instance.new("UICorner",iconBtn).CornerRadius = UDim.new(1,0)
local iconStroke = Instance.new("UIStroke",iconBtn)
iconStroke.Color = Color3.fromRGB(60,95,230); iconStroke.Thickness = 1.2

-- ── main panel frame ─────────────────────────────────────────
local mf = Instance.new("Frame",mGui)
mf.Size = UDim2.new(0,W,0,TITLE_H)   -- starts at title height, expands
mf.Position = UDim2.new(0,46,0,6)
mf.BackgroundColor3 = Color3.fromRGB(10,10,16)
mf.BorderSizePixel = 0
mf.ClipsDescendants = true
Instance.new("UICorner",mf).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke",mf).Color = Color3.fromRGB(55,90,225)
Instance.new("UIStroke",mf).Thickness = 1.1

-- ── title bar (drag handle + minimize button) ─────────────────
local tb = Instance.new("Frame",mf)
tb.Size = UDim2.new(1,0,0,TITLE_H)
tb.BackgroundColor3 = Color3.fromRGB(15,15,24)
tb.BorderSizePixel = 0
Instance.new("UICorner",tb).CornerRadius = UDim.new(0,8)
-- fix bottom corners of title bar
local tbfix = Instance.new("Frame",tb)
tbfix.Size = UDim2.new(1,0,0.5,0); tbfix.Position = UDim2.new(0,0,0.5,0)
tbfix.BackgroundColor3 = Color3.fromRGB(15,15,24); tbfix.BorderSizePixel = 0

local titleLbl = Instance.new("TextLabel",tb)
titleLbl.Size = UDim2.new(1,-40,1,0); titleLbl.Position = UDim2.new(0,10,0,0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "⚔  FyZe Hub"
titleLbl.TextColor3 = Color3.fromRGB(90,130,255); titleLbl.Font = FB; titleLbl.TextSize = 11
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton",tb)
minBtn.Size = UDim2.new(0,26,0,20)
minBtn.Position = UDim2.new(1,-30,0.5,-10)
minBtn.BackgroundColor3 = Color3.fromRGB(30,30,50)
minBtn.Text = "▼"; minBtn.TextColor3 = Color3.fromRGB(180,180,180)
minBtn.Font = FB; minBtn.TextSize = 10; minBtn.BorderSizePixel = 0
Instance.new("UICorner",minBtn).CornerRadius = UDim.new(0,4)

-- ── scrollable content inside panel ──────────────────────────
local panelScroll = Instance.new("ScrollingFrame",mf)
panelScroll.Size = UDim2.new(1,0,1,-TITLE_H)
panelScroll.Position = UDim2.new(0,0,0,TITLE_H)
panelScroll.BackgroundTransparency = 1
panelScroll.BorderSizePixel = 0
panelScroll.ScrollBarThickness = 3
panelScroll.ScrollBarImageColor3 = Color3.fromRGB(60,95,225)
panelScroll.CanvasSize = UDim2.new(0,0,0,0)
panelScroll.ScrollingDirection = Enum.ScrollingDirection.Y
panelScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

-- layout inside scroll
local content = Instance.new("Frame", panelScroll)
content.Size = UDim2.new(1,0,0,0)
content.AutomaticSize = Enum.AutomaticSize.Y
content.BackgroundTransparency = 1; content.BorderSizePixel = 0

local layout = Instance.new("UIListLayout",content)
layout.Padding = UDim.new(0,1)
layout.SortOrder = Enum.SortOrder.LayoutOrder
local cp = Instance.new("UIPadding",content)
cp.PaddingBottom = UDim.new(0,6)

-- resize panel height whenever content changes
local minimized = false
local function resizePanel()
    if minimized then mf.Size = UDim2.new(0,W,0,MINI_H); return end
    local ch = TITLE_H + layout.AbsoluteContentSize.Y + 10
    mf.Size = UDim2.new(0,W,0,math.min(ch, MAX_H))
end
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)
task.defer(resizePanel)

-- minimize / expand
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    panelScroll.Visible = not minimized
    if minimized then
        mf.Size = UDim2.new(0,W,0,MINI_H)
        minBtn.Text = "▲"
    else
        minBtn.Text = "▼"
        resizePanel()
    end
end)

-- ── helpers ───────────────────────────────────────────────────
local lo = 0
local function nlo() lo=lo+1; return lo end

local ROW = 26
local function mkSection(txt)
    local f=Instance.new("Frame",content); f.Size=UDim2.new(1,0,0,17)
    f.BackgroundColor3=Color3.fromRGB(20,20,34); f.BorderSizePixel=0; f.LayoutOrder=nlo()
    local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,-8,1,0); l.Position=UDim2.new(0,8,0,0)
    l.BackgroundTransparency=1; l.Text=txt; l.TextColor3=Color3.fromRGB(65,95,205)
    l.Font=FB; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Left
end

local function mkToggle(txt)
    local fr=Instance.new("Frame",content); fr.Size=UDim2.new(1,0,0,ROW)
    fr.BackgroundColor3=Color3.fromRGB(13,13,21); fr.BorderSizePixel=0; fr.LayoutOrder=nlo()
    local lb=Instance.new("TextLabel",fr); lb.Size=UDim2.new(0.64,0,1,0); lb.Position=UDim2.new(0,8,0,0)
    lb.BackgroundTransparency=1; lb.Text=txt; lb.TextColor3=Color3.fromRGB(188,188,188)
    lb.Font=FB; lb.TextSize=10; lb.TextXAlignment=Enum.TextXAlignment.Left
    local stl=Instance.new("TextLabel",fr); stl.Size=UDim2.new(0.2,0,1,0); stl.Position=UDim2.new(0.64,0,0,0)
    stl.BackgroundTransparency=1; stl.Text="OFF"; stl.TextColor3=Color3.fromRGB(255,58,58)
    stl.Font=FB; stl.TextSize=10; stl.TextXAlignment=Enum.TextXAlignment.Right
    local btn=Instance.new("TextButton",fr); btn.Size=UDim2.new(0,32,0,17)
    btn.Position=UDim2.new(1,-38,0.5,-8.5); btn.BackgroundColor3=Color3.fromRGB(42,42,62)
    btn.Text=""; btn.BorderSizePixel=0; Instance.new("UICorner",btn).CornerRadius=UDim.new(1,0)
    local dot=Instance.new("Frame",btn); dot.Size=UDim2.new(0,12,0,12)
    dot.Position=UDim2.new(0,2.5,0.5,-6); dot.BackgroundColor3=Color3.fromRGB(125,125,125)
    dot.BorderSizePixel=0; Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    return fr,btn,dot,stl
end

local function mkBtn(txt,col,tcol)
    local fr=Instance.new("Frame",content); fr.Size=UDim2.new(1,0,0,24)
    fr.BackgroundTransparency=1; fr.BorderSizePixel=0; fr.LayoutOrder=nlo()
    local b=Instance.new("TextButton",fr); b.Size=UDim2.new(1,-14,1,0); b.Position=UDim2.new(0,7,0,0)
    b.BackgroundColor3=col or Color3.fromRGB(30,30,50)
    b.Text=txt; b.TextColor3=tcol or Color3.fromRGB(255,255,255)
    b.Font=FB; b.TextSize=10; b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    return b
end

local function mkDiv()
    local d=Instance.new("Frame",content); d.Size=UDim2.new(1,-14,0,1)
    d.Position=UDim2.new(0,7,0,0)  -- won't matter, layout handles it
    d.BackgroundColor3=Color3.fromRGB(28,28,48); d.BorderSizePixel=0; d.LayoutOrder=nlo()
end

-- ── build sections ────────────────────────────────────────────
mkSection("  COMBAT")
local _,espB,espD,espSt      = mkToggle("Player ESP")
local _,aaB,aaD,aaSt         = mkToggle("Kill Aura NPCs")
local _,apB,apD,apSt         = mkToggle("Kill Aura Players")
mkDiv()
mkSection("  AIM")
local _,clpB,clpD,clpSt      = mkToggle("Cam Lock Players")
local _,clmB,clmD,clmSt      = mkToggle("Cam Lock Mobs")
local _,saB,saD,saSt         = mkToggle("Silent Aimbot")
mkDiv()
mkSection("  MOVEMENT")
local _,dashB,dashD,dashSt   = mkToggle("Dash Expander")
mkDiv()
mkSection("  HITBOX")
local _,hbB,hbD,hbSt         = mkToggle("Hitbox Expander")
mkDiv()
mkSection("  RANGE")
-- range slider row
local sliderFr=Instance.new("Frame",content); sliderFr.Size=UDim2.new(1,0,0,38)
sliderFr.BackgroundColor3=Color3.fromRGB(13,13,21); sliderFr.BorderSizePixel=0; sliderFr.LayoutOrder=nlo()
local sRangeLbl=Instance.new("TextLabel",sliderFr); sRangeLbl.Size=UDim2.new(0.5,0,0,15)
sRangeLbl.Position=UDim2.new(0,8,0,4); sRangeLbl.BackgroundTransparency=1
sRangeLbl.Text="Attack Range"; sRangeLbl.TextColor3=Color3.fromRGB(130,130,130)
sRangeLbl.Font=FB; sRangeLbl.TextSize=9; sRangeLbl.TextXAlignment=Enum.TextXAlignment.Left
local sValL=Instance.new("TextLabel",sliderFr); sValL.Size=UDim2.new(0,34,0,15)
sValL.Position=UDim2.new(1,-42,0,4); sValL.BackgroundTransparency=1
sValL.Text="20"; sValL.TextColor3=Color3.fromRGB(65,100,240)
sValL.Font=FB; sValL.TextSize=10; sValL.TextXAlignment=Enum.TextXAlignment.Right
local sTrk=Instance.new("Frame",sliderFr); sTrk.Size=UDim2.new(1,-54,0,5)
sTrk.Position=UDim2.new(0,8,0,24); sTrk.BackgroundColor3=Color3.fromRGB(28,28,48); sTrk.BorderSizePixel=0
Instance.new("UICorner",sTrk).CornerRadius=UDim.new(1,0)
local sFill=Instance.new("Frame",sTrk); sFill.Size=UDim2.new(0.025,0,1,0)
sFill.BackgroundColor3=Color3.fromRGB(65,100,240); sFill.BorderSizePixel=0
Instance.new("UICorner",sFill).CornerRadius=UDim.new(1,0)
local sThumb=Instance.new("TextButton",sTrk); sThumb.Size=UDim2.new(0,14,0,14)
sThumb.AnchorPoint=Vector2.new(0.5,0.5); sThumb.Position=UDim2.new(0,0,0.5,0)
sThumb.BackgroundColor3=Color3.fromRGB(255,255,255); sThumb.Text=""; sThumb.BorderSizePixel=0
Instance.new("UICorner",sThumb).CornerRadius=UDim.new(1,0)
local infB=Instance.new("TextButton",sliderFr); infB.Size=UDim2.new(0,34,0,14)
infB.Position=UDim2.new(1,-42,0,22); infB.BackgroundColor3=Color3.fromRGB(28,28,48)
infB.Text="INF"; infB.TextColor3=Color3.fromRGB(155,155,155); infB.Font=FB; infB.TextSize=9
infB.BorderSizePixel=0; Instance.new("UICorner",infB).CornerRadius=UDim.new(0,4)
mkDiv()
mkSection("  TELEPORT")
local tpSkyBtn = mkBtn("⬆  TP to Sky",       Color3.fromRGB(48,18,88),  Color3.fromRGB(195,155,255))
local tpGndBtn = mkBtn("⬇  Return to Ground", Color3.fromRGB(18,52,22),  Color3.fromRGB(115,225,115))
local tpSCBtn  = mkBtn("🏰  Sea Castle",       Color3.fromRGB(22,42,82),  Color3.fromRGB(115,160,255))
local tpManBtn = mkBtn("🏠  Mansion",          Color3.fromRGB(62,35,15),  Color3.fromRGB(222,172,90))
mkDiv()
mkSection("  PLAYERS")
local scrollFr2=Instance.new("Frame",content); scrollFr2.Size=UDim2.new(1,0,0,90)
scrollFr2.BackgroundTransparency=1; scrollFr2.BorderSizePixel=0; scrollFr2.LayoutOrder=nlo()
local pScroll=Instance.new("ScrollingFrame",scrollFr2)
pScroll.Size=UDim2.new(1,0,1,0); pScroll.BackgroundTransparency=1
pScroll.BorderSizePixel=0; pScroll.ScrollBarThickness=2
pScroll.ScrollBarImageColor3=Color3.fromRGB(60,95,225)
pScroll.CanvasSize=UDim2.new(0,0,0,0)
local pListL=Instance.new("UIListLayout",pScroll); pListL.Padding=UDim.new(0,2)
local pListP=Instance.new("UIPadding",pScroll); pListP.PaddingLeft=UDim.new(0,5)
pListP.PaddingRight=UDim.new(0,5); pListP.PaddingTop=UDim.new(0,3)
-- bottom spacer
local spacerEnd=Instance.new("Frame",content); spacerEnd.Size=UDim2.new(1,0,0,4)
spacerEnd.BackgroundTransparency=1; spacerEnd.BorderSizePixel=0; spacerEnd.LayoutOrder=nlo()

-- ── toggle helper ──────────────────────────────────────────
local function setTog(on,btn,dot,stl)
    if on then
        btn.BackgroundColor3=Color3.fromRGB(55,90,225)
        dot.BackgroundColor3=Color3.fromRGB(255,255,255)
        dot.Position=UDim2.new(1,-14.5,0.5,-6)
        stl.Text="ON"; stl.TextColor3=Color3.fromRGB(60,200,100)
    else
        btn.BackgroundColor3=Color3.fromRGB(42,42,62)
        dot.BackgroundColor3=Color3.fromRGB(125,125,125)
        dot.Position=UDim2.new(0,2.5,0.5,-6)
        stl.Text="OFF"; stl.TextColor3=Color3.fromRGB(255,58,58)
    end
end

-- ── slider logic ───────────────────────────────────────────
local SMIN,SMAX=5,999
local function updateSlider()
    if atkInf then
        sValL.Text="INF"; sValL.TextColor3=Color3.fromRGB(255,185,45)
        infB.BackgroundColor3=Color3.fromRGB(55,90,225); infB.TextColor3=Color3.fromRGB(255,255,255)
        sFill.Size=UDim2.new(1,0,1,0); sThumb.Position=UDim2.new(1,0,0.5,0)
    else
        local pct=(atkRange-SMIN)/(SMAX-SMIN)
        sValL.Text=tostring(atkRange); sValL.TextColor3=Color3.fromRGB(65,100,240)
        infB.BackgroundColor3=Color3.fromRGB(28,28,48); infB.TextColor3=Color3.fromRGB(155,155,155)
        sFill.Size=UDim2.new(pct,0,1,0); sThumb.Position=UDim2.new(pct,0,0.5,0)
    end
end

-- ── icon toggle ────────────────────────────────────────────
iconBtn.MouseButton1Click:Connect(function()
    uiOpen = not uiOpen
    mf.Visible = uiOpen
    iconBtn.TextColor3 = uiOpen and Color3.fromRGB(90,130,255) or Color3.fromRGB(70,70,110)
    iconStroke.Color = uiOpen and Color3.fromRGB(60,95,230) or Color3.fromRGB(40,40,70)
end)

-- ── wire toggles ───────────────────────────────────────────
setTog(true,espB,espD,espSt)
espB.MouseButton1Click:Connect(function()
    espOn=not espOn; setTog(espOn,espB,espD,espSt)
    if not espOn then for _,lb in pairs(espLabels) do lb.f.Visible=false; lb.ln.Visible=false end end
end)
clpB.MouseButton1Click:Connect(function() camLockP=not camLockP; setTog(camLockP,clpB,clpD,clpSt) end)
clmB.MouseButton1Click:Connect(function() camLockM=not camLockM; setTog(camLockM,clmB,clmD,clmSt) end)
saB.MouseButton1Click:Connect(function()  silentAim=not silentAim; setTog(silentAim,saB,saD,saSt) end)
hbB.MouseButton1Click:Connect(function()
    hitboxOn=not hitboxOn; setTog(hitboxOn,hbB,hbD,hbSt)
    if not hitboxOn then restoreHitboxes() end
end)
dashB.MouseButton1Click:Connect(function() dashOn=not dashOn; setTog(dashOn,dashB,dashD,dashSt) end)
infB.MouseButton1Click:Connect(function()
    atkInf=not atkInf
    if atkInf then descCache=workspace:GetDescendants(); lastScan=tick() end
    updateSlider()
end)
updateSlider()

-- ── drag panel ─────────────────────────────────────────────
local dragging,dragStart,dragOrigin=false,nil,nil
tb.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
        dragging=true; dragStart=inp.Position; dragOrigin=mf.Position
    end
end)
local sliding=false
sTrk.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then sliding=true end
end)
sThumb.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then sliding=true end
end)
UIS.InputChanged:Connect(function(inp)
    if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
    if dragging and dragStart then
        local d=inp.Position-dragStart
        mf.Position=UDim2.new(dragOrigin.X.Scale,dragOrigin.X.Offset+d.X,dragOrigin.Y.Scale,dragOrigin.Y.Offset+d.Y)
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
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
        dragging=false; sliding=false; dragStart=nil; dragOrigin=nil
    end
end)

-- ═══════════════════════════════════════════
-- FLOATING JUMP BUTTON (separate draggable circle)
-- ═══════════════════════════════════════════
local jGui = Instance.new("ScreenGui")
jGui.Name="FyZeJump"; jGui.ResetOnSpawn=false; jGui.IgnoreGuiInset=true
safeGUI(jGui)

local jBtn = Instance.new("TextButton", jGui)
jBtn.Size = UDim2.new(0,52,0,52)
jBtn.Position = UDim2.new(1,-70,1,-90)   -- bottom right corner default
jBtn.AnchorPoint = Vector2.new(0.5,0.5)
jBtn.BackgroundColor3 = Color3.fromRGB(14,14,24)
jBtn.Text = "↑"
jBtn.TextColor3 = Color3.fromRGB(110,200,110)
jBtn.Font = FB; jBtn.TextSize = 22
jBtn.BorderSizePixel = 0
Instance.new("UICorner",jBtn).CornerRadius = UDim.new(1,0)
local jStroke = Instance.new("UIStroke",jBtn)
jStroke.Color = Color3.fromRGB(50,160,80); jStroke.Thickness = 1.5

-- drag the jump button
local jDragging,jDragStart,jDragOrigin=false,nil,nil
jBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
        jDragging=true; jDragStart=inp.Position; jDragOrigin=jBtn.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if not jDragging then return end
    if inp.UserInputType~=Enum.UserInputType.MouseMovement and inp.UserInputType~=Enum.UserInputType.Touch then return end
    local d=inp.Position-jDragStart
    jBtn.Position=UDim2.new(jDragOrigin.X.Scale,jDragOrigin.X.Offset+d.X,jDragOrigin.Y.Scale,jDragOrigin.Y.Offset+d.Y)
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
        jDragging=false; jDragStart=nil; jDragOrigin=nil
    end
end)

local jHeld = false
jBtn.MouseButton1Down:Connect(function() jHeld = true end)
jBtn.MouseButton1Up:Connect(function()   jHeld = false end)
jBtn.MouseButton1Click:Connect(function()
    if jDragStart and (jBtn.Position.X.Offset~=jDragOrigin and jDragOrigin~=nil) then return end
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hrp and hum then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            hrp.Velocity=Vector3.new(hrp.Velocity.X, 120, hrp.Velocity.Z)
        end)
    end
end)

-- ═══════════════════════════════════════════
-- PLAYER LIST
-- ═══════════════════════════════════════════
local pLabels={}
local function createPLabel(player)
    local row=Instance.new("Frame",pScroll); row.Name=player.Name
    row.Size=UDim2.new(1,0,0,24); row.BackgroundColor3=Color3.fromRGB(15,15,24)
    row.BorderSizePixel=0; Instance.new("UICorner",row).CornerRadius=UDim.new(0,4)
    local nl=Instance.new("TextLabel",row); nl.Size=UDim2.new(1,-6,0.5,0); nl.Position=UDim2.new(0,6,0,0)
    nl.BackgroundTransparency=1; nl.Text=player.Name; nl.TextColor3=Color3.fromRGB(255,255,255)
    nl.Font=FB; nl.TextSize=9; nl.TextXAlignment=Enum.TextXAlignment.Left
    local il=Instance.new("TextLabel",row); il.Size=UDim2.new(1,-6,0.5,0); il.Position=UDim2.new(0,6,0.5,0)
    il.BackgroundTransparency=1; il.Text="..."; il.TextColor3=Color3.fromRGB(120,120,120)
    il.Font=FR; il.TextSize=8; il.TextXAlignment=Enum.TextXAlignment.Left
    pLabels[player]={nl=nl,il=il}
end
local function removePLabel(player)
    if pLabels[player] then
        pcall(function() local r=pScroll:FindFirstChild(player.Name); if r then r:Destroy() end end)
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
    for _,p in ipairs(Players:GetPlayers()) do if p.Character then pSet[p.Character]=true end end
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

local function getRange() return atkInf and math.huge or atkRange end

local function getAllTargets(wantP,wantM)
    local char=lp.Character; if not char then return {} end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return {} end
    local desc=atkInf and workspace:GetDescendants() or getDesc()
    local results={}
    for i=1,#desc do
        local obj=desc[i]
        if obj and obj.Parent and obj.Parent~=char and obj:IsA("Humanoid") and obj.Health>0 then
            local r=obj.Parent:FindFirstChild("HumanoidRootPart")
            if r then
                local isP=pSet[obj.Parent]==true
                if (isP and wantP) or (not isP and wantM) then
                    if atkInf or (root.Position-r.Position).Magnitude<=getRange() then
                        results[#results+1]={h=obj,root=r,model=obj.Parent}
                    end
                end
            end
        end
    end
    return results
end

local function nearestOf(wantP,wantM,range)
    local char=lp.Character; if not char then return nil end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    local best,bestD=nil,range or math.huge
    local desc=getDesc()
    for i=1,#desc do
        local obj=desc[i]
        if obj and obj.Parent and obj.Parent~=char and obj:IsA("Humanoid") and obj.Health>0 then
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
local hitboxOriginals={}
local function expandHitboxes()
    if not hitboxOn then return end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Parent and v.Parent~=lp.Character then
            if v.Parent:FindFirstChildOfClass("Humanoid") then
                if not hitboxOriginals[v] then hitboxOriginals[v]=v.Size end
                pcall(function() v.Size=Vector3.new(hitboxSize,hitboxSize,hitboxSize) end)
            end
        end
    end
end
function restoreHitboxes()
    for part,orig in pairs(hitboxOriginals) do
        pcall(function() if part and part.Parent then part.Size=orig end end)
    end
    hitboxOriginals={}
end

-- ═══════════════════════════════════════════
-- DASH EXPANDER
-- ═══════════════════════════════════════════
local dashHooked=false
local function hookDash()
    if dashHooked then return end; dashHooked=true
    pcall(function()
        local mt=getrawmetatable(game); if not mt then return end
        local old=mt.__newindex; setreadonly(mt,false)
        mt.__newindex=newcclosure(function(self,key,val)
            if dashOn and key=="Velocity" and typeof(val)=="Vector3" then
                local mag=val.Magnitude
                if mag>20 and mag<500 then val=val*DASH_MULT end
            end
            return old(self,key,val)
        end)
        setreadonly(mt,true)
    end)
end
hookDash()

-- ═══════════════════════════════════════════
-- TELEPORT
-- ═══════════════════════════════════════════
local LOCS={
    SEA_CASTLE=Vector3.new(4917,275,-4814),
    MANSION=Vector3.new(-1384,263,-2987),
}
local tpActive=false; local groundPos=nil; local skyPos=nil; local hitRegistry={}

local function tweenTo(pos,dur)
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand=true end
    local tw=TweenSvc:Create(hrp,TweenInfo.new(dur or 1.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=CFrame.new(pos)})
    tw:Play(); tw.Completed:Wait()
    if hum then hum.PlatformStand=false end
end

local function setSkyUI(active)
    tpSkyBtn.Text=active and "⬆  In Sky  [tap=land]" or "⬆  TP to Sky"
    tpSkyBtn.BackgroundColor3=active and Color3.fromRGB(88,32,155) or Color3.fromRGB(48,18,88)
end

tpSkyBtn.MouseButton1Click:Connect(function()
    if tpActive then tpActive=false; setSkyUI(false)
        if groundPos then task.spawn(tweenTo,groundPos+Vector3.new(0,3,0),1.5) end; return end
    local char=lp.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    groundPos=hrp.Position
    local h=4200+math.random(0,800)
    skyPos=Vector3.new(groundPos.X+(math.random()-0.5)*12,groundPos.Y+h,groundPos.Z+(math.random()-0.5)*12)
    tpActive=true; setSkyUI(true); task.spawn(tweenTo,skyPos,2.0)
    task.spawn(function()
        task.wait(2.2)
        while tpActive do
            local c=lp.Character; local h2=c and c:FindFirstChild("HumanoidRootPart")
            if h2 and (h2.Position-skyPos).Magnitude>40 then pcall(function() h2.CFrame=CFrame.new(skyPos) end) end
            task.wait(0.08)
        end
    end)
end)
tpGndBtn.MouseButton1Click:Connect(function()
    tpActive=false; setSkyUI(false)
    local char=lp.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    task.spawn(tweenTo,groundPos and groundPos+Vector3.new(0,3,0) or Vector3.new(hrp.Position.X,hrp.Position.Y-9999,hrp.Position.Z),1.5)
end)
tpSCBtn.MouseButton1Click:Connect(function() task.spawn(tweenTo,LOCS.SEA_CASTLE,2.5) end)
tpManBtn.MouseButton1Click:Connect(function() task.spawn(tweenTo,LOCS.MANSION,2.5) end)

lp.CharacterAdded:Connect(function()
    hitRegistry={}; tpActive=false; groundPos=nil; skyPos=nil; setSkyUI(false); hookDash()
end)

-- ═══════════════════════════════════════════
-- SILENT AIMBOT (mousemoverel)
-- ═══════════════════════════════════════════
local SILENT_SPEED=0.55; local SILENT_FOV=300
local function getScreenPos(wp)
    local ok,sp,vis=pcall(function() return Camera:WorldToViewportPoint(wp) end)
    if not ok or not vis then return nil end
    return Vector2.new(sp.X,sp.Y)
end
local function doSilentAim()
    if not silentAim or not mousemoverel then return end
    local char=lp.Character; if not char then return end
    local best,bestD=nil,SILENT_FOV
    local mp=Vector2.new(mouse.X,mouse.Y)
    local function check(model)
        local hrp=model:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local hum=model:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
        local sp=getScreenPos(hrp.Position+Vector3.new(0,2,0)); if not sp then return end
        local d=(sp-mp).Magnitude
        if d<bestD then bestD=d; best={root=hrp,sp=sp} end
    end
    if apAtkOn then for _,p in ipairs(Players:GetPlayers()) do if p~=lp and p.Character then check(p.Character) end end end
    if aaOn then
        local desc=getDesc()
        for i=1,#desc do
            local obj=desc[i]
            if obj and obj:IsA("Humanoid") and obj.Health>0 and obj.Parent and obj.Parent~=char and not pSet[obj.Parent] then
                check(obj.Parent)
            end
        end
    end
    if best then pcall(function() mousemoverel((best.sp.X-mp.X)*SILENT_SPEED,(best.sp.Y-mp.Y)*SILENT_SPEED) end) end
end

-- ═══════════════════════════════════════════
-- KITSUNE M1
-- ═══════════════════════════════════════════
local cachedKLC=nil
local function getKLC()
    local char=lp.Character; if not char then return nil end
    if cachedKLC and cachedKLC.Parent then return cachedKLC end
    cachedKLC=nil
    local t=char:FindFirstChild("Kitsune-Kitsune"); if not t then return nil end
    local r=t:FindFirstChild("LeftClickRemote"); if r then cachedKLC=r end; return r
end
local function jit(b,a) return b+(math.random()*a*2-a)*0.001 end
local function fireAttack(tgt)
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local tc=tgt.model; if not tc then return end
    local tgtKey=tostring(tc)
    if tpActive and not hitRegistry[tgtKey] then return end
    local hum=tgt.h; local maxB=30; local n=0
    while n<maxB do
        if not hum or not hum.Parent or hum.Health<=0 then break end
        local lc=getKLC(); if not lc then break end
        local dir=(tgt.root.Position-hrp.Position)
        local du=dir.Magnitude>0 and dir.Unit or Vector3.new(0,0,1)
        local vd=Vector3.new(du.X+(math.random()-0.5)*0.06,du.Y+(math.random()-0.5)*0.06,du.Z+(math.random()-0.5)*0.06).Unit
        pcall(function() lc:FireServer(vd,1,true) end)
        n=n+1; task.wait(jit(0.045,12))
    end
    hitRegistry[tgtKey]=true
end

local atkRunning=false
local function startAtkLoop()
    if atkRunning then return end; atkRunning=true
    task.spawn(function()
        while aaOn or apAtkOn do
            descCache=workspace:GetDescendants(); lastScan=tick()
            local tgts=getAllTargets(apAtkOn,aaOn)
            for _,t in ipairs(tgts) do
                if not (aaOn or apAtkOn) then break end
                task.spawn(fireAttack,t); task.wait(jit(0.04,15))
            end
            task.wait(jit(0.3,60))
        end
        atkRunning=false
    end)
end

aaB.MouseButton1Click:Connect(function()
    aaOn=not aaOn; setTog(aaOn,aaB,aaD,aaSt); if aaOn then startAtkLoop() end
end)
apB.MouseButton1Click:Connect(function()
    apAtkOn=not apAtkOn; setTog(apAtkOn,apB,apD,apSt); if apAtkOn then startAtkLoop() end
end)

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
        if t then pcall(function() Camera.CFrame=CFrame.new(Camera.CFrame.Position,t.root.Position+Vector3.new(0,2,0)) end) end
    end
    if camLockM then
        local t=nearestOf(false,true,AIM_RANGE)
        if t then pcall(function() Camera.CFrame=CFrame.new(Camera.CFrame.Position,t.root.Position+Vector3.new(0,2,0)) end) end
    end

    local count=0
    for player,data in pairs(pLabels) do
        count=count+1
        local c=player.Character
        local r=c and c:FindFirstChild("HumanoidRootPart")
        local h=c and c:FindFirstChild("Head")
        if root and r then
            local dist=math.floor((root.Position-r.Position).Magnitude)
            local hum=c:FindFirstChildOfClass("Humanoid")
            local hp=hum and math.floor(hum.Health) or 0
            local mhp=hum and math.floor(hum.MaxHealth) or 100
            data.il.Text=dist.."st  "..hp.."/"..mhp
            local col=hp<=0 and Color3.fromRGB(95,95,95) or dist<20 and Color3.fromRGB(255,58,58) or dist<60 and Color3.fromRGB(255,188,0) or Color3.fromRGB(255,255,255)
            data.nl.TextColor3=col
            data.il.TextColor3=hp<=0 and Color3.fromRGB(95,95,95) or Color3.fromRGB(90,185,90)
            if espOn and h then showESP(player.Name,h.Position+Vector3.new(0,2.5,0),player.Name,hp,mhp,dist,true)
            elseif not espOn then hideESP(player.Name) end
        else
            data.il.Text="offline"
            data.nl.TextColor3=Color3.fromRGB(120,120,120); data.il.TextColor3=Color3.fromRGB(75,75,75)
            hideESP(player.Name)
        end
    end
    if count~=lastCount then pScroll.CanvasSize=UDim2.new(0,0,0,count*26+6); lastCount=count end
end)
