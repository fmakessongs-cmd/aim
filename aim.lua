-- ═══════════════════════════════════════════
--   FyZe Hub | Blox Fruits  v5
-- ═══════════════════════════════════════════
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local TweenSvc   = game:GetService("TweenService")
local Camera     = workspace.CurrentCamera
local lp         = Players.LocalPlayer
local unpack     = table.unpack or unpack
local mouse      = lp:GetMouse()

-- ── state ────────────────────────────────────────────────
local COOLDOWN   = 0.2
local AIM_RANGE  = 250
local atkRange   = 20
local atkInf     = false
local aaOn       = false   -- kill aura NPCs
local apAtkOn    = false   -- kill aura players
local camLockP   = false   -- cam lock players
local camLockM   = false   -- cam lock mobs
local silentAim  = false   -- silent aimbot (mousemoverel, no cam movement)
local espOn      = true
local hitboxOn   = false
local hitboxSize = 15
local dashOn     = false
local DASH_MULT  = 3       -- dash multiplier
local uiOpen     = true

-- ── fonts ────────────────────────────────────────────────
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
local function getLabel(key, isP)
    if espLabels[key] then return espLabels[key] end
    local col = isP and Color3.fromRGB(255,55,55) or Color3.fromRGB(55,220,100)
    local f = Instance.new("Frame"); f.Size=UDim2.new(0,130,0,28)
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

-- icon button (always visible, toggles panel)
local iconBtn = Instance.new("TextButton", mGui)
iconBtn.Size = UDim2.new(0,38,0,38)
iconBtn.Position = UDim2.new(0,8,0,8)
iconBtn.BackgroundColor3 = Color3.fromRGB(18,18,30)
iconBtn.Text = "⚔"
iconBtn.TextColor3 = Color3.fromRGB(100,140,255)
iconBtn.Font = FB; iconBtn.TextSize = 18
iconBtn.BorderSizePixel = 0
Instance.new("UICorner",iconBtn).CornerRadius = UDim.new(0,8)
local iconStroke = Instance.new("UIStroke",iconBtn)
iconStroke.Color = Color3.fromRGB(65,100,240); iconStroke.Thickness = 1.2

-- main panel
local W = 230
local mf = Instance.new("Frame",mGui)
mf.Size = UDim2.new(0,W,0,9999)  -- will be clamped by content
mf.Position = UDim2.new(0,52,0,8)
mf.BackgroundColor3 = Color3.fromRGB(10,10,16)
mf.BorderSizePixel = 0; mf.ClipsDescendants = true
Instance.new("UICorner",mf).CornerRadius = UDim.new(0,8)
local mfStroke = Instance.new("UIStroke",mf)
mfStroke.Color = Color3.fromRGB(60,95,230); mfStroke.Thickness = 1.1

-- drag titlebar
local tb = Instance.new("Frame",mf)
tb.Size=UDim2.new(1,0,0,30); tb.BackgroundColor3=Color3.fromRGB(16,16,26); tb.BorderSizePixel=0
Instance.new("UICorner",tb).CornerRadius=UDim.new(0,8)
local tbfix=Instance.new("Frame",tb); tbfix.Size=UDim2.new(1,0,0.5,0)
tbfix.Position=UDim2.new(0,0,0.5,0); tbfix.BackgroundColor3=Color3.fromRGB(16,16,26); tbfix.BorderSizePixel=0
local titleLbl=Instance.new("TextLabel",tb); titleLbl.Size=UDim2.new(1,0,1,0)
titleLbl.BackgroundTransparency=1; titleLbl.Text="⚔  FyZe Hub"
titleLbl.TextColor3=Color3.fromRGB(100,140,255); titleLbl.Font=FB; titleLbl.TextSize=12
titleLbl.TextXAlignment=Enum.TextXAlignment.Center

-- content frame with auto list layout
local content = Instance.new("Frame",mf)
content.Size = UDim2.new(1,0,1,-30)
content.Position = UDim2.new(0,0,0,30)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
local layout = Instance.new("UIListLayout",content)
layout.Padding = UDim.new(0,1)
layout.SortOrder = Enum.SortOrder.LayoutOrder
local contentPad = Instance.new("UIPadding",content)
contentPad.PaddingBottom = UDim.new(0,4)

local layoutOrder = 0
local function nextOrder() layoutOrder=layoutOrder+1; return layoutOrder end

