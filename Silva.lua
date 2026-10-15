-- ==========================================
--        SILVA MODS  v3  |  FPS PASSEIO
-- ==========================================
-- painel estilo "edson modz"
-- esp universal (box / skeleton / nome / vida)
-- aimbot COM wall check (não puxa atrás de parede)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- CONFIG
-- ==========================================
local config = {
    -- AIMBOT
    aimbotEnabled = true,
    aimbotHead = true,
    aimbotFOV = 150,
    aimbotSmoothing = 1,
    aimbotTeamCheck = true,
    aimbotWallCheck = true,       -- LIGADO: não puxa atrás de parede
    aimbotMaxDistance = 800,
    aimbotShowFOV = true,
    aimbotSticky = true,

    -- ESP
    espEnabled = true,
    espBox = true,
    espSkeleton = true,
    espName = true,
    espHealth = true,
    espDistance = false,
    espTeamCheck = true,
    espMaxDistance = 3000,

    -- MOVE
    speedEnabled = false,
    speedValue = 20,
    jumpEnabled = false,
    jumpValue = 44,
    flyEnabled = false,
    flySpeed = 200,
    noclip = false,

    fullbright = false,
}

-- ==========================================
-- HELPERS
-- ==========================================
local function getChar(p) return p and p.Character end
local function getHRP(p)
    local c = getChar(p)
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
        or c.PrimaryPart
        or c:FindFirstChild("Torso")
        or c:FindFirstChild("UpperTorso")
end
local function isAlive(p)
    local c = getChar(p)
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then return h.Health > 0 end
    return c:FindFirstChild("HumanoidRootPart") ~= nil
end
local function sameTeam(p)
    return p.Team ~= nil and p.Team == LocalPlayer.Team
end
local function distTo(p)
    local a, b = getHRP(p), getHRP(LocalPlayer)
    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end
local function w2s(pos)
    local sp, on = Camera:WorldToViewportPoint(pos)
    if not on then return nil end
    return Vector2.new(sp.X, sp.Y)
end

-- ==========================================
-- DETECÇÃO DE PARTES (universal)
-- ==========================================
local function findHead(char)
    if not char then return nil end
    return char:FindFirstChild("Head")
        or char:FindFirstChild("head")
        or char:FindFirstChild("HeadHitbox")
        or char:FindFirstChild("Hitbox")
end

local function findTorso(char)
    if not char then return nil end
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("LowerTorso")
        or char:FindFirstChild("Chest")
        or char:FindFirstChild("Body")
        or char:FindFirstChild("HumanoidRootPart")
end

local function findLimbByName(char, side, type_)
    -- procura por partes cujo nome contém "left"+""arm" etc
    local sideL = string.lower(side)
    local typeL = string.lower(type_)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local n = string.lower(part.Name):gsub("%s+", ""):gsub("_", "")
            if string.find(n, sideL, 1, true) and string.find(n, typeL, 1, true) then
                return part
            end
        end
    end
    return nil
end

-- ==========================================
-- DRAWING
-- ==========================================
local hasDrawing = pcall(function() return Drawing.new("Square") end)
local function draw(class, props)
    if not hasDrawing then return nil end
    local ok, obj = pcall(function() return Drawing.new(class) end)
    if not ok then return nil end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

-- ==========================================
-- ESP CACHE
-- ==========================================
local espCache = {}

