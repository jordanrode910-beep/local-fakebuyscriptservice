local function showError(title, message)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScriptError"
	gui.ResetOnSpawn = false
	local parent
	pcall(function() parent = game:GetService("CoreGui") end)
	if not parent then parent = game.Players.LocalPlayer:WaitForChild("PlayerGui") end
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 480, 0, 320)
	frame.Position = UDim2.new(0.5, -240, 0.5, -160)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 34)
	titleLabel.Position = UDim2.new(0, 10, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title or "Script Error"
	titleLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -46, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 20
	closeBtn.Parent = frame
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
	closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -20, 0, 20)
	infoLabel.Position = UDim2.new(0, 10, 0, 46)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "Full trace (select and copy):"
	infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 12
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -76)
	scroll.Position = UDim2.new(0, 10, 0, 66)
	scroll.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 400)
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 140)
	scroll.Parent = frame
	Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 8)

	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name = "ErrorMessage"
	msgLabel.BackgroundTransparency = 1
	msgLabel.Text = message or "Unknown error"
	msgLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	msgLabel.Font = Enum.Font.Code
	msgLabel.TextSize = 13
	msgLabel.TextWrapped = true
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.TextYAlignment = Enum.TextYAlignment.Top
	msgLabel.Size = UDim2.new(1, -12, 0, 0)
	msgLabel.Position = UDim2.new(0, 6, 0, 6)
	msgLabel.Parent = scroll
	msgLabel.Size = UDim2.new(1, -12, 0, msgLabel.TextBounds.Y + 20)
	scroll.CanvasSize = UDim2.new(0, 0, 0, msgLabel.TextBounds.Y + 24)
end

local function onError(err)
	return debug.traceback(tostring(err), 2)
end

local success, result = xpcall(function()
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
		local ok, result = pcall(function() return game:HttpGet(url) end)
		if not ok then
			error("Download failed for " .. name .. ": " .. tostring(result))
		end
		return result
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
end, onError)

if not success then
	showError("Script Execution Error", tostring(result))
end