-- section header
local function mkSection(txt)
    local f=Instance.new("Frame",content); f.Size=UDim2.new(1,0,0,18)
    f.BackgroundColor3=Color3.fromRGB(22,22,36); f.BorderSizePixel=0
    f.LayoutOrder=nextOrder()
    local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,-8,1,0)
    l.Position=UDim2.new(0,8,0,0); l.BackgroundTransparency=1
    l.Text=txt; l.TextColor3=Color3.fromRGB(70,100,210)
    l.Font=FB; l.TextSize=9; l.TextXAlignment=Enum.TextXAlignment.Left
end

-- toggle row
local ROW=26
local function mkToggle(txt)
    local fr=Instance.new("Frame",content); fr.Size=UDim2.new(1,0,0,ROW)
    fr.BackgroundColor3=Color3.fromRGB(14,14,22); fr.BorderSizePixel=0
    fr.LayoutOrder=nextOrder()
    local lb=Instance.new("TextLabel",fr); lb.Size=UDim2.new(0.65,0,1,0)
    lb.Position=UDim2.new(0,8,0,0); lb.BackgroundTransparency=1
    lb.Text=txt; lb.TextColor3=Color3.fromRGB(190,190,190)
    lb.Font=FB; lb.TextSize=10; lb.TextXAlignment=Enum.TextXAlignment.Left
    local stl=Instance.new("TextLabel",fr); stl.Size=UDim2.new(0.2,0,1,0)
    stl.Position=UDim2.new(0.65,0,0,0); stl.BackgroundTransparency=1
    stl.Text="OFF"; stl.TextColor3=Color3.fromRGB(255,60,60)
    stl.Font=FB; stl.TextSize=10; stl.TextXAlignment=Enum.TextXAlignment.Right
    local btn=Instance.new("TextButton",fr); btn.Size=UDim2.new(0,32,0,17)
    btn.Position=UDim2.new(1,-38,0.5,-8.5); btn.BackgroundColor3=Color3.fromRGB(45,45,65)
    btn.Text=""; btn.BorderSizePixel=0; Instance.new("UICorner",btn).CornerRadius=UDim.new(1,0)
    local dot=Instance.new("Frame",btn); dot.Size=UDim2.new(0,12,0,12)
    dot.Position=UDim2.new(0,2.5,0.5,-6); dot.BackgroundColor3=Color3.fromRGB(130,130,130)
    dot.BorderSizePixel=0; Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    return fr,btn,dot,stl
end

-- action button (tp etc)
local function mkBtn(txt, col, tcol)
    local fr=Instance.new("Frame",content); fr.Size=UDim2.new(1,0,0,24)
    fr.BackgroundTransparency=1; fr.BorderSizePixel=0; fr.LayoutOrder=nextOrder()
    local b=Instance.new("TextButton",fr); b.Size=UDim2.new(1,-12,1,0)
    b.Position=UDim2.new(0,6,0,0)
    b.BackgroundColor3=col or Color3.fromRGB(35,35,55)
    b.Text=txt; b.TextColor3=tcol or Color3.fromRGB(255,255,255)
    b.Font=FB; b.TextSize=10; b.BorderSizePixel=0
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    return b
end

-- spacer
local function mkSpacer(h)
    local s=Instance.new("Frame",content); s.Size=UDim2.new(1,0,0,h or 3)
    s.BackgroundTransparency=1; s.BorderSizePixel=0; s.LayoutOrder=nextOrder()
end

local function mkDiv()
    local d=Instance.new("Frame",content); d.Size=UDim2.new(1,-12,0,1)
    d.BackgroundColor3=Color3.fromRGB(30,30,50); d.BorderSizePixel=0
    d.LayoutOrder=nextOrder()
end

