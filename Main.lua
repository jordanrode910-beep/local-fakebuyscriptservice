local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI_PARENT
if getfenv().gethui then
    UI_PARENT = getfenv().gethui()
end
if not UI_PARENT then
    pcall(function() UI_PARENT = game:GetService("CoreGui") end)
end
if not UI_PARENT or not pcall(function() return UI_PARENT.Name end) then
    UI_PARENT = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function safeFont(name)
    local ok, font = pcall(function() return Enum.Font[name] end)
    if ok and font then return font else return Enum.Font.SourceSans end
end

local function create(className, props, parent)
    local inst = Instance.new(className)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            pcall(function() inst[k] = v end)
        end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function addHover(btn, c1, c2)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = c2 end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = c1 end)
end

-- === ERROR DISPLAY (fallback) ===
local function showError(title, msg)
    local gui = Instance.new("ScreenGui")
    gui.Name = "ScriptError"
    gui.ResetOnSpawn = false
    gui.Parent = UI_PARENT

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 220)
    frame.Position = UDim2.new(0.5, -200, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(20,20,26)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 30)
    titleLbl.Position = UDim2.new(0, 10, 0, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title or "Error"
    titleLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    titleLbl.Font = Enum.Font.SourceSansBold
    titleLbl.TextSize = 18
    titleLbl.Parent = frame

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 30, 0, 30)
    close.Position = UDim2.new(1, -40, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Text = "X"
    close.TextColor3 = Color3.new(1,1,1)
    close.Font = Enum.Font.SourceSansBold
    close.TextSize = 14
    close.Parent = frame
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
    close.MouseButton1Click:Connect(function() gui:Destroy() end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -50)
    scroll.Position = UDim2.new(0, 10, 0, 42)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0,0,0,200)
    scroll.ScrollBarThickness = 4
    scroll.Parent = frame

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -10, 0, 0)
    textBox.Position = UDim2.new(0, 5, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text = msg or "Unknown error"
    textBox.TextColor3 = Color3.new(1,1,1)
    textBox.Font = Enum.Font.SourceSans
    textBox.TextSize = 14
    textBox.TextWrapped = true
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextEditable = false
    textBox.TextSelectable = true
    textBox.Parent = scroll
    textBox.Size = UDim2.new(1, -10, 0, textBox.TextBounds.Y + 12)
    scroll.CanvasSize = UDim2.new(0, 0, 0, textBox.TextBounds.Y + 12)
end

-- === MAIN SCRIPT (pcall wrapped) ===
local success, err = pcall(function()
    -- Variables
    local ROBUX_SYMBOL = utf8.char(0xE002)
    local CURRENT_ROBUX = 100000
    local ADD_AMOUNT = 1000000
    local PRODUCTS = {}
    local activeView = "List"
    local buyCooldown = false
    local assigningKey = false
    local hiddenUIs = {}
    local connections = {}

    -- Preset
    local PRESET = {
        Name = "Grow a Garden 2",
        Items = {
            {Title="Ghost Pepper Pack (x1)", Price=99, Image="rbxassetid://82563012679034", Key="Seven", Reward="R100", Old="<s>R50</s>", Missing="0,99€"},
            {Title="Ghost Pepper Pack (x3)", Price=249, Image="rbxassetid://82563012679034", Key="Eight", Reward="R300", Old="<s>R200</s>", Missing="2,99€"},
            {Title="Ghost Pepper Pack (x10)", Price=799, Image="rbxassetid://82563012679034", Key="Nine", Reward="R500", Old="<s>R400</s>", Missing="5,99€"},
            {Title="Ghost Pepper Pack (x50)", Price=3499, Image="rbxassetid://82563012679034", Key="Zero", Reward="R4000", Old="<s>R2000</s>", Missing="24,99€"},
            {Title="Dragon's Breath (x1)", Price=1499, Image="rbxassetid://96684224603391", Key="F5", Reward="R100", Old="<s>R0</s>", Missing="1,99€"},
            {Title="Dragon's Breath (x3)", Price=4497, Image="rbxassetid://96684224603391", Key="F6", Reward="R100", Old="<s>R0</s>", Missing="1,99€"},
            {Title="Dragon's Breath (x10)", Price=14990, Image="rbxassetid://96684224603391", Key="F7", Reward="R100", Old="<s>R0</s>", Missing="1,99€"},
            {Title="Moon Bloom (x1)", Price=1349, Image="rbxassetid://98382423902957", Key="F8", Reward="R100", Old="<s>R0</s>", Missing="1,99€"},
            {Title="Empty Slot 9", Price=100, Image="rbxassetid://82563012679034", Key="", Reward="R100", Old="<s>R0</s>", Missing="1,99€"},
            {Title="Empty Slot 10", Price=100, Image="rbxassetid://82563012679034", Key="", Reward="R100", Old="<s>R0</s>", Missing="1,99€"},
            {Title="Empty Slot 11", Price=100, Image="rbxassetid://82563012679034", Key="", Reward="R100", Old="<s>R0</s>", Missing="1,99€"},
            {Title="Empty Slot 12", Price=100, Image="rbxassetid://82563012679034", Key="", Reward="R100", Old="<s>R0</s>", Missing="1,99€"}
        }
    }
    for i=1,#PRESET.Items do
        PRODUCTS[i] = PRESET.Items[i]
    end

    local function formatRobux(n)
        local s = tostring(n)
        while true do
            local k
            s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
            if k == 0 then break end
        end
        return s
    end

    -- UI building
    local BuyGui = create("ScreenGui", {Name = "RobuxBuyPrompt", IgnoreGuiInset = true, Enabled = false}, UI_PARENT)
    local overlay = create("Frame", {Size = UDim2.new(1,0,1,0), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.6, Visible=false}, BuyGui)
    local mainBg = create("Frame", {Size=UDim2.new(0.28,0,0.32,0), Position=UDim2.new(0.5,0,0.442,0), AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=Color3.new(0.05,0.05,0.06)}, BuyGui)
    create("UICorner", {CornerRadius=UDim.new(0.05,0)}, mainBg)
    local titleLabel = create("TextLabel", {Size=UDim2.new(0.5,0,0.1,0), Position=UDim2.new(0.05,0,0.05,0), BackgroundTransparency=1, Text="Buy Item", TextColor3=Color3.new(1,1,1), TextScaled=true, TextXAlignment=Enum.TextXAlignment.Left, Font=safeFont("BuilderSansBold")}, mainBg)
    local robuxLabel = create("TextLabel", {Size=UDim2.new(0.3,0,0.08,0), Position=UDim2.new(0.55,0,0.06,0), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), TextScaled=true, RichText=true, Font=safeFont("BuilderSansMedium")}, mainBg)
    local closeBtn = create("TextButton", {Size=UDim2.new(0.12,0,0.12,0), Position=UDim2.new(0.85,0,0.045,0), BackgroundTransparency=1, Text="X", TextColor3=Color3.new(1,1,1), TextScaled=true, Font=safeFont("Sarpanch")}, mainBg)
    local prodImage = create("ImageLabel", {Size=UDim2.new(0.18,0,0.84,0), Position=UDim2.new(0,0,0.08,0), BackgroundTransparency=1, ScaleType=Enum.ScaleType.Fit}, mainBg)
    local prodTitle = create("TextLabel", {Size=UDim2.new(0.5,0,0.3,0), Position=UDim2.new(0.25,0,0.2,0), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), TextScaled=true, TextXAlignment=Enum.TextXAlignment.Left, Font=safeFont("BuilderSansBold")}, mainBg)
    local prodPrice = create("TextLabel", {Size=UDim2.new(0.46,0,0.216,0), Position=UDim2.new(0.25,0,0.5,0), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), TextScaled=true, Font=safeFont("BuilderSans")}, mainBg)
    local missingFrame = create("Frame", {Size=UDim2.new(0.9,0,0.175,0), Position=UDim2.new(0.05,0,0.55,0), BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=0.9}, mainBg)
    create("UICorner", {CornerRadius=UDim.new(0.15,0)}, missingFrame)
    local rewardLabel = create("TextLabel", {Size=UDim2.new(0.15,0,0.4,0), Position=UDim2.new(0.05,0,0.3,0), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), TextScaled=true, Font=safeFont("BuilderSansBold")}, missingFrame)
    local oldReward = create("TextLabel", {Size=UDim2.new(0.15,0,0.4,0), Position=UDim2.new(0.22,0,0.3,0), BackgroundTransparency=1, TextColor3=Color3.fromRGB(200,200,200), TextScaled=true, RichText=true, Font=safeFont("BuilderSansBold")}, missingFrame)
    local missingPrice = create("TextLabel", {Size=UDim2.new(0.15,0,0.4,0), Position=UDim2.new(0.8,0,0.3,0), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), TextScaled=true, TextXAlignment=Enum.TextXAlignment.Right, Font=safeFont("BuilderSansBold")}, missingFrame)
    local buyBtn = create("TextButton", {Size=UDim2.new(0.9,0,0.125,0), Position=UDim2.new(0.05,0,0.8,0), BackgroundColor3=Color3.fromRGB(40,100,255), Text="Buy", TextColor3=Color3.new(1,1,1), TextScaled=true, Font=safeFont("RobotoMono")}, mainBg)
    create("UICorner", {CornerRadius=UDim.new(0.15,0)}, buyBtn)
    local cooldownBar = create("Frame", {Size=UDim2.new(0,0,1,0), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.5}, buyBtn)
    local completeBg = create("Frame", {Size=UDim2.new(0.28,0,0.32,0), Position=UDim2.new(0.5,0,1.5,0), AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=Color3.fromRGB(20,20,30), Visible=false}, BuyGui)
    create("UICorner", {CornerRadius=UDim.new(0.05,0)}, completeBg)
    local compClose = create("TextButton", {Size=UDim2.new(0.12,0,0.12,0), Position=UDim2.new(0.85,0,0.045,0), BackgroundTransparency=1, Text="X", TextColor3=Color3.new(1,1,1), TextScaled=true, Font=safeFont("Sarpanch")}, completeBg)
    local compImage = create("ImageLabel", {Size=UDim2.new(0.35,0,0.35,0), Position=UDim2.new(0.325,0,0.25,0), BackgroundTransparency=1, Image="rbxassetid://92231445168972"}, completeBg)
    local compText = create("TextLabel", {Size=UDim2.new(0.9,0,0.12,0), Position=UDim2.new(0.05,0,0.65,0), BackgroundTransparency=1, Text="Purchase completed", TextColor3=Color3.new(1,1,1), TextScaled=true, Font=safeFont("BuilderSans")}, completeBg)
    local compOK = create("TextButton", {Size=UDim2.new(0.9,0,0.125,0), Position=UDim2.new(0.05,0,0.8,0), BackgroundColor3=Color3.fromRGB(50,150,255), Text="OK", TextColor3=Color3.new(1,1,1), TextScaled=true, Font=safeFont("RobotoMono")}, completeBg)
    create("UICorner", {CornerRadius=UDim.new(0.15,0)}, compOK)

    local function updateBuyUI(idx)
        local p = PRODUCTS[idx]
        prodTitle.Text = p.Title
        prodPrice.Text = ROBUX_SYMBOL .. formatRobux(p.Price)
        prodImage.Image = p.Image
        rewardLabel.Text = p.Reward:gsub("^R", ROBUX_SYMBOL)
        oldReward.Text = p.Old:gsub("R(%d+)", ROBUX_SYMBOL.."%1")
        missingPrice.Text = p.Missing
        robuxLabel.Text = ROBUX_SYMBOL .. " " .. formatRobux(CURRENT_ROBUX)
        missingFrame.Visible = CURRENT_ROBUX < p.Price
    end

    local function hideOtherUIs()
        hiddenUIs = {}
        local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
        local dirs = {pg}
        if UI_PARENT ~= pg then table.insert(dirs, UI_PARENT) end
        for _, d in ipairs(dirs) do
            for _, g in ipairs(d:GetChildren()) do
                if g:IsA("ScreenGui") and g ~= BuyGui and g.Enabled then
                    g.Enabled = false
                    table.insert(hiddenUIs, g)
                end
            end
        end
    end

    local function restoreOtherUIs()
        for _, g in ipairs(hiddenUIs) do
            if g and g.Parent then g.Enabled = true end
        end
        hiddenUIs = {}
    end

    local currentProduct = 1
    local function openBuy(idx)
        if BuyGui.Enabled then return end
        currentProduct = idx
        updateBuyUI(idx)
        BuyGui.Enabled = true
        overlay.Visible = true
        mainBg.Position = UDim2.new(0.5,0,1.5,0)
        TweenService:Create(mainBg, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5,0,0.442,0)}):Play()
        buyCooldown = true
        cooldownBar.Size = UDim2.new(0,0,1,0)
        cooldownBar.Visible = true
        TweenService:Create(cooldownBar, TweenInfo.new(1.5), {Size = UDim2.new(1,0,1,0)}):Play()
        task.delay(1.5, function() buyCooldown = false cooldownBar.Visible = false end)
        hideOtherUIs()
    end

    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(mainBg, TweenInfo.new(0.1), {Position = UDim2.new(0.5,0,1.5,0)}):Play()
        task.delay(0.1, function() BuyGui.Enabled = false overlay.Visible = false restoreOtherUIs() end)
    end)
    compClose.MouseButton1Click:Connect(function()
        TweenService:Create(completeBg, TweenInfo.new(0.1), {Position = UDim2.new(0.5,0,1.5,0)}):Play()
        task.delay(0.1, function() completeBg.Visible = false BuyGui.Enabled = false overlay.Visible = false restoreOtherUIs() end)
    end)
    compOK.MouseButton1Click:Connect(function()
        TweenService:Create(completeBg, TweenInfo.new(0.1), {Position = UDim2.new(0.5,0,1.5,0)}):Play()
        task.delay(0.1, function() completeBg.Visible = false BuyGui.Enabled = false overlay.Visible = false restoreOtherUIs() end)
    end)
    buyBtn.MouseButton1Click:Connect(function()
        if buyCooldown then return end
        local p = PRODUCTS[currentProduct]
        if CURRENT_ROBUX >= p.Price then
            CURRENT_ROBUX = CURRENT_ROBUX - p.Price
            updateBuyUI(currentProduct)
            mainBg.Position = UDim2.new(0.5,0,1.5,0)
            completeBg.Position = UDim2.new(0.5,0,1.5,0)
            completeBg.Visible = true
            compText.Text = "You have successfully bought " .. p.Title
            TweenService:Create(completeBg, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5,0,0.442,0)}):Play()
        end
    end)

    -- Customizer
    local CustomGui = create("ScreenGui", {Name = "RobuxCustomizer", ResetOnSpawn = false}, UI_PARENT)
    local sidePanel = create("Frame", {Size=UDim2.new(0,340,0,480), Position=UDim2.new(0.02,0,0.15,0), BackgroundColor3=Color3.fromRGB(18,18,24), ClipsDescendants=true}, CustomGui)
    create("UICorner", {CornerRadius=UDim.new(0,12)}, sidePanel)
    local topBar = create("Frame", {Size=UDim2.new(1,0,0,40), BackgroundColor3=Color3.fromRGB(14,14,20)}, sidePanel)
    create("UICorner", {CornerRadius=UDim.new(0,12)}, topBar)
    create("Frame", {Size=UDim2.new(1,0,0,8), Position=UDim2.new(0,0,1,-8), BackgroundColor3=Color3.fromRGB(14,14,20), BorderSizePixel=0}, topBar)
    local backBtn = create("TextButton", {Size=UDim2.new(0,30,0,30), Position=UDim2.new(0,5,0.5,-15), BackgroundColor3=Color3.fromRGB(45,45,55), Text="<-", TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=14, Visible=false}, topBar)
    create("UICorner", {CornerRadius=UDim.new(0,6)}, backBtn)
    local panelTitle = create("TextLabel", {Size=UDim2.new(0.5,0,1,0), Position=UDim2.new(0.12,0,0,0), BackgroundTransparency=1, Text="Presets", TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=14, TextXAlignment=Enum.TextXAlignment.Left}, topBar)
    local minBtn = create("TextButton", {Size=UDim2.new(0,30,0,30), Position=UDim2.new(1,-70,0.5,-15), BackgroundColor3=Color3.fromRGB(45,45,55), Text="-", TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=18}, topBar)
    create("UICorner", {CornerRadius=UDim.new(0,6)}, minBtn)
    local delBtn = create("TextButton", {Size=UDim2.new(0,30,0,30), Position=UDim2.new(1,-35,0.5,-15), BackgroundColor3=Color3.fromRGB(200,40,40), Text="X", TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=14}, topBar)
    create("UICorner", {CornerRadius=UDim.new(0,6)}, delBtn)
    minBtn.MouseButton1Click:Connect(function() sidePanel.Visible = false end)
    local toggleBtn = create("TextButton", {Size=UDim2.new(0,40,0,40), Position=UDim2.new(0.01,0,0.02,0), BackgroundColor3=Color3.fromRGB(30,30,35), Text="☰", TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=20}, CustomGui)
    toggleBtn.MouseButton1Click:Connect(function() sidePanel.Visible = true end)
    delBtn.MouseButton1Click:Connect(function() CustomGui:Destroy() end)

    local viewList = create("ScrollingFrame", {Size=UDim2.new(1,0,1,-40), Position=UDim2.new(0,0,0,40), BackgroundTransparency=1, ScrollBarThickness=4}, sidePanel)
    local viewViewer = create("ScrollingFrame", {Size=UDim2.new(1,0,1,-40), Position=UDim2.new(0,0,0,40), BackgroundTransparency=1, ScrollBarThickness=4, Visible=false}, sidePanel)
    local listLayout = create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10), HorizontalAlignment=Enum.HorizontalAlignment.Center}, viewList)
    create("UIPadding", {PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10)}, viewList)
    local viewerLayout = create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,10), HorizontalAlignment=Enum.HorizontalAlignment.Center}, viewViewer)
    create("UIPadding", {PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10)}, viewViewer)

    local function switchView(view)
        viewList.Visible = view == "List"
        viewViewer.Visible = view == "Viewer"
        panelTitle.Text = view == "List" and "Presets" or "Product Viewer"
        backBtn.Visible = view ~= "List"
        activeView = view
        if view == "Viewer" then
            for _, c in ipairs(viewViewer:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            for i, p in ipairs(PRODUCTS) do
                if p.Key ~= "" then
                    local f = create("Frame", {Size=UDim2.new(0.9,0,0,62), BackgroundColor3=Color3.fromRGB(35,35,45), LayoutOrder=i}, viewViewer)
                    create("UICorner", {CornerRadius=UDim.new(0,8)}, f)
                    local img = create("ImageLabel", {Size=UDim2.new(0,40,0,40), Position=UDim2.new(0,10,0.5,-20), BackgroundTransparency=1, Image=p.Image, ScaleType=Enum.ScaleType.Fit}, f)
                    create("TextLabel", {Size=UDim2.new(0.5,0,0,22), Position=UDim2.new(0,60,0,8), BackgroundTransparency=1, Text=p.Title, TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=12, TextXAlignment=Enum.TextXAlignment.Left}, f)
                    create("TextLabel", {Size=UDim2.new(0.5,0,0,22), Position=UDim2.new(0,60,0,32), BackgroundTransparency=1, Text=ROBUX_SYMBOL..p.Price, TextColor3=Color3.fromRGB(170,230,170), Font=safeFont("Gotham"), TextSize=12}, f)
                    local keyBtn = create("TextButton", {Size=UDim2.new(0,65,0,28), Position=UDim2.new(1,-75,0.5,-14), BackgroundColor3=Color3.fromRGB(30,30,40), Text=p.Key or "None", TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=11}, f)
                    create("UICorner", {CornerRadius=UDim.new(0,6)}, keyBtn)
                    keyBtn.MouseButton1Click:Connect(function()
                        if assigningKey then return end
                        assigningKey = true
                        keyBtn.Text = "..."
                        local conn
                        conn = UserInputService.InputBegan:Connect(function(inp)
                            if inp.UserInputType == Enum.UserInputType.Keyboard then
                                p.Key = inp.KeyCode.Name
                            elseif inp.UserInputType == Enum.UserInputType.MouseButton1 then
                                p.Key = ""
                            end
                            keyBtn.Text = p.Key ~= "" and p.Key or "None"
                            conn:Disconnect()
                            assigningKey = false
                        end)
                    end)
                end
            end
            viewViewer.CanvasSize = UDim2.new(0,0,0, viewerLayout.AbsoluteContentSize.Y + 20)
        end
    end

    backBtn.MouseButton1Click:Connect(function() switchView("List") end)

    -- Robux Manager inside list
    local robuxFrame = create("Frame", {Size=UDim2.new(0.9,0,0,130), BackgroundColor3=Color3.fromRGB(35,35,45), LayoutOrder=0}, viewList)
    create("UICorner", {CornerRadius=UDim.new(0,8)}, robuxFrame)
    create("TextLabel", {Size=UDim2.new(1,-20,0,20), Position=UDim2.new(0,10,0,8), BackgroundTransparency=1, Text="Robux Manager", TextColor3=Color3.fromRGB(220,220,240), Font=safeFont("GothamBold"), TextSize=13, TextXAlignment=Enum.TextXAlignment.Left}, robuxFrame)
    local balanceLabel = create("TextLabel", {Size=UDim2.new(1,-20,0,18), Position=UDim2.new(0,10,0,30), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), Font=safeFont("Gotham"), TextSize=12}, robuxFrame)
    balanceLabel.Text = ROBUX_SYMBOL .. " " .. formatRobux(CURRENT_ROBUX)
    local setBalInput = create("TextBox", {Size=UDim2.new(0.55,-10,0,20), Position=UDim2.new(0.45,0,0,52), BackgroundColor3=Color3.fromRGB(25,25,35), TextColor3=Color3.new(1,1,1), Font=safeFont("Gotham"), TextSize=11, Text=tostring(CURRENT_ROBUX), ClearTextOnFocus=false}, robuxFrame)
    create("UICorner", {CornerRadius=UDim.new(0,4)}, setBalInput)
    setBalInput.FocusLost:Connect(function()
        local n = tonumber(setBalInput.Text)
        if n then CURRENT_ROBUX = n balanceLabel.Text = ROBUX_SYMBOL .. " " .. formatRobux(n) end
    end)
    local addInput = create("TextBox", {Size=UDim2.new(0.55,-10,0,20), Position=UDim2.new(0.45,0,0,78), BackgroundColor3=Color3.fromRGB(25,25,35), TextColor3=Color3.new(1,1,1), Font=safeFont("Gotham"), TextSize=11, Text=tostring(ADD_AMOUNT)}, robuxFrame)
    create("UICorner", {CornerRadius=UDim.new(0,4)}, addInput)
    addInput.FocusLost:Connect(function()
        local n = tonumber(addInput.Text)
        if n then ADD_AMOUNT = n end
    end)
    local addBtn = create("TextButton", {Size=UDim2.new(1,-20,0,24), Position=UDim2.new(0,10,0,102), BackgroundColor3=Color3.fromRGB(40,180,80), Text="+ Add Robux", TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=12}, robuxFrame)
    create("UICorner", {CornerRadius=UDim.new(0,6)}, addBtn)
    addBtn.MouseButton1Click:Connect(function()
        CURRENT_ROBUX = CURRENT_ROBUX + ADD_AMOUNT
        balanceLabel.Text = ROBUX_SYMBOL .. " " .. formatRobux(CURRENT_ROBUX)
        setBalInput.Text = tostring(CURRENT_ROBUX)
    end)

    -- Preset button
    local presetBtn = create("TextButton", {Size=UDim2.new(0.9,0,0,44), BackgroundColor3=Color3.fromRGB(40,40,50), Text=PRESET.Name, TextColor3=Color3.new(1,1,1), Font=safeFont("GothamBold"), TextSize=14, LayoutOrder=1}, viewList)
    create("UICorner", {CornerRadius=UDim.new(0,8)}, presetBtn)
    presetBtn.MouseButton1Click:Connect(function()
        PRODUCTS = {}
        for i,v in ipairs(PRESET.Items) do PRODUCTS[i] = v end
        switchView("Viewer")
    end)

    -- Keybind handling
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or BuyGui.Enabled or assigningKey then return end
        local key = input.KeyCode.Name
        if key == "Plus" and not UserInputService:GetFocusedTextBox() then
            CURRENT_ROBUX = CURRENT_ROBUX + ADD_AMOUNT
            balanceLabel.Text = ROBUX_SYMBOL .. " " .. formatRobux(CURRENT_ROBUX)
            return
        end
        if activeView == "Viewer" then
            for i, p in ipairs(PRODUCTS) do
                if p.Key == key then
                    openBuy(i)
                    break
                end
            end
        end
    end)
end)

if not success then
    local msg = tostring(err)
    if msg == "" then msg = "Unknown error (empty message)" end
    showError("Script Error", msg)
    warn("SCRIPT ERROR: " .. msg)
end
