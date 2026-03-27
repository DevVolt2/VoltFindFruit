-- Volt Find Fruit Script v4
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace    = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService  = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local RS        = ReplicatedStorage
local LP        = Player
local WS        = Workspace

-- ==================== CONFIGURAÇÕES GLOBAIS ====================
getgenv().Config = {
    -- Arma usada no Auto Factory e Auto Raid Castle
    -- Opcoes: "Melee", "Sword", ou qualquer ToolTip de arma
    Weapon = "Melee",

    -- Tempo (em segundos) sem fruta no servidor antes de dar Hop
    HopTime = 3,

    -- Liga/desliga o Auto Collect Fruit
    AutoCollectFruit = true,

    -- Liga/desliga o Auto Factory (Sea 2)
    AutoFactory = false,

    -- Liga/desliga o Auto Raid Castle (Sea 3)
    AutoRaidCastle = false,
}

-- Compatibilidade interna (o codigo usa essas variaveis)
getgenv().ACF             = getgenv().Config.AutoCollectFruit
getgenv().GAutoFactory    = getgenv().Config.AutoFactory
getgenv().GAutoRaidCastle = getgenv().Config.AutoRaidCastle
getgenv().VoltWeapon      = getgenv().Config.Weapon

-- Sincroniza Config -> getgenv em tempo real
task.spawn(function()
    while task.wait(0.5) do
        getgenv().ACF             = getgenv().Config.AutoCollectFruit
        getgenv().GAutoFactory    = getgenv().Config.AutoFactory
        getgenv().GAutoRaidCastle = getgenv().Config.AutoRaidCastle
        getgenv().VoltWeapon      = getgenv().Config.Weapon
    end
end)

AutoRF = true
AutoSF = true
TweenSpeed = 350

-- ==================== SISTEMA DE TEMPO PERSISTENTE ====================
local TIME_FILE   = "Volt Find Fruit.txt"
local savedTime   = 0
if isfile and isfile(TIME_FILE) then
    savedTime = tonumber(readfile(TIME_FILE)) or 0
end
local sessionStart = os.time()

local function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function GetTotalTime()
    return savedTime + (os.time() - sessionStart)
end

-- ==================== SISTEMA DE SAVE/LOAD ====================
local _VoltFolder = "Volt Find Fruit"
local _VoltPath   = _VoltFolder .. "/Settings.json"
if makefolder and not isfolder(_VoltFolder) then makefolder(_VoltFolder) end
_G.VoltSaveData = {}

local function LoadSettings()
    if isfile and isfile(_VoltPath) then
        local ok, result = pcall(function()
            return HttpService:JSONDecode(readfile(_VoltPath))
        end)
        if ok and type(result) == "table" then _G.VoltSaveData = result end
    end
end

local function GetSetting(name, default)
    return _G.VoltSaveData[name] ~= nil and _G.VoltSaveData[name] or default
end

LoadSettings()

-- ==================== NOTIFICAÇÃO ====================
local function ShowNotification(title, message, duration)
    local gui   = Instance.new("ScreenGui")
    gui.Name    = "VoltNotification"
    gui.ResetOnSpawn  = false
    gui.ZIndexBehavior= Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder  = 999
    local frame = Instance.new("Frame")
    frame.Size  = UDim2.new(0,350,0,70)
    frame.Position = UDim2.new(0.5,-175,0,-80)
    frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    frame.BorderSizePixel  = 0
    frame.ZIndex = 1000
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)
    local t = Instance.new("TextLabel", frame)
    t.Size=UDim2.new(1,-20,0,25) t.Position=UDim2.new(0,10,0,8) t.BackgroundTransparency=1
    t.Font=Enum.Font.GothamBold t.Text=title t.TextColor3=Color3.fromRGB(255,100,100)
    t.TextSize=16 t.TextXAlignment=Enum.TextXAlignment.Left t.ZIndex=1001
    local m2 = Instance.new("TextLabel", frame)
    m2.Size=UDim2.new(1,-20,0,22) m2.Position=UDim2.new(0,10,0,38) m2.BackgroundTransparency=1
    m2.Font=Enum.Font.Gotham m2.Text=message m2.TextColor3=Color3.fromRGB(255,255,255)
    m2.TextSize=15 m2.TextXAlignment=Enum.TextXAlignment.Left m2.ZIndex=1001
    gui.Parent = PlayerGui
    frame:TweenPosition(UDim2.new(0.5,-175,0,5), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, 0.3, true)
    task.delay(duration or 3, function()
        frame:TweenPosition(UDim2.new(0.5,-175,0,-80), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.3, true,
            function() task.wait(0.1); gui:Destroy() end)
    end)
