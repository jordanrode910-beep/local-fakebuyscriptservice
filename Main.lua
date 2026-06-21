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
	local fn, err = loadstring(source)
	if not fn then error("Module " .. name .. " failed: " .. tostring(err)) end
	return fn()
end

local CoreUI = loadModule("CoreUI")
local BuildMode = loadModule("BuildMode")
local GizmoSystem = loadModule("GizmoSystem")
local MaterialPicker = loadModule("MaterialPicker")
local BrowserTree = loadModule("BrowserTree")
local ExportImport = loadModule("ExportImport")
local ToolCompiler = loadModule("ToolCompiler")

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
