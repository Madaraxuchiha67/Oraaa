local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

repeat task.wait() until Players.LocalPlayer

local player = Players.LocalPlayer
local success, result = pcall(function()
    return player:GetMouse()
end)

local mouse = success and result or nil

-- ============================================================
--  OBSIDIAN UI (deividcomsono/Obsidian)
--  A small helper layer below maps Tabs.X:AddToggle / AddSlider /
--  AddDropdown ... onto Obsidian groupboxes.
-- ============================================================
local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local ObsidianWindow = Library:CreateWindow({
    Title = "Aotr:update5",
    Footer = "Attack on Titan: Revolution",
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(640, 480),
    Center = true,
    AutoShow = true,
})

local Notifier = {}
function Notifier:Notify(o)
    pcall(function()
        Library:Notify({
            Title = o.Title or "",
            Description = o.Content or "",
            Time = o.Duration or 4,
        })
    end)
end

-- Tab wrapper -> Obsidian tab. Each AddSection() starts a new groupbox,
-- alternating left/right. Controls added before any section go in a groupbox
-- named after the tab.
local function MakeTab(rawTab, title)
    local tab = { _tab = rawTab, _count = 0, _box = nil }

    local function newBox(name)
        tab._count += 1
        if tab._count % 2 == 1 then
            tab._box = rawTab:AddLeftGroupbox(name)
        else
            tab._box = rawTab:AddRightGroupbox(name)
        end
        return tab._box
    end
    local function box() return tab._box or newBox(title) end
    local function note(o)
        if o.Description and o.Description ~= "" then box():AddLabel(o.Description, true) end
    end

    function tab:AddSection(name) newBox(name) end

    function tab:AddToggle(idx, o)
        local t = box():AddToggle(idx, { Text = o.Title, Default = o.Default or false, Callback = o.Callback })
        note(o)
        return t
    end

    function tab:AddSlider(idx, o)
        local s = box():AddSlider(idx, {
            Text = o.Title, Default = o.Default, Min = o.Min, Max = o.Max,
            Rounding = o.Rounding or 0, Callback = o.Callback,
        })
        note(o)
        return s
    end

    function tab:AddDropdown(idx, o)
        local multi = o.Multi == true
        local info = { Text = o.Title, Values = o.Values or {}, Multi = multi, Callback = o.Callback }
        if not multi then info.Default = o.Default end
        local dd = box():AddDropdown(idx, info)
        if multi and type(o.Default) == "table" then
            local map = {}
            for k, v in pairs(o.Default) do
                if type(k) == "number" then map[v] = true elseif v then map[k] = true end
            end
            if next(map) then pcall(function() dd:SetValue(map) end) end
        end
        note(o)
        return dd
    end

    function tab:AddInput(idx, o)
        return box():AddInput(idx, {
            Text = o.Title, Default = o.Default or "", Placeholder = o.Placeholder or "",
            Numeric = o.Numeric or false, Finished = o.Finished or false, Callback = o.Callback,
        })
    end

    function tab:AddButton(o)
        local b = box():AddButton({ Text = o.Title, Func = o.Callback })
        note(o)
        return b
    end

    function tab:AddColorpicker(idx, o)
        local lbl = box():AddLabel(o.Title or "Color")
        local picker = lbl:AddColorPicker(idx, { Default = o.Default or Color3.new(1, 1, 1), Title = o.Title })
        local wrap = { _p = picker }
        function wrap:OnChanged(fn)
            pcall(function() picker:OnChanged(fn) end)
        end
        function wrap:SetValueRGB(c)
            local ok = pcall(function() picker:SetValueRGB(c) end)
            if not ok then
                pcall(function() picker:SetValue({ Color3.toHSV(c) }) end)
            end
        end
        return wrap
    end

    -- Paragraph -> wrapped label (keeps :SetDesc / .DescLabel for the Account tab).
    function tab:AddParagraph(o)
        local ttl, content = o.Title or "", o.Content or ""
        local function render(c)
            if ttl == "" then return c end
            if c:find("\n") or #c > 40 then return ttl .. "\n" .. c end
            return ttl .. ": " .. c
        end
        local lbl = box():AddLabel(render(content), true)
        local p = { DescLabel = lbl and lbl.TextLabel }
        function p:SetDesc(c) pcall(function() lbl:SetText(render(tostring(c))) end) end
        function p:SetTitle(t) ttl = t end
        return p
    end

    return tab
end

local Window = {}
Window.Root = setmetatable({}, {
    __index = function(_, k) if k == "Visible" then return Library.Toggled end end,
    __newindex = function(_, k, v)
        if k == "Visible" and Library.Toggled ~= v then pcall(function() Library:Toggle() end) end
    end,
})
function Window:AddTab(o)
    local raw
    local icon = (o.Icon and o.Icon ~= "") and o.Icon or nil
    local ok = pcall(function() raw = ObsidianWindow:AddTab(o.Title, icon) end)
    if not ok or not raw then raw = ObsidianWindow:AddTab(o.Title) end
    return MakeTab(raw, o.Title)
end
function Window:Minimize(force)
    pcall(function()
        if force == true then
            if Library.Toggled then Library:Toggle() end
        else
            Library:Toggle()
        end
    end)
end
function Window:SelectTab(tab) pcall(function() tab._tab:Show() end) end

local TrayIcon = {}
TrayIcon.isVisible = true
TrayIcon.connection = nil

function TrayIcon:CreateIcon()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TrayIconGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "TrayIcon"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(1, -60, 0, 10)
    iconFrame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = iconFrame

    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.Position = UDim2.new(0, 0, 0, 0)
    iconText.BackgroundTransparency = 1
    iconText.Text = "A"
    iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconText.TextScaled = true
    iconText.Font = Enum.Font.GothamBold
    iconText.Parent = iconFrame

    local hoverTween = nil
    iconFrame.MouseEnter:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(16, 110, 190)}
        )
        hoverTween:Play()
    end)

    iconFrame.MouseLeave:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 50, 0, 50), BackgroundColor3 = Color3.fromRGB(0, 120, 212)}
        )
        hoverTween:Play()
    end)

    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.Position = UDim2.new(0, 0, 0, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = iconFrame

    clickDetector.MouseButton1Click:Connect(function()
        self:ToggleUI()
        local clickTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {Size = UDim2.new(0, 45, 0, 45)}
        )
        clickTween:Play()
        clickTween.Completed:Connect(function()
            local returnTween = TweenService:Create(iconFrame,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                {Size = UDim2.new(0, 50, 0, 50)}
            )
            returnTween:Play()
        end)
    end)

    self.gui = screenGui
    self.frame = iconFrame
    self.text = iconText
    self:CreateTooltip()
end

function TrayIcon:CreateTooltip()
    local tooltip = Instance.new("Frame")
    tooltip.Name = "Tooltip"
    tooltip.Size = UDim2.new(0, 200, 0, 30)
    tooltip.Position = UDim2.new(1, -210, 0.5, -15)
    tooltip.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    tooltip.BorderSizePixel = 0
    tooltip.Visible = false
    tooltip.Parent = self.frame

    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 5)
    tooltipCorner.Parent = tooltip

    local tooltipText = Instance.new("TextLabel")
    tooltipText.Size = UDim2.new(1, -10, 1, 0)
    tooltipText.Position = UDim2.new(0, 5, 0, 0)
    tooltipText.BackgroundTransparency = 1
    tooltipText.Text = "Click to toggle UI visibility"
    tooltipText.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltipText.TextScaled = true
    tooltipText.Font = Enum.Font.Gotham
    tooltipText.Parent = tooltip

    self.frame.MouseEnter:Connect(function() tooltip.Visible = true end)
    self.frame.MouseLeave:Connect(function() tooltip.Visible = false end)
end

function TrayIcon:ToggleUI()
    if self.isVisible then self:HideUI() else self:ShowUI() end
end

function TrayIcon:HideUI()
    if Window and Window.Root then
        Window.Root.Visible = false
        self.isVisible = false
        self.text.Text = "H"
        self.frame.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        Notifier:Notify({ Title = "UI Hidden", Content = "Click the tray icon to show UI again", Duration = 3 })
    end
end

function TrayIcon:ShowUI()
    if Window and Window.Root then
        Window.Root.Visible = true
        self.isVisible = true
        self.text.Text = "A"
        self.frame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
        Notifier:Notify({ Title = "UI Shown", Content = "UI is now visible", Duration = 2 })
    end
end

TrayIcon:CreateIcon()

--//==============================\\--
--||         TABS SETUP           ||--
--\\==============================//--

local EarlyAccountTab = Window:AddTab({ Title = "Account", Icon = "user" })

local Tabs = {
    Main          = Window:AddTab({ Title = "Main(Risky)",               Icon = "swords" }),
    AutoJoin      = Window:AddTab({ Title = "Auto Join",                 Icon = "door-open" }),
    Servers       = Window:AddTab({ Title = "Servers",                   Icon = "server" }),
    Misc          = Window:AddTab({ Title = "Misc",                      Icon = "wrench" }),
    Esp           = Window:AddTab({ Title = "Titans Esp",                Icon = "eye" }),
    Webhook       = Window:AddTab({ Title = "Webhook",                   Icon = "webhook" }),
    Settings      = Window:AddTab({ Title = "Settings",                  Icon = "settings" }),
}

--//==============================\\--
--||         SETTINGS TAB         ||--
--\\==============================//--

Tabs.Settings:AddToggle("TrayIconToggle", {
    Title = "Show Tray Icon",
    Description = "Show/Hide the system tray icon",
    Default = true,
    Callback = function(state)
        if TrayIcon.gui then TrayIcon.gui.Enabled = state end
    end
})

