--[[
    PLS DONATE AUTO-FARM · v2.3  (UIScale boot bug fixed)
]]

repeat task.wait() until game:IsLoaded()

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local HS           = game:GetService("HttpService")
local RunService   = game:GetService("RunService")
local Teleport     = game:GetService("TeleportService")
local VU           = game:GetService("VirtualUser")
local UIS          = game:GetService("UserInputService")
local TCS          = game:GetService("TextChatService")
local Lighting     = game:GetService("Lighting")
local WS           = game:GetService("Workspace")
local StarterGui   = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player       = Players.LocalPlayer
local httpRequest  = (syn and syn.request) or http_request or request or nil
local guiParent    = (gethui and gethui()) or game:GetService("CoreGui")

local CFG = {
    autoClaimBooth     = false,
    autoHop            = false,
    hopAfterNoDonation = 90,
    antiAFK            = true,
    autoBeg            = false,
    begMessage         = "pls donate 🙏 any amount helps",
    begInterval        = 30,
    autoThanks         = true,
    thanksMessage      = "tysm for the donation! ❤️",
    chatSpam           = false,
    spamMessage        = "GOAL: 1000 R$",
    spamInterval       = 2,
    artPaste           = false,
    artLines           = { "  ╔══════════╗ ", "  ║ DONATE  ║ ", "  ║  PLS 🙏  ║ ", "  ╚══════════╝ " },
    artInterval        = 1,
    boothTextEdit      = false,
    boothTextValue     = "GOAL: 500",
    autoRedeem         = false,
    redeemCodes        = {"WELCOME", "FREEGIFT", "2025"},
    fakeDonate         = false,
    fakeDonateAmount   = 100,
    effectBlimpAt      = 10000,
    effectNukeAt       = 100000,
    effectSmiteAt      = 1000000,
    effectsEnabled     = true,
    prankVictim        = "SomeoneCool",
    prankAmount        = 10000,
    prankTemplate      = 1,
    prankLoop          = false,
    prankLoopInterval  = 20,
    webhookURL         = "",
    webhookOn          = false,
    fpsCapEnabled      = false,
    fpsCap             = 30,
    disableRendering   = false,
    lastCommand        = ":heal",
}

local state = {
    lastDonation = tick(), totalReceived = 0, donationCount = 0,
    conns = {}, begThread, spamThread, artThread, prankThread,
}

local function addConn(c) table.insert(state.conns, c); return c end
local function notify(title, text)
    pcall(function() StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = 4}) end)
end
local function sendWebhook(title, desc, color)
    if not CFG.webhookOn or CFG.webhookURL == "" or not httpRequest then return end
    task.spawn(function() pcall(function()
        httpRequest({Url = CFG.webhookURL, Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HS:JSONEncode({username = "PLS Donate Farm",
                embeds = {{title = title, description = desc,
                    color = color or 0x00BFFF,
                    timestamp = DateTime.now():ToIsoDate(),
                    footer = {text = "Player: "..player.Name}}}})})
    end) end)
end

local function sendChat(msg)
    if not msg or msg == "" then return end
    pcall(function()
        if TCS.ChatVersion == Enum.ChatVersion.TextChatService then
            local g = TCS:FindFirstChild("TextChannels") and TCS.TextChannels:FindFirstChild("RBXGeneral")
            if g then g:SendAsync(msg); return end
        end
        local ev = RS:FindFirstChild("DefaultChatSystemChatEvents")
        if ev and ev:FindFirstChild("SayMessageRequest") then ev.SayMessageRequest:FireServer(msg, "All"); return end
        for _, o in ipairs(RS:GetDescendants()) do
            if o:IsA("RemoteEvent") and o.Name:lower():find("say") then o:FireServer(msg, "All"); return end
        end
    end)
end

if CFG.antiAFK then
    addConn(player.Idled:Connect(function() pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end) end))
end

local function findClaimableBooth()
    for _, o in ipairs(WS:GetDescendants()) do
        if o:IsA("ProximityPrompt") then
            local at = (o.ActionText or ""):lower()
            if at:find("claim") or at:find("buy") or at:find("rent") then return o end
        end
    end
end

local function claimBooth()
    if not CFG.autoClaimBooth then return end
    local p = findClaimableBooth()
    if not p then return end
    local part = p.Parent
    if not part or not part:IsA("BasePart") then return end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local orig = hrp.CFrame
    hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    task.wait(0.35)
    pcall(function() fireproximityprompt(p) end)
    pcall(function() p:InputHoldBegin(); task.wait(0.15); p:InputHoldEnd() end)
    task.wait(0.5); hrp.CFrame = orig
    notify("PLS Donate Farm", "Attempted booth claim")
