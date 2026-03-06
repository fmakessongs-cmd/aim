-- FyZe Hub | Delta-compatible | Kitsune only
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenSvc     = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")
local lp           = Players.LocalPlayer
local mouse        = lp:GetMouse()
local Camera       = workspace.CurrentCamera

local tw = task.wait
local ts = task.spawn

local _mmr = (typeof(mousemoverel) == "function") and mousemoverel or nil
local _grm = (typeof(getrawmetatable) == "function") and getrawmetatable or nil
local _sro = (typeof(setreadonly) == "function") and setreadonly or nil
local _ncc = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end
local _gnm = (typeof(getnamecallmethod) == "function") and getnamecallmethod or nil
local _wf  = (typeof(writefile) == "function") and writefile or nil
local _rf  = (typeof(readfile)  == "function") and readfile  or nil
local _isf = (typeof(isfile)    == "function") and isfile    or nil

-- makeGui: parent FIRST, then IgnoreGuiInset (Delta requirement)
local function makeGui(name)
    pcall(function()
        local o = game:GetService("CoreGui"):FindFirstChild(name)
        if o then o:Destroy() end
    end)
    pcall(function()
        local o = lp.PlayerGui:FindFirstChild(name)
        if o then o:Destroy() end
    end)
    local g = Instance.new("ScreenGui")
    g.Name = name
    g.ResetOnSpawn = false
    if not pcall(function() g.Parent = game:GetService("CoreGui") end) then
        pcall(function() g.Parent = lp.PlayerGui end)
    end
    pcall(function() g.IgnoreGuiInset = true end)
    return g
end

local FB = Enum.Font.SourceSansBold
local FR = Enum.Font.SourceSans
pcall(function() FB = Enum.Font.GothamBold end)
pcall(function() FR = Enum.Font.Gotham end)

local function newCorner(parent, radius)
    pcall(function()
        local c = Instance.new("UICorner", parent)
        c.CornerRadius = UDim.new(0, radius or 6)
    end)
end

local function newStroke(parent, color, thickness)
    pcall(function()
        local s = Instance.new("UIStroke", parent)
        s.Color = color; s.Thickness = thickness or 1
    end)
end

-- ── State ─────────────────────────────────────────────────────────────────────
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
local minimized    = false
local AIM_RANGE    = 250
local DASH_MULT    = 3
local pSet         = {}
local descCache    = {}
local lastScan     = 0
local descLock     = false

-- ── TP-to-Player state ────────────────────────────────────────────────────────
local tpTargetPlayer = nil   -- selected Player object
local tpTargetOn     = false -- is the continuous TP active?
local tpConnection   = nil   -- RunService.Stepped connection

local function stopBatTP()
    tpTargetOn = false
    if tpConnection then tpConnection:Disconnect(); tpConnection = nil end
end

local function startBatTP()
    stopBatTP()
    if not tpTargetPlayer then return end
    tpTargetOn = true
    tpConnection = RunService.Stepped:Connect(function()
        if not tpTargetOn or not tpTargetPlayer then stopBatTP(); return end
        pcall(function()
            local myChar  = lp.Character
            local tgtChar = tpTargetPlayer.Character
            if not myChar or not tgtChar then return end
            local myHRP  = myChar:FindFirstChild("HumanoidRootPart")
            local tgtHRP = tgtChar:FindFirstChild("HumanoidRootPart")
            if not myHRP or not tgtHRP then return end
            myHRP.CFrame = CFrame.new(tgtHRP.Position)
            pcall(function() myHRP.AssemblyLinearVelocity = Vector3.zero end)
        end)
    end)
end

-- ── Macro / Combo state ───────────────────────────────────────────────────────
local COMBO_FILE     = "fyzehub_combo.json"
local comboRecording = false
local comboPlaying   = false
local comboFrames    = {}
local savedCombo     = {}

-- Frame kinds:
--   "move"   – position/camera delta each tick
--   "attack" – kitsune fire that happened during recording

local function saveComboToDisk(frames)
    if not _wf then return end
    pcall(function()
        local out = {}
        for _, f in ipairs(frames) do
            if f.kind == "move" then
                out[#out+1] = table.concat({
                    "move",
                    tostring(f.dt),
                    tostring(f.mx), tostring(f.my), tostring(f.mz),
                    tostring(f.clx), tostring(f.cly), tostring(f.clz),
                    tostring(f.jump and 1 or 0)
                }, ",")
            elseif f.kind == "attack" then
                out[#out+1] = "attack,0,0,0,0,0,0,0,0"
            end
        end
        _wf(COMBO_FILE, table.concat(out, "\n"))
    end)
end

