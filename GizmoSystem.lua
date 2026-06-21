local module = {}
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Players = game:GetService("Players")

local GizmoRoot = nil
local HandlePart = nil
local MoveArrows = {}
local RotateRings = {}
local ScaleCubes = {}
local ActiveGizmo = nil
local DragConnection = nil
local DragAxis = nil
local DragMode = nil
local DragStartPlane = nil
local DragStartValue = 0

module.OnDragBegan = nil
module.OnDragUpdate = nil
module.OnDragEnded = nil

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local GizmoContainer = PlayerGui:FindFirstChild("GizmoInteractionContainer") or Instance.new("ScreenGui")
GizmoContainer.Name = "GizmoInteractionContainer"
GizmoContainer.Parent = PlayerGui

local function createArrow(axis, color)
	local cylinder = Instance.new("CylinderHandleAdornment")
	cylinder.AlwaysOnTop = true
	cylinder.Color3 = color
	cylinder.Adornee = HandlePart
	cylinder.Transparency = 0.2
	cylinder.SizeRelativeOffset = Vector3.zero
	cylinder.CFrame = axis == "X" and CFrame.new(2,0,0) * CFrame.Angles(0,0,math.rad(90))
		or axis == "Y" and CFrame.new(0,2,0)
		or axis == "Z" and CFrame.new(0,0,2) * CFrame.Angles(math.rad(90),0,0)
	cylinder.Parent = GizmoContainer
	cylinder.MouseButton1Down:Connect(function()
		ActiveGizmo = cylinder
		DragAxis = axis
		DragMode = "Move"
		DragStartPlane = Vector3.new(UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y, 0)
		if module.OnDragBegan then
			module.OnDragBegan(axis, "Move")
		end
	end)
	return cylinder
end

local function createRing(axis, color)
	local ring = Instance.new("CylinderHandleAdornment")
	ring.AlwaysOnTop = true
	ring.Color3 = color
	ring.Adornee = HandlePart
	ring.Transparency = 0.4
	ring.SizeRelativeOffset = Vector3.new(0.5, 0.5, 0.5)
	local rot = CFrame.new()
	if axis == "X" then rot = CFrame.Angles(0, math.rad(90), 0)
	elseif axis == "Y" then rot = CFrame.Angles(0, 0, 0)
	elseif axis == "Z" then rot = CFrame.Angles(math.rad(90), 0, 0) end
	ring.CFrame = rot
	ring.Parent = GizmoContainer
	ring.MouseButton1Down:Connect(function()
		ActiveGizmo = ring
		DragAxis = axis
		DragMode = "Rotate"
		DragStartPlane = Vector3.new(UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y, 0)
		if module.OnDragBegan then
			module.OnDragBegan(axis, "Rotate")
		end
	end)
	return ring
end

local function createScaleCube(axis, color)
	local cube = Instance.new("CubeHandleAdornment")
	cube.AlwaysOnTop = true
	cube.Color3 = color
	cube.Adornee = HandlePart
	cube.Transparency = 0.2
	cube.SizeRelativeOffset = Vector3.new(0.3, 0.3, 0.3)
	local pos = Vector3.new()
	if axis == "X" then pos = Vector3.new(2, 0, 0)
	elseif axis == "Y" then pos = Vector3.new(0, 2, 0)
	elseif axis == "Z" then pos = Vector3.new(0, 0, 2) end
	cube.CFrame = CFrame.new(pos)
	cube.Parent = GizmoContainer
	cube.MouseButton1Down:Connect(function()
		ActiveGizmo = cube
		DragAxis = axis
		DragMode = "Scale"
		DragStartPlane = Vector3.new(UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y, 0)
		if module.OnDragBegan then
			module.OnDragBegan(axis, "Scale")
		end
	end)
	return cube
end

function module.SetGizmoRoot(root)
	GizmoRoot = root
end

function module.PlaceHandle(cframe)
	if not HandlePart then
		HandlePart = Instance.new("Part")
		HandlePart.Name = "BuildHandle"
		HandlePart.Anchored = true
		HandlePart.CanCollide = false
		HandlePart.CanQuery = false
		HandlePart.Transparency = 0.7
		HandlePart.Color = Color3.fromRGB(0, 170, 255)
		HandlePart.Material = Enum.Material.Neon
		HandlePart.Size = Vector3.new(2, 2, 2)
		HandlePart.Parent = GizmoRoot
		MoveArrows.X = createArrow("X", Color3.fromRGB(255, 0, 0))
		MoveArrows.Y = createArrow("Y", Color3.fromRGB(0, 255, 0))
		MoveArrows.Z = createArrow("Z", Color3.fromRGB(0, 0, 255))
		RotateRings.X = createRing("X", Color3.fromRGB(255, 0, 0))
		RotateRings.Y = createRing("Y", Color3.fromRGB(0, 255, 0))
		RotateRings.Z = createRing("Z", Color3.fromRGB(0, 0, 255))
		ScaleCubes.X = createScaleCube("X", Color3.fromRGB(255, 0, 0))
		ScaleCubes.Y = createScaleCube("Y", Color3.fromRGB(0, 255, 0))
		ScaleCubes.Z = createScaleCube("Z", Color3.fromRGB(0, 0, 255))
	end
	HandlePart.CFrame = cframe
end

function module.GetHandleCFrame()
	return HandlePart and HandlePart.CFrame or CFrame.new()
end

function module.UpdateGizmo(selection)
	if not HandlePart then return end
	local center = Vector3.zero
	local count = 0
	for _, root in ipairs(selection) do
		if root:IsA("BasePart") then
			center += root.CFrame.Position
			count += 1
		else
			center += root:GetPivot().Position
			count += 1
		end
	end
	if count > 0 then
		HandlePart.CFrame = CFrame.new(center / count)
	else
		HandlePart.CFrame = CFrame.new(Workspace.CurrentCamera.CFrame.Position + Workspace.CurrentCamera.CFrame.LookVector * 12)
	end
	for _, arrow in pairs(MoveArrows) do arrow.Enabled = true end
	for _, ring in pairs(RotateRings) do ring.Enabled = true end
	for _, cube in pairs(ScaleCubes) do cube.Enabled = true end
end

function module.Hide()
	if HandlePart then
		HandlePart:Destroy()
		HandlePart = nil
	end
	for _, v in pairs(MoveArrows) do v:Destroy() end
	for _, v in pairs(RotateRings) do v:Destroy() end
	for _, v in pairs(ScaleCubes) do v:Destroy() end
	MoveArrows = {}
	RotateRings = {}
	ScaleCubes = {}
end

local function onInputChanged(input, gameProcessed)
	if not ActiveGizmo or not DragMode then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - DragStartPlane
		local value = 0
		if DragMode == "Move" then
			value = (delta.X + delta.Y) * 0.01
		elseif DragMode == "Rotate" then
			value = delta.X * 0.005
		elseif DragMode == "Scale" then
			value = 1 + (-delta.Y * 0.01)
		end
		if module.OnDragUpdate then
			module.OnDragUpdate(DragAxis, DragMode, value)
		end
		DragStartPlane = input.Position
	end
end

local function onInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if ActiveGizmo then
			if module.OnDragEnded then
				module.OnDragEnded()
			end
			ActiveGizmo = nil
			DragMode = nil
			DragAxis = nil
		end
	end
end

UIS.InputChanged:Connect(onInputChanged)
UIS.InputEnded:Connect(onInputEnded)

return module
