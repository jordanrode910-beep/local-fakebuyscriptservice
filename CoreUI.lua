local module = {}
local UIS, TS, Players, CP, HS, RS
local UI_PARENT, Connections, BuildModeLink
local ROBUX_SYMBOL = utf8.char(0xE002)
local DEFAULT_ROBUX = 0
local ADD_ROBUX_AMOUNT = 1000000

local function safeFont(name)
	local success, font = pcall(function()
		return Enum.Font[name]
	end)
	if success and font then
		return font
	end
	return Enum.Font.SourceSans
end

local PRESETS = {
	{
		Name = "Grow a Garden 2",
		Robux = 10000000,
		Items = {
			{MissingPrice="0,99€", Image="rbxassetid://82563012679034", Key="Seven", Active=true, Price=99, OldReward="<s>R50</s>", Title="Ghost Pepper Pack (x1) [GIFT]", Reward="R100"},
			{MissingPrice="2,99€", Image="rbxassetid://82563012679034", Key="Eight", Active=true, Price=249, OldReward="<s>R200</s>", Title="Ghost Pepper Pack (x3) [GIFT]", Reward="R300"},
			{MissingPrice="5,99€", Image="rbxassetid://82563012679034", Key="Nine", Active=true, Price=799, OldReward="<s>R400</s>", Title="Ghost Pepper Pack (x10) [GIFT]", Reward="R500"},
			{MissingPrice="24,99€", Image="rbxassetid://82563012679034", Key="Zero", Active=true, Price=3499, OldReward="<s>R2000</s>", Title="Ghost Pepper Pack (x50) [GIFT]", Reward="R4000"},
			{MissingPrice="1,99€", Image="rbxassetid://96684224603391", Key="F5", Active=true, Price=1499, OldReward="<s>R0</s>", Title="Dragon's Breath (x1) [GIFT]", Reward="R100"},
			{MissingPrice="1,99€", Image="rbxassetid://96684224603391", Key="F6", Active=true, Price=4497, OldReward="<s>R0</s>", Title="Dragon's Breath (x3) [GIFT]", Reward="R100"},
			{MissingPrice="1,99€", Image="rbxassetid://96684224603391", Key="F7", Active=true, Price=14990, OldReward="<s>R0</s>", Title="Dragon's Breath (x10) [GIFT]", Reward="R100"},
			{MissingPrice="1,99€", Image="rbxassetid://98382423902957", Key="F8", Active=true, Price=1349, OldReward="<s>R0</s>", Title="Moon Bloom (x1) [GIFT]", Reward="R100"},
			{MissingPrice="1,99€", Image="rbxassetid://82563012679034", Key="", Active=false, Price=100, OldReward="<s>R0</s>", Title="New Custom Product 9", Reward="R100"},
			{MissingPrice="1,99€", Image="rbxassetid://82563012679034", Key="", Active=false, Price=100, OldReward="<s>R0</s>", Title="New Custom Product 10", Reward="R100"},
			{MissingPrice="1,99€", Image="rbxassetid://82563012679034", Key="", Active=false, Price=100, OldReward="<s>R0</s>", Title="New Custom Product 11", Reward="R100"},
			{MissingPrice="1,99€", Image="rbxassetid://82563012679034", Key="", Active=false, Price=100, OldReward="<s>R0</s>", Title="New Custom Product 12", Reward="R100"}
		}
	}
}

local function padProducts(items)
	local newItems = {}
	for i = 1, 12 do
		if items[i] then
			local copy = {}
			for k, v in pairs(items[i]) do copy[k] = v end
			newItems[i] = copy
		else
			newItems[i] = {Key = "", Title = "Empty Slot " .. i, Price = 100, Image = "rbxassetid://82563012679034", Reward = "R100", OldReward = "<s>R0</s>", MissingPrice = "1,99€", Active = false}
		end
	end
	return newItems
end

for _, preset in ipairs(PRESETS) do
	preset.Items = padProducts(preset.Items)
end

local Products = PRESETS[1].Items
local CURRENT_ROBUX = DEFAULT_ROBUX
local lastActiveView = nil
local customizerProducts = nil
local currentProductIndex = 1
local isProcessing = false
local canBuy = false
local assigningKey = false
local hiddenUIs = {}

local function formatNumber(n)
	local formatted = tostring(n)
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			pcall(function() inst[k] = v end)
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function addHoverEffect(button, normalColor, hoverColor)
	local connEnter = button.MouseEnter:Connect(function()
		button.BackgroundColor3 = hoverColor
	end)
	local connLeave = button.MouseLeave:Connect(function()
		button.BackgroundColor3 = normalColor
	end)
	table.insert(Connections, connEnter)
	table.insert(Connections, connLeave)
end

local RobuxBuyPrompt, Overlay, Background, TopTitle, RobuxAmount, CloseButton
local ProductFrame, ProductImage, ProductTitle, ProductPriceLabel
local MissingFunds, Reward, OldReward, MissingPrice, BuyButton, Cooldown, Info
local CompleteBackground, C_TopTitle, C_CloseButton, C_Image, C_ProductText, C_OKButton
local ORIGINAL_POSITION = UDim2.new(0.5, 0, 0.442, 0)
local ORIGINAL_BUTTON_COLOR = Color3.new(0.15, 0.3, 0.8)

