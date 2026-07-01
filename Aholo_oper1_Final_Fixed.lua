local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Camera     = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Teams      = game:GetService("Teams")

-- ============================================================
-- GLOBAL VARS
-- ============================================================
getgenv().HeadSize         = 6
getgenv().HeadTransparency = 0.5
getgenv().HeadHitboxOn     = false
getgenv().HeadTeamCheck    = false
getgenv().HeadFriendOnly   = false

getgenv().ESP_Outline = false
getgenv().ESP_Tracer  = false
getgenv().ESP_Info    = false
getgenv().ESP_HP      = false

getgenv().AuraOn         = false
getgenv().AuraRange      = 8
getgenv().AuraTeamCheck  = false
getgenv().AuraFriendOnly = false
getgenv().AuraMode       = "tool"

getgenv().TargetPlayers   = true
getgenv().TargetNPC       = false
getgenv().NPCHostileOnly  = false
getgenv().NPCFriendlyOnly = false

-- ADVANCED TEAM CHECK (Head)
getgenv().AdvTeamCheck_Enabled = false
getgenv().AdvTeamCheck_Teams   = {}

-- ADVANCED TEAM CHECK (Aura)
getgenv().AdvAuraTeamCheck_Enabled = false
getgenv().AdvAuraTeamCheck_Teams   = {}

-- KEYBINDS (tự quản lý, không dùng Rayfield CreateKeybind)
getgenv().Keybind_Hitbox = Enum.KeyCode.F
getgenv().Keybind_Aura   = Enum.KeyCode.G
getgenv().Keybind_GUI    = Enum.KeyCode.Insert

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

local npcCache  = {}
local lastScan  = 0
local SCAN_RATE = 2

-- ============================================================
-- TEAM SCANNING
-- ============================================================
local function getAllTeamNames()
    local names = {}
    for _, team in ipairs(Teams:GetTeams()) do
        table.insert(names, team.Name)
    end
    return names
end

local function refreshTeamList()
    local names = getAllTeamNames()
    for _, name in ipairs(names) do
        if getgenv().AdvTeamCheck_Teams[name] == nil then
            getgenv().AdvTeamCheck_Teams[name] = true
        end
        if getgenv().AdvAuraTeamCheck_Teams[name] == nil then
            getgenv().AdvAuraTeamCheck_Teams[name] = true
        end
    end
    return names
end

-- ============================================================
-- NPC
-- ============================================================
local function refreshNPCs()
    npcCache = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hum and hrp then
                local isPC = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == obj then isPC = true; break end
                end
                if not isPC then table.insert(npcCache, obj) end
            end
        end
    end
end

local TARGET_NAMES = {"target","aggrotarget","attacktarget","currenttarget","targetplayer","victim"}

local function getNPCAlign(model)
    for _, a in ipairs({"Hostile","IsHostile","Enemy","IsEnemy","Aggressive","hostile","enemy"}) do
        if model:GetAttribute(a) == true then return "hostile" end
    end
    for _, a in ipairs({"Friendly","IsFriendly","Ally","IsAlly","friendly","ally"}) do
        if model:GetAttribute(a) == true then return "friendly" end
    end
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("ObjectValue") and desc.Value then
            local n = desc.Name:lower()
            for _, tn in ipairs(TARGET_NAMES) do
                if n == tn then
                    for _, p in ipairs(Players:GetPlayers()) do
                        local chr = p.Character
                        if chr and (desc.Value == chr or desc.Value:IsDescendantOf(chr)) then
                            return "hostile"
                        end
                    end
                end
            end
        end
        if desc:IsA("BoolValue") then
            local n = desc.Name:lower()
            if (n=="hostile" or n=="enemy" or n=="aggressive") and desc.Value then return "hostile" end
            if (n=="friendly" or n=="ally") and desc.Value then return "friendly" end
        end
    end
    return "unknown"
end

local function shouldTargetNPC(model)
    if not getgenv().TargetNPC then return false end
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if getgenv().NPCHostileOnly or getgenv().NPCFriendlyOnly then
        local align = getNPCAlign(model)
        if getgenv().NPCHostileOnly  and align ~= "hostile"  then return false end
        if getgenv().NPCFriendlyOnly and align ~= "friendly" then return false end
    end
    return true
