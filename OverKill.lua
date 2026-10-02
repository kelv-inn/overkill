--[[
    OverKill - Ultimate Roblox UI Library
    Version: 2.0.0
    Description: A modular, highly customizable, and state-of-the-art UI library for Roblox Executors & Studio.
    
    Features:
    - Multi-environment Support (Studio, Synapse, Krnl, Fluxus, etc.)
    - Key System (Premium Access Control)
    - Dynamic Theme Switching & Glassmorphism
    - State Management & Config System (Auto Save/Load)
    - Components: Button, Toggle, Slider, Dropdown, ColorPicker, Keybind, TextBox, Label
    - Never-seen-before: Ghost Mode (Click-through UI), Built-in Notification Engine
--]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse() or nil

-- Environment checks for Executors
local isStudio = RunService:IsStudio()
local GET_HUI = gethui or function() return CoreGui end
local WRITE_FILE = writefile or function(file, data) warn("writefile not supported") end
local READ_FILE = readfile or function(file) return nil end
local IS_FILE = isfile or function(file) return false end

local OverKill = {
    Themes = {},
    State = {},
    Easing = {},
    Connections = {},
    Elements = {},
    Flags = {},
    Configuration = {
        AutoSave = true,
        ConfigName = "OverKill_Config.json"
    },
    GhostMode = false,
    UI_Parent = nil
}

--=========================--
-- 1. Easing & Animation   --
--=========================--
OverKill.Easing = {
    Smooth = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Snappy = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    Bouncy = TweenInfo.new(0.4, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
}

--=========================--
-- 2. Theme Management     --
--=========================--
OverKill.Themes.Default = {
    Background = Color3.fromRGB(15, 15, 20),
    Container = Color3.fromRGB(22, 22, 32),
    ContainerHighlight = Color3.fromRGB(30, 30, 45),
    Accent = Color3.fromRGB(138, 43, 226),        -- Violet
    Highlight = Color3.fromRGB(170, 85, 255),     -- Light Violet
    Text = Color3.fromRGB(255, 255, 255),
    TextSub = Color3.fromRGB(170, 170, 190),
    Border = Color3.fromRGB(40, 35, 60),
    CornerRadius = UDim.new(0, 6)
}

OverKill.CurrentTheme = OverKill.Themes.Default
local ThemeUpdateConnections = {}

function OverKill:SetTheme(themeTable)
    for k, v in pairs(themeTable) do
        self.CurrentTheme[k] = v
    end
    for _, callback in ipairs(ThemeUpdateConnections) do
        callback(self.CurrentTheme)
    end
end

function OverKill:OnThemeUpdate(callback)
    table.insert(ThemeUpdateConnections, callback)
    callback(self.CurrentTheme)
end

--=========================--
-- 3. Utility Functions    --
--=========================--
local function CreateInstance(className, properties, children)
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function CreateCorner(radius)
    return CreateInstance("UICorner", { CornerRadius = radius or OverKill.CurrentTheme.CornerRadius })
end

local function CreateStroke(color, thickness, transparency)
    return CreateInstance("UIStroke", {
        Color = color or OverKill.CurrentTheme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    })
end

--=========================--
-- 4. State Management     --
--=========================--
function OverKill.State.new(flagName, initialValue)
    local state = {
        Name = flagName,
        Value = initialValue,
        Listeners = {}
    }
    
    if flagName then OverKill.Flags[flagName] = state end

    function state:Get() return self.Value end
    
    function state:Set(newValue, skipSave)
        if self.Value ~= newValue then
            self.Value = newValue
            for _, listener in ipairs(self.Listeners) do
                listener(newValue)
            end
            if not skipSave and OverKill.Configuration.AutoSave then
                OverKill:SaveConfig()
            end
        end
    end
    
    function state:Subscribe(callback)
        table.insert(self.Listeners, callback)
        callback(self.Value)
    end
    
    return state
end

--=========================--
-- 5. Config System        --
--=========================--
function OverKill:SaveConfig()
    local savedData = {}
    for flag, state in pairs(self.Flags) do
        -- Convert complex types (like Color3, KeyCode) to savable formats if needed
        local val = state:Get()
        if typeof(val) == "Color3" then
            val = {Type = "Color3", R = val.R, G = val.G, B = val.B}
        elseif typeof(val) == "EnumItem" then
            val = {Type = "EnumItem", Name = val.Name, EnumType = tostring(val.EnumType)}
        end
        savedData[flag] = val
    end
    local json = HttpService:JSONEncode(savedData)
    WRITE_FILE(self.Configuration.ConfigName, json)
end

function OverKill:LoadConfig()
    if IS_FILE(self.Configuration.ConfigName) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(READ_FILE(self.Configuration.ConfigName))
        end)
        if success and type(data) == "table" then
            for flag, val in pairs(data) do
                if self.Flags[flag] then
                    -- Reconstruct complex types
                    if type(val) == "table" and val.Type == "Color3" then
                        val = Color3.new(val.R, val.G, val.B)
                    elseif type(val) == "table" and val.Type == "EnumItem" then
                        -- Simplistic Enum resolving
                        local enumTypes = string.split(val.EnumType, ".")
                        local enumGroup = Enum[enumTypes[#enumTypes]]
                        if enumGroup then
                            for _, eItem in ipairs(enumGroup:GetEnumItems()) do
                                if eItem.Name == val.Name then
                                    val = eItem
                                    break
                                end
                            end
                        end
                    end
                    self.Flags[flag]:Set(val, true)
                end
            end
        end
    end
end

--=========================--
-- 6. Dragging System      --
--=========================--
function OverKill:MakeDraggable(guiElement, dragHandle)
    dragHandle = dragHandle or guiElement
    local dragging, dragInput, dragStart, startPos
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiElement.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiElement.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

--=========================--
-- 7. Notifications Engine --
--=========================--
OverKill.NotificationContainer = nil

function OverKill:Notify(options)
    options = options or {}
    local Title = options.Title or "Notification"
    local Content = options.Content or "This is a notification."
    local Duration = options.Duration or 3

    if not self.NotificationContainer then
        self.NotificationContainer = CreateInstance("Frame", {
            Name = "NotifContainer",
            Size = UDim2.new(0, 300, 1, -40),
            Position = UDim2.new(1, -320, 0, 20),
            BackgroundTransparency = 1,
            Parent = self.UI_Parent
        })
        CreateInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Parent = self.NotificationContainer
        })
    end

    local NotifFrame = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 70),
        BackgroundColor3 = self.CurrentTheme.Container,
        BackgroundTransparency = 1,
        Parent = self.NotificationContainer
    }, {
        CreateCorner(),
        CreateStroke(self.CurrentTheme.Accent, 1, 1),
        CreateInstance("TextLabel", {
            Name = "Title",
            Size = UDim2.new(1, -20, 0, 25),
            Position = UDim2.new(0, 10, 0, 5),
            BackgroundTransparency = 1,
            Text = Title,
            TextColor3 = self.CurrentTheme.Accent,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 1
        }),
        CreateInstance("TextLabel", {
            Name = "Content",
            Size = UDim2.new(1, -20, 0, 35),
            Position = UDim2.new(0, 10, 0, 30),
            BackgroundTransparency = 1,
            Text = Content,
            TextColor3 = self.CurrentTheme.TextSub,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            TextTransparency = 1
        })
    })

    local Stroke = NotifFrame:FindFirstChildOfClass("UIStroke")
    local TitleLbl = NotifFrame.Title
    local ContentLbl = NotifFrame.Content

    -- Entrance Animation
    TweenService:Create(NotifFrame, self.Easing.Bouncy, {BackgroundTransparency = 0}):Play()
    TweenService:Create(Stroke, self.Easing.Smooth, {Transparency = 0}):Play()
    TweenService:Create(TitleLbl, self.Easing.Smooth, {TextTransparency = 0}):Play()
    TweenService:Create(ContentLbl, self.Easing.Smooth, {TextTransparency = 0}):Play()

    task.delay(Duration, function()
        -- Exit Animation
        TweenService:Create(NotifFrame, self.Easing.Smooth, {BackgroundTransparency = 1}):Play()
        TweenService:Create(Stroke, self.Easing.Smooth, {Transparency = 1}):Play()
        TweenService:Create(TitleLbl, self.Easing.Smooth, {TextTransparency = 1}):Play()
        TweenService:Create(ContentLbl, self.Easing.Smooth, {TextTransparency = 1}):Play()
        task.wait(self.Easing.Smooth.Time)
        NotifFrame:Destroy()
    end)