-- ── build UI sections ─────────────────────────────────────
mkSection("  COMBAT")
local _,espB,espD,espSt        = mkToggle("Player ESP")
local _,aaB,aaD,aaSt           = mkToggle("Kill Aura NPCs")
local _,apB,apD,apSt           = mkToggle("Kill Aura Players")
mkDiv()
mkSection("  AIM")
local _,clpB,clpD,clpSt        = mkToggle("Cam Lock Players")
local _,clmB,clmD,clmSt        = mkToggle("Cam Lock Mobs")
local _,saB,saD,saSt           = mkToggle("Silent Aimbot")
mkDiv()
mkSection("  MOVEMENT")
local _,dashB,dashD,dashSt     = mkToggle("Dash Expander")
local jumpBtn  = mkBtn("⬆  High Jump",    Color3.fromRGB(30,60,30),  Color3.fromRGB(130,230,130))
mkDiv()
mkSection("  HITBOX")
local _,hbB,hbD,hbSt           = mkToggle("Hitbox Expander")
mkDiv()
mkSection("  RANGE")
-- range slider inline
local sliderFr=Instance.new("Frame",content); sliderFr.Size=UDim2.new(1,0,0,40)
sliderFr.BackgroundColor3=Color3.fromRGB(14,14,22); sliderFr.BorderSizePixel=0
sliderFr.LayoutOrder=nextOrder()
local sValL=Instance.new("TextLabel",sliderFr); sValL.Size=UDim2.new(0,36,0,16)
sValL.Position=UDim2.new(1,-44,0,4); sValL.BackgroundTransparency=1
sValL.Text="20"; sValL.TextColor3=Color3.fromRGB(65,100,240)
sValL.Font=FB; sValL.TextSize=10; sValL.TextXAlignment=Enum.TextXAlignment.Right
local sTrk=Instance.new("Frame",sliderFr); sTrk.Size=UDim2.new(1,-56,0,5)
sTrk.Position=UDim2.new(0,8,0,23); sTrk.BackgroundColor3=Color3.fromRGB(30,30,50); sTrk.BorderSizePixel=0
Instance.new("UICorner",sTrk).CornerRadius=UDim.new(1,0)
local sFill=Instance.new("Frame",sTrk); sFill.Size=UDim2.new(0.025,0,1,0)
sFill.BackgroundColor3=Color3.fromRGB(65,100,240); sFill.BorderSizePixel=0
Instance.new("UICorner",sFill).CornerRadius=UDim.new(1,0)
local sThumb=Instance.new("TextButton",sTrk); sThumb.Size=UDim2.new(0,14,0,14)
sThumb.AnchorPoint=Vector2.new(0.5,0.5); sThumb.Position=UDim2.new(0,0,0.5,0)
sThumb.BackgroundColor3=Color3.fromRGB(255,255,255); sThumb.Text=""; sThumb.BorderSizePixel=0
Instance.new("UICorner",sThumb).CornerRadius=UDim.new(1,0)
local infB=Instance.new("TextButton",sliderFr); infB.Size=UDim2.new(0,36,0,16)
infB.Position=UDim2.new(1,-44,0,22); infB.BackgroundColor3=Color3.fromRGB(30,30,50)
infB.Text="INF"; infB.TextColor3=Color3.fromRGB(160,160,160); infB.Font=FB; infB.TextSize=9
infB.BorderSizePixel=0; Instance.new("UICorner",infB).CornerRadius=UDim.new(0,4)
local sRangeLbl=Instance.new("TextLabel",sliderFr); sRangeLbl.Size=UDim2.new(0.5,0,0,16)
sRangeLbl.Position=UDim2.new(0,8,0,4); sRangeLbl.BackgroundTransparency=1
sRangeLbl.Text="Attack Range"; sRangeLbl.TextColor3=Color3.fromRGB(140,140,140)
sRangeLbl.Font=FB; sRangeLbl.TextSize=9; sRangeLbl.TextXAlignment=Enum.TextXAlignment.Left
mkDiv()
mkSection("  TELEPORT")
local tpSkyBtn = mkBtn("⬆  TP to Sky",        Color3.fromRGB(50,20,90),  Color3.fromRGB(200,160,255))
local tpGndBtn = mkBtn("⬇  Return to Ground",  Color3.fromRGB(20,55,25),  Color3.fromRGB(120,225,120))
local tpSCBtn  = mkBtn("🏰  Sea Castle",        Color3.fromRGB(25,45,85),  Color3.fromRGB(120,165,255))
local tpManBtn = mkBtn("🏠  Mansion",           Color3.fromRGB(65,38,18),  Color3.fromRGB(225,175,95))
mkDiv()
mkSection("  PLAYERS")
-- player scroll
local scrollFr=Instance.new("Frame",content); scrollFr.Size=UDim2.new(1,0,0,100)
scrollFr.BackgroundTransparency=1; scrollFr.BorderSizePixel=0; scrollFr.LayoutOrder=nextOrder()
local scroll=Instance.new("ScrollingFrame",scrollFr)
scroll.Size=UDim2.new(1,0,1,0); scroll.BackgroundTransparency=1
scroll.BorderSizePixel=0; scroll.ScrollBarThickness=2
scroll.ScrollBarImageColor3=Color3.fromRGB(65,100,240)
scroll.CanvasSize=UDim2.new(0,0,0,0)
local listL=Instance.new("UIListLayout",scroll); listL.Padding=UDim.new(0,2)
local listP=Instance.new("UIPadding",scroll); listP.PaddingLeft=UDim.new(0,5)
listP.PaddingRight=UDim.new(0,5); listP.PaddingTop=UDim.new(0,3)
mkSpacer(3)

