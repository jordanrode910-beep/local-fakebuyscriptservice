local success, err = pcall(function()
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

	local function loadModule(name)
		local source = game:HttpGet(BASE_URL .. name .. ".lua")
		local fn, loadErr = loadstring(source)
		if not fn then
			error("Module " .. name .. " parse error: " .. tostring(loadErr))
		end
		return fn()
	end

	local CoreUI = loadModule("CoreUI")
	local BuildMode = loadModule("BuildMode")
	local GizmoSystem = loadModule("GizmoSystem")
	local MaterialPicker = loadModule("MaterialPicker")
	local BrowserTree = loadModule("BrowserTree")
	local ExportImport = loadModule("ExportImport")
	local ToolCompiler = loadModule("ToolCompiler")

	if not CoreUI or not BuildMode or not GizmoSystem or not MaterialPicker or not BrowserTree or not ExportImport or not ToolCompiler then
		error("One or more modules returned nil. Check module files.")
	end

	local buildModeInstance = BuildMode.Create(UI_PARENT, Connections, {
		GizmoSystem = GizmoSystem,
		MaterialPicker = MaterialPicker,
		BrowserTree = BrowserTree,
		ExportImport = ExportImport,
		ToolCompiler = ToolCompiler
	})

	CoreUI.Initialize(UI_PARENT, Connections, buildModeInstance)

	game:BindToClose(function()
		for _, conn in ipairs(Connections) do
			conn:Disconnect()
		end
		table.clear(Connections)
		if UI_PARENT:FindFirstChild("RobuxBuyPrompt") then UI_PARENT.RobuxBuyPrompt:Destroy() end
		if UI_PARENT:FindFirstChild("RobuxCustomizer") then UI_PARENT.RobuxCustomizer:Destroy() end
		if UI_PARENT:FindFirstChild("BuildModeGui") then UI_PARENT.BuildModeGui:Destroy() end
	end)
end)

if not success then
	local function showError(message)
		local gui = Instance.new("ScreenGui")
		gui.Name = "ErrorGui"
		gui.ResetOnSpawn = false
		local parent
		pcall(function() parent = game:GetService("CoreGui") end)
		if not parent then parent = game.Players.LocalPlayer:WaitForChild("PlayerGui") end
		gui.Parent = parent

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0, 400, 0, 200)
		frame.Position = UDim2.new(0.5, -200, 0.5, -100)
		frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = frame

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -20, 0, 30)
		title.Position = UDim2.new(0, 10, 0, 10)
		title.BackgroundTransparency = 1
		title.Text = "Script Load Error"
		title.TextColor3 = Color3.fromRGB(255, 80, 80)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 18
		title.Parent = frame

		local close = Instance.new("TextButton")
		close.Size = UDim2.new(0, 30, 0, 30)
		close.Position = UDim2.new(1, -40, 0, 5)
		close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		close.Text = "X"
		close.TextColor3 = Color3.fromRGB(255, 255, 255)
		close.Font = Enum.Font.GothamBold
		close.TextSize = 14
		close.Parent = frame
		Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
		close.MouseButton1Click:Connect(function() gui:Destroy() end)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, -20, 1, -50)
		scroll.Position = UDim2.new(0, 10, 0, 45)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.CanvasSize = UDim2.new(0, 0, 0, 200)
		scroll.ScrollBarThickness = 4
		scroll.Parent = frame

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, 0, 0, 200)
		text.BackgroundTransparency = 1
		text.Text = "Error: " .. tostring(message)
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.Font = Enum.Font.Gotham
		text.TextSize = 14
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.Parent = scroll
		scroll.CanvasSize = UDim2.new(0, 0, 0, text.TextBounds.Y + 10)
	end

	showError(err)
end