local function makeESP(player)
    if player == LocalPlayer then return end
    if espCache[player] then return end

    espCache[player] = {
        boxOutline = draw("Square", {Thickness=3, Color=Color3.fromRGB(0,0,0), Filled=false, Visible=false}),
        box        = draw("Square", {Thickness=2, Color=Color3.fromRGB(255,120,0), Filled=false, Visible=false}),
        skHead     = draw("Line",   {Thickness=2, Color=Color3.fromRGB(255,120,0), Visible=false}),
        skLArm     = draw("Line",   {Thickness=2, Color=Color3.fromRGB(255,255,255), Visible=false}),
        skRArm     = draw("Line",   {Thickness=2, Color=Color3.fromRGB(255,255,255), Visible=false}),
        skLLeg     = draw("Line",   {Thickness=2, Color=Color3.fromRGB(255,255,255), Visible=false}),
        skRLeg     = draw("Line",   {Thickness=2, Color=Color3.fromRGB(255,255,255), Visible=false}),
        name       = draw("Text",   {Size=14, Center=true, Outline=true, Color=Color3.fromRGB(255,255,255), Visible=false}),
        dist       = draw("Text",   {Size=12, Center=true, Outline=true, Color=Color3.fromRGB(200,200,200), Visible=false}),
        hpBg       = draw("Square", {Thickness=1, Color=Color3.fromRGB(0,0,0), Filled=true, Visible=false}),
        hpBar      = draw("Square", {Thickness=1, Color=Color3.fromRGB(0,255,0), Filled=true, Visible=false}),
    }
end

local function clearESP(player)
    local e = espCache[player]
    if not e then return end
    for _, obj in pairs(e) do pcall(function() obj:Remove() end) end
    espCache[player] = nil
end

local function getBoundingBox(character)
    if not character then return nil end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local found = false
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 0.95 then
            local size = part.Size
            local cf = part.CFrame
            local hx, hy, hz = size.X/2, size.Y/2, size.Z/2
            local corners = {
                cf * Vector3.new( hx,  hy,  hz), cf * Vector3.new(-hx,  hy,  hz),
                cf * Vector3.new( hx, -hy,  hz), cf * Vector3.new(-hx, -hy,  hz),
                cf * Vector3.new( hx,  hy, -hz), cf * Vector3.new(-hx,  hy, -hz),
                cf * Vector3.new( hx, -hy, -hz), cf * Vector3.new(-hx, -hy, -hz),
            }
            for _, wp in ipairs(corners) do
                local sp = w2s(wp)
                if sp then
                    found = true
                    if sp.X < minX then minX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end
    if not found then return nil end
    return Vector2.new(minX, minY), Vector2.new(maxX, maxY)
end

local function setLine(line, partA, partB)
    if not line then return end
    if not partA or not partB then line.Visible = false return end
    local a = w2s(partA.Position)
    local b = w2s(partB.Position)
    if not a or not b then line.Visible = false return end
    line.From = a
    line.To = b
    line.Visible = true
end

-- ==========================================
-- AIMBOT (com raycast = não passa parede)
-- ==========================================
local lockedTarget = nil

local function isVisible(player)
    local hrp = getHRP(player)
    if not hrp then return false end
    local origin = Camera.CFrame.Position
    local dir = hrp.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.IgnoreWater = true
    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
    return Players:GetPlayerFromCharacter(hitModel) == player
end

local function getTargetPart(player)
    local char = getChar(player)
    if not char then return nil end
    if config.aimbotHead then
        return findHead(char) or getHRP(player)
    end
    return getHRP(player)
end

local function getClosestTarget()
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local best, bestScore = nil, math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            local eligible = true
            if config.aimbotTeamCheck and sameTeam(p) then eligible = false end
            if distTo(p) > config.aimbotMaxDistance then eligible = false end
            if eligible then
                local part = getTargetPart(p)
                if part then
                    local sp = w2s(part.Position)
                    if sp then
                        local d = (sp - center).Magnitude
                        if d <= config.aimbotFOV and d < bestScore then
                            if config.aimbotWallCheck and not isVisible(p) then
                                -- bloqueado pela parede, pula
                            else
                                bestScore = d
                                best = p
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local fovCircle = draw("Circle", {
    Thickness = 1.5,
    Color = Color3.fromRGB(255,120,0),
    Filled = false,
    NumSides = 72,
    Visible = false,
})