-- resize panel to fit content
local function resizePanel()
    local h = 30 + layout.AbsoluteContentSize.Y + 6
    mf.Size = UDim2.new(0,W,0,h)
end
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)
task.defer(resizePanel)

-- ── toggle helper ─────────────────────────────────────────
local function setTog(on,btn,dot,stl)
    if on then
        btn.BackgroundColor3=Color3.fromRGB(60,95,230)
        dot.BackgroundColor3=Color3.fromRGB(255,255,255)
        dot.Position=UDim2.new(1,-14.5,0.5,-6)
        stl.Text="ON"; stl.TextColor3=Color3.fromRGB(65,200,105)
    else
        btn.BackgroundColor3=Color3.fromRGB(45,45,65)
        dot.BackgroundColor3=Color3.fromRGB(130,130,130)
        dot.Position=UDim2.new(0,2.5,0.5,-6)
        stl.Text="OFF"; stl.TextColor3=Color3.fromRGB(255,60,60)
    end
end

-- ── slider ────────────────────────────────────────────────
local SMIN,SMAX=5,999
local function updateSlider()
    if atkInf then
        sValL.Text="INF"; sValL.TextColor3=Color3.fromRGB(255,185,45)
        infB.BackgroundColor3=Color3.fromRGB(60,95,230); infB.TextColor3=Color3.fromRGB(255,255,255)
        sFill.Size=UDim2.new(1,0,1,0); sThumb.Position=UDim2.new(1,0,0.5,0)
    else
        local pct=(atkRange-SMIN)/(SMAX-SMIN)
        sValL.Text=tostring(atkRange); sValL.TextColor3=Color3.fromRGB(65,100,240)
        infB.BackgroundColor3=Color3.fromRGB(30,30,50); infB.TextColor3=Color3.fromRGB(160,160,160)
        sFill.Size=UDim2.new(pct,0,1,0); sThumb.Position=UDim2.new(pct,0,0.5,0)
    end
end

-- ── icon toggle ───────────────────────────────────────────
iconBtn.MouseButton1Click:Connect(function()
    uiOpen = not uiOpen
    mf.Visible = uiOpen
    iconBtn.TextColor3 = uiOpen and Color3.fromRGB(100,140,255) or Color3.fromRGB(80,80,120)
    iconStroke.Color = uiOpen and Color3.fromRGB(65,100,240) or Color3.fromRGB(50,50,80)
end)

-- ── wire toggles ──────────────────────────────────────────
setTog(true,espB,espD,espSt)
espB.MouseButton1Click:Connect(function()
    espOn=not espOn; setTog(espOn,espB,espD,espSt)
    if not espOn then for _,lb in pairs(espLabels) do lb.f.Visible=false; lb.ln.Visible=false end end
end)
aaB.MouseButton1Click:Connect(function()  aaOn=not aaOn;    setTog(aaOn,aaB,aaD,aaSt)
    if aaOn then startAtkLoop() end end)
apB.MouseButton1Click:Connect(function()  apAtkOn=not apAtkOn; setTog(apAtkOn,apB,apD,apSt)
    if apAtkOn then startAtkLoop() end end)
clpB.MouseButton1Click:Connect(function() camLockP=not camLockP; setTog(camLockP,clpB,clpD,clpSt) end)
clmB.MouseButton1Click:Connect(function() camLockM=not camLockM; setTog(camLockM,clmB,clmD,clmSt) end)
saB.MouseButton1Click:Connect(function()  silentAim=not silentAim; setTog(silentAim,saB,saD,saSt) end)
hbB.MouseButton1Click:Connect(function()  hitboxOn=not hitboxOn; setTog(hitboxOn,hbB,hbD,hbSt) end)
dashB.MouseButton1Click:Connect(function() dashOn=not dashOn; setTog(dashOn,dashB,dashD,dashSt) end)
infB.MouseButton1Click:Connect(function()
    atkInf=not atkInf
    if atkInf then descCache=workspace:GetDescendants(); lastScan=tick() end
    updateSlider()
end)
updateSlider()