end

--=========================--
-- 8. Initialization       --
--=========================--
local ScreenGui = CreateInstance("ScreenGui", {
    Name = "OverKill_Ultimate",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    IgnoreGuiInset = true
})

if isStudio then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
else
    local success = pcall(function() ScreenGui.Parent = GET_HUI() end)
    if not success then ScreenGui.Parent = CoreGui end
end
OverKill.UI_Parent = ScreenGui

-- Ghost Mode logic
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F4 then
        OverKill.GhostMode = not OverKill.GhostMode
        for _, inst in ipairs(ScreenGui:GetDescendants()) do
            if inst:IsA("GuiObject") then
                inst.Active = not OverKill.GhostMode
            end
        end
        OverKill:Notify({Title = "Ghost Mode", Content = OverKill.GhostMode and "Enabled - UI is Click-Through" or "Disabled - UI is Interactive"})
    end
end)


--=========================--
-- 9. Key System           --
--=========================--
function OverKill:CreateKeySystem(options)
    options = options or {}
    local ValidKey = options.Key or "OVERKILL-PREMIUM"
    local OnSuccess = options.OnSuccess or function() end

    local KeyWindow = CreateInstance("Frame", {
        Size = UDim2.new(0, 350, 0, 200),
        Position = UDim2.new(0.5, -175, 0.5, -100),
        BackgroundColor3 = self.CurrentTheme.Background,
        Parent = ScreenGui
    }, { CreateCorner(), CreateStroke() })

    local Title = CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Text = "OVERKILL Authentication",
        TextColor3 = self.CurrentTheme.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Parent = KeyWindow
    })

    local SubTitle = CreateInstance("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundTransparency = 1,
        Text = "Please enter your premium key to continue.",
        TextColor3 = self.CurrentTheme.TextSub,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        Parent = KeyWindow
    })

    local KeyBox = CreateInstance("TextBox", {
        Size = UDim2.new(1, -40, 0, 40),
        Position = UDim2.new(0, 20, 0, 80),
        BackgroundColor3 = self.CurrentTheme.Container,
        TextColor3 = self.CurrentTheme.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        PlaceholderText = "Enter Key Here...",
        Text = "",
        Parent = KeyWindow
    }, { CreateCorner(UDim.new(0, 4)) })

    local SubmitBtn = CreateInstance("TextButton", {
        Size = UDim2.new(1, -40, 0, 40),
        Position = UDim2.new(0, 20, 0, 140),
        BackgroundColor3 = self.CurrentTheme.Accent,
        TextColor3 = Color3.fromRGB(255,255,255),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Text = "Verify Key",
        Parent = KeyWindow
    }, { CreateCorner(UDim.new(0, 4)) })

    self:MakeDraggable(KeyWindow)

    SubmitBtn.MouseButton1Click:Connect(function()
        if KeyBox.Text == ValidKey then
            TweenService:Create(KeyWindow, self.Easing.Bouncy, {Size = UDim2.new(0, 350, 0, 0)}):Play()
            task.wait(self.Easing.Bouncy.Time)
            KeyWindow:Destroy()
            self:Notify({Title = "Authentication", Content = "Key Verified! Welcome to OverKill."})
            OnSuccess()
        else
            self:Notify({Title = "Authentication Failed", Content = "Invalid Key provided."})
            TweenService:Create(KeyBox, self.Easing.Snappy, {BackgroundColor3 = Color3.fromRGB(150, 30, 30)}):Play()
            task.wait(0.2)
            TweenService:Create(KeyBox, self.Easing.Snappy, {BackgroundColor3 = self.CurrentTheme.Container}):Play()
        end
    end)