end

-- ==================== INTERFACE ====================
local function CreateGUI()
    if PlayerGui:FindFirstChild("VoltFindFruitGUI") then
        PlayerGui:FindFirstChild("VoltFindFruitGUI"):Destroy()
    end

    -- Remove blur antigo se existir
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("BlurEffect") and obj.Name == "VoltFruitBlur" then obj:Destroy() end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name            = "VoltFindFruitGUI"
    gui.ResetOnSpawn    = false
    gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset  = true

    -- ── Blur de fundo (estilo Night Hub da imagem) ──
    local blur = Instance.new("BlurEffect")
    blur.Name   = "VoltFruitBlur"
    blur.Size   = 20
    blur.Parent = Lighting

    -- ── Fundo escuro semi-transparente sobre a tela ──
    local bg = Instance.new("Frame")
    bg.Name               = "BG"
    bg.Size               = UDim2.new(1, 0, 1, 0)
    bg.Position           = UDim2.new(0, 0, 0, 0)
    bg.BackgroundColor3   = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.45
    bg.BorderSizePixel    = 0
    bg.ZIndex             = 1
    bg.Parent             = gui

    -- ── Título VOLT FIND FRUIT — movido para cima (0.35) ──
    local title = Instance.new("TextLabel")
    title.Name              = "Title"
    title.Size              = UDim2.new(1, 0, 0, 80)
    title.Position          = UDim2.new(0, 0, 0.35, 0)   -- um pouco mais alto
    title.BackgroundTransparency = 1
    title.Font              = Enum.Font.GothamBlack
    title.Text              = "VOLT FIND FRUIT"
    title.TextColor3        = Color3.fromRGB(255, 255, 255)
    title.TextSize          = 58
    -- Sem sombreamento
    title.TextStrokeTransparency = 1
    title.ZIndex            = 5
    title.Parent            = gui

    -- ── Time Lapse — logo abaixo do título ──
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name             = "TimerLabel"
    timerLabel.Size             = UDim2.new(1, 0, 0, 28)
    timerLabel.Position         = UDim2.new(0, 0, 0.35, 86)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font             = Enum.Font.Gotham
    timerLabel.Text             = "Time Lapse: 00:00:00"
    timerLabel.TextColor3       = Color3.fromRGB(255, 255, 255)
    timerLabel.TextSize         = 20
    timerLabel.TextStrokeTransparency = 0.3
    timerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    timerLabel.ZIndex           = 5
    timerLabel.Parent           = gui

    gui.Parent = PlayerGui
    return gui, timerLabel
end

-- ==================== DETECÇÃO DE SEA ====================
World1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089

local function GetSea()
    return World1 and 1 or World2 and 2 or World3 and 3 or 1
end

-- ==================== BYPASS TELEPORT ====================
local function CheckNearestTeleporter(aI)
    local vcspos = typeof(aI) == "CFrame" and aI.Position or aI
    local sea = GetSea()
    local TableLocations = {}
    if sea == 3 then
        TableLocations = {
            ["Mansion"]           = Vector3.new(-12471, 374,   -7551),
            ["Hydra"]             = Vector3.new( 5659,  1013,   -341),
            ["Castle On The Sea"] = Vector3.new(-5092,  315,  -3130),
            ["Floating Turtle"]   = Vector3.new(-12001, 332,  -8861),
            ["Beautiful Pirate"]  = Vector3.new( 5319,   23,    -93),
        }
    elseif sea == 2 then
        TableLocations = {
            ["Flamingo Mansion"]  = Vector3.new( -317,  331,    597),
            ["Flamingo Room"]     = Vector3.new( 2283,   15,    867),
            ["Cursed Ship"]       = Vector3.new(  923,  125,  32853),
            ["Zombie Island"]     = Vector3.new(-6509,   83,   -133),
        }
    else
        TableLocations = {
            ["Sky Island 1"]                = Vector3.new(-4652,  873, -1754),
            ["Sky Island 2"]                = Vector3.new(-7895, 5547,  -380),
            ["Under Water Island"]          = Vector3.new(61164,    5,  1820),
            ["Under Water Island Entrance"] = Vector3.new( 3865,    5, -1926),
        }
    end
    local bestPos, bestDist = nil, math.huge
    for _, v in pairs(TableLocations) do
        local d = (v - vcspos).Magnitude
        if d < bestDist then bestDist = d; bestPos = v end
    end
    return bestPos