Tabs.Settings:AddParagraph({
    Title = "Tray Icon Usage",
    Content = "• The tray icon appears in the top-right corner\n• Click it to hide/show the UI\n• Red icon = UI hidden, Blue icon = UI visible\n• Ctrl+H (keyboard) or double-tap the screen (mobile) also toggles the UI"
})

--//==============================\\--
--||       MAINMENU (PlaceId)     ||--
--\\==============================//--

local allowedPlaceId = 13379208636
if game.PlaceId == allowedPlaceId then
    Tabs.Mainmenu = Window:AddTab({ Title = "Mainmenu", Icon = "house" })
    Tabs.Mainmenu:AddToggle("AutoRollToggle", {
        Title = "Auto Roll",
        Default = false,
        Callback = function(state) ENABLED = state end
    })
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        TrayIcon:ToggleUI()
    end
end)

game.Players.PlayerRemoving:Connect(function(plr)
    if plr == player and TrayIcon.gui then TrayIcon.gui:Destroy() end
end)

--------------------------------------------------------------------------

local HttpService     = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInput    = game:GetService("VirtualInputManager")
local GuiService      = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local char = player.Character or player.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")

local retryRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

local isFlying   = false
local bodyPos
local LocalPlayer = Players.LocalPlayer
local startDelay  = 0
local flyHeight   = 250

--//==============================\\--
--||      👑 AUTO KILL TITANS     ||--
--\\==============================//--

local Services = {
    Players         = game:GetService("Players"),
    RunService      = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    TweenService    = game:GetService("TweenService"),
    CoreGui         = game:GetService("CoreGui")
}

local Player = {
    self      = Services.Players.LocalPlayer,
    character = nil,
    hrp       = nil,
    gui       = nil
}

local Config = {
    flySpeed              = 250,
    canHit                = true,
    isFlying              = false,
    moveMode              = "Teleportation",
    notificationsEnabled  = true,
    startDelay            = 0,
    flyHeight             = 250,
    titanKillCount        = 0,
    autoRefill            = false,
    lastBladesEmpty       = false,
    lastSpearsEmpty       = false
}

local Data = {
    notified    = {},
    activeNotifs = {},
    POST        = nil,
    refill      = nil
}

Player.character = Player.self.Character or Player.self.CharacterAdded:Wait()
Player.hrp       = Player.character:WaitForChild("HumanoidRootPart")
Player.gui       = Player.self:WaitForChild("PlayerGui")

task.spawn(function()
    local success2, result2 = pcall(function()
        return Services.ReplicatedStorage:WaitForChild("Assets", 10):WaitForChild("Remotes", 10):WaitForChild("POST", 10)
    end)
    Data.POST = success2 and result2 or nil
end)

