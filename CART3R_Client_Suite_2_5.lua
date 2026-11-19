

--[[

    CART3R.JAILBREAK

    CLIENT SUITE 2.5

    Roblox Studio / Luau
    Single LocalScript

    Place: StarterPlayerScripts



    AIM targets:

    Other players in this experience and NPC models tagged

    "CarterAimTarget" or with Attribute CarterAimTarget = true.

]]



--==================================================

-- SERVICES

--==================================================



local Players = game:GetService("Players")

local TweenService = game:GetService("TweenService")

local UserInputService = game:GetService("UserInputService")

local RunService = game:GetService("RunService")

local CollectionService = game:GetService("CollectionService")

local Lighting = game:GetService("Lighting")

local Workspace = game:GetService("Workspace")



local LocalPlayer = Players.LocalPlayer

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")



--==================================================

-- CONFIGURATION

--==================================================



local DEFAULTS = {

    Accent = Color3.fromRGB(155, 155, 165),

    Background = Color3.fromRGB(15, 15, 18),

    Panel = Color3.fromRGB(24, 24, 28),

    Text = Color3.fromRGB(235, 235, 240),



    Transparency = 0.05,

    Animations = true,

    Notifications = true,



    ESP = false,

    ShowNames = true,

    ShowDistance = true,

    ShowHealth = true,

    ESPDistance = 10000,
    ESPThroughWalls = true,



    AIMEnabled = false,
    AIMWallCheck = true,

    FOVVisible = true,

    FOVRadius = 113,

    AimSpeed = 50,

    MaxAimDistance = 10000,

    AimRigType = "R15",

    AimBodyPart = "Head",

    CameraFOV = 70,



    Crosshair = false,

    Bloom = false,

}



local Config = {}



for key, value in pairs(DEFAULTS) do

    Config[key] = value

end



local Connections = {}

local ESPObjects = {}

local Profiles = {}

local CurrentProfile = "Default"

local CurrentTab = "ESP"



local destroyed = false

local minimized = false

local selectedTarget = nil
local ToggleRegistry = {}
local MenuKey = Enum.KeyCode.RightShift
local bindCapture = nil
local bindButtons = {}
local MenuBindButton = nil



--==================================================

-- CONNECTION MANAGEMENT

--==================================================



local function connect(signal, callback)

    local connection = signal:Connect(callback)

    table.insert(Connections, connection)

    return connection

end



local function disconnectAll()

    for _, connection in ipairs(Connections) do

        if connection.Connected then

            connection:Disconnect()

        end

    end



    table.clear(Connections)

end



--==================================================

-- CLEAN OLD GUI

--==================================================



local oldGui = PlayerGui:FindFirstChild("CarterClient")



if oldGui then

    oldGui:Destroy()

end



--==================================================

-- UI HELPERS

--==================================================



local function create(className, properties, parent)

    local object = Instance.new(className)



    for property, value in pairs(properties) do

        object[property] = value

    end



    object.Parent = parent

    return object

end



local function round(object, radius)

    create("UICorner", {

        CornerRadius = UDim.new(0, radius or 8)

    }, object)

end



local function stroke(object, color, thickness)

    return create("UIStroke", {

        Color = color,

        Thickness = thickness or 1,

        Transparency = 0.25,

    }, object)

end



local function tween(object, properties, duration)

    if not Config.Animations then

        for property, value in pairs(properties) do

            object[property] = value

        end

        return

    end



    local animation = TweenService:Create(

        object,

        TweenInfo.new(

            duration or 0.18,

            Enum.EasingStyle.Quart,

            Enum.EasingDirection.Out

        ),

        properties

    )



    animation:Play()

    return animation

end



--==================================================

-- GUI ROOT

--==================================================



local Gui = create("ScreenGui", {

    Name = "CarterClient",

    ResetOnSpawn = false,

    IgnoreGuiInset = true,

    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

    DisplayOrder = 1000000,

}, PlayerGui)

-- Highlight effects must live in Workspace (or another supported 3D container),
-- not inside the ScreenGui. Keep them in a dedicated folder for clean teardown.
local oldHighlightFolder = Workspace:FindFirstChild("CarterESPHighlights")
if oldHighlightFolder then
    oldHighlightFolder:Destroy()
end

local ESPHighlightFolder = Instance.new("Folder")
ESPHighlightFolder.Name = "CarterESPHighlights"
ESPHighlightFolder.Parent = Workspace

-- Keep this interface above every other ScreenGui inside this experience's PlayerGui.
local watchedScreenGuis = {}
local function raiseAbovePlayerGuis()
    local highestOrder = 1000000
    for _, child in ipairs(PlayerGui:GetChildren()) do
        if child:IsA("ScreenGui") and child ~= Gui then
            highestOrder = math.max(highestOrder, child.DisplayOrder + 1)
        end
    end
    Gui.DisplayOrder = highestOrder
end

local function watchScreenGui(child)
    if not child:IsA("ScreenGui") or child == Gui or watchedScreenGuis[child] then
        return
    end
    watchedScreenGuis[child] = true
    connect(child:GetPropertyChangedSignal("DisplayOrder"), raiseAbovePlayerGuis)
    raiseAbovePlayerGuis()
end

for _, child in ipairs(PlayerGui:GetChildren()) do
    watchScreenGui(child)
end
connect(PlayerGui.ChildAdded, function(child)
    watchScreenGui(child)
end)


--==================================================

-- NOTIFICATIONS

--==================================================



local function notify(message)

    if not Config.Notifications or destroyed then

        return

    end



    local notification = create("TextLabel", {

        Size = UDim2.fromOffset(265, 42),

        Position = UDim2.new(1, 285, 1, -75),

        AnchorPoint = Vector2.new(1, 1),

        BackgroundColor3 = Config.Panel,

        TextColor3 = Config.Text,

        Text = tostring(message),

        TextSize = 12,

        Font = Enum.Font.GothamMedium,

        BorderSizePixel = 0,

        ZIndex = 100,

    }, Gui)



    round(notification, 8)

    stroke(notification, Color3.fromRGB(65, 65, 72))



    tween(notification, {

        Position = UDim2.new(1, -18, 1, -75)

    }, 0.25)



    task.delay(2.5, function()

        if notification.Parent then

            tween(notification, {

                Position = UDim2.new(1, 285, 1, -75)

            }, 0.2)



            task.wait(0.25)



            if notification.Parent then

                notification:Destroy()

            end

        end

    end)

end



--==================================================

-- MAIN WINDOW

--==================================================



local Main = create("Frame", {

    Name = "Main",

    Size = UDim2.fromOffset(590, 410),

    Position = UDim2.new(0.5, -295, 0.5, -205),

    BackgroundColor3 = Config.Background,

    BackgroundTransparency = Config.Transparency,

    BorderSizePixel = 0,

    ClipsDescendants = true,

}, Gui)

-- Opening the menu releases the mouse; hiding it restores the game's prior mouse state.
local menuOpen = false
local savedMouseBehavior = UserInputService.MouseBehavior
local savedMouseIconEnabled = UserInputService.MouseIconEnabled