end

local function getNPCColor(model)
    local align = getNPCAlign(model)
    if align == "hostile"  then return Color3.fromRGB(255, 60, 60) end
    if align == "friendly" then return Color3.fromRGB(60, 220, 60) end
    return Color3.fromRGB(255, 160, 0)
end

-- ============================================================
-- TARGET LOGIC (HEAD)
-- ============================================================
local function shouldTarget(v)
    if v == LocalPlayer then return false end
    if not getgenv().TargetPlayers then return false end

    -- Advanced Team Check
    if getgenv().AdvTeamCheck_Enabled then
        if v.Team then
            local teamName = v.Team.Name
            return getgenv().AdvTeamCheck_Teams[teamName] == true
        end
        return true
    end

    if getgenv().HeadTeamCheck and LocalPlayer.Team == v.Team then return false end
    if getgenv().HeadFriendOnly and LocalPlayer:IsFriendsWith(v.UserId) then return false end
    return true
end

-- ============================================================
-- TARGET LOGIC (AURA)
-- ============================================================
local function auraTarget(v)
    if v == LocalPlayer then return false end

    if getgenv().AdvAuraTeamCheck_Enabled then
        if v.Team then
            local teamName = v.Team.Name
            return getgenv().AdvAuraTeamCheck_Teams[teamName] == true
        end
        return true
    end

    if getgenv().AuraTeamCheck and LocalPlayer.Team == v.Team then return false end
    if getgenv().AuraFriendOnly and LocalPlayer:IsFriendsWith(v.UserId) then return false end
    return true
end

local function getTeamColor(v)
    if v.Team then return v.Team.TeamColor.Color end
    return Color3.fromRGB(255, 50, 50)
end

-- ============================================================
-- APPLY HEADS
-- ============================================================
local function applyHeads()
    for _, v in ipairs(Players:GetPlayers()) do
        if v == LocalPlayer or not v.Character then continue end
        local head = v.Character:FindFirstChild("Head")
        if not head then continue end
        if getgenv().HeadHitboxOn and shouldTarget(v) then
            head.Size = Vector3.new(getgenv().HeadSize, getgenv().HeadSize, getgenv().HeadSize)
            head.Transparency = getgenv().HeadTransparency
            head.Massless = true; head.CanCollide = false
        else
            head.Size = Vector3.new(2, 1, 1)
            head.Transparency = 0; head.Massless = false; head.CanCollide = false
        end
    end
    for _, model in ipairs(npcCache) do
        if not model or not model.Parent then continue end
        local head = model:FindFirstChild("Head")
        if not head then continue end
        if getgenv().HeadHitboxOn and shouldTargetNPC(model) then
            head.Size = Vector3.new(getgenv().HeadSize, getgenv().HeadSize, getgenv().HeadSize)
            head.Transparency = getgenv().HeadTransparency
            head.Massless = true; head.CanCollide = false
        else
            head.Size = Vector3.new(2, 1, 1)
            head.Transparency = 0; head.Massless = false; head.CanCollide = false
        end
    end
end

RunService.RenderStepped:Connect(applyHeads)
RunService.RenderStepped:Connect(function()
    if tick() - lastScan >= SCAN_RATE then refreshNPCs(); lastScan = tick() end
end)