end

--=========================--
-- 10. Main Library UI      --
--=========================--
function OverKill:CreateWindow(options)
    options = options or {}
    local Title = options.Title or "OverKill UI"
    local Size = options.Size or UDim2.new(0, 600, 0, 400)

    local WindowFrame = CreateInstance("Frame", {
        Name = Title,
        Size = Size,
        Position = UDim2.new(0.5, -Size.X.Offset/2, 0.5, -Size.Y.Offset/2),
        BackgroundColor3 = self.CurrentTheme.Background,
        ClipsDescendants = true,
        Parent = ScreenGui
    }, { CreateCorner(), CreateStroke() })

    local TopBar = CreateInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = self.CurrentTheme.Container,
        Parent = WindowFrame
    })

    local TitleLbl = CreateInstance("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = Title,
        TextColor3 = self.CurrentTheme.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = TopBar
    })

    local TabContainer = CreateInstance("ScrollingFrame", {
        Size = UDim2.new(0, 140, 1, -50),
        Position = UDim2.new(0, 10, 0, 50),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        Parent = WindowFrame
    }, { CreateInstance("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }) })

    local ContentContainer = CreateInstance("Frame", {
        Size = UDim2.new(1, -170, 1, -60),
        Position = UDim2.new(0, 160, 0, 50),
        BackgroundColor3 = self.CurrentTheme.Container,
        Parent = WindowFrame
    }, { CreateCorner(), CreateStroke() })

    self:MakeDraggable(WindowFrame, TopBar)

    local WindowAPI = { Tabs = {}, ActiveTab = nil }

    -- Update visuals on theme change
    self:OnThemeUpdate(function(theme)
        WindowFrame.BackgroundColor3 = theme.Background
        TopBar.BackgroundColor3 = theme.Container
        TitleLbl.TextColor3 = theme.Accent
        ContentContainer.BackgroundColor3 = theme.Container
        WindowFrame:FindFirstChildOfClass("UIStroke").Color = theme.Border
        ContentContainer:FindFirstChildOfClass("UIStroke").Color = theme.Border
    end)

    function WindowAPI:CreateTab(tabName, icon)
        local TabBtn = CreateInstance("TextButton", {
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundColor3 = self.ActiveTab == nil and OverKill.CurrentTheme.Accent or OverKill.CurrentTheme.Background,
            Text = "  " .. tabName,
            TextColor3 = self.ActiveTab == nil and Color3.fromRGB(255,255,255) or OverKill.CurrentTheme.TextSub,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = TabContainer
        }, { CreateCorner(UDim.new(0, 4)) })

        local TabContent = CreateInstance("ScrollingFrame", {
            Size = UDim2.new(1, -20, 1, -20),
            Position = UDim2.new(0, 10, 0, 10),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = OverKill.CurrentTheme.Accent,
            Visible = (self.ActiveTab == nil),
            Parent = ContentContainer
        }, { 
            CreateInstance("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
            CreateInstance("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) })
        })

        if self.ActiveTab == nil then self.ActiveTab = TabBtn end

        TabBtn.MouseButton1Click:Connect(function()
            for btn, content in pairs(self.Tabs) do
                TweenService:Create(btn, OverKill.Easing.Snappy, {
                    BackgroundColor3 = OverKill.CurrentTheme.Background,
                    TextColor3 = OverKill.CurrentTheme.TextSub
                }):Play()
                content.Visible = false
            end
            TweenService:Create(TabBtn, OverKill.Easing.Snappy, {
                BackgroundColor3 = OverKill.CurrentTheme.Accent,
                TextColor3 = Color3.fromRGB(255,255,255)
            }):Play()
            TabContent.Visible = true
            self.ActiveTab = TabBtn
        end)

        self.Tabs[TabBtn] = TabContent

        local TabAPI = {}

        --=======================--
        -- Component: Button     --
        --=======================--
        function TabAPI:CreateButton(options)
            local btnText = options.Text or "Button"
            local callback = options.Callback or function() end

            local Btn = CreateInstance("TextButton", {
                Size = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = OverKill.CurrentTheme.ContainerHighlight,
                Text = btnText,
                TextColor3 = OverKill.CurrentTheme.Text,
                Font = Enum.Font.GothamSemibold,
                TextSize = 14,
                AutoButtonColor = false,
                Parent = TabContent
            }, { CreateCorner(UDim.new(0, 4)), CreateStroke() })

            Btn.MouseEnter:Connect(function() TweenService:Create(Btn, OverKill.Easing.Snappy, {BackgroundColor3 = OverKill.CurrentTheme.Accent}):Play() end)
            Btn.MouseLeave:Connect(function() TweenService:Create(Btn, OverKill.Easing.Snappy, {BackgroundColor3 = OverKill.CurrentTheme.ContainerHighlight}):Play() end)
            Btn.MouseButton1Click:Connect(function() 
                -- Ripple effect simulation
                local ripple = CreateInstance("Frame", {
                    Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0),
                    AnchorPoint = Vector2.new(0.5,0.5), BackgroundColor3 = Color3.fromRGB(255,255,255),
                    BackgroundTransparency = 0.5, Parent = Btn
                }, {CreateCorner(UDim.new(1,0))})
                TweenService:Create(ripple, OverKill.Easing.Smooth, {Size = UDim2.new(1.5,0,1.5,0), BackgroundTransparency = 1}):Play()
                task.delay(OverKill.Easing.Smooth.Time, function() ripple:Destroy() end)

                callback() 
            end)
        end

        --=======================--
        -- Component: Toggle     --
        --=======================--
        function TabAPI:CreateToggle(options)
            local tglText = options.Text or "Toggle"
            local flag = options.Flag
            local default = options.Default or false
            local callback = options.Callback or function() end

            local state = OverKill.State.new(flag, default)

            local TglFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = OverKill.CurrentTheme.ContainerHighlight,
                Parent = TabContent
            }, { CreateCorner(UDim.new(0, 4)), CreateStroke() })

            CreateInstance("TextLabel", {
                Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1, Text = tglText,
                TextColor3 = OverKill.CurrentTheme.Text, Font = Enum.Font.GothamSemibold,
                TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = TglFrame
            })

            local IndicatorOuter = CreateInstance("Frame", {
                Size = UDim2.new(0, 36, 0, 20), Position = UDim2.new(1, -45, 0.5, -10),
                BackgroundColor3 = state:Get() and OverKill.CurrentTheme.Accent or OverKill.CurrentTheme.Border,
                Parent = TglFrame
            }, { CreateCorner(UDim.new(1, 0)) })

            local IndicatorInner = CreateInstance("Frame", {
                Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, state:Get() and 18 or 2, 0.5, -8),
                BackgroundColor3 = Color3.fromRGB(255,255,255), Parent = IndicatorOuter
            }, { CreateCorner(UDim.new(1, 0)) })

            local Btn = CreateInstance("TextButton", {
                Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = TglFrame
            })

            local function UpdateVisuals(val)
                TweenService:Create(IndicatorOuter, OverKill.Easing.Snappy, {BackgroundColor3 = val and OverKill.CurrentTheme.Accent or OverKill.CurrentTheme.Border}):Play()
                TweenService:Create(IndicatorInner, OverKill.Easing.Snappy, {Position = UDim2.new(0, val and 18 or 2, 0.5, -8)}):Play()
            end

            state:Subscribe(function(val)
                UpdateVisuals(val)
                callback(val)
            end)

            Btn.MouseButton1Click:Connect(function()
                state:Set(not state:Get())
            end)

            return state
        end

        --=======================--
        -- Component: Slider     --
        --=======================--
        function TabAPI:CreateSlider(options)
            local slText = options.Text or "Slider"
            local flag = options.Flag
            local min = options.Min or 0
            local max = options.Max or 100
            local default = options.Default or min
            local precise = options.Precise or false
            local callback = options.Callback or function() end

            local state = OverKill.State.new(flag, default)

            local SlFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = OverKill.CurrentTheme.ContainerHighlight,
                Parent = TabContent
            }, { CreateCorner(UDim.new(0, 4)), CreateStroke() })

            CreateInstance("TextLabel", {
                Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 15, 0, 5),
                BackgroundTransparency = 1, Text = slText,
                TextColor3 = OverKill.CurrentTheme.Text, Font = Enum.Font.GothamSemibold,
                TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = SlFrame
            })

            local ValueLbl = CreateInstance("TextLabel", {
                Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -65, 0, 5),
                BackgroundTransparency = 1, Text = tostring(default),
                TextColor3 = OverKill.CurrentTheme.TextSub, Font = Enum.Font.Gotham,
                TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = SlFrame
            })

            local Track = CreateInstance("Frame", {
                Size = UDim2.new(1, -30, 0, 6), Position = UDim2.new(0, 15, 0, 35),
                BackgroundColor3 = OverKill.CurrentTheme.Border, Parent = SlFrame
            }, { CreateCorner(UDim.new(1, 0)) })

            local Fill = CreateInstance("Frame", {
                Size = UDim2.new(math.clamp((default-min)/(max-min), 0, 1), 0, 1, 0),
                BackgroundColor3 = OverKill.CurrentTheme.Accent, Parent = Track
            }, { CreateCorner(UDim.new(1, 0)) })

            local DragBtn = CreateInstance("TextButton", {
                Size = UDim2.new(1,0,1,0), Position = UDim2.new(0,0,0,-10),
                BackgroundTransparency = 1, Text = "", Parent = Track
            })

            local dragging = false
            DragBtn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local mousePos = UserInputService:GetMouseLocation().X
                    local trackPos = Track.AbsolutePosition.X
                    local trackSize = Track.AbsoluteSize.X
                    local percent = math.clamp((mousePos - trackPos) / trackSize, 0, 1)
                    local value = min + ((max - min) * percent)
                    if not precise then value = math.floor(value) end
                    state:Set(value)
                end
            end)

            state:Subscribe(function(val)
                local percent = math.clamp((val-min)/(max-min), 0, 1)
                TweenService:Create(Fill, OverKill.Easing.Snappy, {Size = UDim2.new(percent, 0, 1, 0)}):Play()
                ValueLbl.Text = precise and string.format("%.2f", val) or tostring(math.floor(val))
                callback(val)
            end)

            return state
        end

        --=======================--
        -- Component: Dropdown   --
        --=======================--
        function TabAPI:CreateDropdown(options)
            local ddText = options.Text or "Dropdown"
            local flag = options.Flag
            local items = options.Items or {}
            local default = options.Default or items[1]
            local callback = options.Callback or function() end

            local state = OverKill.State.new(flag, default)
            local isOpen = false

            local DDFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = OverKill.CurrentTheme.ContainerHighlight,
                ClipsDescendants = true,
                Parent = TabContent
            }, { CreateCorner(UDim.new(0, 4)), CreateStroke() })

            CreateInstance("TextLabel", {
                Size = UDim2.new(1, -60, 0, 38), Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1, Text = ddText,
                TextColor3 = OverKill.CurrentTheme.Text, Font = Enum.Font.GothamSemibold,
                TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = DDFrame
            })

            local SelectedLbl = CreateInstance("TextLabel", {
                Size = UDim2.new(0, 100, 0, 38), Position = UDim2.new(1, -135, 0, 0),
                BackgroundTransparency = 1, Text = tostring(default),
                TextColor3 = OverKill.CurrentTheme.Accent, Font = Enum.Font.Gotham,
                TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = DDFrame
            })

            local Icon = CreateInstance("TextLabel", {
                Size = UDim2.new(0, 20, 0, 38), Position = UDim2.new(1, -25, 0, 0),
                BackgroundTransparency = 1, Text = "+", TextColor3 = OverKill.CurrentTheme.TextSub,
                Font = Enum.Font.GothamBold, TextSize = 16, Parent = DDFrame
            })

            local Btn = CreateInstance("TextButton", { Size = UDim2.new(1,0,0,38), BackgroundTransparency = 1, Text = "", Parent = DDFrame })
            
            local ItemContainer = CreateInstance("Frame", {
                Size = UDim2.new(1, -20, 0, 0), Position = UDim2.new(0, 10, 0, 40),
                BackgroundTransparency = 1, Parent = DDFrame
            }, { CreateInstance("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })

            local function UpdateItems()
                for _, child in ipairs(ItemContainer:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
                local ySize = 0
                for _, item in ipairs(items) do
                    local iBtn = CreateInstance("TextButton", {
                        Size = UDim2.new(1, 0, 0, 25), BackgroundColor3 = OverKill.CurrentTheme.Container,
                        Text = "  " .. tostring(item), TextColor3 = OverKill.CurrentTheme.TextSub,
                        Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = ItemContainer
                    }, { CreateCorner(UDim.new(0,3)) })
                    
                    if item == state:Get() then iBtn.TextColor3 = OverKill.CurrentTheme.Accent end

                    iBtn.MouseButton1Click:Connect(function()
                        state:Set(item)
                        isOpen = false
                        TweenService:Create(DDFrame, OverKill.Easing.Snappy, {Size = UDim2.new(1, 0, 0, 38)}):Play()
                        Icon.Rotation = 0
                    end)
                    ySize = ySize + 27
                end
                if isOpen then
                    TweenService:Create(DDFrame, OverKill.Easing.Snappy, {Size = UDim2.new(1, 0, 0, 38 + ySize)}):Play()
                end
            end

            state:Subscribe(function(val)
                SelectedLbl.Text = tostring(val)
                UpdateItems()
                callback(val)
            end)

            Btn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                TweenService:Create(Icon, OverKill.Easing.Snappy, {Rotation = isOpen and 45 or 0}):Play()
                UpdateItems()
                if not isOpen then
                    TweenService:Create(DDFrame, OverKill.Easing.Snappy, {Size = UDim2.new(1, 0, 0, 38)}):Play()
                end
            end)

            function state:Refresh(newItems)
                items = newItems
                UpdateItems()
            end

            return state
        end
        
        --=======================--
        -- Component: Keybind    --
        --=======================--
        function TabAPI:CreateKeybind(options)
            local kbText = options.Text or "Keybind"
            local flag = options.Flag
            local default = options.Default or Enum.KeyCode.RightShift
            local callback = options.Callback or function() end

            local state = OverKill.State.new(flag, default)
            local isBinding = false

            local KBFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = OverKill.CurrentTheme.ContainerHighlight, Parent = TabContent
            }, { CreateCorner(UDim.new(0, 4)), CreateStroke() })

            CreateInstance("TextLabel", {
                Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1, Text = kbText, TextColor3 = OverKill.CurrentTheme.Text,
                Font = Enum.Font.GothamSemibold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = KBFrame
            })

            local BindBtn = CreateInstance("TextButton", {
                Size = UDim2.new(0, 80, 0, 24), Position = UDim2.new(1, -95, 0.5, -12),
                BackgroundColor3 = OverKill.CurrentTheme.Container, Text = default.Name,
                TextColor3 = OverKill.CurrentTheme.Accent, Font = Enum.Font.GothamBold, TextSize = 12, Parent = KBFrame
            }, { CreateCorner(UDim.new(0, 4)) })

            BindBtn.MouseButton1Click:Connect(function()
                isBinding = true
                BindBtn.Text = "..."
                BindBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
            end)

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if isBinding then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        local key = input.KeyCode
                        if key ~= Enum.KeyCode.Unknown then
                            state:Set(key)
                            isBinding = false
                            BindBtn.TextColor3 = OverKill.CurrentTheme.Accent
                        end
                    end
                elseif not gameProcessed then
                    if input.KeyCode == state:Get() then
                        callback()
                    end
                end
            end)

            state:Subscribe(function(val)
                BindBtn.Text = val.Name
            end)

            return state
        end
        
        --=======================--
        -- Component: ColorPicker--
        --=======================--
        function TabAPI:CreateColorPicker(options)
            local cpText = options.Text or "Color Picker"
            local flag = options.Flag
            local default = options.Default or Color3.fromRGB(255, 255, 255)
            local callback = options.Callback or function() end

            local state = OverKill.State.new(flag, default)
            local isOpen = false

            local CPFrame = CreateInstance("Frame", {
                Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = OverKill.CurrentTheme.ContainerHighlight, ClipsDescendants = true, Parent = TabContent
            }, { CreateCorner(UDim.new(0, 4)), CreateStroke() })

            CreateInstance("TextLabel", {
                Size = UDim2.new(1, -60, 0, 38), Position = UDim2.new(0, 15, 0, 0),
                BackgroundTransparency = 1, Text = cpText, TextColor3 = OverKill.CurrentTheme.Text,
                Font = Enum.Font.GothamSemibold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = CPFrame
            })

            local ColorPreview = CreateInstance("Frame", {
                Size = UDim2.new(0, 30, 0, 20), Position = UDim2.new(1, -45, 0, 9),
                BackgroundColor3 = default, Parent = CPFrame
            }, { CreateCorner(UDim.new(0, 4)), CreateStroke(Color3.fromRGB(255,255,255), 1, 0.5) })

            local Btn = CreateInstance("TextButton", { Size = UDim2.new(1,0,0,38), BackgroundTransparency = 1, Text = "", Parent = CPFrame })

            -- Hue & Saturation map
            local ColorMap = CreateInstance("ImageButton", {
                Size = UDim2.new(1, -30, 0, 100), Position = UDim2.new(0, 15, 0, 45),
                Image = "rbxassetid://4155801252", Parent = CPFrame
            }, { CreateCorner(UDim.new(0, 4)) })

            local MapPicker = CreateInstance("Frame", {
                Size = UDim2.new(0, 4, 0, 4), BackgroundColor3 = Color3.new(1,1,1),
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 0), Parent = ColorMap
            }, { CreateCorner(UDim.new(1, 0)), CreateStroke(Color3.new(0,0,0), 1, 0) })

            local function UpdateColor(input)
                local size = ColorMap.AbsoluteSize
                local pos = ColorMap.AbsolutePosition
                local mouseX = math.clamp(input.Position.X - pos.X, 0, size.X)
                local mouseY = math.clamp(input.Position.Y - pos.Y, 0, size.Y)
                
                MapPicker.Position = UDim2.new(0, mouseX, 0, mouseY)
                
                local hue = 1 - (mouseX / size.X)
                local sat = 1 - (mouseY / size.Y)
                local color = Color3.fromHSV(hue, sat, 1)
                
                state:Set(color)
            end

            local dragging = false
            ColorMap.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
                    dragging = true 
                    UpdateColor(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    UpdateColor(input)
                end
            end)

            Btn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                TweenService:Create(CPFrame, OverKill.Easing.Bouncy, {Size = UDim2.new(1, 0, 0, isOpen and 160 or 38)}):Play()
            end)

            state:Subscribe(function(val)
                ColorPreview.BackgroundColor3 = val
                callback(val)
            end)

            return state
        end

        return TabAPI
    end

    -- Initial tab setup rendering
    task.spawn(function()
        OverKill:LoadConfig()
    end)

    return WindowAPI
end

return OverKill