end

local function requestEntrance(pos)
    pcall(function() RS.Remotes.CommF_:InvokeServer("requestEntrance", pos) end)
    local c   = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y + 50, hrp.Position.Z) end
    task.wait(0.5)
end

-- Tween management (AT = tween, FC = heartbeat fixo, GT = move tween, HC = hb move)
local AT, FC, GT, HC = nil, nil, nil, nil
local CBP = nil

local function SF()
    if FC then FC:Disconnect(); FC = nil end
    CBP = nil
end
local function SH()
    if HC then HC:Disconnect(); HC = nil end
end
local function SAT()
    if AT then AT:Cancel(); AT = nil end
    SF(); SH()
    if GT then GT:Cancel(); GT = nil end
    getgenv().TweenCompleted = false
end

-- DAC: desativa colisão do personagem
local function DAC(char)
    if not char then return end
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

-- IFA: retorna true se qualquer farm estiver ativo
local function IFA()
    return getgenv().ACF or getgenv().GAutoFactory or getgenv().GAutoRaidCastle
end

-- TF25: Tween até 25 studs acima do mob e trava lá
local function TF25(hrp, tHRP, spd)
    if not hrp or not tHRP then return end
    spd = spd or TweenSpeed
    if AT then AT:Cancel(); AT = nil end
    SF()
    getgenv().TweenCompleted = false
    local c = LP.Character
    if c then DAC(c) end
    local tCF  = tHRP.CFrame * CFrame.new(0, 25, 0)
    local dist = (hrp.Position - tHRP.Position).Magnitude
    FC = RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then SF(); return end
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    AT = TweenService:Create(hrp, TweenInfo.new(math.max(dist/spd, 0.05), Enum.EasingStyle.Linear), {CFrame=tCF})
    AT:Play()
    AT.Completed:Once(function()
        getgenv().TweenCompleted = true
        local staticCF = hrp.CFrame
        CBP = staticCF * CFrame.new(0, -25, 0)
        if FC then FC:Disconnect(); FC = nil end
        FC = RunService.Heartbeat:Connect(function()
            if not IFA() then SF(); return end
            local ch  = LP.Character
            if not ch then SF(); return end
            local cHRP = ch:FindFirstChild("HumanoidRootPart")
            if not cHRP then SF(); return end
            DAC(ch)
            cHRP.AssemblyLinearVelocity  = Vector3.zero
            cHRP.AssemblyAngularVelocity = Vector3.zero
            cHRP.CFrame = staticCF
        end)
    end)
end

-- TTG: Tween suave até uma CFrame
local function TTG(hrp, tCF, spd)
    if not hrp then return end
    spd = spd or TweenSpeed
    SF(); SH()
    if GT then GT:Cancel(); GT = nil end
    if AT then AT:Cancel(); AT = nil end
    getgenv().TweenCompleted = false
    local c = LP.Character
    if c then DAC(c) end
    local dist = (hrp.Position - tCF.Position).Magnitude
    GT = TweenService:Create(hrp, TweenInfo.new(math.max(dist/spd, 0.05), Enum.EasingStyle.Linear), {CFrame=tCF})
    GT:Play()
    HC = RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then SH(); return end
        if not IFA() then if GT then GT:Cancel(); GT = nil end; SH(); return end
        local ch = LP.Character
        if ch then DAC(ch) end
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    while GT and GT.PlaybackState == Enum.PlaybackState.Playing and IFA() do task.wait(0.05) end
    if GT then GT:Cancel(); GT = nil end
    SH()
    if IFA() then getgenv().TweenCompleted = true end
end

-- Bypass + Tween até o destino (para Auto Collect de frutas)
-- Se a fruta está dentro de 300 studs (mesma ilha), só tween direto sem bypass.
-- Se está longe, espera 1s e faz requestEntrance antes de tweenar.
local _activeTween = nil
local _tweenHB     = nil
local SAME_ISLAND_RADIUS = 300  -- raio considerado "mesma ilha", sem precisar de bypass