-- ============================================================
-- AURA
-- ============================================================
RunService.RenderStepped:Connect(function()
    if not getgenv().AuraOn then return end
    local chr = LocalPlayer.Character; if not chr then return end
    local inRange = false

    for _, v in ipairs(Players:GetPlayers()) do
        if not auraTarget(v) then continue end
        local vc = v.Character; if not vc then continue end
        local hum = vc:FindFirstChildOfClass("Humanoid")
        local hrp = vc:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp or hum.Health <= 0 then continue end
        if LocalPlayer:DistanceFromCharacter(hrp.Position) <= getgenv().AuraRange then
            inRange = true
            if getgenv().AuraMode == "tool" then
                local tool = chr:FindFirstChildOfClass("Tool")
                if tool and tool:FindFirstChild("Handle") then
                    tool:Activate()
                    for _, part in next, vc:GetChildren() do
                        if part:IsA("BasePart") then
                            firetouchinterest(tool.Handle, part, 0)
                            firetouchinterest(tool.Handle, part, 1)
                        end
                    end
                end
            end
        end
    end

    if getgenv().TargetNPC then
        for _, model in ipairs(npcCache) do
            if not shouldTargetNPC(model) then continue end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp and LocalPlayer:DistanceFromCharacter(hrp.Position) <= getgenv().AuraRange then
                inRange = true
                if getgenv().AuraMode == "tool" then
                    local tool = chr:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        tool:Activate()
                        for _, part in next, model:GetChildren() do
                            if part:IsA("BasePart") then
                                firetouchinterest(tool.Handle, part, 0)
                                firetouchinterest(tool.Handle, part, 1)
                            end
                        end
                    end
                end
            end
        end
    end

    if getgenv().AuraMode == "m1" and inRange then
        local tool = chr:FindFirstChildOfClass("Tool")
        if isMobile then
            if tool then pcall(function() tool:Activate() end) end
        else
            pcall(function() mouse1click() end)
        end
    end
end)

-- ============================================================
-- ESP - TỐI ƯU CHỐNG LAG
-- ============================================================
local espData = {}
local espConnections = {}

local function clearESP(key)
    local d = espData[key]
    if not d then return end
    for _, obj in pairs(d) do
        pcall(function()
            if typeof(obj) == "Instance" then
                obj:Destroy()
            else
                obj:Remove()
            end
        end)
    end
    espData[key] = nil
end

local function clearAllESP()
    for k in pairs(espData) do clearESP(k) end
end

local function newText(col)
    local t = Drawing.new("Text")
    t.Visible = false
    t.Color = col
    t.Size = 13
    t.Font = Drawing.Fonts.UI
    t.Outline = true
    t.OutlineColor = Color3.new(0, 0, 0)
    t.Center = true
    return t
end

local function newLine(col)
    local l = Drawing.new("Line")
    l.Visible = false
    l.Color = col
    l.Thickness = 1.2
    l.Transparency = 1
    return l
end

local function getBounds(model)
    local hrp  = model:FindFirstChild("HumanoidRootPart")
    local head = model:FindFirstChild("Head")
    if not hrp or not head then return nil end
    local top, onT = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5, 0))
    local bot, onB = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
    if not onT or not onB or top.Z <= 0 then return nil end
    return top, bot
end

-- Kiểm tra player còn sống và hợp lệ
local function isPlayerValid(v)
    if not v or v == LocalPlayer then return false end
    if not v.Parent then return false end
    local chr = v.Character
    if not chr then return false end
    local hum = chr:FindFirstChildOfClass("Humanoid")
    local hrp = chr:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end
    if hum.Health <= 0 then return false end
    return true
end

-- Kiểm tra NPC còn sống
local function isNPCValid(model)
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end
    if hum.Health <= 0 then return false end
    return true
end