end

task.spawn(function() while true do task.wait(5); if CFG.autoClaimBooth then pcall(claimBooth) end end end)

local function hopServer()
    if not httpRequest then notify("Hop", "executor lacks http") return end
    task.spawn(function()
        local ok, resp = pcall(function()
            return httpRequest({Url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId), Method = "GET"})
        end)
        if not ok or not resp or not resp.Body then return end
        local data = HS:JSONDecode(resp.Body)
        for _, srv in ipairs(data.data or {}) do
            if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                pcall(function() Teleport:TeleportToPlaceInstance(game.PlaceId, srv.id, player) end); return
            end
        end
        notify("Hop", "no viable server")
    end)
end

task.spawn(function()
    while true do task.wait(5)
        if CFG.autoHop and (tick() - state.lastDonation) >= CFG.hopAfterNoDonation then
            hopServer(); task.wait(15)
        end
    end
end)

local function startBeg()
    if state.begThread then return end
    state.begThread = task.spawn(function() while CFG.autoBeg do sendChat(CFG.begMessage); task.wait(CFG.begInterval) end; state.begThread = nil end)
end
local function startSpam()
    if state.spamThread then return end
    state.spamThread = task.spawn(function() while CFG.chatSpam do sendChat(CFG.spamMessage); task.wait(CFG.spamInterval) end; state.spamThread = nil end)
end
local function startArt()
    if state.artThread then return end
    state.artThread = task.spawn(function()
        while CFG.artPaste do
            for _, line in ipairs(CFG.artLines) do
                if not CFG.artPaste then break end
                sendChat(line); task.wait(CFG.artInterval)
            end
            task.wait(CFG.artInterval * 3)
        end
        state.artThread = nil
    end)
end

local function spawnFakeDonate(amount)
    amount = tonumber(amount) or 100
    local sg = Instance.new("ScreenGui")
    sg.Name = "PLSDonateFake"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.Parent = guiParent
    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(0, 360, 0, 80)
    fr.Position = UDim2.new(0.5, -180, 0, -100)
    fr.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    fr.BackgroundTransparency = 0.1; fr.BorderSizePixel = 0; fr.Parent = sg
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", fr)
    stroke.Color = Color3.fromRGB(0, 200, 255); stroke.Thickness = 2
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -20, 0, 26); t.Position = UDim2.new(0, 10, 0, 8)
    t.BackgroundTransparency = 1; t.Text = "💸 DONATION"
    t.TextColor3 = Color3.fromRGB(0, 200, 255)
    t.Font = Enum.Font.GothamBold; t.TextSize = 16
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = fr
    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -20, 0, 30); body.Position = UDim2.new(0, 10, 0, 36)
    body.BackgroundTransparency = 1
    local ps = Players:GetPlayers()
    local pick = ps[math.random(1, math.max(1, #ps))] or player
    body.Text = ("%s donated %d R$"):format(pick.Name, amount)
    body.TextColor3 = Color3.fromRGB(240, 240, 240)
    body.Font = Enum.Font.Gotham; body.TextSize = 14
    body.TextXAlignment = Enum.TextXAlignment.Left; body.Parent = fr
    fr:TweenPosition(UDim2.new(0.5, -180, 0, 20), "Out", "Quad", 0.5, true)
    task.delay(4, function()
        fr:TweenPosition(UDim2.new(0.5, -180, 0, -100), "In", "Quad", 0.4, true)
        task.wait(0.5); sg:Destroy()
    end)
end

local function effectBlimp(amount, donator)
    local sg = Instance.new("ScreenGui"); sg.Name = "PLSBlmp"
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = guiParent
    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(0, 400, 0, 100)
    fr.Position = UDim2.new(-0.5, 0, 0.15, 0)
    fr.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
    fr.BackgroundTransparency = 0.15; fr.BorderSizePixel = 0; fr.Parent = sg
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 20)
    local st = Instance.new("UIStroke", fr); st.Color = Color3.fromRGB(255, 180, 60); st.Thickness = 3
    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.new(0, 80, 1, 0); ic.BackgroundTransparency = 1
    ic.Text = "🎈"; ic.TextSize = 56; ic.Font = Enum.Font.GothamBold; ic.Parent = fr
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -90, 0, 40); t.Position = UDim2.new(0, 90, 0, 10)
    t.BackgroundTransparency = 1; t.Text = ("BLIMP! %d R$"):format(amount)
    t.TextColor3 = Color3.fromRGB(255, 230, 120)
    t.Font = Enum.Font.GothamBlack; t.TextSize = 20
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = fr
    local t2 = Instance.new("TextLabel")
    t2.Size = UDim2.new(1, -90, 0, 30); t2.Position = UDim2.new(0, 90, 0, 50)
    t2.BackgroundTransparency = 1; t2.Text = "from "..tostring(donator or "someone")
    t2.TextColor3 = Color3.fromRGB(220, 220, 240)
    t2.Font = Enum.Font.Gotham; t2.TextSize = 14
    t2.TextXAlignment = Enum.TextXAlignment.Left; t2.Parent = fr
    TweenService:Create(fr, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5, -200, 0.15, 0)}):Play()
    task.delay(5, function()
        TweenService:Create(fr, TweenInfo.new(1, Enum.EasingStyle.Quad), {Position = UDim2.new(1.5, 0, 0.15, 0)}):Play()
        task.wait(1.1); sg:Destroy()
    end)
