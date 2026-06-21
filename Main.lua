-- Robust error display (uses only Legacy font, always works)
local function showError(title, msg)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScriptError"
	gui.ResetOnSpawn = false
	local parent
	pcall(function() parent = game:GetService("CoreGui") end)
	if not parent then parent = game.Players.LocalPlayer:WaitForChild("PlayerGui") end
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 450, 0, 300)
	frame.Position = UDim2.new(0.5, -225, 0.5, -150)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 32)
	titleLabel.Position = UDim2.new(0, 10, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title or "Script Error"
	titleLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
	titleLabel.Font = Enum.Font.Legacy
	titleLabel.TextSize = 20
	titleLabel.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -42, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.Legacy
	closeBtn.TextSize = 18
	closeBtn.Parent = frame
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
	closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -50)
	scroll.Position = UDim2.new(0, 10, 0, 44)
	scroll.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 200)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 140)
	scroll.Parent = frame
	Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 8)

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -12, 0, 0)
	textBox.Position = UDim2.new(0, 6, 0, 4)
	textBox.BackgroundTransparency = 1
	textBox.Text = msg or "Unknown error"
	textBox.TextColor3 = Color3.new(1, 1, 1)
	textBox.Font = Enum.Font.Legacy
	textBox.TextSize = 14
	textBox.TextWrapped = true
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextEditable = false
	textBox.TextSelectable = true
	textBox.Parent = scroll
	textBox.Size = UDim2.new(1, -12, 0, textBox.TextBounds.Y + 12)
	scroll.CanvasSize = UDim2.new(0, 0, 0, textBox.TextBounds.Y + 16)
end

-- Main execution
local success, result = pcall(function()
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local RS = game:GetService("RunService")
	local TS = game:GetService("TweenService")
	local CP = game:GetService("ContentProvider")

	-- 1. Safe UI parent
	local UI_PARENT
	local function getSafeParent()
		if getfenv().gethui then
			local ok, hui = pcall(getfenv().gethui)
			if ok and hui then return hui end
		end
		local player = Players.LocalPlayer
		if player then
			return player:WaitForChild("PlayerGui")
		end
		return nil
	end
	UI_PARENT = getSafeParent()
	if not UI_PARENT then
		showError("Fatal Error", "Could not find a valid UI parent. Try a different executor.")
		return
	end

	-- 2. Load modules from GitHub
	local BASE_URL = "https://raw.githubusercontent.com/jordanrode910-beep/local-fakebuyscriptservice/main/"
	local function fetchModule(name)
		local url = BASE_URL .. name .. ".lua"
		local ok, source = pcall(function() return game:HttpGet(url) end)
		if not ok then error("Download failed: " .. name .. " - " .. tostring(source)) end
		local fn, loadErr = loadstring(source)
		if not fn then error("Syntax error in " .. name .. ": " .. loadErr) end
		local ok, mod = pcall(fn)
		if not ok then error("Execution error in " .. name .. ": " .. tostring(mod)) end
		if type(mod) ~= "table" then error(name .. " returned non-table") end
		return mod
	end

	local CoreUI = fetchModule("CoreUI")
	local BuildMode = fetchModule("BuildMode")
	local GizmoSystem = fetchModule("GizmoSystem")
	local MaterialPicker = fetchModule("MaterialPicker")
	local BrowserTree = fetchModule("BrowserTree")
	local ExportImport = fetchModule("ExportImport")
	local ToolCompiler = fetchModule("ToolCompiler")

	-- 3. Wire everything together
	local Connections = {}
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
			for _, conn in ipairs(Connections) do conn:Disconnect() end
			table.clear(Connections)
			if UI_PARENT:FindFirstChild("RobuxBuyPrompt") then UI_PARENT.RobuxBuyPrompt:Destroy() end
			if UI_PARENT:FindFirstChild("RobuxCustomizer") then UI_PARENT.RobuxCustomizer:Destroy() end
			if UI_PARENT:FindFirstChild("BuildModeGui") then UI_PARENT.BuildModeGui:Destroy() end
		end)
	end)
end)

if not success then
	local msg = tostring(result)
	if msg == "" then msg = "Empty error string" end
	showError("Script Execution Failed", msg)
end