-- Vẽ ESP cho 1 target
local function drawESP(key, model, col, nameStr, dist)
    if not espData[key] then espData[key] = {} end
    local d = espData[key]

    -- Highlight Outline
    if getgenv().ESP_Outline then
        if not d.hl or d.hl.Parent == nil then
            pcall(function()
                if d.hl then d.hl:Destroy() end
            end)
            local hl = Instance.new("Highlight")
            hl.FillTransparency = 1
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = workspace
            d.hl = hl
        end
        pcall(function()
            d.hl.Adornee = model
            d.hl.OutlineColor = col
        end)
    else
        if d.hl then
            pcall(function() d.hl:Destroy() end)
            d.hl = nil
        end
    end

    -- Kiểm tra bounds
    local top, bot = getBounds(model)
    if not top then
        -- Ẩn tất cả nếu không thấy
        for _, k2 in pairs({"tr","nm","di","hpt"}) do
            if d[k2] then
                pcall(function() d[k2].Visible = false end)
            end
        end
        return
    end

    local vp = Camera.ViewportSize
    local tb = Vector2.new(vp.X * 0.5, vp.Y)
    local cx = top.X
    local y1 = top.Y
    local y2 = bot.Y

    -- Tracer
    if getgenv().ESP_Tracer then
        if not d.tr then d.tr = newLine(col) end
        pcall(function()
            d.tr.Color = col
            d.tr.From = tb
            d.tr.To = Vector2.new(cx, y2)
            d.tr.Visible = true
        end)
    elseif d.tr then
        pcall(function() d.tr.Visible = false end)
    end

    -- Name + Distance
    local infoY = y1 - 16
    if getgenv().ESP_Info then
        if not d.nm then d.nm = newText(col) end
        if not d.di then d.di = newText(Color3.new(1, 1, 1)) end
        pcall(function()
            d.nm.Color = col
            d.nm.Text = nameStr
            d.nm.Position = Vector2.new(cx, infoY)
            d.nm.Visible = true
            d.di.Text = dist .. " m"
            d.di.Position = Vector2.new(cx, infoY + 13)
            d.di.Visible = true
        end)
    else
        if d.nm then pcall(function() d.nm.Visible = false end) end
        if d.di then pcall(function() d.di.Visible = false end) end
    end

    -- HP
    if getgenv().ESP_HP then
        local hum = model:FindFirstChildOfClass("Humanoid")
        local hp = hum and math.floor(hum.Health) or 0
        local maxHp = hum and math.max(math.floor(hum.MaxHealth), 1) or 100
        local pct = math.floor(hp / maxHp * 100)
        local r = math.floor(255 * (1 - pct / 100))
        local g = math.floor(255 * (pct / 100))
        local hpCol = Color3.fromRGB(r, g, 0)
        if not d.hpt then d.hpt = newText(hpCol) end
        pcall(function()
            d.hpt.Color = hpCol
            d.hpt.Text = hp .. " HP (" .. pct .. "%)"
            local hpY = getgenv().ESP_Info and (infoY + 26) or (infoY + 13)
            d.hpt.Position = Vector2.new(cx, hpY)
            d.hpt.Visible = true
        end)
    elseif d.hpt then
        pcall(function() d.hpt.Visible = false end)
    end
end

-- ============================================================
-- ESP LOOP - TỐI ƯU CHỐNG LAG
-- ============================================================
-- Dùng Heartbeat thay vì RenderStepped cho logic nặng
-- Giới hạn update rate để tránh lag spike

local espLastUpdate = 0
local ESP_UPDATE_RATE = 1/60  -- 60fps max, có thể điều chỉnh

RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - espLastUpdate < ESP_UPDATE_RATE then return end
    espLastUpdate = now

    local anyOn = getgenv().ESP_Outline or getgenv().ESP_Tracer or getgenv().ESP_Info or getgenv().ESP_HP
    if not anyOn then
        clearAllESP()
        return
    end

    local lhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local activeKeys = {}

    -- Players ESP
    if getgenv().TargetPlayers then
        for _, v in ipairs(Players:GetPlayers()) do
            -- KIỂM TRA: Nếu player không hợp lệ (chết/thoát) -> xóa ESP ngay
            if not isPlayerValid(v) or not shouldTarget(v) then
                clearESP(v)
                continue
            end

            local chr = v.Character
            local hrp = chr:FindFirstChild("HumanoidRootPart")
            if not hrp then
                clearESP(v)
                continue
            end

            activeKeys[v] = true
            local dist = lhrp and math.floor((lhrp.Position - hrp.Position).Magnitude) or 0
            drawESP(v, chr, getTeamColor(v), v.DisplayName, dist)
        end
    end

    -- NPC ESP
    if getgenv().TargetNPC then
        for _, model in ipairs(npcCache) do
            if not isNPCValid(model) or not shouldTargetNPC(model) then
                clearESP(model)
                continue
            end

            local hrp = model:FindFirstChild("HumanoidRootPart")
            if not hrp then
                clearESP(model)
                continue
            end

            activeKeys[model] = true
            local dist = lhrp and math.floor((lhrp.Position - hrp.Position).Magnitude) or 0
            drawESP(model, model, getNPCColor(model), model.Name, dist)
        end
    end

    -- Dọn dẹp key không còn active
    for k in pairs(espData) do
        if not activeKeys[k] then
            clearESP(k)
        end
    end