local function setMainMenuVisible(visible)
    visible = visible == true

    if visible and not menuOpen then
        savedMouseBehavior = UserInputService.MouseBehavior
        savedMouseIconEnabled = UserInputService.MouseIconEnabled
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    elseif not visible and menuOpen then
        UserInputService.MouseBehavior = savedMouseBehavior
        UserInputService.MouseIconEnabled = savedMouseIconEnabled
    end

    menuOpen = visible
    Main.Visible = visible
end

setMainMenuVisible(true)

round(Main, 12)

stroke(Main, Color3.fromRGB(65, 65, 72))



--==================================================

-- HEADER

--==================================================



local Header = create("Frame", {

    Name = "Header",

    Size = UDim2.new(1, 0, 0, 48),

    BackgroundColor3 = Config.Panel,

    BorderSizePixel = 0,

    Active = true,

}, Main)



local Title = create("TextLabel", {

    Position = UDim2.fromOffset(16, 0),

    Size = UDim2.new(1, -120, 1, 0),

    BackgroundTransparency = 1,

    Text = "CART3R  /  CLIENT SUITE 2.5",

    TextColor3 = Config.Text,

    Font = Enum.Font.GothamBold,

    TextSize = 13,

    TextXAlignment = Enum.TextXAlignment.Left,

}, Header)



local MinimizeButton = create("TextButton", {

    Size = UDim2.fromOffset(34, 30),

    Position = UDim2.new(1, -42, 0, 9),

    BackgroundColor3 = Color3.fromRGB(43, 43, 48),

    Text = "—",

    TextColor3 = Config.Text,

    Font = Enum.Font.GothamBold,

    TextSize = 17,

    BorderSizePixel = 0,

}, Header)



round(MinimizeButton, 7)



--==================================================

-- DRAG SYSTEM

--==================================================



local dragging = false

local dragInput

local dragStart

local startPosition



connect(Header.InputBegan, function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1

        or input.UserInputType == Enum.UserInputType.Touch then



        dragging = true

        dragStart = input.Position

        startPosition = Main.Position

    end

end)



connect(UserInputService.InputChanged, function(input)

    if dragging and (

        input.UserInputType == Enum.UserInputType.MouseMovement

        or input.UserInputType == Enum.UserInputType.Touch

    ) then



        local delta = input.Position - dragStart



        Main.Position = UDim2.new(

            startPosition.X.Scale,

            startPosition.X.Offset + delta.X,

            startPosition.Y.Scale,

            startPosition.Y.Offset + delta.Y

        )

    end

end)



connect(UserInputService.InputEnded, function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1

        or input.UserInputType == Enum.UserInputType.Touch then



        dragging = false

    end

end)



--==================================================

-- CONTENT CONTAINER

--==================================================



local Body = create("Frame", {

    Position = UDim2.fromOffset(0, 48),

    Size = UDim2.new(1, 0, 1, -48),

    BackgroundTransparency = 1,

}, Main)



local Sidebar = create("Frame", {

    Size = UDim2.new(0, 145, 1, 0),

    BackgroundColor3 = Color3.fromRGB(19, 19, 22),

    BorderSizePixel = 0,

}, Body)



local Content = create("Frame", {

    Position = UDim2.fromOffset(157, 12),

    Size = UDim2.new(1, -169, 1, -24),

    BackgroundTransparency = 1,

}, Body)



--==================================================

-- TAB SYSTEM

--==================================================



local TabNames = {

    "ESP",

    "AIM",

    "VISUALS",

    "SETTINGS",

}



local TabButtons = {}

local TabPages = {}



for index, name in ipairs(TabNames) do



    local button = create("TextButton", {

        Size = UDim2.fromOffset(125, 38),

        Position = UDim2.fromOffset(10, 15 + (index - 1) * 46),

        BackgroundColor3 = Config.Panel,

        Text = name,

        TextColor3 = Config.Text,

        Font = Enum.Font.GothamMedium,

        TextSize = 12,

        BorderSizePixel = 0,

    }, Sidebar)



    round(button, 7)



    local page = create("ScrollingFrame", {

        Name = name,

        Size = UDim2.fromScale(1, 1),

        BackgroundTransparency = 1,

        BorderSizePixel = 0,

        ScrollBarThickness = 3,

        ScrollBarImageColor3 = Config.Accent,

        CanvasSize = UDim2.new(),

        AutomaticCanvasSize = Enum.AutomaticSize.Y,

        Visible = false,

    }, Content)



    create("UIListLayout", {

        Padding = UDim.new(0, 8),

        SortOrder = Enum.SortOrder.LayoutOrder,

    }, page)



    TabButtons[name] = button

    TabPages[name] = page

end



local function switchTab(name)

    CurrentTab = name



    for tab, page in pairs(TabPages) do

        page.Visible = tab == name

    end



    for tab, button in pairs(TabButtons) do

        tween(button, {

            BackgroundColor3 = tab == name

                and Color3.fromRGB(55, 55, 62)

                or Config.Panel

        })

    end

end



-- TAB BUTTON CONNECTIONS

for _, name in ipairs(TabNames) do

    local tabName = name



    TabButtons[tabName].Activated:Connect(function()

        switchTab(tabName)

    end)

end



switchTab("ESP")

--==================================================

-- WIDGETS

--==================================================



local function section(parent, title)

    return create("TextLabel", {

        Size = UDim2.new(1, -8, 0, 28),

        BackgroundTransparency = 1,

        Text = title,

        TextColor3 = Config.Accent,

        Font = Enum.Font.GothamBold,

        TextSize = 12,

        TextXAlignment = Enum.TextXAlignment.Left,

    }, parent)

end



local function action(parent, title, callback)

    local button = create("TextButton", {

        Size = UDim2.new(1, -8, 0, 36),

        BackgroundColor3 = Config.Panel,

        Text = title,

        TextColor3 = Config.Text,

        TextSize = 12,

        Font = Enum.Font.GothamMedium,

        BorderSizePixel = 0,

        AutoButtonColor = true,

    }, parent)



    round(button, 7)



    connect(button.MouseButton1Click, callback)



    return button

end



local function toggle(parent, title, initial, callback)

    local enabled = initial



    local button = create("TextButton", {

        Size = UDim2.new(1, -8, 0, 36),

        BackgroundColor3 = Config.Panel,

        Text = "",

        BorderSizePixel = 0,

    }, parent)



    round(button, 7)



    create("TextLabel", {

        Position = UDim2.fromOffset(12, 0),

        Size = UDim2.new(1, -65, 1, 0),

        BackgroundTransparency = 1,

        Text = title,

        TextColor3 = Config.Text,

        TextSize = 12,

        Font = Enum.Font.GothamMedium,

        TextXAlignment = Enum.TextXAlignment.Left,

    }, button)



    local indicator = create("Frame", {

        Size = UDim2.fromOffset(32, 17),

        Position = UDim2.new(1, -44, 0.5, -8),

        BackgroundColor3 = enabled

            and Config.Accent

            or Color3.fromRGB(65, 65, 70),

        BorderSizePixel = 0,

    }, button)



    round(indicator, 20)



    local toggleEntry

    local function setValue(value)
        enabled = value
        if toggleEntry then
            toggleEntry.Enabled = enabled
        end

        tween(indicator, {
            BackgroundColor3 = enabled
                and Config.Accent
                or Color3.fromRGB(65, 65, 70)
        })

        callback(enabled)
    end

    connect(button.MouseButton1Click, function()
        setValue(not enabled)
    end)

    toggleEntry = {
        Name = title,
        Enabled = enabled,
        Set = setValue,
        KeyCode = nil,
    }
    table.insert(ToggleRegistry, toggleEntry)

    return setValue