RunService.RenderStepped:Connect(function()
    if config.aimbotEnabled and config.aimbotShowFOV and fovCircle then
        local vp = Camera.ViewportSize
        fovCircle.Position = Vector2.new(vp.X/2, vp.Y/2)
        fovCircle.Radius = config.aimbotFOV
        fovCircle.Visible = true
    elseif fovCircle then
        fovCircle.Visible = false
    end

    if not config.aimbotEnabled then
        lockedTarget = nil
        return
    end

    if config.aimbotSticky and lockedTarget then
        if not isAlive(lockedTarget) or not getChar(lockedTarget) then
            lockedTarget = nil
        elseif config.aimbotWallCheck and not isVisible(lockedTarget) then
            lockedTarget = nil
        end
    end

    if not lockedTarget then
        lockedTarget = getClosestTarget()
    end

    if lockedTarget then
        local part = getTargetPart(lockedTarget)
        if part then
            local aimCF = CFrame.new(Camera.CFrame.Position, part.Position)
            if config.aimbotSmoothing >= 1 then
                Camera.CFrame = aimCF
            else
                Camera.CFrame = Camera.CFrame:Lerp(aimCF, config.aimbotSmoothing)
            end
        end
    end
end)

-- ==========================================
-- ESP LOOP
-- ==========================================
RunService.RenderStepped:Connect(function()
    if not config.espEnabled then
        for _, e in pairs(espCache) do
            for _, obj in pairs(e) do
                pcall(function() obj.Visible = false end)
            end
        end
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not espCache[player] then makeESP(player) end
            local e = espCache[player]

            if e then
                local show = isAlive(player)
                if config.espTeamCheck and sameTeam(player) then show = false end
                if distTo(player) > config.espMaxDistance then show = false end

                local char = getChar(player)
                local topLeft, bottomRight = show and char and getBoundingBox(char) or nil

                if topLeft and bottomRight then
                    local width = bottomRight.X - topLeft.X
                    local height = bottomRight.Y - topLeft.Y

                    -- BOX
                    if config.espBox and e.box then
                        e.box.Size = Vector2.new(width, height)
                        e.box.Position = topLeft
                        e.boxOutline.Size = Vector2.new(width+2, height+2)
                        e.boxOutline.Position = topLeft - Vector2.new(1,1)
                        e.box.Visible = true
                        e.boxOutline.Visible = true
                    else
                        if e.box then e.box.Visible = false end
                        if e.boxOutline then e.boxOutline.Visible = false end
                    end

                    -- SKELETON
                    if config.espSkeleton then
                        local Head = findHead(char)
                        local Torso = findTorso(char)
                        local LArm = findLimbByName(char, "left", "arm") or findLimbByName(char, "l", "arm")
                        local RArm = findLimbByName(char, "right", "arm") or findLimbByName(char, "r", "arm")
                        local LLeg = findLimbByName(char, "left", "leg") or findLimbByName(char, "l", "leg")
                        local RLeg = findLimbByName(char, "right", "leg") or findLimbByName(char, "r", "leg")

                        setLine(e.skHead, Head, Torso)
                        setLine(e.skLArm, Torso, LArm)
                        setLine(e.skRArm, Torso, RArm)
                        setLine(e.skLLeg, Torso, LLeg)
                        setLine(e.skRLeg, Torso, RLeg)
                    else
                        for _, ln in ipairs({e.skHead,e.skLArm,e.skRArm,e.skLLeg,e.skRLeg}) do
                            if ln then ln.Visible = false end
                        end
                    end

                    -- NAME
                    if config.espName and e.name then
                        e.name.Text = player.Name
                        e.name.Position = Vector2.new(topLeft.X + width/2, topLeft.Y - 18)
                        e.name.Visible = true
                    else
                        if e.name then e.name.Visible = false end
                    end

                    -- HEALTH
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if config.espHealth and hum and e.hpBar then
                        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        e.hpBg.Size = Vector2.new(3, height + 2)
                        e.hpBg.Position = Vector2.new(topLeft.X - 8, topLeft.Y - 1)
                        e.hpBar.Size = Vector2.new(3, height * ratio)
                        e.hpBar.Position = Vector2.new(topLeft.X - 8, topLeft.Y + (height - height*ratio))
                        if ratio > 0.6 then e.hpBar.Color = Color3.fromRGB(0,255,0)
                        elseif ratio > 0.3 then e.hpBar.Color = Color3.fromRGB(255,200,0)
                        else e.hpBar.Color = Color3.fromRGB(255,0,0) end
                        e.hpBar.Visible = true
                        e.hpBg.Visible = true
                    else
                        if e.hpBar then e.hpBar.Visible = false end
                        if e.hpBg then e.hpBg.Visible = false end
                    end

                    -- DIST
                    if config.espDistance and e.dist then
                        e.dist.Text = math.floor(distTo(player)) .. "m"
                        e.dist.Position = Vector2.new(topLeft.X + width/2, bottomRight.Y + 4)
                        e.dist.Visible = true
                    else
                        if e.dist then e.dist.Visible = false end
                    end
                else
                    for _, obj in pairs(e) do
                        pcall(function() obj.Visible = false end)
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- MOVE
-- ==========================================
local function applySpeed()
    local c = getChar(LocalPlayer)
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = config.speedEnabled and config.speedValue or 16 end
end
local function applyJump()
    local c = getChar(LocalPlayer)
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then h.UseJumpPower = true; h.JumpPower = config.jumpEnabled and config.jumpValue or 50 end
end

local flyVel, flyGyro
local function startFly()
    local hrp = getHRP(LocalPlayer)
    if not hrp then return end
    flyVel = Instance.new("BodyVelocity")
    flyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
    flyVel.Velocity = Vector3.new(0,0,0)
    flyVel.Parent = hrp
    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
    flyGyro.P = 1e4
    flyGyro.Parent = hrp
end
local function stopFly()
    if flyVel then flyVel:Destroy() flyVel = nil end
    if flyGyro then flyGyro:Destroy() flyGyro = nil end
end

RunService.Heartbeat:Connect(function()
    if not config.flyEnabled then return end
    local hrp = getHRP(LocalPlayer)
    if not hrp or not flyVel then return end
    local moveDir = Vector3.new(0,0,0)
    local camCF = Camera.CFrame
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0,1,0) end
    flyVel.Velocity = moveDir * config.flySpeed
    flyGyro.CFrame = camCF
end)