end)

-- Dọn dẹp khi player rời game
Players.PlayerRemoving:Connect(function(plr)
    clearESP(plr)
end)

-- ============================================================
-- SYNC HELPERS
-- ============================================================
local function syncQuickBtn(state)
    if not QuickBtn then return end
    QuickBtn.Text = state and "HEAD\nON" or "HEAD\nOFF"
    QuickBtn.BackgroundColor3 = state
        and Color3.fromRGB(0, 185, 85) or Color3.fromRGB(0, 100, 170)
end

local function setHitbox(state)
    getgenv().HeadHitboxOn = state
    syncQuickBtn(state)
    pcall(function() Rayfield.Flags.HHit:Set(state) end)
end

local function setAura(state)
    getgenv().AuraOn = state
    pcall(function() Rayfield.Flags.AOn:Set(state) end)
end

-- ============================================================
-- KEYBIND TỰ QUẢN LÝ (FIX: thay vì Rayfield CreateKeybind)
-- ============================================================
-- Khi user đổi keybind trong GUI, chỉ phím mới hoạt động, phím cũ bị xóa

local keybindActions = {}

local function registerKeybind(keyCode, action)
    keybindActions[keyCode] = action
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local action = keybindActions[input.KeyCode]
    if action then
        pcall(action)
    end
end)

-- ============================================================
-- RAYFIELD UI
-- ============================================================
Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name                   = "Aholo oper1",
    LoadingTitle           = "Aholo oper1",
    LoadingSubtitle        = "remake by : Aholo",
    Theme                  = "Rose",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
    ConfigurationSaving    = { Enabled = false },
    KeySystem              = false,
})

-- ── TARGET ────────────────────────────────────────────────────
local TabTarget = Window:CreateTab("Target", 4483362458)
TabTarget:CreateSection("Target Mode")

TabTarget:CreateToggle({ Name="Players", CurrentValue=true, Flag="TP",
    Callback=function(v) getgenv().TargetPlayers = v end })

TabTarget:CreateToggle({ Name="NPC", CurrentValue=false, Flag="TNPC",
    Callback=function(v)
        getgenv().TargetNPC = v
        if v then refreshNPCs() end
        if not v then
            for _, model in ipairs(npcCache) do pcall(function()
                local h = model:FindFirstChild("Head")
                if h then h.Size=Vector3.new(2,1,1); h.Transparency=0; h.Massless=false; h.CanCollide=false end
            end) end
        end
    end })

TabTarget:CreateSection("NPC Filter")
TabTarget:CreateParagraph({ Title="Color legend",
    Content="Red = Hostile  |  Green = Friendly  |  Orange = Unknown\nDetection: ObjectValue Target → player = Hostile" })

TabTarget:CreateToggle({ Name="Hostile Only", CurrentValue=false, Flag="NPCHos",
    Callback=function(v) getgenv().NPCHostileOnly=v; if v then getgenv().NPCFriendlyOnly=false end end })

TabTarget:CreateToggle({ Name="Friendly Only", CurrentValue=false, Flag="NPCFri",
    Callback=function(v) getgenv().NPCFriendlyOnly=v; if v then getgenv().NPCHostileOnly=false end end })

-- ── HITBOX ────────────────────────────────────────────────────
local TabHitbox = Window:CreateTab("Hitbox", 4483362458)
TabHitbox:CreateSection("Head Settings")

TabHitbox:CreateInput({ Name="Head Size", CurrentValue="6", PlaceholderText="1 – 100",
    RemoveTextAfterFocusLost=false, Flag="HSize",
    Callback=function(v) local n=tonumber(v); if n then getgenv().HeadSize=math.clamp(n,1,100) end end })

TabHitbox:CreateInput({ Name="Head Transparency", CurrentValue="0.5", PlaceholderText="0.0 – 1.0",
    RemoveTextAfterFocusLost=false, Flag="HTrans",
    Callback=function(v) local n=tonumber(v); if n then getgenv().HeadTransparency=math.clamp(n,0,1) end end })