end



local function slider(parent, title, minimum, maximum, initial, callback)
    local value = initial

    local container = create("Frame", {
        Size = UDim2.new(1, -8, 0, 65),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
    }, parent)
    round(container, 7)

    local label = create("TextLabel", {
        Position = UDim2.fromOffset(10, 3),
        Size = UDim2.new(1, -20, 0, 25),
        BackgroundTransparency = 1,
        Text = title .. ": " .. tostring(value),
        TextColor3 = Config.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, container)

    local valueInput = create("TextBox", {
        Position = UDim2.new(1, -147, 0, 34),
        Size = UDim2.fromOffset(55, 23),
        BackgroundColor3 = Color3.fromRGB(42, 42, 48),
        Text = tostring(value),
        PlaceholderText = tostring(value),
        TextColor3 = Config.Text,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
    }, container)

    local minus = create("TextButton", {
        Position = UDim2.new(1, -83, 0, 34),
        Size = UDim2.fromOffset(29, 23),
        BackgroundColor3 = Color3.fromRGB(52, 52, 58),
        Text = "-",
        TextColor3 = Config.Text,
        BorderSizePixel = 0,
    }, container)

    local plus = create("TextButton", {
        Position = UDim2.new(1, -43, 0, 34),
        Size = UDim2.fromOffset(29, 23),
        BackgroundColor3 = Color3.fromRGB(52, 52, 58),
        Text = "+",
        TextColor3 = Config.Text,
        BorderSizePixel = 0,
    }, container)

    round(valueInput, 5)
    round(minus, 5)
    round(plus, 5)

    local function setValue(newValue)
        newValue = tonumber(newValue)
        if not newValue then
            valueInput.Text = tostring(value)
            return
        end

        value = math.clamp(math.floor(newValue + 0.5), minimum, maximum)
        label.Text = title .. ": " .. tostring(value)
        valueInput.Text = tostring(value)
        callback(value)
    end

    connect(valueInput.FocusLost, function()
        setValue(valueInput.Text)
    end)

    connect(minus.MouseButton1Click, function()
        setValue(value - 1)
    end)

    connect(plus.MouseButton1Click, function()
        setValue(value + 1)
    end)

    return setValue
end




--==================================================

-- FOV CIRCLE

--==================================================



local FOVCircle = create("Frame", {

    Name = "FOVCircle",

    AnchorPoint = Vector2.new(0.5, 0.5),

    Position = UDim2.fromScale(0.5, 0.5),

    Size = UDim2.fromOffset(

        Config.FOVRadius * 2,

        Config.FOVRadius * 2

    ),

    BackgroundTransparency = 1,

    Visible = Config.FOVVisible,

    ZIndex = 5,

}, Gui)



round(FOVCircle, 100)

local FOVStroke = stroke(FOVCircle, Config.Accent, 1.5)

FOVStroke.Transparency = 0.2



local function updateFOVCircle()

    local diameter = Config.FOVRadius * 2



    FOVCircle.Size = UDim2.fromOffset(diameter, diameter)

    FOVCircle.Visible = Config.FOVVisible

    FOVStroke.Color = Config.Accent

end



--==================================================

-- WALL / LINE-OF-SIGHT CHECK

--==================================================

-- Raycast only for AIM. The target and local character are excluded so only
-- collidable world geometry between the camera and target can block visibility.
local function hasLineOfSight(targetCharacter, targetPart)
    if not targetCharacter or not targetCharacter.Parent or not targetPart
        or not targetPart:IsA("BasePart") then
        return false
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return false
    end

    local origin = camera.CFrame.Position
    local direction = targetPart.Position - origin
    if direction.Magnitude <= 0.01 then
        return true
    end

    local exclusions = {targetCharacter}
    local localCharacter = LocalPlayer.Character
    if localCharacter then
        table.insert(exclusions, localCharacter)
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = exclusions
    rayParams.IgnoreWater = true
    rayParams.RespectCanCollide = true

    local ok, result = pcall(function()
        return Workspace:Raycast(origin, direction, rayParams)
    end)

    if not ok then
        warn("[CART3R] AIM wall-check raycast failed: " .. tostring(result))
        return false
    end

    -- No collidable obstacle was hit before the target.
    return result == nil
end


--==================================================

-- ESP SYSTEM

--==================================================



local function removeESP(player)

    local objects = ESPObjects[player]



    if not objects then

        return

    end



    for _, object in ipairs(objects) do

        if typeof(object) == "RBXScriptConnection" then

            object:Disconnect()

        elseif typeof(object) == "Instance" then

            object:Destroy()

        end

    end



    ESPObjects[player] = nil

end



local function applyESPDepthMode()
    local depthMode = Config.ESPThroughWalls
        and Enum.HighlightDepthMode.AlwaysOnTop
        or Enum.HighlightDepthMode.Occluded
    local billboardAlwaysOnTop = Config.ESPThroughWalls

    for _, objects in pairs(ESPObjects) do
        for _, object in ipairs(objects) do
            if object and object.Parent then
                if object:IsA("Highlight") then
                    object.DepthMode = depthMode
                elseif object:IsA("BillboardGui") then
                    object.AlwaysOnTop = billboardAlwaysOnTop
                end
            end
        end
    end
end


local function updateESP(player)

    removeESP(player)



    if not Config.ESP or player == LocalPlayer then

        return

    end



    local character = player.Character

    if not character then return end



    local humanoid = character:FindFirstChildOfClass("Humanoid")

    local head = character:FindFirstChild("Head")



    if not humanoid or not head then

        return

    end



    local objects = {}



    local highlight = create("Highlight", {

        Adornee = character,

        FillColor = Config.Accent,

        OutlineColor = Config.Text,

        FillTransparency = 0.7,

        OutlineTransparency = 0,

        Enabled = true,

        DepthMode = Config.ESPThroughWalls
            and Enum.HighlightDepthMode.AlwaysOnTop
            or Enum.HighlightDepthMode.Occluded,

    }, ESPHighlightFolder)



    table.insert(objects, highlight)



    local billboard = create("BillboardGui", {

        Name = "CarterESP",

        Adornee = head,

        Size = UDim2.fromOffset(160, 55),

        StudsOffset = Vector3.new(0, 2.7, 0),

        AlwaysOnTop = Config.ESPThroughWalls,

        MaxDistance = Config.ESPDistance,

    }, Gui)



    local label = create("TextLabel", {

        Size = UDim2.fromScale(1, 1),

        BackgroundTransparency = 1,

        TextColor3 = Config.Text,

        TextStrokeTransparency = 0.25,

        TextSize = 12,

        Font = Enum.Font.GothamBold,

        Text = "",

    }, billboard)



    local function refreshLabel()

        if not character.Parent then return end



        local parts = {}



        if Config.ShowNames then

            table.insert(parts, player.DisplayName)

        end



        if Config.ShowDistance then

            local ownCharacter = LocalPlayer.Character

            local ownRoot = ownCharacter

                and ownCharacter:FindFirstChild("HumanoidRootPart")



            local targetRoot = character:FindFirstChild("HumanoidRootPart")



            if ownRoot and targetRoot then

                local distance = (

                    ownRoot.Position - targetRoot.Position

                ).Magnitude



                table.insert(parts, math.floor(distance) .. " studs")

            end

        end



        if Config.ShowHealth then

            table.insert(

                parts,

                "HP " .. math.floor(humanoid.Health)

            )

        end



        label.Text = table.concat(parts, "\n")

        highlight.FillColor = Config.Accent

    end



    table.insert(objects, billboard)

    table.insert(objects, connect(humanoid.HealthChanged, refreshLabel))



    ESPObjects[player] = objects



    refreshLabel()

end



local function refreshESP()

    for _, player in ipairs(Players:GetPlayers()) do

        updateESP(player)

    end

end


--==================================================

-- ESP PAGE

--==================================================



local ESPPage = TabPages.ESP



section(ESPPage, "PLAYER ESP")



toggle(ESPPage, "Enable player ESP", Config.ESP, function(value)

    Config.ESP = value

    refreshESP()

    notify("ESP " .. (value and "enabled" or "disabled"))

end)



toggle(ESPPage, "Show names", Config.ShowNames, function(value)

    Config.ShowNames = value

    refreshESP()

end)



toggle(ESPPage, "Show distance", Config.ShowDistance, function(value)

    Config.ShowDistance = value

    refreshESP()

end)



toggle(ESPPage, "Show health", Config.ShowHealth, function(value)

    Config.ShowHealth = value

    refreshESP()

end)

toggle(ESPPage, "ESP through walls", Config.ESPThroughWalls, function(value)
    Config.ESPThroughWalls = value
    applyESPDepthMode()
    notify(value and "ESP through walls enabled" or "ESP through walls disabled")
end)


slider(ESPPage, "Maximum ESP distance", 50, 10000, Config.ESPDistance, function(value)

    Config.ESPDistance = value



    for _, objects in pairs(ESPObjects) do

        for _, object in ipairs(objects) do

            if object:IsA("BillboardGui") then

                object.MaxDistance = value

            end

        end

    end

end)



section(ESPPage, "PLAYER SEARCH")



local Search = create("TextBox", {

    Size = UDim2.new(1, -8, 0, 36),

    BackgroundColor3 = Config.Panel,

    PlaceholderText = "Search player...",

    Text = "",

    TextColor3 = Config.Text,

    PlaceholderColor3 = Color3.fromRGB(130, 130, 130),

    Font = Enum.Font.Gotham,

    TextSize = 12,

    BorderSizePixel = 0,

    ClearTextOnFocus = false,

}, ESPPage)



round(Search, 7)



local SearchResults = create("TextLabel", {

    Size = UDim2.new(1, -8, 0, 55),

    BackgroundTransparency = 1,

    Text = "Enter a player name.",

    TextColor3 = Config.Text,

    TextSize = 11,

    Font = Enum.Font.Gotham,

    TextXAlignment = Enum.TextXAlignment.Left,

    TextYAlignment = Enum.TextYAlignment.Top,

    TextWrapped = true,

}, ESPPage)



connect(Search:GetPropertyChangedSignal("Text"), function()

    local query = string.lower(Search.Text)

    local results = {}



    for _, player in ipairs(Players:GetPlayers()) do

        if string.find(string.lower(player.Name), query, 1, true)

            or string.find(string.lower(player.DisplayName), query, 1, true) then



            table.insert(results, player.DisplayName .. " (@" .. player.Name .. ")")

        end

    end



    SearchResults.Text = #results > 0

        and table.concat(results, "\n")

        or "No players found"

end)



--==================================================

-- AIM SYSTEM

--==================================================

local TARGET_SCAN_INTERVAL = 0.08

local lastTargetScan = 0

local cachedTarget = nil
local targetStatus = nil



local function getTargetParts(model)

    if not model or not model:IsA("Model") then

        return nil, nil

    end



    local humanoid = model:FindFirstChildOfClass("Humanoid")

    local root = model:FindFirstChild("HumanoidRootPart")

        or model.PrimaryPart



    if not humanoid or humanoid.Health <= 0 then

        return nil, nil

    end



    if not root or not root:IsA("BasePart") then

        return nil, nil

    end



    return humanoid, root

end



local function isValidTarget(model)

    if not model or not model:IsA("Model") then

        return false

    end



    -- Игроки твоей игры

    local player = Players:GetPlayerFromCharacter(model)

    if player then

        if player == LocalPlayer then

            return false

        end

        return getTargetParts(model) ~= nil

    end



    -- NPC с тегом или атрибутом

    if CollectionService:HasTag(model, "CarterAimTarget")

        or model:GetAttribute("CarterAimTarget") == true then

        return getTargetParts(model) ~= nil

    end



    return false

end



local function getSelectedAimPart(model)
    if not model or not Config.AimRigType or not Config.AimBodyPart then
        return nil
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return nil
    end

    local requiredRig = Config.AimRigType == "R6"
        and Enum.HumanoidRigType.R6
        or Enum.HumanoidRigType.R15

    if humanoid.RigType ~= requiredRig then
        return nil
    end

    local part = model:FindFirstChild(Config.AimBodyPart)
    if part and part:IsA("BasePart") then
        return part
    end

    return nil
end

local function findNearestTarget(camera)
    if not Config.AimRigType or not Config.AimBodyPart then
        return nil
    end

    local screenCenter = camera.ViewportSize / 2
    local bestModel = nil
    local bestScreenDistance = Config.FOVRadius

    local character = LocalPlayer.Character
    local ownRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not ownRoot then
        return nil
    end

    local function considerModel(model)
        if not model or not isValidTarget(model) then
            return
        end

        local _, root = getTargetParts(model)
        local aimPart = getSelectedAimPart(model)
        if not root or not aimPart then
            return
        end

        if Config.AIMWallCheck and not hasLineOfSight(model, aimPart) then
            return
        end

        local worldDistance = (root.Position - ownRoot.Position).Magnitude
        if worldDistance > Config.MaxAimDistance then
            return
        end

        local screenPosition, onScreen = camera:WorldToViewportPoint(aimPart.Position)
        if not onScreen or screenPosition.Z <= 0 then
            return
        end

        local screenDistance = (
            Vector2.new(screenPosition.X, screenPosition.Y) - screenCenter
        ).Magnitude

        if screenDistance < bestScreenDistance then
            bestScreenDistance = screenDistance
            bestModel = model
        end
    end

    -- Scan players rather than Workspace descendants.
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            considerModel(player.Character)
        end
    end

    -- Keep support for tagged training NPCs.
    for _, model in ipairs(CollectionService:GetTagged("CarterAimTarget")) do
        if model:IsA("Model") then
            considerModel(model)
        end
    end

    return bestModel
end

local function updateAim(deltaTime)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    if not Config.AIMEnabled then
        selectedTarget = nil
        cachedTarget = nil
        if targetStatus then
            targetStatus.Text = "Target: Disabled"
        end
        return
    end

    if not Config.AimRigType or not Config.AimBodyPart then
        selectedTarget = nil
        cachedTarget = nil
        if targetStatus then
            targetStatus.Text = "Target: Select rig and body part"
        end
        return
    end

    -- Target search is throttled to avoid scanning on every rendered frame.
    local now = os.clock()
    if now - lastTargetScan >= TARGET_SCAN_INTERVAL then
        lastTargetScan = now
        cachedTarget = findNearestTarget(camera)
    end

    local target = cachedTarget
    selectedTarget = target

    if not target or not isValidTarget(target) then
        cachedTarget = nil
        selectedTarget = nil
        targetStatus.Text = "Target: None"
        return
    end

    local aimPart = getSelectedAimPart(target)
    if not aimPart then
        cachedTarget = nil
        selectedTarget = nil
        targetStatus.Text = "Target: Selected body part unavailable"
        return
    end

    if Config.AIMWallCheck and not hasLineOfSight(target, aimPart) then
        cachedTarget = nil
        selectedTarget = nil
        targetStatus.Text = "Target: Blocked by wall"
        return
    end

    targetStatus.Text = "Target: " .. target.Name .. " / " .. Config.AimBodyPart

    local desired = CFrame.lookAt(camera.CFrame.Position, aimPart.Position)
    local alpha = 1 - math.exp(-Config.AimSpeed * 0.3 * deltaTime)

    camera.CFrame = camera.CFrame:Lerp(desired, math.clamp(alpha, 0, 1))
end

--==================================================
-- AIM PAGE
--==================================================

local AIMPage = TabPages.AIM

section(AIMPage, "AIM SETTINGS")

targetStatus = create("TextLabel", {
    Size = UDim2.new(1, -8, 0, 34),
    BackgroundColor3 = Config.Panel,
    Text = "Target: Disabled",
    TextColor3 = Config.Text,
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    BorderSizePixel = 0,
}, AIMPage)
round(targetStatus, 7)

local setAimEnabled
setAimEnabled = toggle(AIMPage, "Enable AIM lock-on", Config.AIMEnabled, function(value)
    if value and (not Config.AimRigType or not Config.AimBodyPart) then
        Config.AIMEnabled = false
        notify("Select R15/R6 and one body part first")
        task.defer(function()
            if setAimEnabled then
                setAimEnabled(false)
            end
        end)
        return
    end

    Config.AIMEnabled = value
    cachedTarget = nil
    selectedTarget = nil
    lastTargetScan = 0
    targetStatus.Text = value and "Target: Searching..." or "Target: Disabled"
    notify(value and "AIM enabled" or "AIM disabled")
end)

toggle(AIMPage, "Wall check (visible targets only)", Config.AIMWallCheck, function(value)
    Config.AIMWallCheck = value
    cachedTarget = nil
    selectedTarget = nil
    notify(value and "AIM wall check enabled" or "AIM wall check disabled")
end)

toggle(AIMPage, "Show FOV circle", Config.FOVVisible, function(value)
    Config.FOVVisible = value
    updateFOVCircle()
end)

slider(AIMPage, "FOV radius (px)", 20, 400, Config.FOVRadius, function(value)
    Config.FOVRadius = value
    updateFOVCircle()
    cachedTarget = nil
end)

slider(AIMPage, "Aim speed", 1, 400, Config.AimSpeed, function(value)
    Config.AimSpeed = value
end)

slider(AIMPage, "Maximum target distance", 50, 10000, Config.MaxAimDistance, function(value)
    Config.MaxAimDistance = value
    cachedTarget = nil
end)

slider(AIMPage, "Camera FOV", 50, 120, Config.CameraFOV, function(value)
    Config.CameraFOV = value
    local camera = Workspace.CurrentCamera
    if camera then
        camera.FieldOfView = value
    end
end)

section(AIMPage, "TARGET INFO")

local bodySelector = create("Frame", {
    Name = "BodyPartSelector",
    Size = UDim2.new(1, -8, 0, 355),
    BackgroundColor3 = Config.Panel,
    BorderSizePixel = 0,
}, AIMPage)
round(bodySelector, 8)

create("TextLabel", {
    Position = UDim2.fromOffset(10, 5),
    Size = UDim2.new(1, -20, 0, 22),
    BackgroundTransparency = 1,
    Text = "1. SELECT RIG TYPE",
    TextColor3 = Config.Accent,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, bodySelector)

local function makeRigButton(text, x)
    local button = create("TextButton", {
        Position = UDim2.fromOffset(x, 30),
        Size = UDim2.fromOffset(82, 29),
        BackgroundColor3 = Color3.fromRGB(48, 48, 55),
        Text = text,
        TextColor3 = Config.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        BorderSizePixel = 0,
    }, bodySelector)
    round(button, 6)
    return button
end

local R15Button = makeRigButton("R15", 10)
local R6Button = makeRigButton("R6", 100)

create("TextLabel", {
    Position = UDim2.fromOffset(10, 66),
    Size = UDim2.new(1, -20, 0, 22),
    BackgroundTransparency = 1,
    Text = "2. CLICK ONE BODY PART ON THE DIAGRAM",
    TextColor3 = Config.Accent,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, bodySelector)

local bodyMap = create("Frame", {
    Name = "BodyDiagram",
    Position = UDim2.fromOffset(10, 91),
    Size = UDim2.fromOffset(250, 250),
    BackgroundColor3 = Color3.fromRGB(18, 18, 22),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, bodySelector)
round(bodyMap, 7)

local selectedPartLabel = create("TextLabel", {
    Position = UDim2.fromOffset(270, 104),
    Size = UDim2.new(1, -280, 0, 65),
    BackgroundTransparency = 1,
    Text = "Selected: " .. tostring(Config.AimBodyPart or "None"),
    TextColor3 = Config.Text,
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, bodySelector)

create("TextLabel", {
    Position = UDim2.fromOffset(270, 174),
    Size = UDim2.new(1, -280, 0, 90),
    BackgroundTransparency = 1,
    Text = "Only one part can be selected. Changing R6/R15 resets the part selection.",
    TextColor3 = Color3.fromRGB(165, 165, 172),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, bodySelector)

local bodyMapButtons = {}
local bodyPartLayouts = {
    R15 = {
        {Part = "Head", Label = "HEAD", X = 101, Y = 6, W = 48, H = 27},
        {Part = "UpperTorso", Label = "UPPER", X = 94, Y = 37, W = 62, H = 35},
        {Part = "LowerTorso", Label = "LOWER", X = 97, Y = 75, W = 56, H = 29},
        {Part = "LeftUpperArm", Label = "L U-ARM", X = 46, Y = 39, W = 44, H = 34},
        {Part = "RightUpperArm", Label = "R U-ARM", X = 160, Y = 39, W = 44, H = 34},
        {Part = "LeftLowerArm", Label = "L ARM", X = 32, Y = 77, W = 50, H = 34},
        {Part = "RightLowerArm", Label = "R ARM", X = 168, Y = 77, W = 50, H = 34},
        {Part = "LeftHand", Label = "L HAND", X = 20, Y = 115, W = 50, H = 25},
        {Part = "RightHand", Label = "R HAND", X = 180, Y = 115, W = 50, H = 25},
        {Part = "LeftUpperLeg", Label = "L U-LEG", X = 88, Y = 108, W = 39, H = 39},
        {Part = "RightUpperLeg", Label = "R U-LEG", X = 130, Y = 108, W = 39, H = 39},
        {Part = "LeftLowerLeg", Label = "L LEG", X = 86, Y = 150, W = 39, H = 39},
        {Part = "RightLowerLeg", Label = "R LEG", X = 132, Y = 150, W = 39, H = 39},
        {Part = "LeftFoot", Label = "L FOOT", X = 76, Y = 193, W = 51, H = 25},
        {Part = "RightFoot", Label = "R FOOT", X = 130, Y = 193, W = 51, H = 25},
    },
    R6 = {
        {Part = "Head", Label = "HEAD", X = 101, Y = 12, W = 48, H = 29},
        {Part = "Torso", Label = "TORSO", X = 91, Y = 47, W = 67, H = 58},
        {Part = "Left Arm", Label = "L ARM", X = 49, Y = 49, W = 36, H = 88},
        {Part = "Right Arm", Label = "R ARM", X = 164, Y = 49, W = 36, H = 88},
        {Part = "Left Leg", Label = "L LEG", X = 90, Y = 110, W = 36, H = 100},
        {Part = "Right Leg", Label = "R LEG", X = 126, Y = 110, W = 36, H = 100},
    },
}

local function refreshBodyPartButtons()
    for _, info in ipairs(bodyMapButtons) do
        info.Button.BackgroundColor3 = Config.AimBodyPart == info.Part
            and Config.Accent
            or Color3.fromRGB(55, 55, 63)
    end

    selectedPartLabel.Text = "Selected: " .. tostring(Config.AimBodyPart or "None")
end

local function renderBodyMap()
    for _, info in ipairs(bodyMapButtons) do
        info.Button:Destroy()
    end
    table.clear(bodyMapButtons)

    local layout = Config.AimRigType and bodyPartLayouts[Config.AimRigType]
    if not layout then
        selectedPartLabel.Text = "Select R15 or R6 first."
        return
    end

    for _, partInfo in ipairs(layout) do
        local button = create("TextButton", {
            Name = "Part_" .. partInfo.Part:gsub("%W", ""),
            Position = UDim2.fromOffset(partInfo.X, partInfo.Y),
            Size = UDim2.fromOffset(partInfo.W, partInfo.H),
            BackgroundColor3 = Config.AimBodyPart == partInfo.Part
                and Config.Accent
                or Color3.fromRGB(55, 55, 63),
            Text = partInfo.Label,
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 8,
            TextWrapped = true,
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, bodyMap)
        round(button, 5)

        table.insert(bodyMapButtons, {Part = partInfo.Part, Button = button})
        connect(button.Activated, function()
            Config.AimBodyPart = partInfo.Part
            cachedTarget = nil
            selectedTarget = nil
            refreshBodyPartButtons()
            notify("Aim part: " .. partInfo.Part)
        end)
    end

    refreshBodyPartButtons()
end

local function setRigType(rigType)
    Config.AimRigType = rigType
    Config.AimBodyPart = nil
    Config.AIMEnabled = false
    cachedTarget = nil
    selectedTarget = nil
    lastTargetScan = 0

    R15Button.BackgroundColor3 = rigType == "R15" and Config.Accent or Color3.fromRGB(48, 48, 55)
    R6Button.BackgroundColor3 = rigType == "R6" and Config.Accent or Color3.fromRGB(48, 48, 55)

    if setAimEnabled then
        setAimEnabled(false)
    end

    targetStatus.Text = "Target: Select a body part"
    renderBodyMap()
end

connect(R15Button.Activated, function()
    setRigType("R15")
end)
connect(R6Button.Activated, function()
    setRigType("R6")
end)

R15Button.BackgroundColor3 = Config.AimRigType == "R15" and Config.Accent or Color3.fromRGB(48, 48, 55)
R6Button.BackgroundColor3 = Config.AimRigType == "R6" and Config.Accent or Color3.fromRGB(48, 48, 55)
renderBodyMap()


--==================================================

-- VISUALS PAGE

--==================================================



local VisualPage = TabPages.VISUALS



section(VisualPage, "CROSSHAIR")



local Crosshair = create("TextLabel", {

    Name = "Crosshair",

    Size = UDim2.fromOffset(30, 30),

    Position = UDim2.fromScale(0.5, 0.5),

    AnchorPoint = Vector2.new(0.5, 0.5),

    BackgroundTransparency = 1,

    Text = "+",

    TextColor3 = Config.Accent,

    TextSize = 24,

    Font = Enum.Font.GothamBold,

    Visible = Config.Crosshair,

    ZIndex = 6,

}, Gui)



toggle(VisualPage, "Enable crosshair", Config.Crosshair, function(value)

    Config.Crosshair = value

    Crosshair.Visible = value

end)



section(VisualPage, "LIGHTING")



toggle(VisualPage, "Bloom effect", Config.Bloom, function(value)

    Config.Bloom = value



    local bloom = Lighting:FindFirstChild("CarterBloom")



    if value then

        if not bloom then

            bloom = create("BloomEffect", {

                Name = "CarterBloom",

                Intensity = 0.3,

                Size = 24,

                Threshold = 1,

            }, Lighting)

        end

    elseif bloom then

        bloom:Destroy()

    end

end)



section(VisualPage, "ACCENT COLORS")



local colorOptions = {

    {"Gray", Color3.fromRGB(155, 155, 165)},

    {"Red", Color3.fromRGB(220, 65, 65)},

    {"Blue", Color3.fromRGB(65, 130, 230)},

    {"Green", Color3.fromRGB(75, 190, 120)},

    {"Purple", Color3.fromRGB(155, 100, 220)},

}



local function applyAccent(color)

    Config.Accent = color



    FOVStroke.Color = color

    Crosshair.TextColor3 = color



    for _, button in pairs(TabButtons) do

        if button.BackgroundColor3 == color then

            button.BackgroundColor3 = color

        end

    end



    refreshESP()

    notify("Accent updated")

end



for _, option in ipairs(colorOptions) do

    action(VisualPage, "Accent: " .. option[1], function()

        applyAccent(option[2])

    end)

end



--==================================================
-- RESIZABLE KEYBIND MINI GUI
--==================================================

local MiniBindPanel = create("Frame", {
    Name = "KeybindMiniGUI",
    Size = UDim2.fromOffset(240, 160),
    Position = UDim2.new(1, -258, 0, 18),
    BackgroundColor3 = Config.Background,
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 80,
}, Gui)
round(MiniBindPanel, 9)
stroke(MiniBindPanel, Color3.fromRGB(75, 75, 84))

local MiniBindHeader = create("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Config.Panel,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 81,
}, MiniBindPanel)

create("TextLabel", {
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -20, 1, 0),
    BackgroundTransparency = 1,
    Text = "KEYBINDS",
    TextColor3 = Config.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 82,
}, MiniBindHeader)

local MiniBindList = create("ScrollingFrame", {
    Position = UDim2.fromOffset(7, 34),
    Size = UDim2.new(1, -14, 1, -41),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 81,
}, MiniBindPanel)
create("UIListLayout", {
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, MiniBindList)

local MiniResizeHandle = create("TextButton", {
    Name = "ResizeHandle",
    Size = UDim2.fromOffset(18, 18),
    Position = UDim2.new(1, -18, 1, -18),
    BackgroundColor3 = Color3.fromRGB(55, 55, 62),
    Text = "◢",
    TextColor3 = Config.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    BorderSizePixel = 0,
    ZIndex = 84,
}, MiniBindPanel)
round(MiniResizeHandle, 4)

local function refreshMiniBindPanel()
    for _, child in ipairs(MiniBindList:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local entries = {}
    if MenuKey then
        table.insert(entries, {Name = "Main Menu", Key = MenuKey.Name})
    end

    for _, entry in ipairs(ToggleRegistry) do
        if entry.KeyCode then
            table.insert(entries, {Name = entry.Name, Key = entry.KeyCode.Name})
        end
    end

    if #entries == 0 then
        create("TextLabel", {
            Size = UDim2.new(1, -5, 0, 22),
            BackgroundTransparency = 1,
            Text = "No keybinds assigned",
            TextColor3 = Color3.fromRGB(155, 155, 160),
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 82,
        }, MiniBindList)
        return
    end

    for index, entry in ipairs(entries) do
        create("TextLabel", {
            Name = "BindEntry",
            LayoutOrder = index,
            Size = UDim2.new(1, -5, 0, 20),
            BackgroundColor3 = Config.Panel,
            BackgroundTransparency = 0.12,
            Text = entry.Name .. "    [" .. entry.Key .. "]",
            TextColor3 = Config.Text,
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            ZIndex = 82,
        }, MiniBindList)
    end
end

local miniDragging = false
local miniResizing = false
local miniDragStart = nil
local miniStartPosition = nil
local miniStartSize = nil

connect(MiniBindHeader.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = true
        miniDragStart = input.Position
        miniStartPosition = MiniBindPanel.Position
    end
end)

connect(MiniResizeHandle.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        miniResizing = true
        miniDragStart = input.Position
        miniStartSize = MiniBindPanel.AbsoluteSize
    end
end)

connect(UserInputService.InputChanged, function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    if miniDragging and miniDragStart and miniStartPosition then
        local delta = input.Position - miniDragStart
        MiniBindPanel.Position = UDim2.new(
            miniStartPosition.X.Scale, miniStartPosition.X.Offset + delta.X,
            miniStartPosition.Y.Scale, miniStartPosition.Y.Offset + delta.Y
        )
    elseif miniResizing and miniDragStart and miniStartSize then
        local delta = input.Position - miniDragStart
        local width = math.clamp(miniStartSize.X + delta.X, 180, 600)
        local height = math.clamp(miniStartSize.Y + delta.Y, 95, 500)
        MiniBindPanel.Size = UDim2.fromOffset(width, height)
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = false
        miniResizing = false
    end
end)

refreshMiniBindPanel()

--==================================================

-- SETTINGS PAGE

--==================================================



local SettingsPage = TabPages.SETTINGS



section(SettingsPage, "GENERAL")



toggle(SettingsPage, "Notifications", Config.Notifications, function(value)

    Config.Notifications = value

end)



toggle(SettingsPage, "Animations", Config.Animations, function(value)

    Config.Animations = value

end)



slider(SettingsPage, "Window transparency", 0, 80, 5, function(value)

    Config.Transparency = value / 100

    Main.BackgroundTransparency = Config.Transparency

end)



section(SettingsPage, "PROFILE MANAGER")



local ProfileName = create("TextBox", {

    Size = UDim2.new(1, -8, 0, 36),

    BackgroundColor3 = Config.Panel,

    Text = "MyProfile",

    PlaceholderText = "Profile name",

    TextColor3 = Config.Text,

    Font = Enum.Font.Gotham,

    TextSize = 12,

    BorderSizePixel = 0,

    ClearTextOnFocus = false,

}, SettingsPage)



round(ProfileName, 7)



local function snapshot()

    local data = {}



    for key, value in pairs(Config) do

        data[key] = value

    end



    return data

end



local function applyProfile(data)

    if not data then return end



    for key, value in pairs(data) do

        Config[key] = value

    end



    Main.BackgroundTransparency = Config.Transparency

    Crosshair.Visible = Config.Crosshair

    Crosshair.TextColor3 = Config.Accent

    R15Button.BackgroundColor3 = Config.AimRigType == "R15" and Config.Accent or Color3.fromRGB(48, 48, 55)
    R6Button.BackgroundColor3 = Config.AimRigType == "R6" and Config.Accent or Color3.fromRGB(48, 48, 55)
    renderBodyMap()


    updateFOVCircle()

    refreshESP()



    local camera = Workspace.CurrentCamera



    if camera then

        camera.FieldOfView = Config.CameraFOV

    end



    notify("Profile loaded")

end



action(SettingsPage, "Save profile", function()

    local name = ProfileName.Text



    if name == "" then

        notify("Enter a profile name")

        return

    end



    Profiles[name] = snapshot()

    CurrentProfile = name



    notify("Saved: " .. name)

end)



action(SettingsPage, "Load profile", function()

    local profile = Profiles[ProfileName.Text]



    if not profile then

        notify("Profile not found")

        return

    end



    CurrentProfile = ProfileName.Text

    applyProfile(profile)

end)



action(SettingsPage, "Delete profile", function()

    local name = ProfileName.Text



    if Profiles[name] then

        Profiles[name] = nil

        notify("Profile deleted")

    else

        notify("Profile not found")

    end

end)



action(SettingsPage, "Reset configuration", function()

    for key, value in pairs(DEFAULTS) do

        Config[key] = value

    end



    selectedTarget = nil



    Main.BackgroundTransparency = Config.Transparency

    Crosshair.Visible = Config.Crosshair

    Crosshair.TextColor3 = Config.Accent

    R15Button.BackgroundColor3 = Config.AimRigType == "R15" and Config.Accent or Color3.fromRGB(48, 48, 55)
    R6Button.BackgroundColor3 = Config.AimRigType == "R6" and Config.Accent or Color3.fromRGB(48, 48, 55)
    renderBodyMap()
    if setAimEnabled then
        setAimEnabled(false)
    end
    targetStatus.Text = "Target: Disabled"


    updateFOVCircle()

    refreshESP()



    local camera = Workspace.CurrentCamera



    if camera then

        camera.FieldOfView = Config.CameraFOV

    end



    notify("Configuration reset")

end)



section(SettingsPage, "KEYBINDS")

local function keyLabel(keyCode)
    return keyCode and keyCode.Name or "Unbound"
end

local function refreshBindButtons()
    if MenuBindButton then
        MenuBindButton.Text = "Toggle Main Menu  [" .. keyLabel(MenuKey) .. "]"
    end

    for entry, button in pairs(bindButtons) do
        button.Text = entry.Name .. "  [" .. keyLabel(entry.KeyCode) .. "]"
    end

    refreshMiniBindPanel()
end

create("TextLabel", {
    Size = UDim2.new(1, -8, 0, 36),
    BackgroundTransparency = 1,
    Text = "Click a binding, then press a key. Backspace clears it; Escape cancels.",
    TextColor3 = Color3.fromRGB(165, 165, 172),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, SettingsPage)

MenuBindButton = action(SettingsPage, "Toggle Main Menu  [RightShift]", function()
    bindCapture = {Kind = "Menu", Button = MenuBindButton}
    MenuBindButton.Text = "Press a key for Main Menu..."
end)

for _, entry in ipairs(ToggleRegistry) do
    local currentEntry = entry
    local button = action(SettingsPage, currentEntry.Name .. "  [Unbound]", function()
        bindCapture = {Kind = "Toggle", Entry = currentEntry, Button = bindButtons[currentEntry]}
        bindButtons[currentEntry].Text = "Press a key for " .. currentEntry.Name .. "..."
    end)
    bindButtons[currentEntry] = button
end

action(SettingsPage, "Reset all keybinds", function()
    MenuKey = Enum.KeyCode.RightShift
    for _, entry in ipairs(ToggleRegistry) do
        entry.KeyCode = nil
    end
    bindCapture = nil
    refreshBindButtons()
    notify("Keybinds reset")
end)

refreshBindButtons()
-- MINIMIZE

--==================================================



connect(MinimizeButton.MouseButton1Click, function()

    minimized = not minimized

    Body.Visible = not minimized



    Main.Size = minimized

        and UDim2.fromOffset(590, 48)

        or UDim2.fromOffset(590, 410)



    MinimizeButton.Text = minimized and "+" or "—"

end)



--==================================================

-- PLAYER EVENTS

--==================================================



local function watchPlayer(player)

    if player == LocalPlayer then return end



    connect(player.CharacterAdded, function()

        task.wait(0.4)



        if Config.ESP then

            updateESP(player)

        end

    end)



    if Config.ESP and player.Character then

        updateESP(player)

    end

end



for _, player in ipairs(Players:GetPlayers()) do

    watchPlayer(player)

end



connect(Players.PlayerAdded, watchPlayer)



connect(Players.PlayerRemoving, function(player)

    removeESP(player)

end)



--==================================================

-- KEYBOARD SHORTCUTS

--==================================================



connect(UserInputService.InputBegan, function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    if UserInputService:GetFocusedTextBox() then
        return
    end

    if bindCapture then
        local capture = bindCapture
        local keyCode = input.KeyCode

        if keyCode == Enum.KeyCode.Escape then
            bindCapture = nil
            refreshBindButtons()
            notify("Keybind change cancelled")
            return
        end

        if keyCode == Enum.KeyCode.Backspace or keyCode == Enum.KeyCode.Delete then
            if capture.Kind == "Menu" then
                MenuKey = Enum.KeyCode.RightShift
                bindCapture = nil
                refreshBindButtons()
                notify("Main Menu key reset to RightShift")
            else
                capture.Entry.KeyCode = nil
                bindCapture = nil
                refreshBindButtons()
                notify("Keybind cleared")
            end
            return
        end

        if keyCode == Enum.KeyCode.Unknown then
            return
        end

        if capture.Kind == "Menu" then
            for _, entry in ipairs(ToggleRegistry) do
                if entry.KeyCode == keyCode then
                    entry.KeyCode = nil
                end
            end
            MenuKey = keyCode
        elseif keyCode == MenuKey then
            bindCapture = nil
            refreshBindButtons()
            notify("That key is reserved for the Main Menu")
            return
        else
            for _, entry in ipairs(ToggleRegistry) do
                if entry ~= capture.Entry and entry.KeyCode == keyCode then
                    entry.KeyCode = nil
                end
            end
            capture.Entry.KeyCode = keyCode
        end

        bindCapture = nil
        refreshBindButtons()
        notify("Keybind updated")
        return
    end

    if MenuKey and input.KeyCode == MenuKey then
        setMainMenuVisible(not Main.Visible)
        return
    end

    for _, entry in ipairs(ToggleRegistry) do
        if entry.KeyCode and input.KeyCode == entry.KeyCode then
            entry.Set(not entry.Enabled)
        end
    end
end)



--==================================================

-- RENDER LOOP

--==================================================



local renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
    if destroyed then
        return
    end

    local camera = Workspace.CurrentCamera

    if Config.AIMEnabled then
        updateAim(deltaTime)
    end

    if FOVCircle.Visible and camera then
        FOVCircle.Position = UDim2.fromOffset(
            camera.ViewportSize.X / 2,
            camera.ViewportSize.Y / 2
        )
    end
end)



table.insert(Connections, renderConnection)



--==================================================

-- INITIALIZATION

--==================================================



switchTab("ESP")

updateFOVCircle()



local camera = Workspace.CurrentCamera



if camera then

    camera.FieldOfView = Config.CameraFOV

end



notify("CART3R CLIENT SUITE 2.5 READY")



print("--------------------------------")

print("[CART3R] CLIENT SUITE 2.5")

print("[CART3R] FOV: 113 px")

print("[CART3R] Aim speed: " .. tostring(Config.AimSpeed))

print("[CART3R] Target: Nearest player / tagged NPC")

print("[CART3R] Toggle menu: " .. (MenuKey and MenuKey.Name or "Unbound"))

print("--------------------------------")



--==================================================

-- CLEANUP

--==================================================



connect(Gui.Destroying, function()

    if destroyed then return end



    destroyed = true

    Config.AIMEnabled = false



    for player in pairs(ESPObjects) do

        removeESP(player)

    end



    local bloom = Lighting:FindFirstChild("CarterBloom")



    if bloom then

        bloom:Destroy()

    end



    disconnectAll()

end)



-- END CART3R CLIENT SUITE 2.5