function showKillNotification(count)
    if not Config.notificationsEnabled then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TN_" .. tick()
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = Services.CoreGui
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 190, 0, 75)
    frame.Position = UDim2.new(1, 20, 0, 10 + (#Data.activeNotifs * 80))
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(184, 164, 101)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "Successfully\nHit:"
    label.TextColor3 = Color3.fromRGB(184, 164, 101)
    label.Font = Enum.Font.Fantasy
    label.TextScaled = true
    local counter = Instance.new("TextLabel", frame)
    counter.Size = UDim2.new(0, 60, 0.5, 0)
    counter.Position = UDim2.new(1, -65, 0, 0)
    counter.BackgroundTransparency = 1
    counter.Text = tostring(count)
    counter.TextColor3 = Color3.fromRGB(255, 255, 255)
    counter.Font = Enum.Font.Fantasy
    counter.TextScaled = true
    table.insert(Data.activeNotifs, gui)
    Services.TweenService:Create(frame, TweenInfo.new(0.35), {
        Position = UDim2.new(1, -210, 0, 10 + ((#Data.activeNotifs - 1) * 80))
    }):Play()
    task.delay(5, function()
        gui:Destroy()
        for i, v in ipairs(Data.activeNotifs) do
            if v == gui then table.remove(Data.activeNotifs, i) break end
        end
    end)
end

local TITAN_PRIORITY = { "Attack_Titan", "Female_Titan", "Armored_Titan" }

local function napeOf(titan)
    local hb = titan:FindFirstChild("Hitboxes")
    local hit = hb and hb:FindFirstChild("Hit")
    return hit and hit:FindFirstChild("Nape")
end

local function isAlive(titan)
    local h = titan:FindFirstChildWhichIsA("Humanoid")
    return h and h.Health > 0
end

-- keep the character reference fresh after respawn (the old code kept a dead HRP)
Player.self.CharacterAdded:Connect(function(c)
    Player.character = c
    Player.hrp = c:WaitForChild("HumanoidRootPart")
end)

local targetList, lastScan = {}, 0

local function scanTargets()
    table.clear(targetList)
    local folder = workspace:FindFirstChild("Titans")
    if not folder or not Player.hrp then return end
    local pos = Player.hrp.Position
    for _, name in ipairs(TITAN_PRIORITY) do
        local t = folder:FindFirstChild(name)
        if t and isAlive(t) then
            local n = napeOf(t)
            if n then targetList[#targetList + 1] = n end
        end
    end
    local others = {}
    for _, t in ipairs(folder:GetChildren()) do
        if not table.find(TITAN_PRIORITY, t.Name) and isAlive(t) then
            local n = napeOf(t)
            if n then others[#others + 1] = { n, (pos - n.Position).Magnitude } end
        end
    end
    table.sort(others, function(a, b) return a[2] < b[2] end)
    for _, o in ipairs(others) do targetList[#targetList + 1] = o[1] end
end

-- target list is rebuilt at most 10x/second instead of every frame
function getClosestValidNape()
    local first = targetList[1]
    if os.clock() - lastScan > 0.1 or not first or not first.Parent then
        scanTargets()
        lastScan = os.clock()
    end
    return targetList[1]
end

Config.hitCooldown = 0.12   -- seconds between hit bursts (was 0.25)
Config.multiHit    = 8      -- napes hit per burst (was 3)
Config.hitAll      = false  -- true = every alive titan gets hit in the same burst

local killConnection
local killStartAt = 0

Config.baseStartDelay = 5   -- fixed 5 second wait before farming begins (slider adds on top)

function killFromAbove()
    killStartAt = os.clock() + Config.baseStartDelay + Config.startDelay
    if killConnection then return end -- one connection only (old code stacked a new one on every toggle)
    killConnection = Services.RunService.Heartbeat:Connect(function()
        if not Config.isFlying or Config.missionDone or os.clock() < killStartAt then return end
        local hrp = Player.hrp
        if not hrp or not hrp.Parent then return end
        local nape = getClosestValidNape()
        if not nape then return end
        local targetPos = nape.Position + Vector3.new(0, Config.flyHeight, 0)
        if Config.moveMode == "Gliding" then
            local delta = targetPos - hrp.Position
            if delta.Magnitude > 1 then hrp.AssemblyLinearVelocity = delta.Unit * Config.flySpeed end
        else
            hrp.CFrame = CFrame.new(targetPos)
        end
        if Config.canHit and (hrp.Position - nape.Position).Magnitude <= 1520 then
            Config.canHit = false
            task.spawn(function()
                local post = Data.POST
                local count = Config.hitAll and #targetList or math.min(Config.multiHit, #targetList)
                for i = 1, count do
                    local n = targetList[i]
                    if n and n.Parent then
                        if post then
                            post:FireServer("Hitboxes", "Register", n, math.random(200, 300), math.random(20, 30) / 100)
                            post:FireServer("Attacks", "Slash", true)
                        end
                        local id = tostring(n:GetDebugId())
                        if not Data.notified[id] then
                            Data.notified[id] = true
                            Config.titanKillCount = Config.titanKillCount + 1
                            showKillNotification(Config.titanKillCount)
                        end
                    end
                end
                if Config.onKillBurst then task.spawn(Config.onKillBurst) end
                task.wait(Config.hitCooldown)
                Config.canHit = true
            end)
        end
    end)
end

--//==============================\\--
--||   👑 REFILL / RELOAD SYSTEM  ||--
--\\==============================//--

local BladeUI_S2       = nil
local Gradient_S2      = nil
local SetsLabel_S2     = nil
local autoBladeRunning = false

pcall(function()
    BladeUI_S2    = player.PlayerGui.Interface.HUD.Main.Top["7"].Blades
    Gradient_S2   = BladeUI_S2.Inner.Bar.Gradient
    SetsLabel_S2  = BladeUI_S2.Sets
end)

local function TweenTo_S2(cf, speed)
    local charRef = player.Character if not charRef then return end
    local hrpRef  = charRef:FindFirstChild("HumanoidRootPart")
    local humRef  = charRef:FindFirstChild("Humanoid")
    if not hrpRef or not humRef or humRef.Health <= 0 then return end
    local distance = (hrpRef.Position - cf.Position).Magnitude
    local t        = distance / speed
    local tween    = TweenService:Create(hrpRef, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    tween:Play()
    return tween
end

local refillParts, refillScanAt = nil, 0

local function FindRefillPart()
    -- scan the whole workspace once, then only re-check the cached parts
    local stale = os.clock() - refillScanAt
    if not refillParts or stale > 30 or (#refillParts == 0 and stale > 3) then
        refillParts = {}
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                local name = v.Name:lower()
                if name:find("refill") or name:find("fill") then
                    refillParts[#refillParts + 1] = v
                end
            end
        end
        refillScanAt = os.clock()
    end
    for _, v in ipairs(refillParts) do
        if v.Parent then
            local display = v:FindFirstChild("Display")
            if display then
                local ok, title = pcall(function() return display.Main.Top.Title.Text end)
                if ok and title ~= "REFILLS: 0 / 3 [R]" then return v end
            end
        end
    end
    return nil
end

local function Refill_S2()
    local refillPart = FindRefillPart()
    if not refillPart then return end
    TweenTo_S2(refillPart.CFrame, 6000)
    pcall(function()
        ReplicatedStorage.Assets.Remotes.POST:FireServer("Attacks", "Reload", refillPart)
    end)
end

local function ChangeBlade_S2()
    pcall(function()
        ReplicatedStorage.Assets.Remotes.GET:InvokeServer("Blades", "Reload")
    end)
end

local function CheckBlade_S2()
    if not Gradient_S2 then return false end
    local x = Gradient_S2.Offset.X
    if x < 0 then
        local bladeOk = false
        pcall(function()
            local rig = workspace.Characters[player.Name]["Rig_" .. player.Name]
            local blade = rig.LeftHand.Blade_1
            if blade.Transparency == 0 then bladeOk = true end
        end)
        if bladeOk then return false end
        if SetsLabel_S2 and SetsLabel_S2.Text == "0 / 3" then
            Refill_S2()
        else
            ChangeBlade_S2()
        end
        return true
    end
    return false
end

if Gradient_S2 then
    Gradient_S2:GetPropertyChangedSignal("Offset"):Connect(function()
        if autoBladeRunning then CheckBlade_S2() end
    end)
end

local bladeLoopToken = 0
local function StartBladeLoop()
    bladeLoopToken = bladeLoopToken + 1
    local my = bladeLoopToken
    autoBladeRunning = true
    task.spawn(function()
        while autoBladeRunning and bladeLoopToken == my do
            CheckBlade_S2()
            task.wait(0.2)
        end
    end)
end

Tabs.Main:AddSection("Auto Farm")

local BladeToggle = Tabs.Main:AddToggle("AutoBladeReload", {
    Title = "Auto Reload / Refill Blades",
    Description = "Switches blade sets automatically; teleports to refill station when all sets are empty",
    Default = true,
    Callback = function(state)
        if state then
            StartBladeLoop()
        else
            autoBladeRunning = false
            bladeLoopToken = bladeLoopToken + 1
        end
    end
})
-- callbacks don't fire on creation, so start it for the default-on state
if BladeToggle.Value then StartBladeLoop() end

--//==============================\\--
--||        👑 AUTO CLICK M1       ||--
--\\==============================//--

local autoM1Running = false
local autoM1Token   = 0
local M1_DELAY       = 0.25
local M1Toggle

local RESULT_TITLES_M1 = { ["MISSION COMPLETED"] = true, ["RAID COMPLETED"] = true }

local function GuiVisibleM1(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function MissionCompleted()
    local ok, res = pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return false end
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = tostring(d.Text or ""):gsub("<[^>]->", "")
                t = t:gsub("^%s+", ""):gsub("%s+$", "")
                if RESULT_TITLES_M1[t:upper()] and GuiVisibleM1(d) then return true end
            end
        end
        return false
    end)
    return ok and res
end

--//==============================\\--
--||     SLOW LAND AFTER MISSION  ||--
--\\==============================//--

Config.missionDone = false
Config.landSpeed   = 15   -- studs per second (lower = slower)

do
    local landed = false

    -- watch for the MISSION / RAID COMPLETED screen (polled, not every frame)
    task.spawn(function()
        while true do
            local done = MissionCompleted()
            if done and not Config.missionDone then
                Config.missionDone = true
                landed = false
            elseif not done and Config.missionDone then
                Config.missionDone = false  -- new mission / retry: farm resumes
                killStartAt = os.clock() + Config.baseStartDelay + Config.startDelay
                landed = false
            end
            task.wait(0.5)
        end
    end)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true

    RunService.Heartbeat:Connect(function(dt)
        if not Config.missionDone or landed then return end
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end

        local ignore = { char }
        local titans = workspace:FindFirstChild("Titans")
        local chars  = workspace:FindFirstChild("Characters")
        if titans then ignore[#ignore + 1] = titans end
        if chars  then ignore[#ignore + 1] = chars  end
        rayParams.FilterDescendantsInstances = ignore

        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -5000, 0), rayParams)
        if not hit then landed = true return end -- nothing below: let normal physics take over

        -- stand height = ground + hip height + half the root part (never lower than this = no clipping)
        local standY = hit.Position.Y + hum.HipHeight + hrp.Size.Y / 2 + 0.2
        local y = hrp.Position.Y

        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        if y <= standY + 0.3 then
            landed = true
            return
        end

        local newY = math.max(standY, y - Config.landSpeed * dt)
        local pos  = hrp.Position
        hrp.CFrame = CFrame.new(pos.X, newY, pos.Z) * (hrp.CFrame - hrp.CFrame.Position)
    end)
end

local cachedAttackBtn
local function FindAttackButton()
    if cachedAttackBtn and cachedAttackBtn.Parent and cachedAttackBtn.Visible then return cachedAttackBtn end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local n = d.Name:lower()
            if n == "attack" or n == "m1" or n == "slash" then cachedAttackBtn = d return d end
        end
    end
    return nil
end

local function ClickM1()
    -- real mouse click in the screen centre (M1)
    pcall(function()
        local cam = workspace.CurrentCamera
        local size = cam and cam.ViewportSize or Vector2.new(800, 600)
        local x, y = size.X / 2, size.Y / 2
        VirtualInput:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    -- on-screen attack button (mobile layout), if one exists
    pcall(function()
        local btn = FindAttackButton()
        if btn then
            if firesignal then
                firesignal(btn.MouseButton1Down)
                firesignal(btn.MouseButton1Up)
                firesignal(btn.MouseButton1Click)
                firesignal(btn.Activated)
            else
                local pos, sz = btn.AbsolutePosition, btn.AbsoluteSize
                local inset = GuiService:GetGuiInset()
                local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.03)
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end
        end
    end)
end

-- M1 no longer spams on its own: it only clicks when Auto Kill actually fires a hit burst
local M1Enabled = true
local lastM1 = 0

Config.onKillBurst = function()
    if not M1Enabled then return end
    if os.clock() - lastM1 < M1_DELAY then return end
    lastM1 = os.clock()
    ClickM1()
end

M1Toggle = Tabs.Main:AddToggle("AutoClickM1", {
    Title = "Auto Click M1 (only while killing)",
    Description = "Clicks M1 only when Auto Kill is hitting titans. Follows the Auto Kill switch",
    Default = true,
    Callback = function(state)
        M1Enabled = state and true or false
    end
})
if M1Toggle and M1Toggle.Value ~= nil then M1Enabled = M1Toggle.Value and true or false end

local KillToggle = Tabs.Main:AddToggle("AutoKillTitans", {
    Title = "Auto Kill Titans",
    Description = "Don't Finish the mission under 17 sec",
    Default = true,
    Callback = function(state)
        Config.isFlying = state
        if state then task.spawn(killFromAbove) end
        -- M1 setting turns on/off together with Auto Kill
        if M1Toggle and M1Toggle.SetValue then pcall(function() M1Toggle:SetValue(state and true or false) end) end
    end
})
if KillToggle.Value then Config.isFlying = true task.spawn(killFromAbove) end

--//==============================\\--
--||   SMOOTH CAMERA WHILE FARMING ||--
--\\==============================//--
-- Keeps your camera angle fixed and only glides the camera position after
-- you, so the view doesn't whip around when Auto Kill teleports you.

Config.lockCamera = true

do
    local SMOOTHNESS = 10      -- higher = camera catches up faster
    local locked, savedType, savedRot, dist = false, nil, nil, 20

    local function farming()
        return Config.lockCamera and Config.isFlying and not Config.missionDone
            and os.clock() >= killStartAt
    end

    RunService:BindToRenderStep("AotrSmoothCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
        local cam = workspace.CurrentCamera
        local root = Player.hrp
        if not cam then return end

        if farming() and root and root.Parent then
            if not locked then
                locked    = true
                savedType = cam.CameraType
                savedRot  = cam.CFrame.Rotation
                dist      = math.clamp((cam.CFrame.Position - root.Position).Magnitude, 8, 40)
                cam.CameraType = Enum.CameraType.Scriptable
            end
            local goal  = root.Position - savedRot.LookVector * dist
            local alpha = 1 - math.exp(-SMOOTHNESS * dt)
            cam.CFrame  = CFrame.new(cam.CFrame.Position:Lerp(goal, alpha)) * savedRot
        elseif locked then
            locked = false
            cam.CameraType = savedType or Enum.CameraType.Custom
        end
    end)
end

Tabs.Main:AddToggle("SmoothCameraLock", {
    Title = "Smooth Camera While Farming",
    Description = "Keeps the camera angle steady and follows you smoothly instead of snapping around",
    Default = true,
    Callback = function(state) Config.lockCamera = state and true or false end
})

Tabs.Main:AddDropdown("MoveMode", {
    Title = "Movement Mode",
    Values = {"Teleportation", "Gliding"},
    Default = 1,
    Callback = function(option) Config.moveMode = option end
})

Tabs.Main:AddSlider("StartDelaySlider", {
    Title = "Farm Delay",
    Description = "Extra seconds added on top of the fixed 5 second start delay",
    Default = 0,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = function(value) Config.startDelay = value end
})

Tabs.Main:AddSlider("LandSpeedSlider", {
    Title = "Landing Speed (after mission)",
    Description = "How slowly you descend once the mission is complete",
    Default = 15,
    Min = 5,
    Max = 60,
    Rounding = 0,
    Callback = function(value) Config.landSpeed = value end
})

Tabs.Main:AddSlider("FlySpeedSlider", {
    Title = "Gliding Speed",
    Default = 300,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.flySpeed = value end
})

Tabs.Main:AddSlider("FlyHeightSlider", {
    Title = "Float Height",
    Default = 250,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(value) Config.flyHeight = value end
})

Tabs.Main:AddSlider("HitSpeedSlider", {
    Title = "Hit Interval (ms) - lower = faster",
    Default = 120,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.hitCooldown = value / 1000 end
})

Tabs.Main:AddSlider("MultiHitSlider", {
    Title = "Titans Hit Per Burst",
    Default = 8,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(value) Config.multiHit = value end
})

Tabs.Main:AddToggle("HitAllTitans", {
    Title = "Hit All Titans At Once",
    Description = "Every alive titan gets hit in the same burst (ignores Titans Hit Per Burst)",
    Default = false,
    Callback = function(state) Config.hitAll = state end
})

local _Remotes = game:GetService("ReplicatedStorage").Assets.Remotes
local GET, POST = _Remotes.GET, _Remotes.POST

--//==============================\\--
--||        👑 AUTO Retry         ||--
--\\==============================//--

local VIM = game:GetService("VirtualInputManager")

local interface = player:FindFirstChild("PlayerGui")
    and player.PlayerGui:FindFirstChild("Interface")

local rewards     = interface and interface:FindFirstChild("Rewards")
local rewardsMain = rewards and rewards:FindFirstChild("Main")
local retryBtn    = rewardsMain
    and rewardsMain:FindFirstChild("Info")
    and rewardsMain.Info:FindFirstChild("Main")
    and rewardsMain.Info.Main:FindFirstChild("Buttons")
    and rewardsMain.Info.Main.Buttons:FindFirstChild("Retry")

local autoRetryEnabled = false

local function showDebugDot(x, y)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, x - 5, 0, y - 5)
    dot.BackgroundColor3 = Color3.new(1, 0, 0)
    dot.BorderSizePixel = 0
    dot.ZIndex = 10000
    dot.Name = "DebugDot"
    pcall(function() dot.Parent = game:GetService("CoreGui") end)
    game:GetService("Debris"):AddItem(dot, 2)
end

local function Retryshi()
    local pos  = retryBtn.AbsolutePosition
    local size = retryBtn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2 + 20
    local y
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        y = pos.Y + size.Y / 2 + 60
    else
        y = pos.Y + size.Y / 2 + inset.Y
    end
    showDebugDot(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function shouldClickRetry()
    return retryBtn
        and rewards and rewards.Visible
        and rewardsMain and rewardsMain.Visible
        and retryBtn.Visible
        and retryBtn.AbsoluteSize.Magnitude > 10
end

task.spawn(function()
    while true do
        if autoRetryEnabled and shouldClickRetry() then
            task.wait(0.3)
            if shouldClickRetry() then
                Retryshi()
                task.wait(2)
            end
        end
        task.wait(0.25)
    end
end)

Tabs.Main:AddSection("Utilities")

Tabs.Main:AddToggle("AutoRetryToggle", {
    Title = "Auto Retry",
    Default = false,
    Callback = function(state) autoRetryEnabled = state end
})

--//==============================\\--
--||     AUTO SKIP CUTSCENES      ||--
--\\==============================//--

local autoSkipRunning = false
local autoSkipToken   = 0
local skipClickedAt   = setmetatable({}, { __mode = "k" })

local function SkipGuiShown(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function LooksLikeSkip(btn)
    if btn.Name:lower():find("skip", 1, true) then return true end
    if btn:IsA("TextButton") then
        local t = btn.Text:gsub("<[^>]->", ""):lower()
        if t:find("skip", 1, true) then return true end
    end
    for _, c in ipairs(btn:GetChildren()) do -- label sitting inside an ImageButton
        if c:IsA("TextLabel") then
            local t = c.Text:gsub("<[^>]->", ""):lower()
            if t:find("skip", 1, true) then return true end
        end
    end
    return false
end

local function PressButton(btn)
    local fired = false
    if getconnections then
        for _, sig in ipairs({ btn.MouseButton1Down, btn.MouseButton1Up, btn.MouseButton1Click, btn.Activated }) do
            pcall(function()
                for _, c in ipairs(getconnections(sig)) do
                    c:Fire()
                    fired = true
                end
            end)
        end
    end
    if not fired and firesignal then
        pcall(function()
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
            fired = true
        end)
    end
    if not fired then -- last resort: a real click on the button
        local pos, sz = btn.AbsolutePosition, btn.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
        VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end
end

local function SkipCutscenesOnce()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.AbsoluteSize.X > 0 and d.AbsoluteSize.Y > 0
            and LooksLikeSkip(d) and SkipGuiShown(d) then
            local last = skipClickedAt[d]
            if not last or os.clock() - last > 1.5 then
                skipClickedAt[d] = os.clock()
                PressButton(d)
                return
            end
        end
    end
end

local function StartSkipLoop()
    autoSkipToken += 1
    local my = autoSkipToken
    autoSkipRunning = true
    task.spawn(function()
        while autoSkipRunning and autoSkipToken == my do
            pcall(SkipCutscenesOnce)
            task.wait(0.5)
        end
    end)
end

local SkipToggle = Tabs.Main:AddToggle("AutoSkipCutscenes", {
    Title = "Auto Skip Cutscenes",
    Description = "Presses the Skip button as soon as a cutscene shows one",
    Default = true,
    Callback = function(state)
        if state then
            StartSkipLoop()
        else
            autoSkipRunning = false
            autoSkipToken += 1
        end
    end
})
if SkipToggle.Value then StartSkipLoop() end

--//==============================\\--
--||        👑 AUTO Escape        ||--
--\\==============================//--

local escapeRunning    = false
local escapeThread     = nil
local cleanGUIThread   = nil
local lastEscapeButton = nil

Tabs.Main:AddToggle("Escape", {
    Title = "Auto Escape",
    Default = false,
    Callback = function(Value)
        escapeRunning = Value
        if not Value then lastEscapeButton = nil return end
        escapeThread = task.spawn(function()
            local pg = player:WaitForChild("PlayerGui")
            while escapeRunning do
                local iface   = pg:FindFirstChild("Interface")
                local buttons = iface and iface:FindFirstChild("Buttons")
                if buttons then
                    local list = buttons:GetChildren()
                    if #list > 0 then
                        POST:FireServer("Attacks", "Slash_Escape")
                        for _, b in ipairs(list) do b:Destroy() end
                    end
                end
                task.wait(0.05)
            end
        end)
    end
})

--//==============================\\--
--||         👑 Auto Roll         ||--
--\\==============================//--

local CLICK_DELAY = 0.2
local WAIT_DELAY  = 1
local ENABLED     = false

local function canClick(btn)
    return btn and btn.Visible and btn.AbsoluteSize.Magnitude > 10
end

local function isActuallyVisible(obj)
    if not obj then return false end
    local current = obj
    local Gui = player:WaitForChild("PlayerGui")
    while current and current ~= Gui do
        local success3, result3 = pcall(function() return current.Visible end)
        if success3 and not result3 then return false end
        current = current.Parent
    end
    return obj.AbsoluteSize.Magnitude > 10
end

local function clickButton(btn)
    if not btn then return false end
    local pos  = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2
    local y = pos.Y + size.Y / 2 + inset.Y
    VIM:SendMouseMoveEvent(x, y, game)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    return true
end

local function findButton(parent, buttonName)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj.Name == buttonName and obj:IsA("GuiButton") then return obj end
        for _, child in pairs(obj:GetChildren()) do
            local result4 = searchRecursive(child)
            if result4 then return result4 end
        end
        return nil
    end
    return searchRecursive(parent)
end

local function findButtonByText(parent, text)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj:IsA("GuiButton") or obj:IsA("TextButton") then
            local hasText = obj:FindFirstChild("Text") or obj.Text
            if hasText and string.find(string.lower(tostring(hasText)), string.lower(text)) then return obj end
        end
        for _, child in pairs(obj:GetChildren()) do
            local result5 = searchRecursive(child)
            if result5 then return result5 end
        end
        return nil
    end
    return searchRecursive(parent)
end

task.spawn(function()
    local Gui = player:WaitForChild("PlayerGui")
    local interface2 = Gui:WaitForChild("Interface", 10)
    if not interface2 then return end
    local rollButton = nil
    local searchPaths = {"Customisation.Family.Buttons_2.Roll", "Roll", "RollButton"}
    for _, path in pairs(searchPaths) do
        local pathParts = string.split(path, ".")
        local current = interface2
        for _, part in pairs(pathParts) do
            if current then current = current:FindFirstChild(part) end
        end
        if current and current:IsA("GuiButton") then rollButton = current break end
    end
    if not rollButton then rollButton = findButton(interface2, "Roll") end
    if not rollButton then rollButton = findButtonByText(interface2, "roll") end
    if not rollButton then return end
    while true do
        if ENABLED then
            if canClick(rollButton) and isActuallyVisible(rollButton) then
                clickButton(rollButton)
                task.wait(CLICK_DELAY)
            else task.wait(WAIT_DELAY) end
        else task.wait(1) end
    end
end)

--//==============================\\--
--||        AUTO JOIN TAB         ||--
--\\==============================//--

local Difficulties      = {"Best For You","Easy","Normal","Hard","Severe","Aberrant"}
local DifficultiesRaids = {"Best For You","Hard","Severe","Aberrant"}
local ModifiersList     = {"No Perks","No Skills","No Memories","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"}
local MissionMaps       = {"Shiganshina","Trost","Outskirts","Forest","Utgard","Docks","Stohess","Chapel"}
local MissionObjectives = {
    ["Shiganshina"]={"Skirmish","Breach","Random"},
    ["Trost"]      ={"Skirmish","Protect","Random"},
    ["Outskirts"]  ={"Skirmish","Escort","Random"},
    ["Forest"]     ={"Skirmish","Guard","Random"},
    ["Utgard"]     ={"Skirmish","Defend","Random"},
    ["Docks"]      ={"Skirmish","Stall","Random"},
    ["Stohess"]    ={"Skirmish","Random"},
    ["Chapel"]     ={"Skirmish","Random"},
}
local RaidMaps      = {"Shiganshina","Trost","Stohess"}
local RaidObjectives= {["Shiganshina"]={"Armored Titan","Colossal Titan"},["Trost"]={"Attack Titan"},["Stohess"]={"Female Titan"}}
local WaveMaps      = {"Trost"}

_G.AJ = {
    SelectMissionMap        = MissionMaps[1],
    SelectMissionObjective  = MissionObjectives[MissionMaps[1]][1],
    SelectMissionDifficulty = "Easy",
    SelectMissionModifiers  = {},
    SelectRaidMap           = RaidMaps[1],
    SelectRaidObjective     = RaidObjectives[RaidMaps[1]][1],
    SelectRaidDifficulty    = "Easy",
    SelectRaidModifiers     = {},
    SelectWaveMap           = WaveMaps[1],
    AutoJoinMission         = false,
    AutoJoinMissionBoost    = false,
    AutoJoinRaid            = false,
    AutoJoinWaves           = false,
}

local function PressButton(d)
    game:GetService("GuiService").SelectedObject = d
    VIM:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end

local function CreateAndStart(data)
    if game.PlaceId == 14916516914 then
        local ok, res = pcall(function() return GET:InvokeServer("S_Missions","Create",data) end)
        if ok and typeof(res) == "Instance" then
            task.wait(1)
            pcall(function() return GET:InvokeServer("S_Missions","Start") end)
            return true
        end
        return false
    end
end

-- Mission section
Tabs.AutoJoin:AddSection("Auto Join Missions")

local MissionObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_MissionMap", {
    Title = "Select Map",
    Values = MissionMaps,
    Default = _G.AJ.SelectMissionMap,
    Callback = function(v)
        _G.AJ.SelectMissionMap = v
        local objs = MissionObjectives[v]
        if objs then _G.AJ.SelectMissionObjective = objs[1] end
        if MissionObjectiveDropdown2 then MissionObjectiveDropdown2:SetValues(MissionObjectives[v] or {}) end
    end
})

MissionObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_MissionObjective", {
    Title = "Select Objective",
    Values = MissionObjectives[_G.AJ.SelectMissionMap] or {},
    Default = _G.AJ.SelectMissionObjective,
    Callback = function(v) _G.AJ.SelectMissionObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionDifficulty", {
    Title = "Select Difficulty",
    Values = Difficulties,
    Default = _G.AJ.SelectMissionDifficulty,
    Callback = function(v) _G.AJ.SelectMissionDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectMissionModifiers,
    Callback = function(v) _G.AJ.SelectMissionModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMission", {
    Title = "Auto Join Mission",
    Description = "Automatically joins missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMission = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission then
            CreateAndStart({Name=_G.AJ.SelectMissionMap,Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMissionBoost", {
    Title = "Auto Join Mission (Rewards Boost)",
    Description = "Automatically joins boosted missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMissionBoost = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMissionBoost then
            CreateAndStart({Name=game:GetService("Workspace"):GetAttribute("Boosted_Map"),Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

-- Raids section
Tabs.AutoJoin:AddSection("Auto Join Raids")

local RaidObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_RaidMap", {
    Title = "Select Raid Map",
    Values = RaidMaps,
    Default = _G.AJ.SelectRaidMap,
    Callback = function(v)
        _G.AJ.SelectRaidMap = v
        local objs = RaidObjectives[v]
        if objs then _G.AJ.SelectRaidObjective = objs[1] end
        if RaidObjectiveDropdown2 then RaidObjectiveDropdown2:SetValues(RaidObjectives[v] or {}) end
    end
})

RaidObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_RaidObjective", {
    Title = "Select Raid Boss",
    Values = RaidObjectives[_G.AJ.SelectRaidMap] or {},
    Default = _G.AJ.SelectRaidObjective,
    Callback = function(v) _G.AJ.SelectRaidObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidDifficulty", {
    Title = "Select Difficulty",
    Values = DifficultiesRaids,
    Default = _G.AJ.SelectRaidDifficulty,
    Callback = function(v) _G.AJ.SelectRaidDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectRaidModifiers,
    Callback = function(v) _G.AJ.SelectRaidModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinRaid", {
    Title = "Auto Join Raid",
    Description = "Automatically joins raids",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinRaid = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinRaid then
            CreateAndStart({Name=_G.AJ.SelectRaidMap,Type="Raids",Difficulty=_G.AJ.SelectRaidDifficulty,Objective=_G.AJ.SelectRaidObjective,Modifiers=_G.AJ.SelectRaidModifiers,Limit=8})
        end
    end
end)

-- Waves section
Tabs.AutoJoin:AddSection("Auto Join Waves")

Tabs.AutoJoin:AddDropdown("AJ_WaveMap", {
    Title = "Select Wave Map",
    Values = WaveMaps,
    Default = _G.AJ.SelectWaveMap,
    Callback = function(v) _G.AJ.SelectWaveMap = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinWaves", {
    Title = "Auto Join Waves",
    Description = "Automatically joins waves",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinWaves = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinWaves then
            CreateAndStart({Name=_G.AJ.SelectWaveMap,Type="Waves",Difficulty="Easy",Objective="Waves",Limit=8})
        end
    end
end)

-- Leave wrong mission auto-correct
spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission or _G.AJ.AutoJoinRaid or _G.AJ.AutoJoinWaves then
            for _, v in pairs(game:GetService("ReplicatedStorage").Missions:GetChildren()) do
                if v.Leader.Value == player.Name then
                    local Target = nil
                    if _G.AJ.AutoJoinMission then Target = _G.AJ.SelectMissionMap
                    elseif _G.AJ.AutoJoinMissionBoost then Target = game:GetService("Workspace"):GetAttribute("Boosted_Map")
                    elseif _G.AJ.AutoJoinRaid then Target = _G.AJ.SelectRaidMap
                    elseif _G.AJ.AutoJoinWaves then Target = _G.AJ.SelectWaveMap end
                    if v.Name ~= Target then
                        GET:InvokeServer("S_Missions","Leave")
                    end
                end
            end
        end
    end
end)

--//==============================\\--
--||        SERVERS TAB           ||--
--\\==============================//--

local TPS = TeleportService

Tabs.Servers:AddSection("Server")

Tabs.Servers:AddInput("JobIDInput", {
    Title = "JobID",
    Placeholder = "Paste Job ID here",
    Callback = function(x) _G.JobId_Textbox = x end
})

Tabs.Servers:AddToggle("AutoJoinJobID", {
    Title = "Auto Join JobID",
    Default = false,
    Callback = function(v)
        _G.AutoJoinJobID = v
        if v then
            task.spawn(function()
                while _G.AutoJoinJobID do
                    if _G.JobId_Textbox and _G.JobId_Textbox ~= "" then
                        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
                        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
                    else
                        warn("Please enter a JobID before enabling Auto Join JobID")
                        _G.AutoJoinJobID = false break
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Join JobID",
    Callback = function()
        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
    end
})

Tabs.Servers:AddButton({
    Title = "Copy JobID",
    Callback = function()
        setclipboard(game.JobId)
        Notifier:Notify({ Title="Aotr:update5", Content="Copied JobID!", Duration=3 })
    end
})

Tabs.Servers:AddSection("Basic")

Tabs.Servers:AddButton({
    Title = "Rejoin",
    Description = "Re-enter the same server",
    Callback = function() TeleportService:Teleport(game.PlaceId, player) end
})

getgenv().ServerHop = function()
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local data = HttpService:JSONDecode(game:HttpGet(url))
    for _, v in ipairs(data.data or {}) do
        if v.playing < v.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, Players.LocalPlayer) return
        end
    end
end

Tabs.Servers:AddButton({
    Title = "Server Hop",
    Description = "Move to new server",
    Callback = function() getgenv().ServerHop() end
})

Tabs.Servers:AddSection("Smart Server")

Tabs.Servers:AddSlider("MaxPlayersFilter", {
    Title = "Max Players Filter",
    Min = 1,
    Max = 20,
    Default = 5,
    Rounding = 0,
    Callback = function(v) _G.SetP = v end
})

Tabs.Servers:AddButton({
    Title = "Smart Hop",
    Description = "Find server with fewest players",
    Callback = function()
        local limit = _G.SetP
        local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
        for _, v in ipairs(body.data or {}) do
            if v.playing <= limit then TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, player) break end
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Low Ping Hop",
    Description = "Find lowest ping server",
    Callback = function()
        pcall(function()
            local bestServer, lowestPing = nil, math.random(50, 200)
            local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
            for _, v in ipairs(body.data or {}) do
                local ping = tonumber(v.ping)
                if ping and ping < lowestPing then lowestPing = ping bestServer = v.id end
            end
            if bestServer then TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(bestServer), player) end
        end)
    end
})

--//==============================\\--
--||           MISC TAB           ||--
--\\==============================//--

getgenv().AutoHideAfterDelay = false

Tabs.Misc:AddSection("Interface")

Tabs.Misc:AddToggle("AutoHideAfter10s", {
    Title = "Auto Hide UI (5s)",
    Default = false,
    Callback = function(state)
        getgenv().AutoHideAfterDelay = state
        if state then
            task.delay(5, function()
                if not getgenv().AutoHideAfterDelay then return end
                getgenv().AutoHideUI = true
                Window:Minimize(true)
            end)
        end
    end
})

local lastTap = 0
local function toggleUI()
    Window:Minimize()
end

UserInputService.TouchTap:Connect(function(_, gameProcessed)
    if gameProcessed then return end
    local now = tick()
    if now - lastTap <= 0.4 then toggleUI() end
    lastTap = now
end)

Tabs.Misc:AddToggle("ToggleNotifications", {
    Title = "Notifications",
    Default = false,
    Callback = function(value) Config.notificationsEnabled = value end
})

Tabs.Misc:AddSection("Game")

local delaySeconds = 180
local toggleActive = false

Tabs.Misc:AddToggle("ForceRetryToggle", {
    Title = "Fail Safe",
    Default = false,
    Callback = function(state)
        toggleActive = state
        if state then
            task.delay(delaySeconds, function()
                if toggleActive then
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            end)
        end
    end
})

-- Auto Force Retry: fires 15s after the MISSION / RAID COMPLETED screen appears
do
    local AUTO_FORCE_RETRY_DELAY = 15
    local autoForceRetry = true
    Tabs.Misc:AddToggle("AutoForceRetry15", {
        Title = "Auto Force Retry (15s)",
        Description = "Automatically Force Retry 15 seconds after a mission is completed.",
        Default = true,
        Callback = function(state) autoForceRetry = state end
    })
    task.spawn(function()
        local shownAt, fired = nil, false
        while true do
            task.wait(0.5)
            if autoForceRetry and MissionCompleted() then
                shownAt = shownAt or os.clock()
                if not fired and os.clock() - shownAt >= AUTO_FORCE_RETRY_DELAY then
                    fired = true
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            else
                shownAt, fired = nil, false
            end
        end
    end)
end

-- Damage Text
local iface2 = player:WaitForChild("PlayerGui"):WaitForChild("Interface")
local damageConnection

Tabs.Misc:AddToggle("dmg", {
    Title = "Remove Dmg Text",
    Default = false,
    Callback = function(state)
        if state then
            for _, obj in pairs(iface2:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end
            damageConnection = iface2.DescendantAdded:Connect(function(obj)
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end)
        else
            if damageConnection then damageConnection:Disconnect() damageConnection = nil end
        end
    end
})

-- Teleport buttons
local lobbyPlaceId    = 14916516914
local mainMenuPlaceId = 13379208636

Tabs.Misc:AddSection("Teleport")

Tabs.Misc:AddButton({
    Title = "Return to Lobby",
    Callback = function() TeleportService:Teleport(lobbyPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Return to Main Menu",
    Callback = function() TeleportService:Teleport(mainMenuPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Force Retry",
    Callback = function()
        local ok, err = pcall(function()
            retryRemote:InvokeServer("Functions", "Retry", "Add")
        end)
        if not ok then warn(".") end
    end,
})

--//==============================\\--
--||   MISSION LIMIT -> LOBBY     ||--
--\\==============================//--
-- Counts finished missions/raids (MISSION / RAID COMPLETED screen) and
-- teleports you back to the Lobby once the limit is reached.
do
    local limitOn, limit, done = false, 10, 0

    Tabs.Misc:AddSection("Mission Limit")

    local counter = Tabs.Misc:AddParagraph({ Title = "Missions done", Content = "0 / 10" })
    local function refresh() counter:SetDesc(done .. " / " .. limit) end

    Tabs.Misc:AddToggle("MissionLimitToggle", {
        Title = "Return to Lobby after X missions",
        Description = "Teleports you to the Lobby when the mission limit is reached.",
        Default = false,
        Callback = function(state)
            limitOn = state
            done = 0
            refresh()
        end
    })

    Tabs.Misc:AddSlider("MissionLimitSlider", {
        Title = "Mission Limit",
        Min = 10,
        Max = 50,
        Default = 10,
        Rounding = 0,
        Callback = function(v)
            limit = math.floor(v)
            refresh()
        end
    })

    task.spawn(function()
        local wasDone = false
        while true do
            task.wait(0.5)
            if game.PlaceId == lobbyPlaceId or game.PlaceId == mainMenuPlaceId then
                wasDone = false
                continue
            end
            local nowDone = MissionCompleted()
            if nowDone and not wasDone then
                wasDone = true
                if limitOn then
                    done += 1
                    refresh()
                    if done >= limit then
                        Notifier:Notify({
                            Title = "Mission Limit",
                            Content = "Reached " .. limit .. " missions. Returning to Lobby...",
                            Duration = 4,
                        })
                        task.wait(3)
                        done = 0
                        refresh()
                        pcall(function() TeleportService:Teleport(lobbyPlaceId, player) end)
                    end
                end
            elseif not nowDone then
                wasDone = false
            end
        end
    end)
end

--//==============================\\--
--||            👑 ESP            ||--
--\\==============================//--

local ESPEnabled = false
local ESPColor   = Color3.fromRGB(96, 205, 255)
local ESPSize    = Vector3.new(50, 50, 50)

local function createNapeESP(nape)
    if not nape:FindFirstChild("NapeESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name        = "NapeESP"
        esp.Adornee     = nape
        esp.AlwaysOnTop = true
        esp.ZIndex      = 5
        esp.Size        = ESPSize
        esp.Transparency = 0.5
        esp.Color3      = ESPColor
        esp.Parent      = nape
    end
end

local function applyNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit  = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:IsA("BasePart") then createNapeESP(nape) end
            end
        end
    end
end

local function removeAllNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:FindFirstChild("NapeESP") then nape.NapeESP:Destroy() end
            end
        end
    end
end

local function updateNapeESPColor()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then
                    local esp = nape:FindFirstChild("NapeESP")
                    if esp then esp.Color3 = ESPColor end
                end
            end
        end
    end
end

local titansFolderEsp = workspace:FindFirstChild("Titans")
if titansFolderEsp then
    titansFolderEsp.ChildAdded:Connect(function(titan)
        if not ESPEnabled then return end
        task.wait(0.5)
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then createNapeESP(nape) end
            end
        end
    end)
end

Tabs.Esp:AddToggle("NapeESP", {
    Title = "Enable Nape ESP",
    Default = false,
    Callback = function(value)
        ESPEnabled = value
        if value then applyNapeESP() else removeAllNapeESP() end
    end
})

local Colorpicker = Tabs.Esp:AddColorpicker("ESPColorPicker", {
    Title = "ESP Color",
    Default = ESPColor
})

Colorpicker:OnChanged(function(newColor)
    ESPColor = newColor
    updateNapeESPColor()
end)

Colorpicker:SetValueRGB(Color3.fromRGB(96, 205, 255))

-- ============================================================
--  Account / Webhook
--  Logic is copied verbatim from the original; only the UI layer is Obsidian.
-- ============================================================
do
local okMod, errMod = pcall(function()

-- ---------- compat layer (replaces Smooth Hub globals the extracted code expects) ----------
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local IN_MENU = (game.PlaceId == 13379208636)
local modToken = {}
_G.AotrUpdate5ModToken = modToken
local function Alive() return _G.AotrUpdate5ModToken == modToken end
local SH = { DEV = false }
function SH.say(...) print("[Aotr:update5]", ...) end
function SH.dbg(...) if SH.DEV then print(...) end end
function SH.Guard(name, fn)
    local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
    if not ok then warn("[Aotr:update5] block " .. tostring(name) .. " failed to load: " .. tostring(err)) end
end
function SH.PlayOn() return true end
local Farm = {}
SH.Farm = Farm
function Farm.CanUseHere()
    return not IN_MENU and game.PlaceId ~= 14916516914
end
local Cfg = {
    AutoFarmThunder = false,
    UseThunderSpears = false,
}
local function Save() end
-- thunder-spear counter (verbatim from Smooth Hub; the "stuck" detector belongs to its farm loop and is not included)
    local function SpearsLeft()
        local char = LocalPlayer.Character
        local n = char and char:GetAttribute("Spears")
        if type(n) == "number" then return n end
        return nil
    end
Farm.SpearsLeft = SpearsLeft
local function IsShown(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return obj:IsA("GuiObject") and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end

-- tiny file store for the Webhook tab (own file, never mixed into configs)
local SettingsStore = {}
do
    local DIR = "Aotr_update5/" .. tostring(LocalPlayer.UserId)
    local function Path(file) return DIR .. "/" .. file .. ".json" end
    function SettingsStore.Load(file)
        local data = {}
        pcall(function()
            if isfile and readfile and isfile(Path(file)) then
                local d = HttpService:JSONDecode(readfile(Path(file)))
                if type(d) == "table" then data = d end
            end
        end)
        return data
    end
    function SettingsStore.Write(file, data)
        pcall(function()
            if not (writefile and makefolder) then return end
            if isfolder and not isfolder("Aotr_update5") then makefolder("Aotr_update5") end
            if isfolder and not isfolder(DIR) then makefolder(DIR) end
            writefile(Path(file), HttpService:JSONEncode(data))
        end)
    end
    function SettingsStore.Restore(target, data)
        if type(data) ~= "table" then return end
        for k, v in pairs(data) do
            if target[k] ~= nil and type(target[k]) == type(v) then target[k] = v end
        end
    end
end

-- paragraph -> object with a .Text setter
local function MakeLabel(para)
    local obj = { __instance = para and para.DescLabel }
    return setmetatable(obj, { __newindex = function(_, k, v)
        if k == "Text" then pcall(function() para:SetDesc(tostring(v)) end) end
    end })
end


local AccountTab = EarlyAccountTab
local WebhookTab = Tabs.Webhook
Tabs.Account = AccountTab


-- ================== ACCOUNT TAB ==================
AccountTab:AddSection("📊 Account Overview")
AccountTab:AddParagraph({ Title = "Info", Content = "Read from your player data. N/A = this value was not found." })
local ReplicatedStorageSvc = game:GetService("ReplicatedStorage")
local function FindGui(path)
    local cur = PlayerGui
    for seg in path:gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end
local function CountShards()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    local total = 0
    for _, c in ipairs(items:GetChildren()) do
        if c.Name:lower():find("shard", 1, true) then
            local q = 1
            local label = c:FindFirstChild("Quantity", true)
            if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
                q = tonumber((label.Text:gsub("[^%d]", ""))) or 1
            end
            total += q
        end
    end
    return total
end
local function CurrentFamily()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    for _, c in ipairs(items:GetChildren()) do
        local id, name = c.Name:match("^(%d+)%s*%-%s*(.+)$")
        if id and tonumber(id) % 100 == 2 then
            local main = c:FindFirstChild("Main")
            local eq = main and main:FindFirstChild("Equipped")
            if eq and eq:IsA("GuiObject") and eq.Visible then
                local check = eq:FindFirstChild("Checkmark")
                local on = true
                if check and check:IsA("ImageLabel") and check.ImageTransparency >= 1 then on = false end
                if on then return name end
            end
        end
    end
    return "None"
end
local function AttrTrue(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local x = v:lower()
        return x == "true" or x == "yes" or x == "1"
    end
    return false
end
local hiddenLabelCache, hiddenLabelAt = nil, 0
local function FindWarningLabel()
    if os.clock() - hiddenLabelAt < 15 then return hiddenLabelCache end
    hiddenLabelAt = os.clock()
    hiddenLabelCache = false
    local n = 0
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        n += 1
        if n % 600 == 0 then task.wait() end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = (d.Text or ""):lower()
            if t:find("exploiter", 1, true) or t:find("shadow ban", 1, true) or t:find("shadowban", 1, true) then
                hiddenLabelCache = d:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", "")
                break
            end
        end
    end
    return hiddenLabelCache
end
local function ShadowStatus()
    if FindWarningLabel() then return "✅" end
    if AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted")) then
        return "✅"
    end
    return "❌"
end
local function FlagCompare()
    local others, flagged = 0, 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            others += 1
            if AttrTrue(plr:GetAttribute("Exploiter")) or AttrTrue(plr:GetAttribute("Blacklisted")) then
                flagged += 1
            end
        end
    end
    local mine = (AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted"))) and "flagged" or "clear"
    return ("You: %s | Others flagged: %d/%d"):format(mine, flagged, others)
end
local FIELDS = {
    { key = "ShadowBan", title = "🛠️ Shadow Ban", raw = true, aliases = {}, calc = ShadowStatus,
      colors = { ["✅"] = Color3.fromRGB(80, 200, 120), ["❌"] = Color3.fromRGB(235, 87, 87) } },
    { key = "FlagCompare", title = "🔍 Flag Compare", raw = true, aliases = {}, calc = FlagCompare },
    { key = "Blacklisted", title = "🚫 Blacklisted", flag = true, aliases = { "blacklisted" } },
    { key = "Exploiter", title = "⚠️ Exploiter Flag", flag = true, aliases = { "exploiter" } },
    { key = "Level",     title = "▶️ Level",    aliases = { "level", "lvl", "playerlevel" } },
    { key = "XP",        title = "📈 XP",       aliases = {}, strip = "^XP:%s*",
      gui = "Interface.Gear_Up.XP.Percentage" },
    { key = "Prestige",  title = "🔺 Prestige", aliases = { "prestige", "prestigelevel" } },
    { key = "Gold",      title = "💰 Gold",     aliases = { "gold", "coins", "money" },
      gui = "Interface.Topbar.Main.Currencies.Gold.Amount" },
    { key = "Gems",      title = "💎 Gems",     aliases = { "gems", "gem" },
      gui = "Interface.Topbar.Main.Currencies.Gems.Amount" },
    { key = "Family",    title = "⚡ Family",   aliases = { "family", "familyname", "clan" }, calc = CurrentFamily },
    { key = "Title",     title = "🏷️ Title",    aliases = { "title" }, pretty = true },
    { key = "Shards",    title = "✨ Shards",   aliases = { "shards", "shard" }, calc = CountShards },
}
for _, f in ipairs(FIELDS) do
    local para = AccountTab:AddParagraph({ Title = f.title, Content = "..." })
    f.label = MakeLabel(para)
    f.last = nil
end
local function NormName(s)
    return (tostring(s):lower():gsub("[^%w]", ""))
end
local function Fmt(v)
    if type(v) == "number" then
        if v ~= math.floor(v) then return string.format("%.2f", v) end
        local s = tostring(math.floor(v))
        local neg = s:sub(1, 1) == "-"
        if neg then s = s:sub(2) end
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end
    return tostring(v)
end
local function Truthy(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower()
        return s == "true" or s == "yes" or s == "1"
    end
    return false
end
local dataRoots = { LocalPlayer }
local lastRootScan = 0
local function ScanRoots(force)
    if not force and os.clock() - lastRootScan < 15 then return end
    lastRootScan = os.clock()
    local roots = { LocalPlayer }
    local uid = tostring(LocalPlayer.UserId)
    local n = 0
    for _, d in ipairs(ReplicatedStorageSvc:GetDescendants()) do
        n += 1
        if n % 500 == 0 then task.wait() end
        if d.Name == LocalPlayer.Name or d.Name == uid then
            table.insert(roots, d)
        end
    end
    dataRoots = roots
end
local SKIP_NAMES = { PlayerGui = true, PlayerScripts = true }
local function CollectEntries()
    local entries = {}
    local function keep(v)
        local t = type(v)
        return t == "number" or t == "string" or t == "boolean"
    end
    local function walk(inst, depth)
        pcall(function()
            for k, v in pairs(inst:GetAttributes()) do
                if keep(v) then
                    entries[#entries + 1] = { name = k, value = v, path = inst:GetFullName() .. " @" .. k }
                end
            end
            if inst:IsA("ValueBase") then
                local ok, v = pcall(function() return inst.Value end)
                if ok and keep(v) then
                    entries[#entries + 1] = { name = inst.Name, value = v, path = inst:GetFullName() }
                end
            end
        end)
        if depth >= 6 then return end
        for _, c in ipairs(inst:GetChildren()) do
            if not SKIP_NAMES[c.Name] then walk(c, depth + 1) end
        end
    end
    for _, root in ipairs(dataRoots) do
        if root and root.Parent then walk(root, 0) end
    end
    return entries
end
local function IsExcludedPath(path)
    return path:find("%.Boosts") ~= nil or path:find("%.Gamepasses") ~= nil
end
local function LookupField(entries, field)
    for _, alias in ipairs(field.aliases) do
        for _, e in ipairs(entries) do
            if NormName(e.name) == alias and not IsExcludedPath(e.path) then
                return e.value
            end
        end
    end
    return nil
end
local function ReadGui(path)
    local cur = FindGui(path)
    if cur and (cur:IsA("TextLabel") or cur:IsA("TextButton")) then
        local t = (cur.Text or ""):gsub("<[^>]->", "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then return t end
    end
    return nil
end
local function LabelObject(label)
    local inst = label and label.__instance
    if not inst then return nil end
    if inst:IsA("TextLabel") then return inst end
    return inst:FindFirstChildWhichIsA("TextLabel", true)
end
local lastEntries = {}
local function RefreshOverview()
    ScanRoots(false)
    local entries = CollectEntries()
    lastEntries = entries
    for _, f in ipairs(FIELDS) do
        local v
        if f.calc then
            local okC, r = pcall(f.calc)
            if okC then v = r end
        end
        if v == nil and f.gui then v = ReadGui(f.gui) end
        if v == nil then v = LookupField(entries, f) end
        local text
        if v == nil then
            text = "N/A"
        elseif f.raw then
            text = tostring(v)
        elseif f.flag then
            text = Truthy(v) and "⚠️ Yes" or "✅ No"
        elseif f.strip then
            text = (tostring(v):gsub(f.strip, ""))
        elseif f.pretty then
            text = (tostring(v):gsub("_", " "))
        else
            text = Fmt(v)
        end
        if text ~= f.last then
            f.last = text
            pcall(function() f.label.Text = text end)
            if f.colors and f.colors[text] then
                pcall(function()
                    local obj = LabelObject(f.label)
                    if obj then obj.TextColor3 = f.colors[text] end
                end)
            end
        end
    end
end
task.spawn(function()
    while Alive() do
        pcall(RefreshOverview)
        for _ = 1, 12 do
            if not Alive() then return end
            task.wait(0.25)
        end
    end
end)

-- ================== WEBHOOK (Rewards Logger) ==================
SH.Guard("webhook", function()

    local player = LocalPlayer

    local webhookURL = ""
    local sendWebhook = false
    local showUsername = true
    local thumbnailURL = "https://media.discordapp.net/attachments/1159475375752106086/1370816214242164836/image.png"

    -- Toggle to control whether webhook should be sent
    Tabs.Webhook:AddToggle("SendWebhookToggle", {
        Title = "Notify Webhook",
        Default = false,
        Callback = function(Value)
            sendWebhook = Value
        end
    })

    -- Toggle to display Roblox username
    Tabs.Webhook:AddToggle("DisplayUsernameToggle", {
        Title = "Display Roblox Username",
        Default = true,
        Callback = function(Value)
            showUsername = Value
        end
    })

    -- Input for the webhook URL
    Tabs.Webhook:AddInput("WebhookInput", {
        Title = "Webhook",
        Placeholder = "https://discord.com/api/webhooks/...",
        Finished = true,
        Callback = function(Value)
            webhookURL = Value
        end
    })

    -- Check visibility of GUI
    local function isActuallyVisible(instance)
        if not instance then return false end
        if not instance:IsDescendantOf(player.PlayerGui) then return false end
        while instance and instance ~= player.PlayerGui do
            if instance:IsA("GuiObject") and not instance.Visible then
                return false
            end
            instance = instance.Parent
        end
        return true
    end

    -- Get Retry button
    local function getRetryButton()
        local interface = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Interface")
        local rewards = interface and interface:FindFirstChild("Rewards")
        local rewardsMain = rewards and rewards:FindFirstChild("Main")
        local retryBtn = rewardsMain
            and rewardsMain:FindFirstChild("Info")
            and rewardsMain.Info:FindFirstChild("Main")
            and rewardsMain.Info.Main:FindFirstChild("Buttons")
            and rewardsMain.Info.Main.Buttons:FindFirstChild("Retry")
        return retryBtn
    end

    -- Get GUI text value
    local function getText(path)
        local node = player:FindFirstChild("PlayerGui")
        for _, part in ipairs(string.split(path, ".")) do
            if node then
                node = node:FindFirstChild(part)
            end
        end
        return node and node.Text or "0"
    end

    -- Get items and stats panels
    local function getItems()
        local gui = player:FindFirstChild("PlayerGui")
        local interface = gui and gui:FindFirstChild("Interface")
        local rewards = interface and interface:FindFirstChild("Rewards")
        local main = rewards and rewards:FindFirstChild("Main")
        local info = main and main:FindFirstChild("Info")
        local infoMain = info and info:FindFirstChild("Main")
        local items = infoMain and infoMain:FindFirstChild("Items")
        local stats = infoMain and infoMain:FindFirstChild("Stats")
        return items, stats
    end

    -- Loop check and send webhook
    local lastMissionTime = nil

    task.spawn(function()
        while Alive() do
            local retryBtn = getRetryButton()
            local items, stats = getItems()
            if isActuallyVisible(retryBtn) and stats and sendWebhook and webhookURL ~= "" then
                local currentTime = getText("Interface.Rewards.Main.Info.Main.Stats.Time_Taken.Amount")
                if currentTime ~= "0" and currentTime ~= lastMissionTime then
                    lastMissionTime = currentTime

                    local gold = getText("Interface.Rewards.Main.Info.Main.Items.Gold.Main.Inner.Quantity")
                    local xp = getText("Interface.Rewards.Main.Info.Main.Items.XP.Main.Inner.Quantity")
                    local bp_xp = getText("Interface.Rewards.Main.Info.Main.Items.BP_XP.Main.Inner.Quantity")
                    local gems = getText("Interface.Rewards.Main.Info.Main.Items.Gems.Main.Inner.Quantity")
                    local serum = getText("Interface.Rewards.Main.Info.Main.Items.Serum.Main.Inner.Quantity")
                    local common = getText("Interface.Rewards.Main.Info.Main.Items.Common_Perk.Main.Inner.Quantity")
                    local secret = getText("Interface.Rewards.Main.Info.Main.Items.Secret_Perk.Main.Inner.Quantity")
                    local epic = getText("Interface.Rewards.Main.Info.Main.Items.Epic_Perk.Main.Inner.Quantity")
                    local prestige = getText("Interface.Rewards.Main.Info.Main.Items.Prestige_Scroll.Main.Inner.Quantity")

                    local damage = getText("Interface.Rewards.Main.Info.Main.Stats.Damage_Dealt.Amount")
                    local kills = getText("Interface.Rewards.Main.Info.Main.Stats.Titans_Killed.Amount")
                    local crits = getText("Interface.Rewards.Main.Info.Main.Stats.Critical_Hits.Amount")

                    local timeString = os.date("%d-%b-%Y %I:%M %p")

                    local fields = {
                        {name = "**User:**", value = tostring(showUsername and player.Name or "Disabled"), inline = false},
                        {name = "**Stats:**", value = string.format(
                            "%s Time Taken\n%s Damage Dealt\n%s Titan Kills\n%s Critical Hits", currentTime, damage, kills, crits
                        ), inline = true},
                        {name = "**Rewards:**", value = string.format(
                            "%s Gold\n%s XP\n%s Gems", gold, xp, gems
                        ), inline = true},
                        {name = "**Drops:**", value = string.format(
                            "BP XP: %s\nCommon: %s\nSecret: %s\nEpic: %s\nPrestige: %s", bp_xp, common, secret, epic, prestige
                        ), inline = true},
                        {name = "**Special Rewards:**", value = string.format(
                            "Serum: %s", serum
                        ), inline = false}
                    }

                    local embed = {
                        title = "AOT:R Rewards Logger",
                        thumbnail = { url = thumbnailURL },
                        fields = fields,
                        footer = { text = "Sent at: " .. timeString }
                    }

                    local data = {
                        content = (tonumber(serum) or 0) > 0 and "@everyone" or nil,
                        embeds = {embed}
                    }

                    request({
                        Url = webhookURL,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = HttpService:JSONEncode(data)
                    })
                end
            end
            task.wait(1)
        end
    end)
end)


end)
if not okMod then warn("[Aotr:update5] Account/Webhook/Refill module failed: " .. tostring(errMod)) end
end

--//==============================\\--
--||         SAVE / LOAD          ||--
--\\==============================//--

Window:SelectTab(Tabs.Main)

pcall(function()
    local menu = Tabs.Settings._tab:AddRightGroupbox("Menu")
    menu:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {
        Default = "LeftControl", NoUI = true, Text = "Menu keybind",
    })
    Library.ToggleKeybind = Library.Options.MenuKeybind
end)

local function safe(name, fn)
    local ok, err = pcall(fn)
    if not ok then warn("[Aotr:update5] " .. name .. " failed: " .. tostring(err)) end
end

safe("ThemeManager", function()
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("Aotr_update5")
end)
safe("SaveManager", function()
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("Aotr_update5")
    SaveManager:BuildConfigSection(Tabs.Settings._tab)
end)
safe("ThemeTab", function() ThemeManager:ApplyToTab(Tabs.Settings._tab) end)
safe("Autoload", function() SaveManager:LoadAutoloadConfig() end)

--//==============================\\--
--||   AUTO FARM OFF IN LOBBY     ||--
--\\==============================//--
-- Runs after the config autoload so a saved "on" state can't re-enable farming.
do
    local FARM_TOGGLES = { "AutoKillTitans", "AutoClickM1", "AutoBladeReload", "HitAllTitans" }
    if game.PlaceId == lobbyPlaceId then
        task.spawn(function()
            while true do
                Config.isFlying = false
                for _, idx in ipairs(FARM_TOGGLES) do
                    local t = Library.Toggles and Library.Toggles[idx]
                    if t and t.Value then pcall(function() t:SetValue(false) end) end
                end
                task.wait(1)
            end
        end)
    end
end

--//==============================\\--
--||      HUB BACKGROUND IMAGE     ||--
--\\==============================//--
-- Image is embedded (base64), written to the executor workspace and applied
-- behind the UI. Tweak the two numbers below to taste.
do
    local IMAGE_TRANSPARENCY = 0.45 -- 0 = fully visible image, 1 = invisible
    local PANEL_TRANSPARENCY = 0.45 -- see-through panels so the image shows

    local BG_B64 = table.concat({
[==[
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
oI2lkBOV5aNQFSX/2Q==
]==]
    })

    local function b64decode(data)
        data = data:gsub("%s", "")
        local fn = (crypt and crypt.base64decode) or (crypt and crypt.base64 and crypt.base64.decode)
            or base64_decode or (base64 and (base64.decode or base64.Decode))
        if fn then
            local ok, res = pcall(fn, data)
            if ok and type(res) == "string" and #res > 0 then return res end
        end
        local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        local lookup = {}
        for k = 1, #chars do lookup[chars:byte(k)] = k - 1 end
        local out, n, buf, bits = {}, 0, 0, 0
        for k = 1, #data do
            local v = lookup[data:byte(k)]
            if v then
                buf = buf * 64 + v
                bits += 6
                if bits >= 8 then
                    bits -= 8
                    local byte = math.floor(buf / 2 ^ bits)
                    buf = buf % 2 ^ bits
                    n += 1
                    out[n] = string.char(byte)
                end
            end
        end
        return table.concat(out)
    end

    task.spawn(function()
        local ok, err = pcall(function()
            if not (writefile and getcustomasset) then error("executor has no writefile/getcustomasset") end
            task.wait(0.5)

            local path = "Aotr_update5_bg2.jpg"
            if not (isfile and isfile(path)) then writefile(path, b64decode(BG_B64)) end
            local asset = getcustomasset(path)

            -- find the main window frame (largest window-sized frame in the Obsidian ScreenGui)
            local main
            local gui = Library.ScreenGui
            if gui then
                local best = 0
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("Frame") then
                        local s = d.AbsoluteSize
                        if s.X >= 300 and s.X <= 900 and s.Y >= 250 and s.Y <= 700 and s.X * s.Y > best then
                            best, main = s.X * s.Y, d
                        end
                    end
                end
            end
            if not main then error("window frame not found") end
            if main:FindFirstChild("AotrBackground") then main.AotrBackground:Destroy() end

            local img = Instance.new("ImageLabel")
            img.Name = "AotrBackground"
            img.BackgroundTransparency = 1
            img.Size = UDim2.fromScale(1, 1)
            img.Position = UDim2.fromScale(0, 0)
            img.Image = asset
            img.ScaleType = Enum.ScaleType.Crop
            img.ImageTransparency = IMAGE_TRANSPARENCY
            img.ZIndex = 0
            img.Parent = main
            local corner = main:FindFirstChildOfClass("UICorner")
            if corner then corner:Clone().Parent = img end

            -- make big panels see-through (skip small controls like toggles/sliders)
            for _, d in ipairs(main:GetDescendants()) do
                if (d:IsA("Frame") or d:IsA("ScrollingFrame")) and d.BackgroundTransparency < PANEL_TRANSPARENCY then
                    local s = d.AbsoluteSize
                    if s.X >= 120 and s.Y >= 60 then d.BackgroundTransparency = PANEL_TRANSPARENCY end
                end
            end
            main.BackgroundTransparency = math.max(main.BackgroundTransparency, 0.2)
        end)
        if not ok then warn("[Aotr:update5] background failed: " .. tostring(err)) end
    end)
end

Notifier:Notify({
    Title   = "Aotr:update5",
    Content = "Loaded successfully! Tap the tray icon to hide/show the UI.",
    Duration = 4,
})