local function buildBuyPrompt()
	RobuxBuyPrompt = create("ScreenGui", {Name = "RobuxBuyPrompt", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false}, UI_PARENT)
	Overlay = create("Frame", {Name = "Overlay", Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.6, BorderSizePixel = 0, Visible = false}, RobuxBuyPrompt)
	Background = create("Frame", {Name = "Background", Size = UDim2.new(0.28,0,0.32,0), Position = ORIGINAL_POSITION, AnchorPoint = Vector2.new(0.5,0.5), BackgroundColor3 = Color3.new(0.05,0.05,0.06), BorderSizePixel = 0}, RobuxBuyPrompt)
	create("UICorner", {CornerRadius = UDim.new(0.05,0)}, Background)
	create("UIStroke", {Color = Color3.new(0.1,0.1,0.12), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, Background)
	TopTitle = create("TextLabel", {Size = UDim2.new(0.5,0,0.1,0), Position = UDim2.new(0.05,0,0.05,0), BackgroundTransparency = 1, Text = "Buy Item", TextColor3 = Color3.new(1,1,1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Font = safeFont("BuilderSansBold")}, Background)
	RobuxAmount = create("TextLabel", {Name = "RobuxAmount", Size = UDim2.new(0.295,0,0.08,0), Position = UDim2.new(0.55,0,0.062,0), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1), TextScaled = true, RichText = true, Font = safeFont("BuilderSansMedium")}, Background)
	CloseButton = create("TextButton", {Size = UDim2.new(0.12,0,0.12,0), Position = UDim2.new(0.85,0,0.045,0), BackgroundTransparency = 1, Text = "X", TextColor3 = Color3.new(1,1,1), TextScaled = true, Font = safeFont("Sarpanch")}, Background)
	ProductFrame = create("Frame", {Size = UDim2.new(0.9,0,0.3,0), Position = UDim2.new(0.05,0,0.2,0), BackgroundTransparency = 1}, Background)
	ProductImage = create("ImageLabel", {Size = UDim2.new(0.18,0,0.84,0), Position = UDim2.new(0,0,0.08,0), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit}, ProductFrame)
	create("UICorner", {CornerRadius = UDim.new(1,0)}, ProductImage)
	ProductTitle = create("TextLabel", {Size = UDim2.new(0.5,0,0.3,0), Position = UDim2.new(0.25,0,0.2,0), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Font = safeFont("BuilderSansBold")}, ProductFrame)
	ProductPriceLabel = create("TextLabel", {Size = UDim2.new(0.461,0,0.216,0), Position = UDim2.new(0.25,0,0.5,0), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Font = safeFont("BuilderSans")}, ProductFrame)
	MissingFunds = create("Frame", {Size = UDim2.new(0.9,0,0.175,0), Position = UDim2.new(0.05,0,0.55,0), BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0.9}, Background)
	create("UICorner", {CornerRadius = UDim.new(0.15,0)}, MissingFunds)
	create("UIStroke", {Color = Color3.new(1,1,1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, MissingFunds)
	Reward = create("TextLabel", {Size = UDim2.new(0.15,0,0.4,0), Position = UDim2.new(0.05,0,0.3,0), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Font = safeFont("BuilderSansBold")}, MissingFunds)
	OldReward = create("TextLabel", {Size = UDim2.new(0.15,0,0.4,0), Position = UDim2.new(0.22,0,0.3,0), BackgroundTransparency = 1, TextColor3 = Color3.new(0.784,0.784,0.784), TextScaled = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Font = safeFont("BuilderSansBold")}, MissingFunds)
	MissingPrice = create("TextLabel", {Size = UDim2.new(0.15,0,0.4,0), Position = UDim2.new(0.8,0,0.3,0), BackgroundTransparency = 1, TextColor3 = Color3.new(1,1,1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, Font = safeFont("BuilderSansBold")}, MissingFunds)
	BuyButton = create("TextButton", {Size = UDim2.new(0.9,0,0.125,0), Position = UDim2.new(0.05,0,0.8,0), BackgroundColor3 = ORIGINAL_BUTTON_COLOR, Text = "Buy", TextColor3 = Color3.new(1,1,1), TextScaled = true, Font = safeFont("RobotoMono")}, Background)
	create("UICorner", {CornerRadius = UDim.new(0.15,0)}, BuyButton)
	Cooldown = create("Frame", {Size = UDim2.new(0,0,1,0), Position = UDim2.new(0,0,0,0), BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.5, BorderSizePixel = 0}, BuyButton)
	Info = create("TextLabel", {Size = UDim2.new(0.9,0,0.03,0), Position = UDim2.new(0.05,0,0.94,0), BackgroundTransparency = 1, Text = "Your payment method will be charged. Roblox <u>Terms of Use</u> apply.", RichText = true, TextColor3 = Color3.new(0.784,0.784,0.784), TextScaled = true, Font = safeFont("BuilderSans")}, Background)
	CompleteBackground = create("Frame", {Size = UDim2.new(0.28,0,0.32,0), Position = UDim2.new(ORIGINAL_POSITION.X.Scale, ORIGINAL_POSITION.X.Offset, 1.5,0), AnchorPoint = Vector2.new(0.5,0.5), BackgroundColor3 = Color3.new(0.094,0.102,0.118), BorderSizePixel = 0}, RobuxBuyPrompt)
	create("UICorner", {CornerRadius = UDim.new(0.05,0)}, CompleteBackground)
	create("UIStroke", {Color = Color3.new(0.196,0.212,0.239), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, CompleteBackground)
	C_TopTitle = create("TextLabel", {Size = UDim2.new(0.5,0,0.1,0), Position = UDim2.new(0.05,0,0.05,0), BackgroundTransparency = 1, Text = "Purchase completed", TextColor3 = Color3.new(1,1,1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Font = safeFont("BuilderSansBold")}, CompleteBackground)
	C_CloseButton = create("TextButton", {Size = UDim2.new(0.12,0,0.12,0), Position = UDim2.new(0.85,0,0.045,0), BackgroundTransparency = 1, Text = "X", TextColor3 = Color3.new(1,1,1), TextScaled = true, Font = safeFont("Sarpanch")}, CompleteBackground)
	C_Image = create("ImageLabel", {Size = UDim2.new(0.35,0,0.35,0), Position = UDim2.new(0.325,0,0.25,0), BackgroundTransparency = 1, Image = "rbxassetid://92231445168972", ScaleType = Enum.ScaleType.Fit}, CompleteBackground)
	C_ProductText = create("TextLabel", {Size = UDim2.new(0.9,0,0.12,0), Position = UDim2.new(0.05,0,0.65,0), BackgroundTransparency = 1, Text = "You have successfully bought [ItemName]", TextColor3 = Color3.new(1,1,1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Font = safeFont("BuilderSans")}, CompleteBackground)
	C_OKButton = create("TextButton", {Size = UDim2.new(0.9,0,0.125,0), Position = UDim2.new(0.05,0,0.8,0), BackgroundColor3 = Color3.new(0.196,0.373,0.984), Text = "OK", TextColor3 = Color3.new(1,1,1), TextScaled = true, Font = safeFont("RobotoMono")}, CompleteBackground)
	create("UICorner", {CornerRadius = UDim.new(0.15,0)}, C_OKButton)

	if not CloseButton or not C_CloseButton or not C_OKButton or not BuyButton then
		error("Failed to build one or more critical buttons in RobuxBuyPrompt")
	end
end

local function updateRobux()
	RobuxAmount.Text = ROBUX_SYMBOL .. " " .. formatNumber(CURRENT_ROBUX)
	local curProd = Products[currentProductIndex]
	if curProd then
		MissingFunds.Visible = CURRENT_ROBUX < tonumber(curProd.Price)
	end
end

local function refreshPromptUI()
	local p = Products[currentProductIndex]
	if not p then return end
	ProductTitle.Text = p.Title
	ProductPriceLabel.Text = ROBUX_SYMBOL .. formatNumber(p.Price)
	ProductImage.Image = p.Image
	Reward.Text = p.Reward:gsub("^R", ROBUX_SYMBOL)
	OldReward.Text = p.OldReward:gsub("R(%d+)", ROBUX_SYMBOL.."%1")
	MissingPrice.Text = p.MissingPrice
	updateRobux()
	task.spawn(function() pcall(function() CP:PreloadAsync({ProductImage, C_Image}) end) end)
end

local function hideOtherUIs()
	hiddenUIs = {}
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local searchDirs = {}
	if pg then table.insert(searchDirs, pg) end
	if UI_PARENT and UI_PARENT ~= pg then table.insert(searchDirs, UI_PARENT) end
	for _, parentObj in ipairs(searchDirs) do
		for _, gui in ipairs(parentObj:GetChildren()) do
			if gui:IsA("ScreenGui") and gui ~= RobuxBuyPrompt and gui.Enabled then
				gui.Enabled = false
				table.insert(hiddenUIs, gui)
			end
		end
	end
end

local function restoreOtherUIs()
	for _, gui in ipairs(hiddenUIs) do
		if gui and gui.Parent then gui.Enabled = true end
	end
	hiddenUIs = {}
end

local function cancelPrompt()
	if isProcessing then return end
	isProcessing = true
	local slideOut = TS:Create(Background, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(ORIGINAL_POSITION.X.Scale, ORIGINAL_POSITION.X.Offset, 1.5, 0)})
	slideOut:Play()
	slideOut.Completed:Once(function()
		RobuxBuyPrompt.Enabled = false
		Overlay.Visible = false
		Background.Position = ORIGINAL_POSITION
		isProcessing = false
		restoreOtherUIs()
	end)
end

local function finishPurchaseScreen()
	if isProcessing then return end
	isProcessing = true
	local slideOut = TS:Create(CompleteBackground, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(ORIGINAL_POSITION.X.Scale, ORIGINAL_POSITION.X.Offset, 1.5, 0)})
	slideOut:Play()
	slideOut.Completed:Once(function()
		local p = Products[currentProductIndex]
		CURRENT_ROBUX = CURRENT_ROBUX - tonumber(p.Price)
		updateRobux()
		RobuxBuyPrompt.Enabled = false
		Overlay.Visible = false
		CompleteBackground.Position = UDim2.new(ORIGINAL_POSITION.X.Scale, ORIGINAL_POSITION.X.Offset, 1.5, 0)
		Background.Position = ORIGINAL_POSITION
		isProcessing = false
		restoreOtherUIs()
	end)
end

local function playOpenAnimation()
	canBuy = false
	Cooldown.Visible = true
	Cooldown.Size = UDim2.new(0, 0, 1, 0)
	BuyButton.BackgroundColor3 = ORIGINAL_BUTTON_COLOR
	Background.Position = UDim2.new(ORIGINAL_POSITION.X.Scale, ORIGINAL_POSITION.X.Offset, 1.5, 0)
	CompleteBackground.Position = UDim2.new(ORIGINAL_POSITION.X.Scale, ORIGINAL_POSITION.X.Offset, 1.5, 0)
	TS:Create(Background, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = ORIGINAL_POSITION}):Play()
	local cdTween = TS:Create(Cooldown, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)})
	cdTween.Completed:Connect(function() Cooldown.Visible = false canBuy = true end)
	cdTween:Play()
end

local function openWithProduct(index)
	if isProcessing or RobuxBuyPrompt.Enabled then return end
	currentProductIndex = index
	refreshPromptUI()
	RobuxBuyPrompt.Enabled = true
end

local function assignMobileKeybind(p, kbBtn)
	local promptOverlay = create("Frame", {Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.fromRGB(0,0,0), BackgroundTransparency = 0.5, Active = true}, CustomizerGui)
	local promptBox = create("TextBox", {Size = UDim2.new(0.6,0,0,50), Position = UDim2.new(0.2,0,0.4,0), BackgroundColor3 = Color3.fromRGB(30,30,40), TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 18, Text = "Tap here & Type Key", ClearTextOnFocus = true}, promptOverlay)
	create("UICorner", {CornerRadius = UDim.new(0,8)}, promptBox)
	table.insert(Connections, promptBox.FocusLost:Connect(function()
		local t = promptBox.Text:upper()
		if string.len(t) > 0 then
			p.Key = t
			kbBtn.Text = p.Key
		else
			p.Key = ""
			kbBtn.Text = "None"
		end
		assigningKey = false
		promptOverlay:Destroy()
	end))
end

local function addRobux()
	CURRENT_ROBUX = CURRENT_ROBUX + ADD_ROBUX_AMOUNT
	module.UpdateBalanceDisplay()
end

local CustomizerGui, SidePanel, ToggleBtn, TopBar, BackBtn, PanelTitle, MinBtn, DelBtn
local View_PresetList, View_PresetViewer, View_Customizer, View_ExtendedConfig
local Layout_PL, Layout_PV, Layout_C, Layout_EC
local RobuxInput, BalanceInput, AddAmountInput, BalanceLabel

local function buildCustomizer()
	CustomizerGui = create("ScreenGui", {Name = "RobuxCustomizer", ResetOnSpawn = false}, UI_PARENT)
	ToggleBtn = create("TextButton", {Size = UDim2.new(0,40,0,40), Position = UDim2.new(0.01,0,0.02,0), BackgroundColor3 = Color3.fromRGB(30,30,35), Text = "\226\154\153\239\184\143", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 20, Visible = false}, CustomizerGui)
	create("UICorner", {CornerRadius = UDim.new(0,8)}, ToggleBtn)
	create("UIStroke", {Color = Color3.fromRGB(80,80,100), Thickness = 1}, ToggleBtn)
	SidePanel = create("Frame", {Size = UDim2.new(0,360,0,520), Position = UDim2.new(0.02,0,0.15,0), BackgroundColor3 = Color3.fromRGB(18,18,24), Active = true, ClipsDescendants = true}, CustomizerGui)
	create("UICorner", {CornerRadius = UDim.new(0,12)}, SidePanel)
	create("UIStroke", {Color = Color3.fromRGB(60,60,80), Thickness = 1.5}, SidePanel)
	TopBar = create("Frame", {Size = UDim2.new(1,0,0,40), BackgroundColor3 = Color3.fromRGB(14,14,20)}, SidePanel)
	create("UICorner", {CornerRadius = UDim.new(0,12)}, TopBar)
	create("Frame", {Size = UDim2.new(1,0,0,8), Position = UDim2.new(0,0,1,-8), BackgroundColor3 = Color3.fromRGB(14,14,20), BorderSizePixel = 0}, TopBar)
	BackBtn = create("TextButton", {Size = UDim2.new(0,30,0,30), Position = UDim2.new(0,5,0.5,-15), BackgroundColor3 = Color3.fromRGB(45,45,55), Text = "<-", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 14, Visible = false}, TopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, BackBtn)
	PanelTitle = create("TextLabel", {Size = UDim2.new(0.5,0,1,0), Position = UDim2.new(0.12,0,0,0), BackgroundTransparency = 1, Text = "Presets", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left}, TopBar)
	MinBtn = create("TextButton", {Size = UDim2.new(0,30,0,30), Position = UDim2.new(1,-70,0.5,-15), BackgroundColor3 = Color3.fromRGB(45,45,55), Text = "-", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 18}, TopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, MinBtn)
	DelBtn = create("TextButton", {Size = UDim2.new(0,30,0,30), Position = UDim2.new(1,-35,0.5,-15), BackgroundColor3 = Color3.fromRGB(200,40,40), Text = "X", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 14}, TopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, DelBtn)

	local dragging, dragInput, dragStart, startPos
	table.insert(Connections, TopBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = SidePanel.Position
			input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end))
	table.insert(Connections, TopBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
	end))
	table.insert(Connections, UIS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			SidePanel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
	table.insert(Connections, MinBtn.MouseButton1Click:Connect(function() SidePanel.Visible = false ToggleBtn.Visible = true end))
	table.insert(Connections, ToggleBtn.MouseButton1Click:Connect(function() SidePanel.Visible = true ToggleBtn.Visible = false end))
	table.insert(Connections, DelBtn.MouseButton1Click:Connect(function() CustomizerGui:Destroy() end))

	View_PresetList = create("ScrollingFrame", {Size = UDim2.new(1,0,1,-40), Position = UDim2.new(0,0,0,40), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(100,100,120)}, SidePanel)
	View_PresetViewer = create("ScrollingFrame", {Size = UDim2.new(1,0,1,-40), Position = UDim2.new(0,0,0,40), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(100,100,120), Visible = false}, SidePanel)
	View_Customizer = create("ScrollingFrame", {Size = UDim2.new(1,0,1,-40), Position = UDim2.new(0,0,0,40), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(100,100,120), Visible = false}, SidePanel)
	View_ExtendedConfig = create("ScrollingFrame", {Size = UDim2.new(1,0,1,-40), Position = UDim2.new(0,0,0,40), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(100,100,120), Visible = false}, SidePanel)
	Layout_PL = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, View_PresetList)
	create("UIPadding", {PaddingTop = UDim.new(0,10), PaddingBottom = UDim.new(0,10)}, View_PresetList)
	Layout_PV = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, View_PresetViewer)
	create("UIPadding", {PaddingTop = UDim.new(0,10), PaddingBottom = UDim.new(0,10)}, View_PresetViewer)
	Layout_C = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, View_Customizer)
	create("UIPadding", {PaddingTop = UDim.new(0,10), PaddingBottom = UDim.new(0,10)}, View_Customizer)
	Layout_EC = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, View_ExtendedConfig)
	create("UIPadding", {PaddingTop = UDim.new(0,10), PaddingBottom = UDim.new(0,10)}, View_ExtendedConfig)

	table.insert(Connections, Layout_PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() View_PresetList.CanvasSize = UDim2.new(0,0,0, Layout_PL.AbsoluteContentSize.Y + 20) end))
	table.insert(Connections, Layout_PV:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() View_PresetViewer.CanvasSize = UDim2.new(0,0,0, Layout_PV.AbsoluteContentSize.Y + 20) end))
	table.insert(Connections, Layout_C:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() View_Customizer.CanvasSize = UDim2.new(0,0,0, Layout_C.AbsoluteContentSize.Y + 20) end))
	table.insert(Connections, Layout_EC:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() View_ExtendedConfig.CanvasSize = UDim2.new(0,0,0, Layout_EC.AbsoluteContentSize.Y + 20) end))