TabHitbox:CreateToggle({ Name="Head Hitbox", CurrentValue=false, Flag="HHit",
    Callback=function(s) getgenv().HeadHitboxOn=s; syncQuickBtn(s) end })

TabHitbox:CreateSection("Filters")

TabHitbox:CreateToggle({ Name="Team Check", CurrentValue=false, Flag="HTC",
    Callback=function(v)
        getgenv().HeadTeamCheck = v
        if v and getgenv().AdvTeamCheck_Enabled then
            getgenv().AdvTeamCheck_Enabled = false
            pcall(function() Rayfield.Flags.AdvTeam:Set(false) end)
        end
    end })

TabHitbox:CreateToggle({ Name="Skip Friends", CurrentValue=false, Flag="HFC",
    Callback=function(v) getgenv().HeadFriendOnly=v end })

-- ── ADVANCED TEAM CHECK (HEAD) ──────────────────────────────
TabHitbox:CreateSection("Advanced Team Check")

TabHitbox:CreateParagraph({ Title="How it works",
    Content="ON = team được chọn sẽ BỊ DÍNH headsize\nOFF = team được chọn KHÔNG bị dính\nKhi bật Advanced, Team Check cũ sẽ tự tắt" })

TabHitbox:CreateToggle({ Name="Enable Advanced Team Check", CurrentValue=false, Flag="AdvTeam",
    Callback=function(v)
        getgenv().AdvTeamCheck_Enabled = v
        if v and getgenv().HeadTeamCheck then
            getgenv().HeadTeamCheck = false
            pcall(function() Rayfield.Flags.HTC:Set(false) end)
        end
        if v then refreshTeamList() end
    end })

-- Tạo toggle cho từng team
local AdvTeamToggles = {}
local function createAdvTeamToggles()
    local teamNames = refreshTeamList()
    for _, name in ipairs(teamNames) do
        local flagName = "AdvTeam_" .. name:gsub(" ", "_")
        local defaultVal = getgenv().AdvTeamCheck_Teams[name]
        if defaultVal == nil then defaultVal = true end

        local tgl = TabHitbox:CreateToggle({
            Name = "[HEAD] " .. name,
            CurrentValue = defaultVal,
            Flag = flagName,
            Callback = function(val)
                getgenv().AdvTeamCheck_Teams[name] = val
            end
        })
        table.insert(AdvTeamToggles, tgl)
    end
end

task.delay(0.5, createAdvTeamToggles)

-- ── ESP ───────────────────────────────────────────────────────
local TabESP = Window:CreateTab("ESP", 4483362458)
TabESP:CreateSection("Draw")

TabESP:CreateToggle({ Name="Outline ESP (through walls)", CurrentValue=false, Flag="EOutline",
    Callback=function(v) getgenv().ESP_Outline=v end })
TabESP:CreateToggle({ Name="Tracers",     CurrentValue=false, Flag="ETrace", Callback=function(v) getgenv().ESP_Tracer=v end })
TabESP:CreateToggle({ Name="Name + Dist", CurrentValue=false, Flag="EInfo",  Callback=function(v) getgenv().ESP_Info=v end })
TabESP:CreateToggle({ Name="Health (HP + %)", CurrentValue=false, Flag="EHP", Callback=function(v) getgenv().ESP_HP=v end })

-- ── AURA ─────────────────────────────────────────────────────
local TabAura = Window:CreateTab("Aura", 4483362458)
TabAura:CreateSection("Mode")

TabAura:CreateDropdown({ Name="Aura Mode", Options={"Aura Tool","Auto M1"},
    CurrentOption={"Aura Tool"}, Flag="AMode", MultipleOptions=false,
    Callback=function(v) getgenv().AuraMode=(v[1]=="Aura Tool") and "tool" or "m1" end })

TabAura:CreateSection("Settings")
TabAura:CreateInput({ Name="Range", CurrentValue="8", PlaceholderText="1 – 50",
    RemoveTextAfterFocusLost=false, Flag="ARange",
    Callback=function(v) local n=tonumber(v); if n then getgenv().AuraRange=math.clamp(n,1,50) end end })