-- ── drag ─────────────────────────────────────────────────
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
-- PLAYER LIST
-- ═══════════════════════════════════════════
local pLabels={}
local function createPLabel(player)
    local row=Instance.new("Frame",scroll); row.Name=player.Name
    row.Size=UDim2.new(1,0,0,26); row.BackgroundColor3=Color3.fromRGB(16,16,26)
    row.BorderSizePixel=0; Instance.new("UICorner",row).CornerRadius=UDim.new(0,4)
    local nl=Instance.new("TextLabel",row); nl.Size=UDim2.new(1,-6,0.5,0)
    nl.Position=UDim2.new(0,6,0,0); nl.BackgroundTransparency=1
    nl.Text=player.Name; nl.TextColor3=Color3.fromRGB(255,255,255)
    nl.Font=FB; nl.TextSize=9; nl.TextXAlignment=Enum.TextXAlignment.Left
    local il=Instance.new("TextLabel",row); il.Size=UDim2.new(1,-6,0.5,0)
    il.Position=UDim2.new(0,6,0.5,0); il.BackgroundTransparency=1
    il.Text="..."; il.TextColor3=Color3.fromRGB(130,130,130)
    il.Font=FR; il.TextSize=8; il.TextXAlignment=Enum.TextXAlignment.Left
    pLabels[player]={nl=nl,il=il}
end
local function removePLabel(player)
    if pLabels[player] then
        pcall(function()
            local r=scroll:FindFirstChild(player.Name)
            if r then r:Destroy() end
        end)
        pLabels[player]=nil
    end
end
for _,p in ipairs(Players:GetPlayers()) do if p~=lp then createPLabel(p) end end
Players.PlayerAdded:Connect(function(p) if p~=lp then createPLabel(p) end end)
Players.PlayerRemoving:Connect(function(p) removePLabel(p); hideESP(p.Name) end)

-- ═══════════════════════════════════════════
-- GAME DATA & TARGETING
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

local function getRange() return atkInf and math.huge or atkRange end