local function loadComboFromDisk()
    if not _rf or not _isf then return {} end
    local ok, data = pcall(function()
        return _isf(COMBO_FILE) and _rf(COMBO_FILE) or ""
    end)
    if not ok or data == "" then return {} end
    local frames = {}
    for line in data:gmatch("[^\n]+") do
        local parts = {}
        for v in line:gmatch("[^,]+") do parts[#parts+1] = v end
        if parts[1] == "move" and #parts >= 9 then
            frames[#frames+1] = {
                kind = "move",
                dt   = tonumber(parts[2]) or 0.05,
                mx   = tonumber(parts[3]) or 0,
                my   = tonumber(parts[4]) or 0,
                mz   = tonumber(parts[5]) or 0,
                clx  = tonumber(parts[6]) or 0,
                cly  = tonumber(parts[7]) or 0,
                clz  = tonumber(parts[8]) or 0,
                jump = parts[9] == "1"
            }
        elseif parts[1] == "attack" then
            frames[#frames+1] = {kind = "attack"}
        end
    end
    return frames
end

local function deleteComboFile()
    if _wf then pcall(function() _wf(COMBO_FILE, "") end) end
    savedCombo = {}; comboFrames = {}
end

savedCombo = loadComboFromDisk()

-- ── ESP GUI ───────────────────────────────────────────────────────────────────
local eGui      = makeGui("FyZeESP")
local espLabels = {}

local function getLabel(key, isP)
    if espLabels[key] then return espLabels[key] end
    local col = isP and Color3.fromRGB(255,55,55) or Color3.fromRGB(55,220,100)
    local f = Instance.new("Frame", eGui)
    f.Size = UDim2.new(0,120,0,26); f.BackgroundColor3=Color3.fromRGB(8,8,14)
    f.BackgroundTransparency=0.1; f.BorderSizePixel=0
    pcall(function() f.AnchorPoint=Vector2.new(0.5,1) end)
    newCorner(f,4); newStroke(f,col,1)
    local n = Instance.new("TextLabel",f)
    n.Size=UDim2.new(1,0,0.5,0); n.BackgroundTransparency=1
    n.Font=FB; n.TextSize=9; n.TextColor3=Color3.fromRGB(255,255,255)
    n.TextXAlignment=Enum.TextXAlignment.Center; n.Text=key
    local i = Instance.new("TextLabel",f)
    i.Size=UDim2.new(1,0,0.5,0); i.Position=UDim2.new(0,0,0.5,0)
    i.BackgroundTransparency=1; i.Font=FR; i.TextSize=8
    i.TextColor3=Color3.fromRGB(150,150,150)
    i.TextXAlignment=Enum.TextXAlignment.Center; i.Text="..."
    local ln = Instance.new("Frame",eGui)
    ln.Size=UDim2.new(0,1,0,7); ln.BorderSizePixel=0
    ln.BackgroundColor3=col; ln.BackgroundTransparency=0.3
    pcall(function() ln.AnchorPoint=Vector2.new(0.5,0) end)
    espLabels[key]={f=f,n=n,i=i,ln=ln}
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

-- ══════════════════════════════════════════════════════════════════════════════
-- MAIN PANEL  (Delta-safe: no ClipsDescendants, no GetPropertyChangedSignal,
--              no UIListLayout auto-sizing — manual rowY pixel tracking)
-- ══════════════════════════════════════════════════════════════════════════════
local mGui     = makeGui("FyZePanel")
local W        = 225
local MAX_H    = 430
local TH       = 28

-- Icon button (always visible, toggles panel)
local iconBtn = Instance.new("TextButton", mGui)
iconBtn.Size=UDim2.new(0,32,0,32); iconBtn.Position=UDim2.new(0,4,0,4)
iconBtn.BackgroundColor3=Color3.fromRGB(14,14,24); iconBtn.Text="FH"
iconBtn.Font=FB; iconBtn.TextSize=10; iconBtn.TextColor3=Color3.fromRGB(90,130,255)
iconBtn.BorderSizePixel=0; newCorner(iconBtn,6); newStroke(iconBtn,Color3.fromRGB(55,90,210),1)

-- Outer container — NO ClipsDescendants (hides everything in Delta)
local mf = Instance.new("Frame", mGui)
mf.Size=UDim2.new(0,W,0,TH); mf.Position=UDim2.new(0,42,0,4)
mf.BackgroundColor3=Color3.fromRGB(10,10,16); mf.BorderSizePixel=0
newCorner(mf,7); newStroke(mf,Color3.fromRGB(55,90,210),1)

-- Title bar
local tb = Instance.new("Frame", mf)
tb.Size=UDim2.new(1,0,0,TH); tb.BackgroundColor3=Color3.fromRGB(14,14,22); tb.BorderSizePixel=0
newCorner(tb,7)

local titleLbl = Instance.new("TextLabel", tb)
titleLbl.Size=UDim2.new(1,-50,1,0); titleLbl.Position=UDim2.new(0,8,0,0)
titleLbl.BackgroundTransparency=1; titleLbl.Text="FyZe Hub"
titleLbl.TextColor3=Color3.fromRGB(90,130,255); titleLbl.Font=FB; titleLbl.TextSize=11
titleLbl.TextXAlignment=Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton", tb)
minBtn.Size=UDim2.new(0,22,0,18); minBtn.Position=UDim2.new(1,-26,0.5,-9)
minBtn.BackgroundColor3=Color3.fromRGB(28,28,46); minBtn.Text="-"
minBtn.Font=FB; minBtn.TextSize=13; minBtn.TextColor3=Color3.fromRGB(200,200,200)
minBtn.BorderSizePixel=0; newCorner(minBtn,4)

-- Body scroll — rows placed directly here with manual rowY
local bodyScroll = Instance.new("ScrollingFrame", mf)
bodyScroll.Position=UDim2.new(0,0,0,TH); bodyScroll.Size=UDim2.new(1,0,0,0)
bodyScroll.BackgroundTransparency=1; bodyScroll.BorderSizePixel=0
bodyScroll.ScrollBarThickness=3; bodyScroll.CanvasSize=UDim2.new(0,0,0,0)
pcall(function() bodyScroll.ScrollBarImageColor3=Color3.fromRGB(55,90,210) end)

-- rowY: manual pixel tracker — replaces UIListLayout (broken in Delta)
local rowY = 0

local function resizePanel()
    if minimized then
        bodyScroll.Visible=false
        mf.Size=UDim2.new(0,W,0,TH); return
    end
    bodyScroll.Visible=true
    local bodyH=math.min(rowY,MAX_H-TH)
    bodyScroll.Size=UDim2.new(1,0,0,bodyH)
    bodyScroll.CanvasSize=UDim2.new(0,0,0,rowY)
    mf.Size=UDim2.new(0,W,0,TH+bodyH)
end

minBtn.MouseButton1Click:Connect(function()
    minimized=not minimized; minBtn.Text=minimized and "+" or "-"; resizePanel()
end)

-- Row helpers
local function mkSection(txt)
    local h=16
    local f=Instance.new("Frame",bodyScroll)
    f.Position=UDim2.new(0,0,0,rowY); f.Size=UDim2.new(1,0,0,h)
    f.BackgroundColor3=Color3.fromRGB(18,18,30); f.BorderSizePixel=0
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,-8,1,0); l.Position=UDim2.new(0,8,0,0)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=Color3.fromRGB(60,90,200); l.Font=FB; l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left
    rowY=rowY+h+1
end

local function mkToggle(txt)
    local h=25
    local fr=Instance.new("Frame",bodyScroll)
    fr.Position=UDim2.new(0,0,0,rowY); fr.Size=UDim2.new(1,0,0,h)
    fr.BackgroundColor3=Color3.fromRGB(12,12,20); fr.BorderSizePixel=0
    local lb=Instance.new("TextLabel",fr)
    lb.Size=UDim2.new(0.60,0,1,0); lb.Position=UDim2.new(0,7,0,0)
    lb.BackgroundTransparency=1; lb.Text=txt
    lb.TextColor3=Color3.fromRGB(185,185,185); lb.Font=FB; lb.TextSize=10
    lb.TextXAlignment=Enum.TextXAlignment.Left
    local stl=Instance.new("TextLabel",fr)
    stl.Size=UDim2.new(0,28,1,0); stl.Position=UDim2.new(1,-65,0,0)
    stl.BackgroundTransparency=1; stl.Text="OFF"
    stl.TextColor3=Color3.fromRGB(255,55,55); stl.Font=FB; stl.TextSize=10
    stl.TextXAlignment=Enum.TextXAlignment.Right
    local track=Instance.new("TextButton",fr)
    track.Size=UDim2.new(0,34,0,18); track.Position=UDim2.new(1,-40,0.5,-9)
    track.BackgroundColor3=Color3.fromRGB(40,40,60); track.Text=""
    track.BorderSizePixel=0; newCorner(track,99)
    local dot=Instance.new("Frame",track)
    dot.Size=UDim2.new(0,12,0,12); dot.Position=UDim2.new(0,3,0.5,-6)
    dot.BackgroundColor3=Color3.fromRGB(120,120,120); dot.BorderSizePixel=0; newCorner(dot,99)
    rowY=rowY+h+1
    return fr,track,dot,stl
end

local function mkBtn(txt,col,tcol)
    local h=24
    local b=Instance.new("TextButton",bodyScroll)
    b.Position=UDim2.new(0,6,0,rowY); b.Size=UDim2.new(1,-12,0,h)
    b.BackgroundColor3=col or Color3.fromRGB(28,28,44)
    b.Text=txt; b.TextColor3=tcol or Color3.fromRGB(255,255,255)
    b.Font=FB; b.TextSize=10; b.BorderSizePixel=0; newCorner(b,4)
    rowY=rowY+h+2
    return b
end

local function mkDiv()
    local f=Instance.new("Frame",bodyScroll)
    f.Position=UDim2.new(0,6,0,rowY); f.Size=UDim2.new(1,-12,0,1)
    f.BackgroundColor3=Color3.fromRGB(30,30,50); f.BorderSizePixel=0
    rowY=rowY+3
end

local function mkLabel(txt)
    local h=18
    local l=Instance.new("TextLabel",bodyScroll)
    l.Position=UDim2.new(0,7,0,rowY); l.Size=UDim2.new(1,-14,0,h)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=Color3.fromRGB(110,110,130); l.Font=FR; l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left
    rowY=rowY+h+1
    return l
end

-- ── Build menu ────────────────────────────────────────────────────────────────
mkSection("COMBAT")
local _,espB,  espD,  espSt  = mkToggle("Player ESP")
local _,aaB,   aaD,   aaSt   = mkToggle("Kill Aura NPCs")
local _,apB,   apD,   apSt   = mkToggle("Kill Aura Players")
mkDiv()
mkSection("AIM")
local _,clpB, clpD, clpSt = mkToggle("Cam Lock Players")
local _,clmB, clmD, clmSt = mkToggle("Cam Lock Mobs")
local _,saB,  saD,  saSt  = mkToggle("Silent Aimbot")
mkDiv()
mkSection("MOVEMENT")
local _,dashB,dashD,dashSt = mkToggle("Dash Expander")
mkDiv()
mkSection("HITBOX")
local _,hbB, hbD, hbSt = mkToggle("Hitbox Expander")
mkDiv()
mkSection("RANGE")

-- Slider (all inline, no helpers that can fail in Delta)
local SMIN,SMAX=5,999
local slH=38
local slFr=Instance.new("Frame",bodyScroll)
slFr.Position=UDim2.new(0,0,0,rowY); slFr.Size=UDim2.new(1,0,0,slH)
slFr.BackgroundColor3=Color3.fromRGB(12,12,20); slFr.BorderSizePixel=0
rowY=rowY+slH+2
local sLbl=Instance.new("TextLabel",slFr)
sLbl.Size=UDim2.new(0.55,0,0,14); sLbl.Position=UDim2.new(0,7,0,3)
sLbl.BackgroundTransparency=1; sLbl.Text="Attack Range"
sLbl.TextColor3=Color3.fromRGB(120,120,120); sLbl.Font=FB; sLbl.TextSize=9
sLbl.TextXAlignment=Enum.TextXAlignment.Left
local sValL=Instance.new("TextLabel",slFr)
sValL.Size=UDim2.new(0,34,0,14); sValL.Position=UDim2.new(1,-42,0,3)
sValL.BackgroundTransparency=1; sValL.Text=tostring(atkRange)
sValL.TextColor3=Color3.fromRGB(65,100,235); sValL.Font=FB; sValL.TextSize=10
sValL.TextXAlignment=Enum.TextXAlignment.Right
local sTrk=Instance.new("Frame",slFr)
sTrk.Size=UDim2.new(1,-54,0,6); sTrk.Position=UDim2.new(0,7,0,22)
sTrk.BackgroundColor3=Color3.fromRGB(26,26,44); sTrk.BorderSizePixel=0; newCorner(sTrk,99)
local sFill=Instance.new("Frame",sTrk)
sFill.Size=UDim2.new(0.025,0,1,0); sFill.BackgroundColor3=Color3.fromRGB(65,100,235)
sFill.BorderSizePixel=0; newCorner(sFill,99)
-- No AnchorPoint on thumb (Delta bug) — manual offset
local sThumb=Instance.new("TextButton",sTrk)
sThumb.Size=UDim2.new(0,14,0,14); sThumb.Position=UDim2.new(0,-7,0,-4)
sThumb.BackgroundColor3=Color3.fromRGB(255,255,255); sThumb.Text=""
sThumb.BorderSizePixel=0; newCorner(sThumb,99)
local infB=Instance.new("TextButton",slFr)
infB.Size=UDim2.new(0,34,0,14); infB.Position=UDim2.new(1,-42,0,21)
infB.BackgroundColor3=Color3.fromRGB(26,26,44); infB.Text="INF"
infB.TextColor3=Color3.fromRGB(145,145,145); infB.Font=FB; infB.TextSize=9
infB.BorderSizePixel=0; newCorner(infB,3)

mkDiv()
mkSection("TELEPORT")
local tpSkyBtn=mkBtn("^ TP to Sky",     Color3.fromRGB(44,16,80),  Color3.fromRGB(188,148,255))
local tpGndBtn=mkBtn("v Return Ground", Color3.fromRGB(16,48,20),  Color3.fromRGB(108,218,108))
mkDiv()

-- ── TP TO PLAYER section ──────────────────────────────────────────────────────
mkSection("TP TO PLAYER")

-- Row: target name label + START/STOP button
local tpRowH=24
local tpNameLbl=Instance.new("TextLabel",bodyScroll)
tpNameLbl.Position=UDim2.new(0,6,0,rowY); tpNameLbl.Size=UDim2.new(1,-82,0,tpRowH)
tpNameLbl.BackgroundColor3=Color3.fromRGB(16,16,28); tpNameLbl.BorderSizePixel=0
tpNameLbl.Text="No target"; tpNameLbl.Font=FR; tpNameLbl.TextSize=10
tpNameLbl.TextColor3=Color3.fromRGB(160,160,160)
tpNameLbl.TextXAlignment=Enum.TextXAlignment.Left
newCorner(tpNameLbl,4)
-- small left padding via position offset instead of UIPadding
tpNameLbl.Position=UDim2.new(0,6,0,rowY)

local tpTogBtn=Instance.new("TextButton",bodyScroll)
tpTogBtn.Position=UDim2.new(1,-74,0,rowY); tpTogBtn.Size=UDim2.new(0,68,0,tpRowH)
tpTogBtn.BackgroundColor3=Color3.fromRGB(22,60,22); tpTogBtn.BorderSizePixel=0
tpTogBtn.Text="START"; tpTogBtn.Font=FB; tpTogBtn.TextSize=10
tpTogBtn.TextColor3=Color3.fromRGB(108,218,108); newCorner(tpTogBtn,4)
rowY=rowY+tpRowH+3

-- Player picker: scrollable list of buttons
local tpPickH=68  -- shows ~3 rows
local tpPickFr=Instance.new("ScrollingFrame",bodyScroll)
tpPickFr.Position=UDim2.new(0,4,0,rowY); tpPickFr.Size=UDim2.new(1,-8,0,tpPickH)
tpPickFr.BackgroundTransparency=1; tpPickFr.BorderSizePixel=0
tpPickFr.ScrollBarThickness=2; tpPickFr.CanvasSize=UDim2.new(0,0,0,0)
pcall(function() tpPickFr.ScrollBarImageColor3=Color3.fromRGB(55,90,210) end)
rowY=rowY+tpPickH+4

local tpBtns={};  local tpBtnY=0

local function rebuildTpPicker()
    for _,b in pairs(tpBtns) do pcall(function() b:Destroy() end) end
    tpBtns={}; tpBtnY=0
    local btnH=22
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=lp then
            local pb=Instance.new("TextButton",tpPickFr)
            pb.Name=p.Name
            pb.Position=UDim2.new(0,0,0,tpBtnY); pb.Size=UDim2.new(1,0,0,btnH)
            local sel=(tpTargetPlayer==p)
            pb.BackgroundColor3=sel and Color3.fromRGB(50,86,220) or Color3.fromRGB(18,18,30)
            pb.BorderSizePixel=0; pb.Font=FB; pb.TextSize=9
            pb.Text="  "..p.Name
            pb.TextColor3=sel and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,180)
            pb.TextXAlignment=Enum.TextXAlignment.Left
            newCorner(pb,3)
            pb.MouseButton1Click:Connect(function()
                if tpTargetPlayer==p then
                    -- deselect / stop
                    tpTargetPlayer=nil; stopBatTP()
                    tpNameLbl.Text="No target"; tpNameLbl.TextColor3=Color3.fromRGB(160,160,160)
                    tpTogBtn.Text="START"; tpTogBtn.BackgroundColor3=Color3.fromRGB(22,60,22)
                    tpTogBtn.TextColor3=Color3.fromRGB(108,218,108)
                else
                    tpTargetPlayer=p
                    tpNameLbl.Text=p.Name; tpNameLbl.TextColor3=Color3.fromRGB(108,218,255)
                    if tpTargetOn then startBatTP() end  -- swap target live
                end
                rebuildTpPicker()
            end)
            tpBtns[p]=pb; tpBtnY=tpBtnY+btnH
        end
    end
    tpPickFr.CanvasSize=UDim2.new(0,0,0,tpBtnY)