local noclipConn
local function toggleNoclip(state)
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if not state then return end
    noclipConn = RunService.Stepped:Connect(function()
        local c = getChar(LocalPlayer)
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

local savedLight = {}
local function setFullbright(s)
    if s then
        savedLight.Ambient = Lighting.Ambient
        savedLight.OutdoorAmbient = Lighting.OutdoorAmbient
        savedLight.Brightness = Lighting.Brightness
        savedLight.ClockTime = Lighting.ClockTime
        savedLight.FogEnd = Lighting.FogEnd
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 12
        Lighting.FogEnd = 1e6
    else
        for k,v in pairs(savedLight) do pcall(function() Lighting[k] = v end) end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    applySpeed(); applyJump()
    if config.noclip then toggleNoclip(true) end
    if config.flyEnabled then startFly() end
end)

Players.PlayerRemoving:Connect(function(p) clearESP(p) end)

-- ==========================================
-- GUI  |  SILVA MODS  (estilo edson modz)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SilvaMods"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

-- botão flutuante
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0, 130, 0, 38)
openBtn.Position = UDim2.new(0.5, -65, 0, 20)
openBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
openBtn.TextColor3 = Color3.fromRGB(255, 140, 20)
openBtn.Text = "SILVA MODS"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 14
openBtn.BorderSizePixel = 0
openBtn.Active = tru