local function TweenDirectToFruit(hrp, targetPos)
    if _activeTween then pcall(function() _activeTween:Cancel() end); _activeTween = nil end
    if _tweenHB then _tweenHB:Disconnect(); _tweenHB = nil end
    local c = LP.Character
    if c then
        for _, p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
    end
    local dist = (targetPos - hrp.Position).Magnitude
    local dur  = math.max(dist / TweenSpeed, 0.05)
    _activeTween = TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame=CFrame.new(targetPos)})
    _tweenHB = RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then if _tweenHB then _tweenHB:Disconnect(); _tweenHB=nil end return end
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    _activeTween:Play()
    _activeTween.Completed:Wait()
    if _tweenHB then _tweenHB:Disconnect(); _tweenHB = nil end
    _activeTween = nil
end

local function BypassAndTweenToFruit(targetCF)
    local c   = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local targetPos = typeof(targetCF) == "CFrame" and targetCF.Position or targetCF
    local dist = (targetPos - hrp.Position).Magnitude

    -- Fruta na mesma ilha (dentro do raio): só tween direto, sem bypass
    if dist <= SAME_ISLAND_RADIUS then
        TweenDirectToFruit(hrp, targetPos)
        return
    end

    -- Fruta longe: espera 1s antes do bypass
    task.wait(1)
    -- Revalida character após a espera
    c   = LP.Character
    hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local nearestIslandPos = CheckNearestTeleporter(targetPos)
    if nearestIslandPos then requestEntrance(nearestIslandPos) end
    c   = LP.Character
    hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    TweenDirectToFruit(hrp, targetPos)
end

-- ==================== EQUIP WEAPON ====================
local function EquipWeapon(toolName)
    local char    = LP.Character or LP.CharacterAdded:Wait()
    local backpack = LP.Backpack
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == toolName then
            tool.Parent = char
            return
        end
    end
end

-- EQ: equipa Melee pelo ToolTip (estilo Volt Hub), só quando Factory ou RaidCastle ativos
local function EQ()
    if not (getgenv().GAutoFactory or getgenv().GAutoRaidCastle) then return end
    local wtype = getgenv().VoltWeapon or "Melee"
    for _, v in ipairs(LP.Backpack:GetChildren()) do
        if v:IsA("Tool") and v.ToolTip == wtype then
            EquipWeapon(v.Name)
            return
        end
    end
end

-- RA / RH (RegisterAttack / RegisterHit remotes)
local RA, RH
task.spawn(function()
    task.wait(2)
    local M = RS:WaitForChild("Modules", 5)
    if M then
        local N = M:FindFirstChild("Net")
        if N then
            RA = N:FindFirstChild("RE/RegisterAttack")
            RH = N:FindFirstChild("RE/RegisterHit")
        end
    end
end)

-- ==================== AUTO TEAM ====================
getgenv().VoltTeam = getgenv().VoltTeam or "Pirates"

local function SetVoltTeam(teamName)
    getgenv().VoltTeam = teamName
    pcall(function() RS.Remotes.CommF_:InvokeServer("SetTeam", teamName) end)
    print("🏴 Time definido para: " .. teamName)
end

-- ==================== SERVER HOP ====================
local function Hop()
    while true do
        local ok, result = pcall(function()
            return game.HttpService:JSONDecode(
                game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId ..
                "/servers/Public?sortOrder=Asc&limit=100")
            )
        end)
        if ok and result and result.data then
            for _, s in pairs(result.data) do
                if s.id ~= game.JobId and tonumber(s.playing) < tonumber(s.maxPlayers) then
                    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, s.id, game.Players.LocalPlayer)
                    task.wait(5)  -- aguarda o teleporte ocorrer
                end
            end
        end
        task.wait(1)
    end
end