end
rebuildTpPicker()

tpTogBtn.MouseButton1Click:Connect(function()
    if not tpTargetPlayer then return end
    if tpTargetOn then
        stopBatTP()
        tpTogBtn.Text="START"; tpTogBtn.BackgroundColor3=Color3.fromRGB(22,60,22)
        tpTogBtn.TextColor3=Color3.fromRGB(108,218,108)
    else
        startBatTP()
        tpTogBtn.Text="STOP"; tpTogBtn.BackgroundColor3=Color3.fromRGB(80,20,14)
        tpTogBtn.TextColor3=Color3.fromRGB(255,100,100)
    end
end)

Players.PlayerAdded:Connect(function()   rebuildTpPicker() end)
Players.PlayerRemoving:Connect(function(p)
    if tpTargetPlayer==p then
        tpTargetPlayer=nil; stopBatTP()
        tpNameLbl.Text="No target"; tpNameLbl.TextColor3=Color3.fromRGB(160,160,160)
        tpTogBtn.Text="START"; tpTogBtn.BackgroundColor3=Color3.fromRGB(22,60,22)
        tpTogBtn.TextColor3=Color3.fromRGB(108,218,108)
    end
    rebuildTpPicker()
end)

mkDiv()

-- ── COMBO section ─────────────────────────────────────────────────────────────
mkSection("COMBO")
local comboStatusLbl=mkLabel(#savedCombo>0 and ("Saved: "..#savedCombo.." frames") or "No combo saved")
local recBtn  = mkBtn("Record Macro", Color3.fromRGB(20,50,20),  Color3.fromRGB(108,218,108))
local playBtn = mkBtn("Start Macro",  Color3.fromRGB(18,38,76),  Color3.fromRGB(108,155,245))
local delBtn  = mkBtn("Delete Combo", Color3.fromRGB(50,14,14),  Color3.fromRGB(218,90,90))
mkDiv()

mkSection("PLAYERS")
local pListH=85
local pListFr=Instance.new("ScrollingFrame",bodyScroll)
pListFr.Position=UDim2.new(0,4,0,rowY); pListFr.Size=UDim2.new(1,-8,0,pListH)
pListFr.BackgroundTransparency=1; pListFr.BorderSizePixel=0
pListFr.ScrollBarThickness=2; pListFr.CanvasSize=UDim2.new(0,0,0,0)
pcall(function() pListFr.ScrollBarImageColor3=Color3.fromRGB(55,90,210) end)
rowY=rowY+pListH+4

rowY=rowY+4  -- bottom padding
resizePanel()  -- called ONCE after all rows built

-- ── Toggle helper ─────────────────────────────────────────────────────────────
local function setTog(on,track,dot,stl)
    if on then
        track.BackgroundColor3=Color3.fromRGB(50,86,220)
        dot.BackgroundColor3=Color3.fromRGB(255,255,255)
        dot.Position=UDim2.new(1,-15,0.5,-6)
        if stl then stl.Text="ON";  stl.TextColor3=Color3.fromRGB(55,195,95)  end
    else
        track.BackgroundColor3=Color3.fromRGB(40,40,60)
        dot.BackgroundColor3=Color3.fromRGB(120,120,120)
        dot.Position=UDim2.new(0,3,0.5,-6)
        if stl then stl.Text="OFF"; stl.TextColor3=Color3.fromRGB(255,55,55) end
    end
end

local function updateSlider()
    if atkInf then
        sValL.Text="INF"; sValL.TextColor3=Color3.fromRGB(255,178,40)
        infB.BackgroundColor3=Color3.fromRGB(50,86,220); infB.TextColor3=Color3.fromRGB(255,255,255)
        sFill.Size=UDim2.new(1,0,1,0); sThumb.Position=UDim2.new(1,-7,0,-4)
    else
        local pct=(atkRange-SMIN)/(SMAX-SMIN)
        sValL.Text=tostring(atkRange); sValL.TextColor3=Color3.fromRGB(65,100,235)
        infB.BackgroundColor3=Color3.fromRGB(26,26,44); infB.TextColor3=Color3.fromRGB(145,145,145)
        sFill.Size=UDim2.new(pct,0,1,0); sThumb.Position=UDim2.new(pct,-7,0,-4)
    end
end

local function updateComboStatus()
    local n=#savedCombo
    comboStatusLbl.Text=n>0 and ("Saved: "..n.." frames") or "No combo saved"
end

-- ── Player set ────────────────────────────────────────────────────────────────
local function rebuildPSet()
    pSet={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Character then pSet[p.Character]=true end
    end
end
local function getDesc()
    local now=tick()
    if now-lastScan>=2 and not descLock then
        descLock=true; descCache=workspace:GetDescendants(); lastScan=tick(); descLock=false
    end
    return descCache
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(rebuildPSet); rebuildPSet() end)
Players.PlayerRemoving:Connect(rebuildPSet)
for _,p in ipairs(Players:GetPlayers()) do p.CharacterAdded:Connect(rebuildPSet) end
rebuildPSet(); descCache=workspace:GetDescendants(); lastScan=tick()

-- ── Target finders ────────────────────────────────────────────────────────────
local Enemies=workspace:FindFirstChild("Enemies")  -- FindFirstChild only, no yield

local function iterTargets(wantP,wantM,root,rangeLimit)
    local out={}
    if wantM then
        local src=Enemies or workspace
        for _,model in ipairs(src:GetChildren()) do
            if model~=lp.Character and not pSet[model] then
                local hum=model:FindFirstChildOfClass("Humanoid")
                local r=model:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health>0 and r then
                    local d=(root.Position-r.Position).Magnitude
                    if atkInf or d<=(rangeLimit or atkRange) then
                        out[#out+1]={h=hum,root=r,model=model,dist=d}
                    end
                end
            end
        end
    end
    if wantP then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=lp and p.Character then
                local hum=p.Character:FindFirstChildOfClass("Humanoid")
                local r=p.Character:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health>0 and r then
                    local d=(root.Position-r.Position).Magnitude
                    if atkInf or d<=(rangeLimit or atkRange) then
                        out[#out+1]={h=hum,root=r,model=p.Character,dist=d}
                    end
                end
            end
        end
    end
    return out
end

local function getAllTargets(wantP,wantM)
    local char=lp.Character; if not char then return {} end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return {} end
    return iterTargets(wantP,wantM,root)
end

local function nearestOf(wantP,wantM,range)
    local char=lp.Character; if not char then return nil end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    local tgts=iterTargets(wantP,wantM,root,range or 1e9)
    local best,bestD=nil,range or 1e9
    for _,t in ipairs(tgts) do if t.dist<bestD then bestD=t.dist; best=t end end
    return best
end

-- ── Hitbox ────────────────────────────────────────────────────────────────────
local hbOriginals={}
local function expandHitboxes()
    if not hitboxOn then return end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Parent and v.Parent~=lp.Character
        and v.Parent:FindFirstChildOfClass("Humanoid") then
            if not hbOriginals[v] then hbOriginals[v]=v.Size end
            pcall(function() v.Size=Vector3.new(15,15,15) end)
        end
    end
end
local function restoreHitboxes()
    for part,orig in pairs(hbOriginals) do
        pcall(function() if part and part.Parent then part.Size=orig end end)
    end; hbOriginals={}
end

-- ── Dash hook ─────────────────────────────────────────────────────────────────
local dashHooked=false
local function hookDash()
    if dashHooked or not _grm or not _sro then return end; dashHooked=true
    pcall(function()
        local mt=_grm(game); if not mt then return end
        local old=mt.__newindex; _sro(mt,false)
        mt.__newindex=_ncc(function(self,k,v)
            if dashOn and k=="Velocity" and typeof(v)=="Vector3" then
                local m=v.Magnitude; if m>20 and m<500 then v=v*DASH_MULT end
            end
            return old(self,k,v)
        end); _sro(mt,true)
    end)
end
hookDash()

-- ── Teleport ──────────────────────────────────────────────────────────────────
local tpActive=false; local groundPos=nil; local skyPos=nil; local hitReg={}

local function teleportTo(pos)
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand=true end; hrp.Anchored=true
    for _=1,3 do pcall(function() hrp.CFrame=CFrame.new(pos) end); tw() end
    hrp.Anchored=false; if hum then tw(0.1); hum.PlatformStand=false end
end

local function tweenSky(pos,dur)
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand=true end
    local ok,tw2=pcall(function()
        return TweenSvc:Create(hrp,TweenInfo.new(dur or 2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=CFrame.new(pos)})
    end)
    if ok and tw2 then tw2:Play(); tw2.Completed:Wait() else teleportTo(pos) end
    if hum then tw(0.1); hum.PlatformStand=false end
end

local function setSkyUI(on)
    tpSkyBtn.Text=on and "^ In Sky (tap=land)" or "^ TP to Sky"
    tpSkyBtn.BackgroundColor3=on and Color3.fromRGB(80,28,145) or Color3.fromRGB(44,16,80)
end

tpSkyBtn.MouseButton1Click:Connect(function()
    if tpActive then tpActive=false; setSkyUI(false)
        if groundPos then ts(teleportTo,groundPos+Vector3.new(0,3,0)) end; return end
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
            if h2 and (h2.Position-skyPos).Magnitude>40 then pcall(function() h2.CFrame=CFrame.new(skyPos) end) end
            tw(0.08)
        end
    end)
end)

tpGndBtn.MouseButton1Click:Connect(function()
    tpActive=false; setSkyUI(false)
    local char=lp.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    ts(teleportTo,groundPos and groundPos+Vector3.new(0,3,0) or Vector3.new(hrp.Position.X,hrp.Position.Y-400,hrp.Position.Z))
end)

lp.CharacterAdded:Connect(function()
    hitReg={}; tpActive=false; groundPos=nil; skyPos=nil; setSkyUI(false)
    hookDash(); rebuildPSet(); stopBatTP()
    cachedKLC=nil; RE_Atk=nil; RE_Hit=nil
end)

-- ── Silent aim ────────────────────────────────────────────────────────────────
local function doSilentAim()
    if not silentAim or not _mmr then return end
    local char=lp.Character; if not char then return end
    local vp=Camera.ViewportSize; local cx=vp.X/2; local cy=vp.Y/2
    local best,bestD=nil,350
    local function chk(model)
        if model==char then return end
        local head=model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart"); if not head then return end
        local hum=model:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return end
        local ok,sp,vis=pcall(function() return Camera:WorldToViewportPoint(head.Position) end)
        if not ok or not vis then return end
        local d=math.sqrt((sp.X-cx)^2+(sp.Y-cy)^2)
        if d<bestD then bestD=d; best=Vector2.new(sp.X,sp.Y) end
    end
    for _,p in ipairs(Players:GetPlayers()) do if p~=lp and p.Character then chk(p.Character) end end
    local src=Enemies or workspace
    for _,model in ipairs(src:GetChildren()) do if model~=char and not pSet[model] then chk(model) end end
    if best then
        local dx=best.X-mouse.X; local dy=best.Y-mouse.Y
        if math.abs(dx)>3 or math.abs(dy)>3 then pcall(function() _mmr(dx*0.45,dy*0.45) end) end
    end
end

-- ── Kitsune attack ────────────────────────────────────────────────────────────
-- remotes found via FindFirstChild only (no WaitForChild blocking)
local mods=RS:FindFirstChild("Modules")
local net=mods and mods:FindFirstChild("Net")
local RE_Atk=net and net:FindFirstChild("RE/RegisterAttack")
local RE_Hit=net and net:FindFirstChild("RE/RegisterHit")

local function ensureRemotes()
    if RE_Atk and RE_Hit then return true end
    local m=RS:FindFirstChild("Modules"); local n=m and m:FindFirstChild("Net"); if not n then return false end
    RE_Atk=RE_Atk or n:FindFirstChild("RE/RegisterAttack")
    RE_Hit=RE_Hit or n:FindFirstChild("RE/RegisterHit")
    return RE_Atk~=nil and RE_Hit~=nil
end

local cachedKLC=nil
local function getKLC()
    local char=lp.Character; if not char then return nil end
    if cachedKLC and cachedKLC.Parent then return cachedKLC end; cachedKLC=nil
    local t=char:FindFirstChild("Kitsune-Kitsune"); if not t then return nil end
    local r=t:FindFirstChild("LeftClickRemote"); if r then cachedKLC=r end; return r
end

local function jit(b,a) return b+(math.random()*a*2-a)*0.001 end

-- recAttack: inject an "attack" frame into the recording mid-tick
local function recAttack()
    if comboRecording then
        comboFrames[#comboFrames+1]={kind="attack"}
    end
end

local function fireKitsune(tgt,hrp)
    if not tgt.h or tgt.h.Health<=0 then return false end
    if not ensureRemotes() then return false end
    local dir=tgt.root.Position-hrp.Position
    local du=dir.Magnitude>0 and dir.Unit or Vector3.new(0,0,1)
    local lc=getKLC()
    if lc then
        local vd=Vector3.new(du.X+(math.random()-0.5)*0.06,du.Y+(math.random()-0.5)*0.06,du.Z+(math.random()-0.5)*0.06).Unit
        pcall(function() lc:FireServer(vd,1,true) end)
    end
    pcall(function() RE_Atk:FireServer(0.4) end); tw(jit(0.03,8))
    local hitParts={}
    local hb=tgt.model:FindFirstChild("ModelHitbox"); if hb then hitParts[#hitParts+1]=hb end
    hitParts[#hitParts+1]=tgt.root
    for _,part in ipairs(hitParts) do
        pcall(function() RE_Hit:FireServer(part,{},nil) end); tw(jit(0.018,6))
    end
    recAttack()  -- log this attack into the macro recording
    return true
end

local function fireAttack(tgt)
    local char=lp.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if not tgt.model then return end
    local hum=tgt.h; local n=0
    while n<30 do
        if not hum or not hum.Parent or hum.Health<=0 then break end
        if not fireKitsune(tgt,hrp) then break end
        n=n+1; tw(jit(0.045,15))
    end
end

-- ── Attack loop ───────────────────────────────────────────────────────────────
local atkRunning=false
local function startAtkLoop()
    if atkRunning then return end; atkRunning=true
    ts(function()
        while aaOn or apAtkOn do
            local tgts=getAllTargets(apAtkOn,aaOn)
            for _,t in ipairs(tgts) do
                if not(aaOn or apAtkOn) then break end
                ts(fireAttack,t); tw(jit(0.04,15))
            end; tw(jit(0.3,60))
        end; atkRunning=false
    end)
end

-- ── Combo record / playback ───────────────────────────────────────────────────
local recLastPos=nil; local recLastTime=nil

local function startRecording()
    comboRecording=true; comboFrames={}; recLastTime=tick()
    local char=lp.Character
    recLastPos=char and char:FindFirstChild("HumanoidRootPart")
        and char.HumanoidRootPart.Position or Vector3.new()
    recBtn.Text="Stop Recording"; recBtn.BackgroundColor3=Color3.fromRGB(80,14,14)
    recBtn.TextColor3=Color3.fromRGB(255,90,90)
    ts(function()
        while comboRecording do
            local char2=lp.Character
            local hrp2=char2 and char2:FindFirstChild("HumanoidRootPart")
            local hum2=char2 and char2:FindFirstChildOfClass("Humanoid")
            if hrp2 then
                local now=tick(); local dt=now-recLastTime; recLastTime=now
                local cf=Camera.CFrame; local pos=hrp2.Position
                local dp=pos-recLastPos; local cl=cf.LookVector
                local isJump=false
                if hum2 then
                    local st=hum2:GetState()
                    isJump=(st==Enum.HumanoidStateType.Jumping or st==Enum.HumanoidStateType.Freefall)
                end
                -- Only push a move frame; attack frames are pushed by recAttack()
                comboFrames[#comboFrames+1]={
                    kind="move", dt=dt,
                    mx=dp.X, my=dp.Y, mz=dp.Z,
                    clx=cl.X, cly=cl.Y, clz=cl.Z,
                    jump=isJump
                }
                recLastPos=pos
            end; tw(0.05)
        end
    end)
end

local function stopRecording()
    comboRecording=false
    savedCombo=comboFrames; saveComboToDisk(savedCombo); updateComboStatus()
    recBtn.Text="Record Macro"; recBtn.BackgroundColor3=Color3.fromRGB(20,50,20)
    recBtn.TextColor3=Color3.fromRGB(108,218,108)
end

local function playMacro()
    if comboPlaying or #savedCombo==0 then return end; comboPlaying=true
    playBtn.Text="Stop Macro"; playBtn.BackgroundColor3=Color3.fromRGB(80,20,14)
    playBtn.TextColor3=Color3.fromRGB(255,130,90)
    ts(function()
        local char=lp.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then
            comboPlaying=false; playBtn.Text="Start Macro"
            playBtn.BackgroundColor3=Color3.fromRGB(18,38,76); playBtn.TextColor3=Color3.fromRGB(108,155,245); return
        end
        for _,frame in ipairs(savedCombo) do
            if not comboPlaying then break end
            char=lp.Character; hrp=char and char:FindFirstChild("HumanoidRootPart")
            hum=char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then break end

            if frame.kind=="attack" then
                -- Re-fire kitsune at nearest target during playback
                pcall(function()
                    local myHRP=char:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
                    local tgt=nearestOf(true,true,atkInf and 1e9 or atkRange)
                    if tgt then fireKitsune(tgt,myHRP) end
                end)

            elseif frame.kind=="move" then
                -- Replay camera
                local look=Vector3.new(frame.clx,frame.cly,frame.clz)
                pcall(function()
                    Camera.CFrame=CFrame.new(Camera.CFrame.Position,Camera.CFrame.Position+look)
                end)
                -- Replay movement delta
                local newPos=hrp.Position+Vector3.new(frame.mx,frame.my,frame.mz)
                pcall(function()
                    hrp.CFrame=CFrame.new(newPos)*(hrp.CFrame-hrp.CFrame.Position)
                end)
                -- Replay jump
                if frame.jump then
                    pcall(function()
                        hum:ChangeState(Enum.HumanoidStateType.Jumping); tw()
                        if not pcall(function()
                            hrp.AssemblyLinearVelocity=Vector3.new(hrp.AssemblyLinearVelocity.X,80,hrp.AssemblyLinearVelocity.Z)
                        end) then hrp.Velocity=Vector3.new(hrp.Velocity.X,80,hrp.Velocity.Z) end
                    end)
                end
                tw(math.max(frame.dt,0.016))
            end
        end
        comboPlaying=false; playBtn.Text="Start Macro"
        playBtn.BackgroundColor3=Color3.fromRGB(18,38,76); playBtn.TextColor3=Color3.fromRGB(108,155,245)
    end)
end

recBtn.MouseButton1Click:Connect(function()
    if comboRecording then stopRecording() else startRecording() end
end)
playBtn.MouseButton1Click:Connect(function()
    if comboPlaying then
        comboPlaying=false; playBtn.Text="Start Macro"
        playBtn.BackgroundColor3=Color3.fromRGB(18,38,76); playBtn.TextColor3=Color3.fromRGB(108,155,245)
    else playMacro() end
end)
delBtn.MouseButton1Click:Connect(function()
    if comboRecording then stopRecording() end
    if comboPlaying then
        comboPlaying=false; playBtn.Text="Start Macro"
        playBtn.BackgroundColor3=Color3.fromRGB(18,38,76); playBtn.TextColor3=Color3.fromRGB(108,155,245)
    end
    deleteComboFile(); updateComboStatus()
end)

-- ── Button wiring ─────────────────────────────────────────────────────────────
iconBtn.MouseButton1Click:Connect(function()
    uiOpen=not uiOpen; mf.Visible=uiOpen
    iconBtn.TextColor3=uiOpen and Color3.fromRGB(90,130,255) or Color3.fromRGB(70,70,105)
end)

setTog(true,espB,espD,espSt)
espB.MouseButton1Click:Connect(function()
    espOn=not espOn; setTog(espOn,espB,espD,espSt)
    if not espOn then for _,lb in pairs(espLabels) do lb.f.Visible=false; lb.ln.Visible=false end end
end)
aaB.MouseButton1Click:Connect(function()  aaOn=not aaOn;       setTog(aaOn,aaB,aaD,aaSt);     if aaOn then startAtkLoop() end end)
apB.MouseButton1Click:Connect(function()  apAtkOn=not apAtkOn; setTog(apAtkOn,apB,apD,apSt);  if apAtkOn then startAtkLoop() end end)
clpB.MouseButton1Click:Connect(function() camLockP=not camLockP;  setTog(camLockP,clpB,clpD,clpSt)  end)
clmB.MouseButton1Click:Connect(function() camLockM=not camLockM;  setTog(camLockM,clmB,clmD,clmSt)  end)
saB.MouseButton1Click:Connect(function()  silentAim=not silentAim;setTog(silentAim,saB,saD,saSt)     end)
dashB.MouseButton1Click:Connect(function() dashOn=not dashOn;     setTog(dashOn,dashB,dashD,dashSt)  end)
hbB.MouseButton1Click:Connect(function()
    hitboxOn=not hitboxOn; setTog(hitboxOn,hbB,hbD,hbSt)
    if not hitboxOn then restoreHitboxes() end
end)
infB.MouseButton1Click:Connect(function() atkInf=not atkInf; updateSlider() end)
updateSlider()

-- ── Drag (panel) ──────────────────────────────────────────────────────────────
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
        mf.Position=UDim2.new(dragOrigin.X.Scale,dragOrigin.X.Offset+d.X,
            dragOrigin.Y.Scale,dragOrigin.Y.Offset+d.Y)
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

-- ── Player list (manual row positions) ───────────────────────────────────────
local pLabels={}
local pRowY=0

local function createPLabel(player)
    local row=Instance.new("Frame",pListFr)
    row.Name=player.Name; row.Position=UDim2.new(0,0,0,pRowY); row.Size=UDim2.new(1,0,0,23)
    row.BackgroundColor3=Color3.fromRGB(14,14,22); row.BorderSizePixel=0; newCorner(row,3)
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
    pLabels[player]={nl=nl,il=il,row=row}
    pRowY=pRowY+25; pListFr.CanvasSize=UDim2.new(0,0,0,pRowY)
end

local function removePLabel(player)
    if not pLabels[player] then return end
    pcall(function() pLabels[player].row:Destroy() end); pLabels[player]=nil
    pRowY=0
    for _,data in pairs(pLabels) do
        data.row.Position=UDim2.new(0,0,0,pRowY); pRowY=pRowY+25
    end
    pListFr.CanvasSize=UDim2.new(0,0,0,pRowY)
end

for _,p in ipairs(Players:GetPlayers()) do if p~=lp then createPLabel(p) end end
Players.PlayerAdded:Connect(function(p)   if p~=lp then createPLabel(p) end end)
Players.PlayerRemoving:Connect(function(p) removePLabel(p); hideESP(p.Name) end)

-- ── Jump button ───────────────────────────────────────────────────────────────
local jGui=makeGui("FyZeJump")
local jBtn=Instance.new("TextButton",jGui)
jBtn.Size=UDim2.new(0,50,0,50); jBtn.Position=UDim2.new(1,-64,1,-64)
jBtn.BackgroundColor3=Color3.fromRGB(12,12,22); jBtn.Text="^"
jBtn.Font=FB; jBtn.TextSize=22; jBtn.TextColor3=Color3.fromRGB(100,195,100)
jBtn.BorderSizePixel=0; newCorner(jBtn,99); newStroke(jBtn,Color3.fromRGB(45,150,70),1)

local jHeld=false; local jDragged=false; local jDS=nil; local jDO=nil; local DRAG_T=8
jBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType~=Enum.UserInputType.MouseButton1
    and inp.UserInputType~=Enum.UserInputType.Touch then return end
    jHeld=true; jDragged=false
    jDS=Vector2.new(inp.Position.X,inp.Position.Y)
    jDO=Vector2.new(jBtn.AbsolutePosition.X,jBtn.AbsolutePosition.Y)
end)
jBtn.InputChanged:Connect(function(inp)
    if not jHeld then return end
    if inp.UserInputType~=Enum.UserInputType.MouseMovement
    and inp.UserInputType~=Enum.UserInputType.Touch then return end
    local dx=inp.Position.X-jDS.X; local dy=inp.Position.Y-jDS.Y
    if math.sqrt(dx*dx+dy*dy)>=DRAG_T then jDragged=true end
    if jDragged then jBtn.Position=UDim2.new(0,jDO.X+dx,0,jDO.Y+dy) end
end)
jBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType~=Enum.UserInputType.MouseButton1
    and inp.UserInputType~=Enum.UserInputType.Touch then return end
    local wasDrag=jDragged; jHeld=false; jDragged=false; jDS=nil; jDO=nil
    if not wasDrag then
        local char=lp.Character; if not char then return end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid"); if not hrp or not hum then return end
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping); tw()
            if not pcall(function()
                hrp.AssemblyLinearVelocity=Vector3.new(hrp.AssemblyLinearVelocity.X,130,hrp.AssemblyLinearVelocity.Z)
            end) then hrp.Velocity=Vector3.new(hrp.Velocity.X,130,hrp.Velocity.Z) end
        end)
    end
end)

-- ── Heartbeat ─────────────────────────────────────────────────────────────────
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
        local c=player.Character; local r2=c and c:FindFirstChild("HumanoidRootPart")
        local hd=c and c:FindFirstChild("Head")
        if root and r2 then
            local dist=math.floor((root.Position-r2.Position).Magnitude)
            local hm=c:FindFirstChildOfClass("Humanoid")
            local hp=hm and math.floor(hm.Health) or 0
            local mhp=hm and math.floor(hm.MaxHealth) or 100
            data.il.Text=dist.."m "..hp.."/"..mhp
            data.nl.TextColor3=hp<=0 and Color3.fromRGB(90,90,90)
                or dist<20 and Color3.fromRGB(255,55,55)
                or dist<60 and Color3.fromRGB(255,185,0)
                or Color3.fromRGB(255,255,255)
            data.il.TextColor3=hp<=0 and Color3.fromRGB(90,90,90) or Color3.fromRGB(85,180,85)
            if espOn and hd then showESP(player.Name,hd.Position+Vector3.new(0,2.5,0),player.Name,hp,mhp,dist,true)
            elseif not espOn then hideESP(player.Name) end
        else
            data.il.Text="offline"
            data.nl.TextColor3=Color3.fromRGB(115,115,115); data.il.TextColor3=Color3.fromRGB(70,70,70)
            hideESP(player.Name)
        end
    end
    if count~=lastCount then
        pListFr.CanvasSize=UDim2.new(0,0,0,count*25); lastCount=count
    end
end)