end

local function switchView(viewName, titleStr)
	View_PresetList.Visible = (viewName == "List")
	View_PresetViewer.Visible = (viewName == "Viewer")
	View_Customizer.Visible = (viewName == "Customizer")
	View_ExtendedConfig.Visible = (viewName == "ExtendedConfig")
	PanelTitle.Text = titleStr
	BackBtn.Visible = (viewName ~= "List")
	if viewName == "Customizer" then
		if not customizerProducts then
			customizerProducts = {}
			for i = 1, 12 do
				customizerProducts[i] = {Key = "", Title = "Empty Slot " .. i, Price = 100, Image = "rbxassetid://82563012679034", Reward = "R100", OldReward = "<s>R0</s>", MissingPrice = "1,99€", Active = false}
			end
		end
		Products = customizerProducts
		lastActiveView = "Customizer"
		updateRobux()
	elseif viewName == "Viewer" then
		lastActiveView = "PresetViewer"
		updateRobux()
	elseif viewName == "ExtendedConfig" then
		lastActiveView = "ExtendedConfig"
	else
		lastActiveView = nil
	end
end

table.insert(Connections, BackBtn.MouseButton1Click:Connect(function() switchView("List", "Presets") end))

local function renderPresetViewerUI()
	for _, child in ipairs(View_PresetViewer:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	for i = 1, 12 do
		local p = Products[i]
		if p.Active then
			local frame = create("Frame", {Size = UDim2.new(0.9,0,0,62), BackgroundColor3 = Color3.fromRGB(35,35,45), LayoutOrder = i}, View_PresetViewer)
			create("UICorner", {CornerRadius = UDim.new(0,8)}, frame)
			create("UIStroke", {Color = Color3.fromRGB(70,70,90), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, frame)
			local img = create("ImageLabel", {Size = UDim2.new(0,40,0,40), Position = UDim2.new(0,10,0.5,-20), BackgroundTransparency = 1, Image = p.Image, ScaleType = Enum.ScaleType.Fit}, frame)
			local title = create("TextLabel", {Size = UDim2.new(0.5,0,0,22), Position = UDim2.new(0,60,0,8), BackgroundTransparency = 1, Text = p.Title, TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, frame)
			local price = create("TextLabel", {Size = UDim2.new(0.5,0,0,22), Position = UDim2.new(0,60,0,32), BackgroundTransparency = 1, Text = ROBUX_SYMBOL .. p.Price, TextColor3 = Color3.fromRGB(170,230,170), Font = safeFont("Gotham"), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, frame)
			local kbBtn = create("TextButton", {Size = UDim2.new(0,65,0,28), Position = UDim2.new(1,-75,0.5,-14), BackgroundColor3 = Color3.fromRGB(30,30,40), TextColor3 = Color3.fromRGB(200,200,220), Font = safeFont("GothamBold"), TextSize = 11, Text = (p.Key == "" and "None" or p.Key)}, frame)
			create("UICorner", {CornerRadius = UDim.new(0,6)}, kbBtn)
			create("UIStroke", {Color = Color3.fromRGB(60,60,80), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, kbBtn)
			addHoverEffect(kbBtn, Color3.fromRGB(30,30,40), Color3.fromRGB(50,50,65))
			table.insert(Connections, kbBtn.MouseButton1Click:Connect(function()
				if assigningKey then return end
				assigningKey = true
				if UIS.TouchEnabled and not UIS.KeyboardEnabled then
					assignMobileKeybind(p, kbBtn)
				else
					kbBtn.Text = "..."
					local listenConn
					listenConn = UIS.InputBegan:Connect(function(inputObj)
						if inputObj.UserInputType == Enum.UserInputType.Keyboard then p.Key = inputObj.KeyCode.Name kbBtn.Text = p.Key
						elseif inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.MouseButton2 then p.Key = "" kbBtn.Text = "None" end
						listenConn:Disconnect()
						task.wait(0.1)
						assigningKey = false
					end)
				end
			end))
		end
	end
end

local function renderCustomizerUI()
	for _, child in ipairs(View_Customizer:GetChildren()) do if child:IsA("Frame") and child.LayoutOrder > 1 then child:Destroy() end end
	RobuxInput.Text = tostring(CURRENT_ROBUX)
	for i = 1, 12 do
		local p = Products[i]
		local frame = create("Frame", {Size = UDim2.new(0.9,0,0, p.Active and 270 or 44), BackgroundColor3 = Color3.fromRGB(35,35,45), LayoutOrder = i + 1}, View_Customizer)
		create("UICorner", {CornerRadius = UDim.new(0,8)}, frame)
		create("UIStroke", {Color = Color3.fromRGB(70,70,90), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, frame)
		create("TextLabel", {Size = UDim2.new(1,-50,0,38), Position = UDim2.new(0,10,0,3), BackgroundTransparency = 1, Text = "Product Slot " .. i, TextColor3 = Color3.fromRGB(200,200,220), Font = safeFont("GothamBold"), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, frame)
		if p.Active then
			local btn = create("TextButton", {Size = UDim2.new(0,40,0,24), Position = UDim2.new(1,-48,0,8), BackgroundColor3 = Color3.fromRGB(200,50,50), Text = "Del", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 11}, frame)
			create("UICorner", {CornerRadius = UDim.new(0,6)}, btn)
			addHoverEffect(btn, Color3.fromRGB(200,50,50), Color3.fromRGB(230,70,70))
			table.insert(Connections, btn.MouseButton1Click:Connect(function() p.Active = false renderCustomizerUI() end))
			local kbLabel = create("TextLabel", {Size = UDim2.new(0.3,0,0,24), Position = UDim2.new(0,10,0,42), BackgroundTransparency = 1, Text = "Keybind:", TextColor3 = Color3.fromRGB(180,180,200), Font = safeFont("Gotham"), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
			local kbBtn = create("TextButton", {Size = UDim2.new(0.65,-10,0,24), Position = UDim2.new(0.35,0,0,42), BackgroundColor3 = Color3.fromRGB(25,25,35), TextColor3 = Color3.fromRGB(200,200,220), Font = safeFont("GothamBold"), TextSize = 11, Text = (p.Key == "" and "None" or p.Key)}, frame)
			create("UICorner", {CornerRadius = UDim.new(0,5)}, kbBtn)
			create("UIStroke", {Color = Color3.fromRGB(60,60,80), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, kbBtn)
			addHoverEffect(kbBtn, Color3.fromRGB(25,25,35), Color3.fromRGB(45,45,60))
			table.insert(Connections, kbBtn.MouseButton1Click:Connect(function()
				if assigningKey then return end
				assigningKey = true
				if UIS.TouchEnabled and not UIS.KeyboardEnabled then
					assignMobileKeybind(p, kbBtn)
				else
					kbBtn.Text = "Press any key..."
					local listenConn
					listenConn = UIS.InputBegan:Connect(function(inputObj)
						if inputObj.UserInputType == Enum.UserInputType.Keyboard then p.Key = inputObj.KeyCode.Name kbBtn.Text = p.Key
						elseif inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.MouseButton2 then p.Key = "" kbBtn.Text = "None" end
						listenConn:Disconnect()
						task.wait(0.1)
						assigningKey = false
					end)
				end
			end))
			local function createRow(label, defaultText, y, cb)
				create("TextLabel", {Size = UDim2.new(0.3,0,0,24), Position = UDim2.new(0,10,0,y), BackgroundTransparency = 1, Text = label, TextColor3 = Color3.fromRGB(200,200,220), Font = safeFont("Gotham"), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
				local box = create("TextBox", {Size = UDim2.new(0.65,-10,0,24), Position = UDim2.new(0.35,0,0,y), BackgroundColor3 = Color3.fromRGB(25,25,35), TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("Gotham"), TextSize = 11, Text = tostring(defaultText), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left}, frame)
				create("UICorner", {CornerRadius = UDim.new(0,5)}, box)
				create("UIStroke", {Color = Color3.fromRGB(60,60,80), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, box)
				create("UIPadding", {PaddingLeft = UDim.new(0,5)}, box)
				table.insert(Connections, box.FocusLost:Connect(function() cb(box.Text) end))
			end
			createRow("Title:", p.Title, 72, function(v) p.Title = v refreshPromptUI() end)
			createRow("Price:", p.Price, 102, function(v) p.Price = tonumber(v) or p.Price refreshPromptUI() end)
			createRow("Image ID:", p.Image, 132, function(v) p.Image = v refreshPromptUI() end)
			createRow("Reward:", p.Reward, 162, function(v) p.Reward = v refreshPromptUI() end)
			createRow("Old Rwd:", p.OldReward, 192, function(v) p.OldReward = v refreshPromptUI() end)
			createRow("Missing:", p.MissingPrice, 222, function(v) p.MissingPrice = v refreshPromptUI() end)
		else
			local btn = create("TextButton", {Size = UDim2.new(0,40,0,24), Position = UDim2.new(1,-48,0,8), BackgroundColor3 = Color3.fromRGB(50,200,50), Text = "Add", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 11}, frame)
			create("UICorner", {CornerRadius = UDim.new(0,6)}, btn)
			addHoverEffect(btn, Color3.fromRGB(50,200,50), Color3.fromRGB(70,230,70))
			table.insert(Connections, btn.MouseButton1Click:Connect(function() p.Active = true renderCustomizerUI() end))
		end
	end
end

local function buildPresetList()
	local robuxManager = create("Frame", {Size = UDim2.new(0.9,0,0,130), BackgroundColor3 = Color3.fromRGB(35,35,45), LayoutOrder = 0}, View_PresetList)
	create("UICorner", {CornerRadius = UDim.new(0,8)}, robuxManager)
	create("UIStroke", {Color = Color3.fromRGB(70,70,90), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, robuxManager)
	create("TextLabel", {Size = UDim2.new(1,-10,0,20), Position = UDim2.new(0,10,0,8), BackgroundTransparency = 1, Text = "Robux Manager", TextColor3 = Color3.fromRGB(220,220,240), Font = safeFont("GothamBold"), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, robuxManager)
	BalanceLabel = create("TextLabel", {Size = UDim2.new(1,-20,0,18), Position = UDim2.new(0,10,0,30), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("Gotham"), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Text = ROBUX_SYMBOL .. " " .. formatNumber(CURRENT_ROBUX)}, robuxManager)
	create("TextLabel", {Size = UDim2.new(0.4,0,0,20), Position = UDim2.new(0,10,0,52), BackgroundTransparency = 1, Text = "Set Balance:", TextColor3 = Color3.fromRGB(200,200,220), Font = safeFont("Gotham"), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, robuxManager)
	BalanceInput = create("TextBox", {Size = UDim2.new(0.55,-10,0,20), Position = UDim2.new(0.45,0,0,52), BackgroundColor3 = Color3.fromRGB(25,25,35), TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("Gotham"), TextSize = 11, Text = tostring(CURRENT_ROBUX), ClearTextOnFocus = false}, robuxManager)
	create("UICorner", {CornerRadius = UDim.new(0,4)}, BalanceInput)
	create("UIStroke", {Color = Color3.fromRGB(60,60,80), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, BalanceInput)
	table.insert(Connections, BalanceInput.FocusLost:Connect(function()
		local val = tonumber(BalanceInput.Text)
		if val then
			CURRENT_ROBUX = val
			BalanceLabel.Text = ROBUX_SYMBOL .. " " .. formatNumber(CURRENT_ROBUX)
			updateRobux()
		else
			BalanceInput.Text = tostring(CURRENT_ROBUX)
		end
	end))
	create("TextLabel", {Size = UDim2.new(0.4,0,0,20), Position = UDim2.new(0,10,0,78), BackgroundTransparency = 1, Text = "Add Amount:", TextColor3 = Color3.fromRGB(200,200,220), Font = safeFont("Gotham"), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, robuxManager)
	AddAmountInput = create("TextBox", {Size = UDim2.new(0.55,-10,0,20), Position = UDim2.new(0.45,0,0,78), BackgroundColor3 = Color3.fromRGB(25,25,35), TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("Gotham"), TextSize = 11, Text = tostring(ADD_ROBUX_AMOUNT), ClearTextOnFocus = false}, robuxManager)
	create("UICorner", {CornerRadius = UDim.new(0,4)}, AddAmountInput)
	create("UIStroke", {Color = Color3.fromRGB(60,60,80), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, AddAmountInput)
	table.insert(Connections, AddAmountInput.FocusLost:Connect(function()
		local val = tonumber(AddAmountInput.Text)
		if val then
			ADD_ROBUX_AMOUNT = val
		else
			AddAmountInput.Text = tostring(ADD_ROBUX_AMOUNT)
		end
	end))
	local moreRobuxBtn = create("TextButton", {Size = UDim2.new(1,-20,0,24), Position = UDim2.new(0,10,0,102), BackgroundColor3 = Color3.fromRGB(40,180,80), Text = "+ Add Robux", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 12}, robuxManager)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, moreRobuxBtn)
	addHoverEffect(moreRobuxBtn, Color3.fromRGB(40,180,80), Color3.fromRGB(60,210,100))
	table.insert(Connections, moreRobuxBtn.MouseButton1Click:Connect(addRobux))
	for i, preset in ipairs(PRESETS) do
		local btn = create("TextButton", {Size = UDim2.new(0.9,0,0,44), BackgroundColor3 = Color3.fromRGB(40,40,50), Text = preset.Name, TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 14, LayoutOrder = i}, View_PresetList)
		create("UICorner", {CornerRadius = UDim.new(0,8)}, btn)
		create("UIStroke", {Color = Color3.fromRGB(80,80,100), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, btn)
		addHoverEffect(btn, Color3.fromRGB(40,40,50), Color3.fromRGB(60,60,75))
		table.insert(Connections, btn.MouseButton1Click:Connect(function()
			Products = preset.Items
			switchView("Viewer", "Preset: " .. preset.Name)
		end))
	end
	local openCustomBtn = create("TextButton", {Size = UDim2.new(0.9,0,0,44), BackgroundColor3 = Color3.fromRGB(200,100,30), Text = "Open Advanced Customizer", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 14, LayoutOrder = #PRESETS + 1}, View_PresetList)
	create("UICorner", {CornerRadius = UDim.new(0,8)}, openCustomBtn)
	create("UIStroke", {Color = Color3.fromRGB(255,150,50), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, openCustomBtn)
	addHoverEffect(openCustomBtn, Color3.fromRGB(200,100,30), Color3.fromRGB(230,120,40))
	table.insert(Connections, openCustomBtn.MouseButton1Click:Connect(function() switchView("Customizer", "Advanced Customizer") end))
	local openExtendedBtn = create("TextButton", {Size = UDim2.new(0.9,0,0,44), BackgroundColor3 = Color3.fromRGB(130,40,180), Text = "Open Build Mode", TextColor3 = Color3.fromRGB(255,255,255), Font = safeFont("GothamBold"), TextSize = 14, LayoutOrder = #PRESETS + 2}, View_PresetList)
	create("UICorner", {CornerRadius = UDim.new(0,8)}, openExtendedBtn)
	create("UIStroke", {Color = Color3.fromRGB(150,60,200), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, openExtendedBtn)
	addHoverEffect(openExtendedBtn, Color3.fromRGB(130,40,180), Color3.fromRGB(160,70,210))
	table.insert(Connections, openExtendedBtn.MouseButton1Click:Connect(function()
		if BuildModeLink then BuildModeLink.EnterBuildMode("My Tool") end
	end))
end

local function wireCloseButton()
	table.insert(Connections, CloseButton.MouseButton1Click:Connect(cancelPrompt))
	table.insert(Connections, C_CloseButton.MouseButton1Click:Connect(finishPurchaseScreen))
	table.insert(Connections, C_OKButton.MouseButton1Click:Connect(finishPurchaseScreen))
	table.insert(Connections, BuyButton.MouseButton1Click:Connect(function()
		if not canBuy or isProcessing then return end
		local p = Products[currentProductIndex]
		if CURRENT_ROBUX >= tonumber(p.Price) then
			isProcessing = true
			BuyButton.AutoButtonColor = false
			TS:Create(BuyButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.new(ORIGINAL_BUTTON_COLOR.R*0.5, ORIGINAL_BUTTON_COLOR.G*0.5, ORIGINAL_BUTTON_COLOR.B*0.5)}):Play()
			task.wait(0.8)
			local slideOut = TS:Create(Background, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(ORIGINAL_POSITION.X.Scale, ORIGINAL_POSITION.X.Offset, 1.5, 0)})
			slideOut:Play()
			slideOut.Completed:Once(function()
				C_ProductText.Text = "You have successfully bought " .. p.Title
				TS:Create(CompleteBackground, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = ORIGINAL_POSITION}):Play()
				isProcessing = false
			end)
		end
	end))
	table.insert(Connections, RobuxBuyPrompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if RobuxBuyPrompt.Enabled then
			isProcessing = false
			BuyButton.AutoButtonColor = true
			Overlay.Visible = true
			hideOtherUIs()
			playOpenAnimation()
		end
	end))
end

local function wireKeybinds()
	table.insert(Connections, UIS.InputBegan:Connect(function(input, gp)
		if gp or assigningKey or RobuxBuyPrompt.Enabled then return end
		local keyName = input.KeyCode.Name
		if keyName == "Plus" and not UIS:GetFocusedTextBox() then addRobux() return end
		if not lastActiveView then return end
		for i = 1, 12 do
			local p = Products[i]
			if p.Active and p.Key ~= "" and keyName == p.Key then
				if isProcessing then return end
				openWithProduct(i)
			end
		end
	end))
end

function module.Initialize(parent, conns, buildMode)
	UI_PARENT = parent
	Connections = conns
	BuildModeLink = buildMode
	UIS = game:GetService("UserInputService")
	TS = game:GetService("TweenService")
	Players = game:GetService("Players")
	CP = game:GetService("ContentProvider")
	HS = game:GetService("HttpService")
	RS = game:GetService("RunService")
	buildBuyPrompt()
	buildCustomizer()
	buildPresetList()
	wireCloseButton()
	wireKeybinds()
	updateRobux()
end

function module.UpdateBalanceDisplay()
	BalanceLabel.Text = ROBUX_SYMBOL .. " " .. formatNumber(CURRENT_ROBUX)
	BalanceInput.Text = tostring(CURRENT_ROBUX)
	RobuxInput.Text = tostring(CURRENT_ROBUX)
	RobuxAmount.Text = ROBUX_SYMBOL .. " " .. formatNumber(CURRENT_ROBUX)
end

return module
