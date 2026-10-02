# OverKill UI Library Documentation (v2.0)

Welcome to the documentation for **OverKill**, the ultimate, state-of-the-art UI library tailored for both Roblox Studio development and Executor environments.

## New Premium Features
- **Key System**: Secure your scripts behind a visually stunning authentication screen.
- **Config Manager**: Automatically saves and loads your users' states and settings directly to their executor's workspace (supports `writefile`/`readfile`).
- **Ghost Mode**: Press `F4` to instantly toggle the UI to be transparent and click-through, allowing seamless gameplay without closing the menu.
- **Notification Engine**: Beautiful, animated toast notifications that slide in with bouncy easing to alert users.
- **Advanced Environment Support**: Automatically detects and leverages Executor functions like `gethui()` to hide the GUI from standard CoreGui detection where applicable.

---

## Getting Started

### 1. Initialization
```lua
local OverKill = loadstring(game:HttpGet("https://raw.githubusercontent.com/kelv-inn/overkill/refs/heads/main/OverKill.lua"))()
```

### 2. (Optional) Key System Authentication
If you want to protect your script:
```lua
OverKill:CreateKeySystem({
    -- Key = "PREMIUM-OVERKILL-KEY",               -- Use this for a hardcoded key
    KeyUrl = "https://example.com/raw/key.txt",    -- Use this to fetch the key from a website
    KeyExpiration = 86400,                         -- 24 hours in seconds (Saves and bypasses key system until expired)
    OnSuccess = function()
        -- Load your main UI here
        LoadMainUI()
    end
})
```

### 3. Creating the Main Window & Tabs
The new architecture supports Tabs inherently.
```lua
local Window = OverKill:CreateWindow({
    Title = "OverKill Hub v2",
    Size = UDim2.new(0, 600, 0, 400)
})

local MainTab = Window:CreateTab("Main", "rbxassetid://123456")
local SettingsTab = Window:CreateTab("Settings")
```

---

## Component API

The components now take a `Flag` property to hook seamlessly into the **Config Manager**.

**Button:**
```lua
MainTab:CreateButton({
    Text = "Kill All",
    Callback = function()
        print("Executing Kill All...")
    end
})
```

**Toggle:**
```lua
MainTab:CreateToggle({
    Text = "Auto-Farm",
    Flag = "AutoFarmToggle",
    Default = false,
    Callback = function(state)
        print("Auto-farm is:", state)
    end
})
```

**Slider:**
```lua
MainTab:CreateSlider({
    Text = "WalkSpeed",
    Flag = "WS_Slider",
    Min = 16,
    Max = 200,
    Default = 16,
    Precise = false, -- Set to true for decimals
    Callback = function(val)
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = val
    end
})
```

**Dropdown:**
```lua
MainTab:CreateDropdown({
    Text = "Target Player",
    Flag = "TargetDropdown",
    Items = {"Player1", "Player2", "Player3"},
    Default = "Player1",
    Callback = function(selected)
        print("Selected:", selected)
    end
})
```

**Keybind:**
```lua
SettingsTab:CreateKeybind({
    Text = "Hide UI Bind",
    Flag = "HideUIBind",
    Default = Enum.KeyCode.RightShift,
    Callback = function()
        print("Keybind triggered!")
    end
})
```

**Color Picker:**
```lua
SettingsTab:CreateColorPicker({
    Text = "ESP Color",
    Flag = "ESPColorFlag",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        print("New ESP Color:", color)
    end
})
```

---

## Theming & Notifications

**Send a Notification:**
```lua
OverKill:Notify({
    Title = "Warning",
    Content = "You are taking damage!",
    Duration = 5
})
```

**Change Theme dynamically:**
```lua
OverKill:SetTheme({
    Accent = Color3.fromRGB(0, 255, 100), -- Change theme to Neon Green
    Background = Color3.fromRGB(10, 10, 10)
})
```

Enjoy the sheer power of **OverKill**!