-- ==================== DETECÇÃO DE FRUTAS ====================
-- Declarado ANTES do loop de Hop para que AnyFruitInServer() e isCollecting estejam disponíveis
local isCollecting = false
local FruitNames = {"Bomb-Bomb","Spike-Spike","Chop-Chop","Spring-Spring","Kilo-Kilo","Smoke-Smoke","Flame-Flame","Ice-Ice","Sand-Sand","Dark-Dark","Ghost-Ghost","Magma-Magma","Quake-Quake","Buddha-Buddha","Love-Love","Spider-Spider","Phoenix-Phoenix","Portal-Portal","Rumble-Rumble","Pain-Pain","Blizzard-Blizzard","Gravity-Gravity","Dough-Dough","Shadow-Shadow","Venom-Venom","Control-Control","Spirit-Spirit","Dragon-Dragon","Leopard-Leopard"}
local FruitSet = {}
for _, name in ipairs(FruitNames) do FruitSet[name] = true end

local function IsFruitModel(m)
    if not m or not m:IsA("Model") then return false end
    return FruitSet[m.Name] or m.Name:find("Fruit") ~= nil
end

local function AnyFruitInServer()
    for _, m in ipairs(WS:GetChildren()) do if IsFruitModel(m) then return true end end
    return false
end

-- SetTeam automático — libera sistema após envio
local _systemReady = false
task.spawn(function()
    local commF2 = RS:WaitForChild("Remotes", 10) and RS.Remotes:FindFirstChild("CommF_")
    if not LP.Team and commF2 then
        task.wait(3)
        pcall(function() commF2:InvokeServer("SetTeam", getgenv().VoltTeam) end)
    end
    task.wait(2) -- 2s de análise após SetTeam
    _systemReady = true
end)

getgenv().SetVoltTeam = SetVoltTeam



local function GetNearestFruit()
    local c   = LP.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest, minDist = nil, math.huge
    for _, m in ipairs(WS:GetChildren()) do
        if IsFruitModel(m) then
            local p = m:FindFirstChild("Handle") or m:FindFirstChildWhichIsA("BasePart")
            if p then
                local d = (hrp.Position - p.Position).Magnitude
                if d < minDist then minDist = d; nearest = p end
            end
        end
    end
    return nearest
end

-- ==================== ANTI-FALL ====================
RunService.Heartbeat:Connect(function()
    pcall(function()
        if getgenv().ACF and LP.Character then
            local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position.Y < -100 then
                hrp.CFrame = CFrame.new(-5058,314,-3039)
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end)
end)

-- ==================== NOCLIP ====================
local NoClipConnection = nil
local function EnableNoClip()
    if NoClipConnection then return end
    NoClipConnection = RunService.Stepped:Connect(function()
        pcall(function()
            if IFA() then
                local char = LP.Character
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end)
    end)
end
local function DisableNoClip()
    if NoClipConnection then NoClipConnection:Disconnect(); NoClipConnection = nil end
    pcall(function()
        local char = LP.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end)
end
EnableNoClip()

-- ==================== AUTO BUY FRUIT ====================
local CommF_ = RS:WaitForChild("Remotes"):WaitForChild("CommF_")
task.spawn(function()
    while task.wait(0.25) do
        pcall(function() if AutoRF and CommF_ then CommF_:InvokeServer("Cousin","Buy") end end)
    end
end)

-- ==================== AUTO STORE (máx 3 tentativas) ====================
local storeFruitAttempts = {}

local function UpdateStoreFruit()
    pcall(function()
        for _, t in pairs(LP.Backpack:GetChildren()) do
            local e = t:FindFirstChild("EatRemote",true)
            if e then
                local key = t.Name
                storeFruitAttempts[key] = storeFruitAttempts[key] or 0
                if storeFruitAttempts[key] < 3 then
                    storeFruitAttempts[key] = storeFruitAttempts[key] + 1
                    RS.Remotes.CommF_:InvokeServer("StoreFruit", e.Parent:GetAttribute("OriginalName"), LP.Backpack:FindFirstChild(t.Name))
                end
            end
        end
        local c = LP.Character
        if c then
            for _, t in pairs(c:GetChildren()) do
                if t:IsA("Tool") then
                    local e = t:FindFirstChild("EatRemote",true)
                    if e then
                        local key = t.Name .. "_equipped"
                        storeFruitAttempts[key] = storeFruitAttempts[key] or 0
                        if storeFruitAttempts[key] < 3 then
                            storeFruitAttempts[key] = storeFruitAttempts[key] + 1
                            RS.Remotes.CommF_:InvokeServer("StoreFruit", e.Parent:GetAttribute("OriginalName"), c:FindFirstChild(t.Name))
                        end
                    end
                end
            end
        end
    end)
