local function showError(title, message)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScriptError"
	gui.ResetOnSpawn = false
	local parent
	pcall(function() parent = game:GetService("CoreGui") end)
	if not parent then parent = game.Players.LocalPlayer:WaitForChild("PlayerGui") end
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 420, 0, 240)
	frame.Position = UDim2.new(0.5, -210, 0.5, -120)
	frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 32)
	titleLabel.Position = UDim2.new(0, 10, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title or "Error"
	titleLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -44, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.Parent = frame
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
	closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -24, 1, -54)
	scroll.Position = UDim2.new(0, 12, 0, 44)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 200)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
	scroll.Parent = frame

	local msgLabel = Instance.new("TextLabel")
	msgLabel.Size = UDim2.new(1, -8, 0, 0)
	msgLabel.BackgroundTransparency = 1
	msgLabel.Text = message or "Unknown error"
	msgLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.TextSize = 14
	msgLabel.TextWrapped = true
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.TextYAlignment = Enum.TextYAlignment.Top
	msgLabel.Parent = scroll
	msgLabel.Size = UDim2.new(1, -8, 0, msgLabel.TextBounds.Y + 20)
	scroll.CanvasSize = UDim2.new(0, 0, 0, msgLabel.TextBounds.Y + 24)
end

local success, result = pcall(function()
	local HttpService = game:GetService("HttpService")
	local UIS = game:GetService("UserInputService")
	local RS = game:GetService("RunService")
	local Players = game:GetService("Players")
	local TS = game:GetService("TweenService")
	local CP = game:GetService("ContentProvider")

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

	local Connections = {}
	local BASE_URL = "https://raw.githubusercontent.com/jordanrode910-beep/local-fakebuyscriptservice/main/"

	local function fetchModule(name)
		local url = BASE_URL .. name .. ".lua"
		local source, httpErr = pcall(function() return game:HttpGet(url) end)
		if not source then
			error("Download failed for " .. name .. ": " .. tostring(httpErr))
		end
		return source
	end

	local function safeLoadModule(name)
		local source = fetchModule(name)
		local fn, loadErr = loadstring(source)
		if not fn then
			error("Parse error in " .. name .. ": " .. tostring(loadErr))
		end
		local ok, module = pcall(fn)
		if not ok then
			error("Execution error in " .. name .. ": " .. tostring(module))
		end
		if type(module) ~= "table" then
			error(name .. " did not return a table")
		end
		return module
	end

	local CoreUI = safeLoadModule("CoreUI")
	local BuildMode = safeLoadModule("BuildMode")
	local GizmoSystem = safeLoadModule("GizmoSystem")
	local MaterialPicker = safeLoadModule("MaterialPicker")
	local BrowserTree = safeLoadModule("BrowserTree")
	local ExportImport = safeLoadModule("ExportImport")
	local ToolCompiler = safeLoadModule("ToolCompiler")

	local buildModeInstance = BuildMode.Create(UI_PARENT, Connections, {
		GizmoSystem = GizmoSystem,
		MaterialPicker = MaterialPicker,
		BrowserTree = BrowserTree,
		ExportImport = ExportImport,
		ToolCompiler = ToolCompiler
	})

	CoreUI.Initialize(UI_PARENT, Connections, buildModeInstance)

	game:BindToClose(function()
		pcall(function()
			for _, conn in ipairs(Connections) do
				conn:Disconnect()
			end
			table.clear(Connections)
			if UI_PARENT:FindFirstChild("RobuxBuyPrompt") then UI_PARENT.RobuxBuyPrompt:Destroy() end
			if UI_PARENT:FindFirstChild("RobuxCustomizer") then UI_PARENT.RobuxCustomizer:Destroy() end
			if UI_PARENT:FindFirstChild("BuildModeGui") then UI_PARENT.BuildModeGui:Destroy() end
		end)
	end)
end)

if not success then
	showError("Script Failed", tostring(result))
end