local function getAllTargets(wantP, wantM)
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
                local ok_type=(isP and wantP) or (not isP and wantM)
                if ok_type then
                    local inRange=atkInf or (root.Position-r.Position).Magnitude<=getRange()
                    if inRange then results[#results+1]={h=obj,root=r,model=obj.Parent} end
                end
            end
        end
    end
    return results
end

local function nearestOf(wantP, wantM, range)
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
    local desc=workspace:GetDescendants()
    for _,v in ipairs(desc) do
        if v:IsA("BasePart") and v.Parent and v.Parent~=lp.Character then
            local hum=v.Parent:FindFirstChildOfClass("Humanoid")
            if hum then
                if not hitboxOriginals[v] then
                    hitboxOriginals[v]=v.Size
                end
                pcall(function() v.Size=Vector3.new(hitboxSize,hitboxSize,hitboxSize) end)
            end
        end
    end
end

local function restoreHitboxes()
    for part,origSize in pairs(hitboxOriginals) do
        pcall(function() if part and part.Parent then part.Size=origSize end end)
    end
    hitboxOriginals={}
end

hbB.MouseButton1Click:Connect(function()
    hitboxOn=not hitboxOn; setTog(hitboxOn,hbB,hbD,hbSt)
    if not hitboxOn then restoreHitboxes() end
end)

-- ═══════════════════════════════════════════
-- DASH EXPANDER
-- ═══════════════════════════════════════════
-- hooks the dash action to multiply the velocity applied
local dashHooked=false
local function hookDash()
    if dashHooked then return end
    dashHooked=true
    pcall(function()
        local mt=getrawmetatable(game)
        if not mt then return end
        local old=mt.__newindex
        setreadonly(mt,false)
        mt.__newindex=newcclosure(function(self,key,val)
            if dashOn and key=="Velocity" and typeof(val)=="Vector3" then
                local mag=val.Magnitude
                if mag>20 and mag<500 then
                    val=val*DASH_MULT
                end
            end
            return old(self,key,val)
        end)
        setreadonly(mt,true)
    end)
end
hookDash()

-- ═══════════════════════════════════════════
-- HIGH JUMP
-- ═══════════════════════════════════════════
jumpBtn.MouseButton1Click:Connect(function()
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
-- TELEPORT
-- ═══════════════════════════════════════════
-- Blox Fruits Third Sea coordinates (well-known from community scripts)
local LOCS = {
    SEA_CASTLE = Vector3.new(4917,  275, -4814),   -- Castle on the Sea, Third Sea
    MANSION    = Vector3.new(-1384, 263, -2987),   -- Floating Turtle / Mansion, Third Sea
}

local tpActive=false; local groundPos=nil; local skyPos=nil
local hitRegistry={}

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
    tpSkyBtn.Text = active and "⬆  In Sky  [tap=land]" or "⬆  TP to Sky"
    tpSkyBtn.BackgroundColor3 = active and Color3.fromRGB(90,35,160) or Color3.fromRGB(50,20,90)
end

tpSkyBtn.MouseButton1Click:Connect(function()
    if tpActive then
        tpActive=false; setSkyUI(false)
        if groundPos then task.spawn(tweenTo,groundPos+Vector3.new(0,3,0),1.5) end
        return
    end
    local char=lp.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    groundPos=hrp.Position
    local h=4200+math.random(0,800)
    skyPos=Vector3.new(groundPos.X+(math.random()-0.5)*12, groundPos.Y+h, groundPos.Z+(math.random()-0.5)*12)
    tpActive=true; setSkyUI(true)
    task.spawn(tweenTo,skyPos,2.0)
    task.spawn(function()
        task.wait(2.2)
        while tpActive do
            local c=lp.Character; local h2=c and c:FindFirstChild("HumanoidRootPart")
            if h2 and (h2.Position-skyPos).Magnitude>40 then
                pcall(function() h2.CFrame=CFrame.new(skyPos) end)
            end
            task.wait(0.08)
        end
    end)
end)

tpGndBtn.MouseButton1Click:Connect(function()
    tpActive=false; setSkyUI(false)
    local char=lp.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local dest=groundPos and (groundPos+Vector3.new(0,3,0)) or Vector3.new(hrp.Position.X,hrp.Position.Y-9999,hrp.Position.Z)
    task.spawn(tweenTo,dest,1.5)
end)

tpSCBtn.MouseButton1Click:Connect(function()
    task.spawn(tweenTo,LOCS.SEA_CASTLE,2.5)
end)

tpManBtn.MouseButton1Click:Connect(function()
    task.spawn(tweenTo,LOCS.MANSION,2.5)
end)

lp.CharacterAdded:Connect(function()
    hitRegistry={}; tpActive=false; groundPos=nil; skyPos=nil; setSkyUI(false)
    hookDash()
end)

-- ═══════════════════════════════════════════
-- SILENT AIMBOT  (mousemoverel — moves mouse toward target silently)
-- Based on method from published Blox Fruits community scripts
-- Does NOT touch Camera.CFrame so screen stays still
-- ═══════════════════════════════════════════
local SILENT_AIM_SPEED = 0.55  -- 0=instant snap, 1=very slow
local SILENT_AIM_FOV   = 300   -- pixel radius to consider targets

local function getScreenPos(worldPos)
    local ok,sp,vis = pcall(function() return Camera:WorldToViewportPoint(worldPos) end)
    if not ok or not vis then return nil end
    return Vector2.new(sp.X, sp.Y)
end

local function doSilentAim()
    if not silentAim then return end
    if not mousemoverel then return end  -- needs executor support
    -- pick nearest enemy to current mouse position (closest on screen)
    local char=lp.Character; if not char then return end
    local bestTarget=nil; local bestDist=SILENT_AIM_FOV
    local mousePos=Vector2.new(mouse.X, mouse.Y)
    -- check all players first if apAtkOn, else mobs
    local function checkTarget(model)
        local hrp=model:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local hum=model:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
        local sp=getScreenPos(hrp.Position+Vector3.new(0,2,0)); if not sp then return end
        local d=(sp-mousePos).Magnitude
        if d<bestDist then bestDist=d; bestTarget={model=model,root=hrp,screenPos=sp} end
    end
    if apAtkOn then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=lp and p.Character then checkTarget(p.Character) end
        end
    end
    if aaOn then
        local desc=getDesc()
        for i=1,#desc do
            local obj=desc[i]
            if obj and obj:IsA("Humanoid") and obj.Health>0 and obj.Parent and obj.Parent~=char then
                if not pSet[obj.Parent] then checkTarget(obj.Parent) end
            end
        end
    end
    if bestTarget then
        local sp=bestTarget.screenPos
        local dx=sp.X-mousePos.X; local dy=sp.Y-mousePos.Y
        -- smoothly move mouse toward target using mousemoverel
        pcall(function()
            mousemoverel(dx*SILENT_AIM_SPEED, dy*SILENT_AIM_SPEED)
        end)
    end
end

-- ═══════════════════════════════════════════
-- KITSUNE M1 ATTACK
-- ═══════════════════════════════════════════
local cachedKLC=nil
local function getKLC()
    local char=lp.Character; if not char then return nil end
    if cachedKLC and cachedKLC.Parent then return cachedKLC end
    cachedKLC=nil
    local t=char:FindFirstChild("Kitsune-Kitsune"); if not t then return nil end
    local r=t:FindFirstChild("LeftClickRemote")
    if r then cachedKLC=r end
    return r
end

local function jit(base,amt)
    return base+(math.random()*amt*2-amt)*0.001
end

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
function startAtkLoop()
    if atkRunning then return end
    atkRunning=true
    task.spawn(function()
        while aaOn or apAtkOn do
            descCache=workspace:GetDescendants(); lastScan=tick()
            local tgts=getAllTargets(apAtkOn,aaOn)
            for _,t in ipairs(tgts) do
                if not (aaOn or apAtkOn) then break end
                task.spawn(fireAttack,t)
                task.wait(jit(0.04,15))
            end
            task.wait(jit(0.3,60))
        end
        atkRunning=false
    end)
end

aaB.MouseButton1Click:Connect(function()
    aaOn=not aaOn; setTog(aaOn,aaB,aaD,aaSt)
    if aaOn then startAtkLoop() end
end)
apB.MouseButton1Click:Connect(function()
    apAtkOn=not apAtkOn; setTog(apAtkOn,apB,apD,apSt)
    if apAtkOn then startAtkLoop() end
end)

-- ═══════════════════════════════════════════
-- HEARTBEAT (ESP + cam lock + hitbox + silent aim)
-- ═══════════════════════════════════════════
local frame=0; local lastCount=-1
RunService.Heartbeat:Connect(function()
    frame=frame+1

    -- hitbox expander (every 30 frames ~0.5s)
    if hitboxOn and frame%30==0 then expandHitboxes() end

    if frame%2~=0 then return end

    local char=lp.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")

    -- silent aimbot (mousemoverel, every other frame)
    if silentAim and frame%2==0 then doSilentAim() end

    -- cam lock players
    if camLockP then
        local t=nearestOf(true,false,AIM_RANGE)
        if t then pcall(function()
            Camera.CFrame=CFrame.new(Camera.CFrame.Position, t.root.Position+Vector3.new(0,2,0))
        end) end
    end
    -- cam lock mobs
    if camLockM then
        local t=nearestOf(false,true,AIM_RANGE)
        if t then pcall(function()
            Camera.CFrame=CFrame.new(Camera.CFrame.Position, t.root.Position+Vector3.new(0,2,0))
        end) end
    end

    -- ESP + player list
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
            local col; if hp<=0 then col=Color3.fromRGB(100,100,100)
            elseif dist<20 then col=Color3.fromRGB(255,60,60)
            elseif dist<60 then col=Color3.fromRGB(255,190,0)
            else col=Color3.fromRGB(255,255,255) end
            data.nl.TextColor3=col
            data.il.TextColor3=hp<=0 and Color3.fromRGB(100,100,100) or Color3.fromRGB(100,190,100)
            if espOn and h then showESP(player.Name,h.Position+Vector3.new(0,2.5,0),player.Name,hp,mhp,dist,true)
            elseif not espOn then hideESP(player.Name) end
        else
            data.il.Text="offline"
            data.nl.TextColor3=Color3.fromRGB(130,130,130)
            data.il.TextColor3=Color3.fromRGB(80,80,80)
            hideESP(player.Name)
        end
    end
    if count~=lastCount then
        scroll.CanvasSize=UDim2.new(0,0,0,count*28+6); lastCount=count
    end
end)