TabAura:CreateToggle({ Name="Enable Aura", CurrentValue=false, Flag="AOn",
    Callback=function(v) getgenv().AuraOn=v end })

TabAura:CreateSection("Filters")

TabAura:CreateToggle({ Name="Team Check", CurrentValue=false, Flag="ATC",
    Callback=function(v)
        getgenv().AuraTeamCheck = v
        if v and getgenv().AdvAuraTeamCheck_Enabled then
            getgenv().AdvAuraTeamCheck_Enabled = false
            pcall(function() Rayfield.Flags.AdvAuraTeam:Set(false) end)
        end
    end })

TabAura:CreateToggle({ Name="Skip Friends", CurrentValue=false, Flag="AFC",
    Callback=function(v) getgenv().AuraFriendOnly=v end })

-- ── ADVANCED TEAM CHECK (AURA) ──────────────────────────────
TabAura:CreateSection("Advanced Team Check (Aura)")

TabAura:CreateParagraph({ Title="How it works",
    Content="ON = team được chọn sẽ BỊ DÍNH aura\nOFF = team được chọn KHÔNG bị dính\nKhi bật Advanced, Team Check cũ sẽ tự tắt" })

TabAura:CreateToggle({ Name="Enable Advanced Aura Team Check", CurrentValue=false, Flag="AdvAuraTeam",
    Callback=function(v)
        getgenv().AdvAuraTeamCheck_Enabled = v
        if v and getgenv().AuraTeamCheck then
            getgenv().AuraTeamCheck = false
            pcall(function() Rayfield.Flags.ATC:Set(false) end)
        end
        if v then refreshTeamList() end
    end })

local AdvAuraTeamToggles = {}
local function createAdvAuraTeamToggles()
    local teamNames = refreshTeamList()
    for _, name in ipairs(teamNames) do
        local flagName = "AdvAuraTeam_" .. name:gsub(" ", "_")
        local defaultVal = getgenv().AdvAuraTeamCheck_Teams[name]
        if defaultVal == nil then defaultVal = true end

        local tgl = TabAura:CreateToggle({
            Name = "[AURA] " .. name,
            CurrentValue = defaultVal,
            Flag = flagName,
            Callback = function(val)
                getgenv().AdvAuraTeamCheck_Teams[name] = val
            end
        })
        table.insert(AdvAuraTeamToggles, tgl)
    end
end

task.delay(0.5, createAdvAuraTeamToggles)

-- ── SETTINGS ─────────────────────────────────────────────────
local TabSettings = Window:CreateTab("Settings", 4483362458)