end

task.spawn(function()
    while task.wait(2) do
        pcall(function()
            local toRemove = {}
            for key in pairs(storeFruitAttempts) do
                local toolName = key:gsub("_equipped","")
                if not LP.Backpack:FindFirstChild(toolName) and not (LP.Character and LP.Character:FindFirstChild(toolName)) then
                    table.insert(toRemove, key)
                end
            end
            for _, k in ipairs(toRemove) do storeFruitAttempts[k] = nil end
        end)
    end
end)

task.spawn(function()
    while task.wait(0.5) do if AutoSF then UpdateStoreFruit() end end
end)

-- ==================== AUTO COLLECT FRUIT (Bypass → Tween) ====================
local fruitsCollectedThisSession = 0

local function HasFruit()
    for _, t in pairs(LP.Backpack:GetChildren()) do if t:FindFirstChild("EatRemote",true) then return true end end
    local c = LP.Character
    if c then for _, t in pairs(c:GetChildren()) do if t:IsA("Tool") and t:FindFirstChild("EatRemote",true) then return true end end end
    return false
end

local _hopCooldown = false

task.spawn(function()
    while task.wait(0.3) do
        pcall(function()
            if not _systemReady then return end
            if not getgenv().ACF then isCollecting=false; return end
            if isCollecting then return end
            if not AnyFruitInServer() then
                isCollecting=false
                if not _hopCooldown then
                    _hopCooldown = true
                    task.delay(getgenv().Config.HopTime, function()
                        task.spawn(Hop)
                        task.delay(getgenv().Config.HopTime, function() _hopCooldown = false end)
                    end)
                end
                return
            end
            isCollecting = true
            local fruitPart = GetNearestFruit()
            if not fruitPart then isCollecting=false; return end
            local c   = LP.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if not hrp then isCollecting=false; return end
            for _, part in pairs(c:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=false end end
            BypassAndTweenToFruit(fruitPart.CFrame)
            task.wait(0.2)
            local maxWait, waited, collected = 3, 0, false
            while waited < maxWait and fruitPart and fruitPart.Parent do
                task.wait(0.1); waited = waited + 0.1
                if HasFruit() or not fruitPart.Parent then collected=true; break end
            end
            if collected then fruitsCollectedThisSession = fruitsCollectedThisSession + 1 end
            isCollecting = false
        end)
    end
end)

-- ============================================================
-- AUTO FACTORY — Sea 2 — Tween até o Core, fica fixo lá e ataca
-- Toggle: getgenv().GAutoFactory = true / false
-- ============================================================
getgenv()._FactorySpawnCF = CFrame.new(296.386322, 73.2758331, -57.0976982)

-- Loop de ataque (RegisterHit)
task.spawn(function()
    while task.wait(0.1) do
        if not getgenv().GAutoFactory then continue end
        if not RA or not RH then continue end
        pcall(function()
            if not (WS.Map and WS.Map:FindFirstChild("Factory") and WS.Map.Factory:FindFirstChild("Core")) then return end
            local fTgts = {}
            for _, m in pairs(WS.Enemies:GetChildren()) do
                if m:FindFirstChild("Head") and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                    table.insert(fTgts, {m, m.Head})
                end
            end
            if #fTgts > 0 then
                RA:FireServer(0.1)
                RH:FireServer(fTgts[1][2], fTgts)
            end
        end)
    end
end)

-- Loop de movimento + fixação no Core
task.spawn(function()
    while task.wait(0.2) do
        if not getgenv().GAutoFactory then continue end
        pcall(function()
            local c   = LP.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChild("Humanoid")
            if not hrp or not hum then return end

            -- Respawn handling
            if hum.Health <= 0 then
                SAT()
                repeat task.wait() until LP.Character and LP.Character:FindFirstChild("Humanoid") and LP.Character.Humanoid.Health > 0
                task.wait(1); return
            end

            DAC(c)
            EQ() -- equipa weapon configurada

            if WS.Map and WS.Map:FindFirstChild("Factory") and WS.Map.Factory:FindFirstChild("Core") then
                -- Destino: Entrance da Factory (ou spawn padrão)
                local entranceCF = (WS.Map.Factory:FindFirstChild("Entrance") and WS.Map.Factory.Entrance.CFrame)
                    or getgenv()._FactorySpawnCF

                if (hrp.Position - entranceCF.Position).Magnitude > 30 then
                    -- Bypass Teleport
                    local nearPos = CheckNearestTeleporter(entranceCF.Position)
                    if nearPos then requestEntrance(nearPos); task.wait(0.3) end
                    -- Re-lê após teleporte
                    c   = LP.Character
                    hrp = c and c:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    -- Tween até o Core
                    TTG(hrp, entranceCF, TweenSpeed)
                    task.wait(0.1)
                end

                if not getgenv().GAutoFactory then return end
                c   = LP.Character
                hrp = c and c:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                -- Fica fixo no Core via Heartbeat
                local staticCF = entranceCF
                getgenv().TweenCompleted = true
                if FC then FC:Disconnect(); FC = nil end
                FC = RunService.Heartbeat:Connect(function()
                    if not getgenv().GAutoFactory then SF(); return end
                    local ch  = LP.Character
                    local cHRP = ch and ch:FindFirstChild("HumanoidRootPart")
                    if not ch or not cHRP then SF(); return end
                    DAC(ch)
                    cHRP.AssemblyLinearVelocity  = Vector3.zero
                    cHRP.AssemblyAngularVelocity = Vector3.zero
                    cHRP.CFrame = staticCF
                end)

                -- Aguarda Factory acabar ou toggle desligar
                while getgenv().GAutoFactory
                    and WS.Map and WS.Map:FindFirstChild("Factory")
                    and WS.Map.Factory:FindFirstChild("Core") do
                    task.wait(0.15)
                end
                SF(); getgenv().TweenCompleted = false
            else
                -- Factory ainda não spawnou: vai pro spawn e aguarda
                SF(); getgenv().TweenCompleted = false
                c   = LP.Character
                hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = getgenv()._FactorySpawnCF end
                local fWait = 0
                repeat
                    task.wait(2); fWait = fWait + 2
                    if not getgenv().GAutoFactory then return end
                until (WS.Map and WS.Map:FindFirstChild("Factory") and WS.Map.Factory:FindFirstChild("Core"))
                    or fWait >= 300
            end
        end)
    end
end)

-- ============================================================
-- AUTO RAID CASTLE — Sea 3 — TF25 (25 studs acima do mob) e ataca
-- Toggle: getgenv().GAutoRaidCastle = true / false
-- ============================================================
getgenv()._RaidCastleCF  = CFrame.new(-5092, 315, -3130)
getgenv()._RaidNames     = {"Raider","Mercenary","Galley Pirate","Galley Captain"}

local function GetRaidMob()
    for _, enemy in pairs(WS.Enemies:GetChildren()) do
        for _, rName in ipairs(getgenv()._RaidNames) do
            if enemy.Name == rName
               and enemy:FindFirstChild("HumanoidRootPart")
               and enemy:FindFirstChild("Humanoid")
               and enemy.Humanoid.Health > 0 then
                return enemy, rName
            end
        end
    end
    return nil, nil
end

-- Loop de ataque (RegisterHit) para Raid Castle
task.spawn(function()
    while task.wait(0.1) do
        if not getgenv().GAutoRaidCastle then continue end
        if not RA or not RH then continue end
        pcall(function()
            local rTgts = {}
            for _, m in pairs(WS.Enemies:GetChildren()) do
                if m:FindFirstChild("Head") and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then
                    for _, rName in ipairs(getgenv()._RaidNames) do
                        if m.Name == rName then table.insert(rTgts, {m, m.Head}); break end
                    end
                end
            end
            if #rTgts > 0 then
                RA:FireServer(0.1)
                RH:FireServer(rTgts[1][2], rTgts)
            end
        end)
    end
end)

-- Loop de movimento + TF25 para Raid Castle
task.spawn(function()
    while task.wait(0.15) do
        if not getgenv().GAutoRaidCastle then continue end
        pcall(function()
            local c   = LP.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChild("Humanoid")
            if not hrp or not hum then return end

            -- Respawn handling
            if hum.Health <= 0 then
                SAT()
                repeat task.wait() until LP.Character and LP.Character:FindFirstChild("Humanoid") and LP.Character.Humanoid.Health > 0
                task.wait(1); return
            end

            DAC(c)
            hum:ChangeState(11) -- Enum.HumanoidStateType.Running
            EQ() -- equipa weapon configurada

            local rMob, rName = GetRaidMob()

            if rMob then
                -- Se muito longe do Raid Castle, faz bypass
                if (hrp.Position - getgenv()._RaidCastleCF.Position).Magnitude > 2000 then
                    local nearPos = CheckNearestTeleporter(getgenv()._RaidCastleCF.Position)
                    if nearPos then
                        requestEntrance(nearPos)
                        task.wait(0.5)
                    else
                        pcall(function() RS.Remotes.CommF_:InvokeServer("requestEntrance", getgenv()._RaidCastleCF.Position) end)
                        c   = LP.Character
                        hrp = c and c:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y+50, hrp.Position.Z) end
                        task.wait(0.5)
                    end
                    c   = LP.Character
                    hrp = c and c:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                end

                if not getgenv().GAutoRaidCastle then return end

                -- TF25: posiciona 25 studs acima do mob
                TF25(hrp, rMob.HumanoidRootPart, TweenSpeed)
                local rWaitT = 0
                repeat task.wait(0.05); rWaitT = rWaitT + 0.05
                until getgenv().TweenCompleted or rWaitT >= 15 or not getgenv().GAutoRaidCastle

                if not getgenv().GAutoRaidCastle then SAT(); return end

                -- Fica atacando enquanto o mob vive
                while rMob.Parent and rMob:FindFirstChild("Humanoid")
                    and rMob.Humanoid.Health > 0
                    and getgenv().GAutoRaidCastle do
                    c   = LP.Character
                    hrp = c and c:FindFirstChild("HumanoidRootPart")
                    if not c or not hrp then SAT(); break end
                    if c:FindFirstChild("Humanoid") and c.Humanoid.Health <= 0 then SAT(); break end
                    -- Reposiciona se afastou demais
                    if rMob:FindFirstChild("HumanoidRootPart")
                       and (hrp.Position - rMob.HumanoidRootPart.Position).Magnitude > 60 then
                        TF25(hrp, rMob.HumanoidRootPart, TweenSpeed)
                    end
                    task.wait(0.05)
                end
                SAT()
            else
                -- Sem mob: vai para o Raid Castle e aguarda
                SF(); getgenv().TweenCompleted = false
                c   = LP.Character
                hrp = c and c:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                if (hrp.Position - getgenv()._RaidCastleCF.Position).Magnitude > 500 then
                    local nearPos = CheckNearestTeleporter(getgenv()._RaidCastleCF.Position)
                    if nearPos then
                        requestEntrance(nearPos); task.wait(0.5)
                    else
                        pcall(function() RS.Remotes.CommF_:InvokeServer("requestEntrance", getgenv()._RaidCastleCF.Position) end)
                        c   = LP.Character
                        hrp = c and c:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y+50, hrp.Position.Z) end
                        task.wait(0.5)
                    end
                    c   = LP.Character
                    hrp = c and c:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    TTG(hrp, getgenv()._RaidCastleCF, TweenSpeed)
                end
                task.wait(2)
            end
        end)
    end
end)

-- ==================== INICIALIZAÇÃO ====================
local ScreenGui, TimeDisplay = CreateGUI()

-- Atualiza UI + salva tempo a cada segundo
task.spawn(function()
    while task.wait(1) do
        local total = GetTotalTime()
        if writefile then writefile(TIME_FILE, tostring(total)) end
        if TimeDisplay and TimeDisplay.Parent then
            TimeDisplay.Text = "Time Lapse: " .. FormatTime(total)
        end
    end
end)

print("✅ Volt Find Fruit v4 carregado!")
print("🌊 Sea: " .. GetSea())
print("🏴 Time: " .. getgenv().VoltTeam)
print("⏱️ Tempo persistente: " .. TIME_FILE)
print("🍎 Auto Collect Fruit: " .. tostring(getgenv().Config.AutoCollectFruit))
print("⏳ Hop Time: " .. tostring(getgenv().Config.HopTime) .. "s")
print("🏭 Auto Factory: " .. tostring(getgenv().Config.AutoFactory))
print("🏰 Auto Raid Castle: " .. tostring(getgenv().Config.AutoRaidCastle))
print("⚔️ Weapon: " .. getgenv().Config.Weapon)
print("📋 Edite getgenv().Config para alterar as configuracoes em tempo real")