end

local function effectNuke(amount, donator)
    local sg = Instance.new("ScreenGui"); sg.Name = "PLSNuke"
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = guiParent
    local flash = Instance.new("Frame")
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
    flash.BorderSizePixel = 0; flash.Parent = sg
    TweenService:Create(flash, TweenInfo.new(1.5), {BackgroundTransparency = 1}):Play()
    local c = Instance.new("TextLabel")
    c.Size = UDim2.new(1, 0, 0, 120); c.Position = UDim2.new(0, 0, 0.4, 0)
    c.BackgroundTransparency = 1
    c.Text = "☢️ NUCLEAR DONATION ☢️\n"..amount.." R$ from "..tostring(donator or "someone")
    c.TextColor3 = Color3.fromRGB(255, 100, 50)
    c.Font = Enum.Font.GothamBlack; c.TextSize = 24
    c.TextStrokeTransparency = 0; c.Parent = sg
    task.delay(2, function() sg:Destroy() end)
end

local function effectSmite(amount, donator)
    local sg = Instance.new("ScreenGui"); sg.Name = "PLSSmite"
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = guiParent
    local beam = Instance.new("Frame")
    beam.Size = UDim2.new(0, 24, 0, 0)
    beam.Position = UDim2.new(0.5, -12, 0, 0)
    beam.BackgroundColor3 = Color3.fromRGB(255, 240, 100)
    beam.BorderSizePixel = 0; beam.Parent = sg
    TweenService:Create(beam, TweenInfo.new(0.3), {Size = UDim2.new(0, 24, 1, 0)}):Play()
    task.wait(0.3)
    local bolt = Instance.new("TextLabel")
    bolt.Size = UDim2.new(0, 200, 0, 200)
    bolt.Position = UDim2.new(0.5, -100, 0.35, 0)
    bolt.BackgroundTransparency = 1; bolt.Text = "⚡"; bolt.TextSize = 180
    bolt.TextColor3 = Color3.fromRGB(255, 255, 100); bolt.Parent = sg
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 80); label.Position = UDim2.new(0, 0, 0.75, 0)
    label.BackgroundTransparency = 1
    label.Text = "SMITED! "..amount.." R$ from "..tostring(donator or "someone")
    label.TextColor3 = Color3.fromRGB(255, 255, 200)
    label.TextStrokeTransparency = 0; label.TextStrokeColor3 = Color3.fromRGB(80, 80, 0)
    label.Font = Enum.Font.GothamBlack; label.TextSize = 22; label.Parent = sg
    task.wait(2)
    TweenService:Create(beam, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    TweenService:Create(bolt, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    task.wait(0.6); sg:Destroy()
end

local function triggerEffect(kind, amount, donator)
    if kind == "blimp" then effectBlimp(amount or 10000, donator)
    elseif kind == "nuke" then effectNuke(amount or 100000, donator)
    elseif kind == "smite" then effectSmite(amount or 1000000, donator) end
end

local PRANK_TEMPLATES = {
    "[DONATION] %s donated %d R$ to %s!",
    "🎁 %s just donated %d R$ to %s",
    "💰 Donation received: %s → %s (%d R$)",
    "✅ %s tipped %d R$ — tysm!",
}

local function buildPrankMessage()
    local victim = CFG.prankVictim or "Someone"
    local amount = tonumber(CFG.prankAmount) or 10000
    local idx = tonumber(CFG.prankTemplate) or 1
    local tmpl = PRANK_TEMPLATES[idx] or PRANK_TEMPLATES[1]
    local ok, result = pcall(string.format, tmpl, victim, amount, player.Name)
    if not ok then return ("[DONATION] %s donated %d R$ to %s!"):format(victim, amount, player.Name) end
    return result
end

local function firePrankChat()
    local msg = buildPrankMessage()
    sendChat(msg)
    notify("Prank", "sent: "..msg:sub(1, 50))
end

local function startPrankLoop()
    if state.prankThread then return end
    state.prankThread = task.spawn(function()
        while CFG.prankLoop do
            pcall(firePrankChat)
            task.wait(CFG.prankLoopInterval)
        end
        state.prankThread = nil
    end)
end

local function tryFakeDonationRemote()
    local victim = CFG.prankVictim or "Someone"
    local amount = tonumber(CFG.prankAmount) or 10000
    local count = 0
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local nm = obj.Name:lower()
            if nm:find("donat") or nm:find("tip") or nm:find("contribut") then
                pcall(function()
                    obj:FireServer(victim, amount)
                    obj:FireServer({Player = victim, Amount = amount})
                end)
                count = count + 1
            end
        end
    end
    notify("Prank", ("fired %d remotes (may reject)"):format(count))
end

local function onDonationReceived(amount, donator)
    amount = tonumber(amount) or 0
    state.lastDonation = tick()
    state.totalReceived = state.totalReceived + amount
    state.donationCount = state.donationCount + 1
    if CFG.autoThanks then task.delay(0.5, function() sendChat(CFG.thanksMessage) end) end
    if CFG.effectsEnabled then
        if amount >= CFG.effectSmiteAt then triggerEffect("smite", amount, donator)
        elseif amount >= CFG.effectNukeAt then triggerEffect("nuke", amount, donator)
        elseif amount >= CFG.effectBlimpAt then triggerEffect("blimp", amount, donator) end
    end
    sendWebhook("💰 Donation Received",
        ("**%d R$** from **%s**\nSession: **%d R$**\nCount: **%d**"):format(amount, tostring(donator or "someone"), state.totalReceived, state.donationCount), 0x00FF88)
    notify("Donation!", ("+%d R$ from %s"):format(amount, tostring(donator or "someone")))
end

for _, o in ipairs(RS:GetDescendants()) do
    if o:IsA("RemoteEvent") then
        local nm = o.Name:lower()
        if nm:find("donat") or nm:find("tip") or nm:find("contribut") then
            addConn(o.OnClientEvent:Connect(function(...)
                local args = {...}
                for _, a in ipairs(args) do
                    if type(a) == "number" then
                        onDonationReceived(a, args[1] ~= a and args[1] or args[2]); return
                    elseif type(a) == "table" then
                        local amt = a.Amount or a.amount or a.Value or a.Robux
                        local who = a.Player or a.Donator or a.Name or a.From
                        if amt then onDonationReceived(amt, who); return end
                    end
                end
            end))
        end
    end
end

local boothRemotes = {}
for _, o in ipairs(RS:GetDescendants()) do
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        local nm = o.Name:lower()
        if nm:find("booth") or nm:find("customiz") or nm:find("settext") or nm:find("sign") or nm:find("edit") then
            table.insert(boothRemotes, o)
        end
    end
end

local function pushBoothText()
    if not CFG.boothTextEdit then return end
    if #boothRemotes == 0 then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, obj in ipairs(WS:GetDescendants()) do
            if obj:IsA("SurfaceGui") and obj.Adornee and (obj.Adornee.Position - hrp.Position).Magnitude < 20 then
                for _, txt in ipairs(obj:GetDescendants()) do
                    if txt:IsA("TextLabel") then pcall(function() txt.Text = CFG.boothTextValue end) end
                end
            end
        end
        return
    end
    for _, r in ipairs(boothRemotes) do
        pcall(function()
            if r:IsA("RemoteEvent") then r:FireServer(CFG.boothTextValue)
            else r:InvokeServer(CFG.boothTextValue) end
        end)
    end
end

task.spawn(function() while true do task.wait(4); if CFG.boothTextEdit then pcall(pushBoothText) end end end)

local function tryRedeem()
    if not CFG.autoRedeem then return end
    local remotes = {}
    for _, o in ipairs(RS:GetDescendants()) do
        if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
            local nm = o.Name:lower()
            if nm:find("redeem") or nm:find("promo") or nm:find("code") then table.insert(remotes, o) end
        end
    end
    for _, r in ipairs(remotes) do
        for _, code in ipairs(CFG.redeemCodes) do
            pcall(function() if r:IsA("RemoteEvent") then r:FireServer(code) else r:InvokeServer(code) end end)
            task.wait(1.2)
        end
    end
end

local function executeAdminCommand(cmd)
    if not cmd or cmd == "" then return end
    local fired = false
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nm = obj.Name:lower()
            if nm:find("admin") or nm:find("command") or nm:find("cmd") or nm:find("execute") then
                pcall(function()
                    if obj:IsA("RemoteEvent") then obj:FireServer(cmd) else obj:InvokeServer(cmd) end
                end)
                fired = true
            end
        end
    end
    if not fired then sendChat(cmd) end
    notify("Admin", "fired: "..cmd)
end

local function applyRender()
    if CFG.disableRendering then
        pcall(function()
            Lighting.GlobalShadows = false; Lighting.FogEnd = 0; Lighting.Brightness = 0
            Lighting.EnvironmentDiffuseScale = 0; Lighting.EnvironmentSpecularScale = 0
            for _, fx in ipairs(Lighting:GetChildren()) do
                if fx:IsA("PostEffect") or fx:IsA("Atmosphere") or fx:IsA("Sky") then fx.Enabled = false end
            end
        end)
    else
        pcall(function()
            Lighting.GlobalShadows = true; Lighting.FogEnd = 100000; Lighting.Brightness = 2
            Lighting.EnvironmentDiffuseScale = 1; Lighting.EnvironmentSpecularScale = 1
            for _, fx in ipairs(Lighting:GetChildren()) do
                if fx:IsA("PostEffect") or fx:IsA("Atmosphere") or fx:IsA("Sky") then fx.Enabled = true end
            end
        end)
    end
end

task.spawn(function()
    while true do
        local t0 = tick(); RunService.RenderStepped:Wait()
        if CFG.fpsCapEnabled then
            local target = 1 / math.max(1, CFG.fpsCap)
            local e = tick() - t0
            if e < target then task.wait(target - e) end
        end
    end
end)

local function buildGUI()
    local old = guiParent:FindFirstChild("PLSDonateFarmGui")
    if old then old:Destroy() end
    local gui = Instance.new("ScreenGui")
    gui.Name = "PLSDonateFarmGui"; gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent = guiParent
    pcall(function() gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)

    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.new(0.5, 0, 0.5, 0)
    holder.Size = UDim2.new(0, 520, 0, 400)
    holder.BackgroundTransparency = 1; holder.Active = true
    holder.Parent = gui

    local uiScale = Instance.new("UIScale", holder)
    uiScale.Scale = 0.85  -- safe default before viewport ready

    -- FIXED recomputeScale — guards against invalid viewport
    local function recomputeScale()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        if vp.X < 200 or vp.Y < 200 then return end  -- viewport not ready, don't touch scale
        local sx = math.min(1, (vp.X - 24) / 520)
        local sy = math.min(1, (vp.Y - 24) / 400)
        local s = math.min(sx, sy)
        s = math.max(0.55, math.min(1, s))  -- clamp: never below 0.55, never above 1
        uiScale.Scale = s
    end
    recomputeScale()
    -- retry loop for the first 5 seconds — catches camera-ready moment
    task.spawn(function()
        for i = 1, 20 do
            task.wait(0.25)
            recomputeScale()
        end
    end)
    -- listen for real ViewportSize changes (rotation, resize)
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(recomputeScale)
    end
    UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(recomputeScale)

    local main = Instance.new("Frame")
    main.Size = UDim2.new(1, 0, 1, 0)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    main.BorderSizePixel = 0; main.Parent = holder
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(50, 50, 70); stroke.Thickness = 1

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 36)
    header.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    header.BorderSizePixel = 0; header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 1, 0); title.Position = UDim2.new(0, 14, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "PLS DONATE FARM · Arceus"
    title.TextColor3 = Color3.fromRGB(0, 200, 255)
    title.Font = Enum.Font.GothamBold; title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = header

    local minimize = Instance.new("TextButton")
    minimize.Size = UDim2.new(0, 26, 0, 26); minimize.Position = UDim2.new(1, -66, 0, 5)
    minimize.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    minimize.Text = "–"; minimize.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimize.Font = Enum.Font.GothamBold; minimize.TextSize = 16
    minimize.BorderSizePixel = 0; minimize.Parent = header
    Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 6)

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 26, 0, 26); close.Position = UDim2.new(1, -34, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(60, 25, 25)
    close.Text = "×"; close.TextColor3 = Color3.fromRGB(240, 100, 100)
    close.Font = Enum.Font.GothamBold; close.TextSize = 16
    close.BorderSizePixel = 0; close.Parent = header
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

    local tabsBar = Instance.new("ScrollingFrame")
    tabsBar.Size = UDim2.new(0, 120, 1, -46)
    tabsBar.Position = UDim2.new(0, 8, 0, 44)
    tabsBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    tabsBar.BorderSizePixel = 0; tabsBar.ScrollBarThickness = 6
    tabsBar.ScrollBarImageColor3 = Color3.fromRGB(0, 140, 200)
    tabsBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabsBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabsBar.ScrollingDirection = Enum.ScrollingDirection.Y
    tabsBar.Active = true; tabsBar.Elasticity = 0.1; tabsBar.Parent = main
    Instance.new("UICorner", tabsBar).CornerRadius = UDim.new(0, 8)
    local tl = Instance.new("UIListLayout")
    tl.Padding = UDim.new(0, 4); tl.SortOrder = Enum.SortOrder.LayoutOrder; tl.Parent = tabsBar
    local tp = Instance.new("UIPadding")
    tp.PaddingTop = UDim.new(0, 6); tp.PaddingBottom = UDim.new(0, 6)
    tp.PaddingLeft = UDim.new(0, 5); tp.PaddingRight = UDim.new(0, 10); tp.Parent = tabsBar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -140, 1, -54); content.Position = UDim2.new(0, 132, 0, 44)
    content.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    content.BorderSizePixel = 0; content.Parent = main
    Instance.new("UICorner", content).CornerRadius = UDim.new(0, 8)

    local pages, pageOrder = {}, {}
    local tabCounter = 0

    local function addPage(name, icon)
        tabCounter = tabCounter + 1
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32); btn.LayoutOrder = tabCounter
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        btn.Text = "  "..icon.."  "..name
        btn.TextColor3 = Color3.fromRGB(200, 200, 210)
        btn.Font = Enum.Font.GothamMedium; btn.TextSize = 12
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.BorderSizePixel = 0; btn.Parent = tabsBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, -16, 1, -16); page.Position = UDim2.new(0, 8, 0, 8)
        page.BackgroundTransparency = 1; page.BorderSizePixel = 0
        page.ScrollBarThickness = 10
        page.ScrollBarImageColor3 = Color3.fromRGB(0, 140, 200)
        page.ScrollingDirection = Enum.ScrollingDirection.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.ClipsDescendants = true; page.Active = true
        page.Elasticity = 0.1; page.ScrollingEnabled = true
        page.Visible = false; page.Parent = content
        local l = Instance.new("UIListLayout")
        l.Padding = UDim.new(0, 6); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent = page
        local p = Instance.new("UIPadding")
        p.PaddingTop = UDim.new(0, 4); p.PaddingBottom = UDim.new(0, 20)
        p.PaddingRight = UDim.new(0, 12); p.Parent = page
        table.insert(pageOrder, {btn = btn, page = page, name = name})
        pages[name] = {btn = btn, page = page}
        return page
    end

    local function activate(name)
        for _, p in pairs(pages) do
            p.page.Visible = false
            p.btn.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
            p.btn.TextColor3 = Color3.fromRGB(200, 200, 210)
        end
        if pages[name] then
            pages[name].page.Visible = true
            pages[name].btn.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
            pages[name].btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
    for _, p in ipairs(pageOrder) do p.btn.MouseButton1Click:Connect(function() activate(p.name) end) end

    local function nextOrder(parent)
        local c = (parent:GetAttribute("_wOrder") or 0) + 1
        parent:SetAttribute("_wOrder", c); return c
    end

    local function makeToggle(parent, label, default, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34); row.LayoutOrder = nextOrder(parent)
        row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        row.BorderSizePixel = 0; row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -70, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label; lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
        lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 44, 0, 20); toggle.Position = UDim2.new(1, -54, 0.5, -10)
        toggle.BackgroundColor3 = default and Color3.fromRGB(0, 160, 100) or Color3.fromRGB(50, 50, 65)
        toggle.Text = ""; toggle.BorderSizePixel = 0; toggle.ZIndex = 2; toggle.Parent = row
        Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 10)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0; knob.Parent = toggle
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local enabled = default
        local function set(v)
            enabled = v
            toggle.BackgroundColor3 = v and Color3.fromRGB(0, 160, 100) or Color3.fromRGB(50, 50, 65)
            knob:TweenPosition(v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8), "Out", "Quad", 0.15, true)
            if callback then
                local ok, err = pcall(callback, v)
                if not ok then warn("[PLS Farm] toggle '"..label.."': "..tostring(err)) end
            end
        end
        toggle.MouseButton1Click:Connect(function() set(not enabled) end)
        return row
    end

    local function makeInput(parent, label, default, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34); row.LayoutOrder = nextOrder(parent)
        row.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
        row.BorderSizePixel = 0; row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 120, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label; lbl.TextColor3 = Color3.fromRGB(210, 210, 220)
        lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = row
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -140, 0, 22); box.Position = UDim2.new(0, 130, 0, 6)
        box.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        box.Text = tostring(default or "")
        box.TextColor3 = Color3.fromRGB(230, 230, 240)
        box.PlaceholderText = "..."
        box.Font = Enum.Font.Gotham; box.TextSize = 12
        box.BorderSizePixel = 0; box.ClearTextOnFocus = false; box.Parent = row
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 8); p.PaddingRight = UDim.new(0, 8); p.Parent = box
        box.FocusLost:Connect(function()
            if callback then
                local ok, err = pcall(callback, box.Text)
                if not ok then warn("[PLS Farm] input '"..label.."': "..tostring(err)) end
            end
        end)
        return row, box
    end

    local function makeButton(parent, label, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32); btn.LayoutOrder = nextOrder(parent)
        btn.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
        btn.Text = label; btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamMedium; btn.TextSize = 12
        btn.BorderSizePixel = 0; btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(function()
            local ok, err = pcall(callback)
            if not ok then warn("[PLS Farm] button '"..label.."': "..tostring(err)) end
        end)
        return btn
    end

    local farmPage = addPage("Farm", "🌾")
    makeToggle(farmPage, "Auto Claim Booth", CFG.autoClaimBooth, function(v) CFG.autoClaimBooth = v end)
    makeToggle(farmPage, "Auto Server Hop", CFG.autoHop, function(v) CFG.autoHop = v end)
    makeInput(farmPage, "Hop After (sec)", CFG.hopAfterNoDonation, function(v) CFG.hopAfterNoDonation = tonumber(v) or 90 end)
    makeToggle(farmPage, "Anti-AFK", CFG.antiAFK, function(v) CFG.antiAFK = v end)
    makeButton(farmPage, "Hop Now", hopServer)
    makeButton(farmPage, "Claim Booth Now", function() CFG.autoClaimBooth = true; claimBooth() end)

    local chatPage = addPage("Chat", "💬")
    makeToggle(chatPage, "Auto Beg", CFG.autoBeg, function(v) CFG.autoBeg = v; if v then startBeg() end end)
    makeInput(chatPage, "Beg Message", CFG.begMessage, function(v) CFG.begMessage = v end)
    makeInput(chatPage, "Beg Interval", CFG.begInterval, function(v) CFG.begInterval = tonumber(v) or 30 end)
    makeToggle(chatPage, "Auto Thanks", CFG.autoThanks, function(v) CFG.autoThanks = v end)
    makeInput(chatPage, "Thanks Msg", CFG.thanksMessage, function(v) CFG.thanksMessage = v end)
    makeToggle(chatPage, "Chat Spam", CFG.chatSpam, function(v) CFG.chatSpam = v; if v then startSpam() end end)
    makeInput(chatPage, "Spam Message", CFG.spamMessage, function(v) CFG.spamMessage = v end)
    makeInput(chatPage, "Spam Interval", CFG.spamInterval, function(v) CFG.spamInterval = tonumber(v) or 2 end)
    makeToggle(chatPage, "Art Paste", CFG.artPaste, function(v) CFG.artPaste = v; if v then startArt() end end)

    local boothPage = addPage("Booth", "🏪")
    makeToggle(boothPage, "Booth Text Edit", CFG.boothTextEdit, function(v) CFG.boothTextEdit = v end)
    makeInput(boothPage, "Booth Text", CFG.boothTextValue, function(v) CFG.boothTextValue = v end)
    makeToggle(boothPage, "Auto Redeem", CFG.autoRedeem, function(v) CFG.autoRedeem = v end)
    makeButton(boothPage, "Redeem Now", tryRedeem)
    makeToggle(boothPage, "Fake Donate Visual", CFG.fakeDonate, function(v) CFG.fakeDonate = v end)
    makeInput(boothPage, "Fake Amount", CFG.fakeDonateAmount, function(v) CFG.fakeDonateAmount = tonumber(v) or 100 end)
    makeButton(boothPage, "Trigger Fake Donate (self)", function() spawnFakeDonate(CFG.fakeDonateAmount) end)

    local fxPage = addPage("Effects", "✨")
    makeToggle(fxPage, "Effects Enabled", CFG.effectsEnabled, function(v) CFG.effectsEnabled = v end)
    makeInput(fxPage, "Blimp threshold", CFG.effectBlimpAt, function(v) CFG.effectBlimpAt = tonumber(v) or 10000 end)
    makeInput(fxPage, "Nuke threshold", CFG.effectNukeAt, function(v) CFG.effectNukeAt = tonumber(v) or 100000 end)
    makeInput(fxPage, "Smite threshold", CFG.effectSmiteAt, function(v) CFG.effectSmiteAt = tonumber(v) or 1000000 end)
    makeButton(fxPage, "Preview Blimp", function() triggerEffect("blimp", 10000, player.Name) end)
    makeButton(fxPage, "Preview Nuke", function() triggerEffect("nuke", 100000, player.Name) end)
    makeButton(fxPage, "Preview Smite", function() triggerEffect("smite", 1000000, player.Name) end)

    local prankPage = addPage("Prank", "🎭")
    makeInput(prankPage, "Victim Name", CFG.prankVictim, function(v) CFG.prankVictim = v end)
    makeInput(prankPage, "Amount", CFG.prankAmount, function(v) CFG.prankAmount = tonumber(v) or 10000 end)
    makeInput(prankPage, "Template (1-4)", CFG.prankTemplate, function(v) CFG.prankTemplate = tonumber(v) or 1 end)
    makeButton(prankPage, "Send Fake Donation Chat", firePrankChat)
    makeToggle(prankPage, "Loop Prank", CFG.prankLoop, function(v)
        CFG.prankLoop = v
        if v then startPrankLoop() end
    end)
    makeInput(prankPage, "Loop Interval (sec)", CFG.prankLoopInterval, function(v) CFG.prankLoopInterval = tonumber(v) or 20 end)
    makeButton(prankPage, "Try Fire Donation Remote", tryFakeDonationRemote)
    makeButton(prankPage, "Preview Template 1", function() notify("T1", "[DONATION] Victim donated 10,000 R$ to You!") end)
    makeButton(prankPage, "Preview Template 2", function() notify("T2", "🎁 Victim just donated 10,000 R$ to You") end)
    makeButton(prankPage, "Preview Template 3", function() notify("T3", "💰 Donation received: Victim → You (10,000 R$)") end)
    makeButton(prankPage, "Preview Template 4", function() notify("T4", "✅ Victim tipped 10,000 R$ — tysm!") end)

    local hookPage = addPage("Webhook", "🔔")
    makeInput(hookPage, "URL", CFG.webhookURL, function(v) CFG.webhookURL = v end)
    makeToggle(hookPage, "Enable", CFG.webhookOn, function(v) CFG.webhookOn = v end)
    makeButton(hookPage, "Test Webhook", function() sendWebhook("Test Ping", "PLS Donate Farm connected.", 0x00BFFF) end)

    local perfPage = addPage("Perf", "⚙️")
    makeToggle(perfPage, "FPS Cap", CFG.fpsCapEnabled, function(v) CFG.fpsCapEnabled = v end)
    makeInput(perfPage, "FPS Target", CFG.fpsCap, function(v) CFG.fpsCap = tonumber(v) or 30 end)
    makeToggle(perfPage, "Disable Rendering", CFG.disableRendering, function(v) CFG.disableRendering = v; applyRender() end)
    makeButton(perfPage, "Apply Render", applyRender)

    local adminPage = addPage("Admin", "🛡️")
    local _, cmdBox = makeInput(adminPage, "Command", CFG.lastCommand, function(v) CFG.lastCommand = v end)
    makeButton(adminPage, "Execute Command", function() executeAdminCommand(cmdBox.Text or CFG.lastCommand) end)
    makeButton(adminPage, ":heal", function() executeAdminCommand(":heal") end)
    makeButton(adminPage, ":god", function() executeAdminCommand(":god") end)
    makeButton(adminPage, ":fly", function() executeAdminCommand(":fly") end)
    makeButton(adminPage, ":unfly", function() executeAdminCommand(":unfly") end)
    makeButton(adminPage, ":speed 50", function() executeAdminCommand(":speed 50") end)
    makeButton(adminPage, ":noclip", function() executeAdminCommand(":noclip") end)
    makeButton(adminPage, ":rejoin", function() executeAdminCommand(":rejoin") end)

    local dragging, dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = holder.Position
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local d = input.Position - dragStart
            holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)

    local minimized = false
    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        holder.Size = minimized and UDim2.new(0, 520, 0, 36) or UDim2.new(0, 520, 0, 400)
        tabsBar.Visible = not minimized
        content.Visible = not minimized
        minimize.Text = minimized and "+" or "–"
        recomputeScale()
    end)
    close.MouseButton1Click:Connect(function() gui:Destroy() end)

    activate("Farm")
    notify("PLS Donate Farm", "v2.3 · "..tostring(player.Name))
end

buildGUI()

task.spawn(function()
    task.wait(3)
    if CFG.autoRedeem then pcall(tryRedeem) end
end)

print("[PLS Donate Farm v2.3] loaded for "..player.Name.." · job "..game.JobId)