TabSettings:CreateSection("Performance")
local PerfLabel = TabSettings:CreateLabel("FPS: --  |  Ping: -- ms")
local fpsCount  = 0
local lastFPSTs = tick()
RunService.RenderStepped:Connect(function()
    fpsCount = fpsCount + 1
    if tick() - lastFPSTs >= 1 then
        local fps = fpsCount; fpsCount = 0; lastFPSTs = tick()
        local ping = 0
        pcall(function()
            ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        PerfLabel:Set("FPS: " .. fps .. "  |  Ping: " .. ping .. " ms")
    end
end)

-- KEYBINDS - Tự quản lý qua UIS, không dùng Rayfield CreateKeybind
TabSettings:CreateSection("Keybinds")

-- Hitbox Keybind
local KB_Hit_Label = TabSettings:CreateLabel("Hitbox Keybind: F")
TabSettings:CreateInput({
    Name = "Set Hitbox Keybind (type key name)",
    CurrentValue = "F",
    PlaceholderText = "e.g. F, G, LeftShift, etc.",
    RemoveTextAfterFocusLost = true,
    Flag = "KB_Hit_Input",
    Callback = function(v)
        local keyName = v:gsub("%s+", ""):upper()
        local keyCode = Enum.KeyCode[keyName]
        if keyCode then
            getgenv().Keybind_Hitbox = keyCode
            -- Cập nhật label
            pcall(function() KB_Hit_Label:Set("Hitbox Keybind: " .. keyName) end)
            -- Đăng ký lại
            registerKeybind(keyCode, function()
                setHitbox(not getgenv().HeadHitboxOn)
            end)
        end
    end
})

-- Aura Keybind
local KB_Aura_Label = TabSettings:CreateLabel("Aura Keybind: G")
TabSettings:CreateInput({
    Name = "Set Aura Keybind (type key name)",
    CurrentValue = "G",
    PlaceholderText = "e.g. G, H, LeftControl, etc.",
    RemoveTextAfterFocusLost = true,
    Flag = "KB_Aura_Input",
    Callback = function(v)
        local keyName = v:gsub("%s+", ""):upper()
        local keyCode = Enum.KeyCode[keyName]
        if keyCode then
            getgenv().Keybind_Aura = keyCode
            pcall(function() KB_Aura_Label:Set("Aura Keybind: " .. keyName) end)
            registerKeybind(keyCode, function()
                setAura(not getgenv().AuraOn)
            end)
        end
    end
})

-- GUI Keybind
local KB_GUI_Label = TabSettings:CreateLabel("GUI Keybind: Insert")
TabSettings:CreateInput({
    Name = "Set GUI Keybind (type key name)",
    CurrentValue = "Insert",
    PlaceholderText = "e.g. Insert, Delete, RightShift, etc.",
    RemoveTextAfterFocusLost = true,
    Flag = "KB_GUI_Input",
    Callback = function(v)
        local keyName = v:gsub("%s+", ""):upper()
        local keyCode = Enum.KeyCode[keyName]
        if keyCode then
            getgenv().Keybind_GUI = keyCode
            pcall(function() KB_GUI_Label:Set("GUI Keybind: " .. keyName) end)
            registerKeybind(keyCode, function()
                pcall(function() Rayfield:ToggleUI() end)
            end)
        end
    end
})

-- Đăng ký keybind mặc định
registerKeybind(getgenv().Keybind_Hitbox, function()
    setHitbox(not getgenv().HeadHitboxOn)
end)
registerKeybind(getgenv().Keybind_Aura, function()
    setAura(not getgenv().AuraOn)
end)
registerKeybind(getgenv().Keybind_GUI, function()
    pcall(function() Rayfield:ToggleUI() end)
end)

TabSettings:CreateSection("Quick Button")
TabSettings:CreateToggle({ Name="Show Quick Toggle Button", CurrentValue=false, Flag="ShowQuick",
    Callback=function(v) if QuickGui then QuickGui.Enabled=v end end })

-- ============================================================
-- QUICK TOGGLE BUTTON
-- ============================================================
QuickGui = Instance.new("ScreenGui")
QuickGui.Name           = "QuickToggle_op1"
QuickGui.ResetOnSpawn   = false
QuickGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
QuickGui.Enabled        = false
QuickGui.Parent         = game.CoreGui

QuickBtn = Instance.new("TextButton")
QuickBtn.Parent               = QuickGui
QuickBtn.Size                 = UDim2.new(0, 68, 0, 68)
QuickBtn.Position             = UDim2.new(1, -78, 1, -86)
QuickBtn.BackgroundColor3     = Color3.fromRGB(0, 100, 170)
QuickBtn.BackgroundTransparency = 0.1
QuickBtn.Text                 = "HEAD\nOFF"
QuickBtn.TextColor3           = Color3.fromRGB(255, 255, 255)
QuickBtn.Font                 = Enum.Font.GothamBold
QuickBtn.TextSize             = 12
QuickBtn.TextWrapped          = true
QuickBtn.Active               = true
QuickBtn.Draggable            = true
Instance.new("UICorner", QuickBtn).CornerRadius = UDim.new(0.2, 0)
local qs = Instance.new("UIStroke", QuickBtn)
qs.Color = Color3.fromRGB(0, 200, 255); qs.Thickness = 2

QuickBtn.MouseButton1Click:Connect(function()
    setHitbox(not getgenv().HeadHitboxOn)
end)

task.delay(2, function()
    Rayfield:Notify({ Title="Aholo oper1", Content="remake by : Aholo | Fixed ESP + Keybind", Duration=4 })
end)
