local module = {}
local UIS, RS, Players, TS, HS, CP, Workspace, Camera
local UI_PARENT, Connections
local GizmoSystem, MaterialPicker, BrowserTree, ExportImport, ToolCompiler

local BuildMode = {
	Active = false,
	Root = nil,
	GizmoRoot = nil,
	Selection = {},
	Mode = "Move",
	Snap = 1,
	RotateSnap = 15,
	ScaleSnap = 0.25,
	BrowserSearch = "",
	History = {},
	Redo = {},
	Slots = {},
	HandlePreset = nil,
	LastSave = nil,
	ToolName = "My Custom Tool",
	AutosaveToken = 0,
	SuppressHistory = false,
	CurrentTemplates = {},
	Drag = {
		Active = false,
		Type = nil,
		StartPoint = nil,
		StartCenter = nil,
		StartTransforms = nil,
		StartScale = nil,
		StartYaw = nil
	}
}

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then inst[k] = v end
	end
	if parent then inst.Parent = parent end
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

local function gatherParts(inst, list)
	list = list or {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function getBoundsForInstance(inst)
	local parts = gatherParts(inst, {})
	if #parts == 0 then
		local pivot = inst:IsA("BasePart") and inst.CFrame or CFrame.new()
		return pivot.Position, Vector3.new(1,1,1), pivot
	end
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(parts) do
		local cf = part.CFrame
		local s = part.Size * 0.5
		for _, ox in ipairs({-1, 1}) do
			for _, oy in ipairs({-1, 1}) do
				for _, oz in ipairs({-1, 1}) do
					local p = (cf * CFrame.new(s.X * ox, s.Y * oy, s.Z * oz)).Position
					minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
					maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
				end
			end
		end
	end
	local center = (minV + maxV) * 0.5
	local size = maxV - minV
	return center, size, CFrame.new(center)
end

local function getSelectionCenter()
	if #BuildMode.Selection == 0 then
		return Camera.CFrame.Position + Camera.CFrame.LookVector * 12
	end
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, root in ipairs(BuildMode.Selection) do
		local center, size = getBoundsForInstance(root)
		local half = size * 0.5
		local pts = {
			center + Vector3.new(-half.X, -half.Y, -half.Z),
			center + Vector3.new(-half.X, -half.Y, half.Z),
			center + Vector3.new(-half.X, half.Y, -half.Z),
			center + Vector3.new(-half.X, half.Y, half.Z),
			center + Vector3.new(half.X, -half.Y, -half.Z),
			center + Vector3.new(half.X, -half.Y, half.Z),
			center + Vector3.new(half.X, half.Y, -half.Z),
			center + Vector3.new(half.X, half.Y, half.Z)
		}
		for _, p in ipairs(pts) do
			minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
			maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
		end
	end
	return (minV + maxV) * 0.5
end

local function snapVector(v, snap)
	snap = math.max(0.001, tonumber(snap) or 1)
	return Vector3.new(math.round(v.X / snap) * snap, math.round(v.Y / snap) * snap, math.round(v.Z / snap) * snap)
end

local function readSnapBoxes()
	local s = tonumber(SnapBox.Text:match("[%d%.%-]+")) or 1
	local r = tonumber(RotateSnapBox.Text:match("[%d%.%-]+")) or 15
	local sc = tonumber(ScaleSnapBox.Text:match("[%d%.%-]+")) or 0.25
	BuildMode.Snap = math.max(0.001, s)
	BuildMode.RotateSnap = math.max(1, r)
	BuildMode.ScaleSnap = math.max(0.01, sc)
end

local function setActiveMode(mode)
	BuildMode.Mode = mode
	ModeMoveBtn.BackgroundColor3 = mode == "Move" and Color3.fromRGB(50, 120, 220) or Color3.fromRGB(60, 60, 70)
	ModeRotateBtn.BackgroundColor3 = mode == "Rotate" and Color3.fromRGB(50, 120, 220) or Color3.fromRGB(60, 60, 70)
	ModeScaleBtn.BackgroundColor3 = mode == "Scale" and Color3.fromRGB(50, 120, 220) or Color3.fromRGB(60, 60, 70)
	ModeSelectBtn.BackgroundColor3 = mode == "Select" and Color3.fromRGB(50, 120, 220) or Color3.fromRGB(60, 60, 70)
end

local function safeSet(inst, prop, value)
	pcall(function()
		inst[prop] = value
	end)
end

local function sanitizeClone(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("LocalScript") or d:IsA("Script") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") or d:IsA("BindableFunction") then
			d:Destroy()
		end
	end
end

local function makePartTemplate()
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.new(1, 1, 1)
	p.Color = Color3.fromRGB(180, 180, 180)
	p.Material = Enum.Material.Plastic
	p.Name = "Part"
	return p
end

local function serializeInstance(inst)
	local data = {Class = inst.ClassName, Name = inst.Name, Props = {}, Children = {}}
	local function put(k, v)
		data.Props[k] = v
	end
	if inst:IsA("BasePart") then
		put("CFrame", {inst.CFrame:GetComponents()})
		put("Size", {inst.Size.X, inst.Size.Y, inst.Size.Z})
		put("Color", {inst.Color.R, inst.Color.G, inst.Color.B})
		put("Transparency", inst.Transparency)
		put("Reflectance", inst.Reflectance)
		put("Anchored", inst.Anchored)
		put("CanCollide", inst.CanCollide)
		put("CanTouch", inst.CanTouch)
		put("CanQuery", inst.CanQuery)
		put("CastShadow", inst.CastShadow)
		put("Material", inst.Material.Name)
		put("MaterialVariant", inst.MaterialVariant or "")
		if inst:IsA("MeshPart") then
			put("MeshId", inst.MeshId)
			put("TextureID", inst.TextureID)
		end
		if inst:IsA("UnionOperation") then
			put("UsePartColor", inst.UsePartColor)
		end
	elseif inst:IsA("Model") then
		put("Pivot", {inst:GetPivot():GetComponents()})
	elseif inst:IsA("Accessory") then
		put("AccessoryType", inst.AccessoryType.Name)
	elseif inst:IsA("Tool") then
		put("RequiresHandle", inst.RequiresHandle)
		put("CanBeDropped", inst.CanBeDropped)
	elseif inst:IsA("Attachment") then
		put("Position", {inst.Position.X, inst.Position.Y, inst.Position.Z})
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		put("Texture", inst.Texture)
		put("Face", inst.Face.Name)
		put("Transparency", inst.Transparency)
	elseif inst:IsA("SpecialMesh") then
		put("MeshId", inst.MeshId)
		put("TextureId", inst.TextureId)
		put("MeshType", inst.MeshType.Name)
		put("Scale", {inst.Scale.X, inst.Scale.Y, inst.Scale.Z})
		put("Offset", {inst.Offset.X, inst.Offset.Y, inst.Offset.Z})
	end
	for _, child in ipairs(inst:GetChildren()) do
		if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder") or child:IsA("Accessory") or child:IsA("Tool") or child:IsA("Attachment") or child:IsA("Decal") or child:IsA("Texture") or child:IsA("SpecialMesh") then
			table.insert(data.Children, serializeInstance(child))
		end
	end
	return data
end

local function deserializeInstance(data)
	local ok, inst = pcall(function()
		return Instance.new(data.Class)
	end)
	if not ok or not inst then
		return nil
	end
	inst.Name = data.Name or data.Class
	local props = data.Props or {}
	if inst:IsA("BasePart") then
		local c = props.CFrame
		if c then
			inst.CFrame = CFrame.new(unpack(c, 1, 12))
		end
		local s = props.Size
		if s then
			inst.Size = Vector3.new(s[1], s[2], s[3])
		end
		local col = props.Color
		if col then
			inst.Color = Color3.new(col[1], col[2], col[3])
		end
		safeSet(inst, "Transparency", props.Transparency)
		safeSet(inst, "Reflectance", props.Reflectance)
		safeSet(inst, "Anchored", props.Anchored)
		safeSet(inst, "CanCollide", props.CanCollide)
		safeSet(inst, "CanTouch", props.CanTouch)
		safeSet(inst, "CanQuery", props.CanQuery)
		safeSet(inst, "CastShadow", props.CastShadow)
		if props.Material then
			pcall(function()
				inst.Material = Enum.Material[props.Material] or inst.Material
			end)
		end
		safeSet(inst, "MaterialVariant", props.MaterialVariant or "")
		if inst:IsA("MeshPart") then
			safeSet(inst, "MeshId", props.MeshId or "")
			safeSet(inst, "TextureID", props.TextureID or "")
		end
		if inst:IsA("UnionOperation") then
			safeSet(inst, "UsePartColor", props.UsePartColor)
		end
	elseif inst:IsA("Model") then
		safeSet(inst, "PrimaryPart", nil)
	elseif inst:IsA("Accessory") then
		pcall(function()
			inst.AccessoryType = Enum.AccessoryType[props.AccessoryType] or inst.AccessoryType
		end)
	elseif inst:IsA("Tool") then
		safeSet(inst, "RequiresHandle", props.RequiresHandle)
		safeSet(inst, "CanBeDropped", props.CanBeDropped)
	elseif inst:IsA("Attachment") then
		local p = props.Position
		if p then
			inst.Position = Vector3.new(p[1], p[2], p[3])
		end
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		safeSet(inst, "Texture", props.Texture or "")
		pcall(function()
			inst.Face = Enum.NormalId[props.Face] or inst.Face
		end)
		safeSet(inst, "Transparency", props.Transparency)
	elseif inst:IsA("SpecialMesh") then
		safeSet(inst, "MeshId", props.MeshId or "")
		safeSet(inst, "TextureId", props.TextureId or "")
		pcall(function()
			inst.MeshType = Enum.MeshType[props.MeshType] or inst.MeshType
		end)
		local sc = props.Scale
		if sc then
			inst.Scale = Vector3.new(sc[1], sc[2], sc[3])
		end
		local of = props.Offset
		if of then
			inst.Offset = Vector3.new(of[1], of[2], of[3])
		end
	end
	for _, childData in ipairs(data.Children or {}) do
		local child = deserializeInstance(childData)
		if child then
			child.Parent = inst
		end
	end
	if inst:IsA("Model") and props.Pivot then
		pcall(function()
			inst:PivotTo(CFrame.new(unpack(props.Pivot, 1, 12)))
		end)
	end
	return inst
end

local function exportState()
	local buildData = {ToolName = BuildMode.ToolName, Snap = BuildMode.Snap, RotateSnap = BuildMode.RotateSnap, ScaleSnap = BuildMode.ScaleSnap, Objects = {}}
	for _, child in ipairs(BuildMode.Root:GetChildren()) do
		if child ~= BuildMode.GizmoRoot then
			table.insert(buildData.Objects, serializeInstance(child))
		end
	end
	return HS:JSONEncode(buildData)
end

local function importState(text)
	local ok, decoded = pcall(function()
		return HS:JSONDecode(text)
	end)
	if not ok or type(decoded) ~= "table" then
		return false, "Invalid code"
	end
	BuildMode.SuppressHistory = true
	for _, child in ipairs(BuildMode.Root:GetChildren()) do
		if child ~= BuildMode.GizmoRoot then
			child:Destroy()
		end
	end
	for _, item in ipairs(decoded.Objects or {}) do
		local inst = deserializeInstance(item)
		if inst then
			inst.Parent = BuildMode.Root
		end
	end
	if decoded.ToolName then
		BuildMode.ToolName = tostring(decoded.ToolName)
	end
	if decoded.Snap then
		BuildMode.Snap = tonumber(decoded.Snap) or BuildMode.Snap
	end
	if decoded.RotateSnap then
		BuildMode.RotateSnap = tonumber(decoded.RotateSnap) or BuildMode.RotateSnap
	end
	if decoded.ScaleSnap then
		BuildMode.ScaleSnap = tonumber(decoded.ScaleSnap) or BuildMode.ScaleSnap
	end
	BuildMode.SuppressHistory = false
	BuildMode.LastSave = text
	return true
end

local function snapshotHistory()
	if BuildMode.SuppressHistory then
		return
	end
	local state = exportState()
	if BuildMode.History[#BuildMode.History] ~= state then
		table.insert(BuildMode.History, state)
		if #BuildMode.History > 30 then
			table.remove(BuildMode.History, 1)
		end
	end
	BuildMode.Redo = {}
end

local function undo()
	if #BuildMode.History < 2 then
		return
	end
	local current = table.remove(BuildMode.History)
	table.insert(BuildMode.Redo, current)
	local previous = BuildMode.History[#BuildMode.History]
	if previous then
		BuildMode.SuppressHistory = true
		importState(previous)
		BuildMode.SuppressHistory = false
	end
end

local function redo()
	local state = table.remove(BuildMode.Redo)
	if not state then
		return
	end
	BuildMode.SuppressHistory = true
	importState(state)
	BuildMode.SuppressHistory = false
	table.insert(BuildMode.History, state)
end

local SelectedBoxes = {}

local function clearSelectedBoxes()
	for _, box in ipairs(SelectedBoxes) do
		if box and box.Parent then
			box:Destroy()
		end
	end
	table.clear(SelectedBoxes)
end

local function selectRoots(roots, additive)
	if not additive then
		BuildMode.Selection = {}
	end
	local seen = {}
	for _, r in ipairs(BuildMode.Selection) do
		seen[r] = true
	end
	for _, root in ipairs(roots) do
		if root and not seen[root] then
			table.insert(BuildMode.Selection, root)
			seen[root] = true
		end
	end
	clearSelectedBoxes()
	for _, root in ipairs(BuildMode.Selection) do
		local box
		if root:IsA("Model") or root:IsA("Accessory") or root:IsA("Tool") or root:IsA("Folder") then
			box = Instance.new("SelectionBox")
			box.LineThickness = 0.05
			box.Color3 = Color3.fromRGB(0, 170, 255)
			box.SurfaceTransparency = 0.85
			box.Adornee = root
			box.Parent = BuildMode.GizmoRoot
		elseif root:IsA("BasePart") then
			box = Instance.new("SelectionBox")
			box.LineThickness = 0.05
			box.Color3 = Color3.fromRGB(0, 170, 255)
			box.SurfaceTransparency = 0.85
			box.Adornee = root
			box.Parent = BuildMode.GizmoRoot
		end
		if box then
			table.insert(SelectedBoxes, box)
		end
	end
	GizmoSystem.UpdateGizmo(BuildMode.Selection)
end

local function isBuildObject(inst)
	return inst and inst:IsDescendantOf(BuildMode.Root) and inst ~= BuildMode.Root and inst ~= BuildMode.GizmoRoot
end

local function getSelectionRoot(inst)
	if not isBuildObject(inst) then
		return nil
	end
	local current = inst
	while current and current.Parent and current.Parent ~= BuildMode.Root do
		current = current.Parent
	end
	return current
end

local function trySelectTarget(target, additive)
	local root = getSelectionRoot(target)
	if root then
		selectRoots({root}, additive)
		return true
	end
	return false
end

local function refreshExplorer()
	for _, child in ipairs(InspectorScroll:GetChildren()) do
		if child:IsA("Frame") and child.Name == "ExplorerRow" then
			child:Destroy()
		end
	end
	local header = create("TextLabel", {Name = "ExplorerRow", Size = UDim2.new(1,0,0,22), BackgroundTransparency = 1, Text = "Current Build", TextColor3 = Color3.fromRGB(220,220,230), Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1}, InspectorScroll)
	local list = create("ScrollingFrame", {Name = "ExplorerRow", Size = UDim2.new(1,0,0,150), BackgroundColor3 = Color3.fromRGB(32,32,38), BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0,0,0,0), LayoutOrder = 2}, InspectorScroll)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, list)
	local lay = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,4)}, list)
	local function addRow(text, cb)
		local btn = create("TextButton", {Size = UDim2.new(1,-8,0,24), Position = UDim2.new(0,4,0,0), BackgroundColor3 = Color3.fromRGB(45,45,52), Text = text, TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, list)
		create("UICorner", {CornerRadius = UDim.new(0,5)}, btn)
		table.insert(Connections, btn.MouseButton1Click:Connect(cb))
	end
	for _, child in ipairs(BuildMode.Root:GetChildren()) do
		if child ~= BuildMode.GizmoRoot then
			addRow(child.Name .. " [" .. child.ClassName .. "]", function()
				selectRoots({child}, false)
				refreshInspector()
			end)
		end
	end
	list.CanvasSize = UDim2.new(0,0,0, lay.AbsoluteContentSize.Y + 8)
end

function refreshInspector()
	for _, c in ipairs(InspectorScroll:GetChildren()) do
		if c:IsA("GuiObject") and c.Name ~= "MaterialPicker" and c.Name ~= "ExplorerRow" then
			c:Destroy()
		end
	end
	refreshExplorer()
	local root = BuildMode.Selection[1]
	local title = create("TextLabel", {Size = UDim2.new(1,0,0,22), BackgroundTransparency = 1, Text = root and (root.Name .. " [" .. root.ClassName .. "]") or "No selection", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 10}, InspectorScroll)
	createRow(InspectorScroll, "Name", root and root.Name or "", function(v)
		if root then
			root.Name = v
			refreshExplorer()
		end
	end, 11)
	createRow(InspectorScroll, "Tool Name", BuildMode.ToolName, function(v)
		BuildMode.ToolName = v
	end, 12)
	createRow(InspectorScroll, "Snap", tostring(BuildMode.Snap), function(v)
		SnapBox.Text = "Snap " .. (tonumber(v) or BuildMode.Snap)
		readSnapBoxes()
	end, 13)
	createRow(InspectorScroll, "Rotate", tostring(BuildMode.RotateSnap), function(v)
		RotateSnapBox.Text = "Rot " .. (tonumber(v) or BuildMode.RotateSnap)
		readSnapBoxes()
	end, 14)
	createRow(InspectorScroll, "Scale", tostring(BuildMode.ScaleSnap), function(v)
		ScaleSnapBox.Text = "Scale " .. (tonumber(v) or BuildMode.ScaleSnap)
		readSnapBoxes()
	end, 15)
	if root and root:IsA("BasePart") then
		createRow(InspectorScroll, "Pos X", tostring(math.round(root.Position.X * 100) / 100), function(v)
			local n = tonumber(v)
			if n then
				root.CFrame = CFrame.new(n, root.Position.Y, root.Position.Z) * (root.CFrame - root.CFrame.Position)
				snapshotHistory()
				selectRoots({root}, false)
			end
		end, 20)
		createRow(InspectorScroll, "Pos Y", tostring(math.round(root.Position.Y * 100) / 100), function(v)
			local n = tonumber(v)
			if n then
				root.CFrame = CFrame.new(root.Position.X, n, root.Position.Z) * (root.CFrame - root.CFrame.Position)
				snapshotHistory()
				selectRoots({root}, false)
			end
		end, 21)
		createRow(InspectorScroll, "Pos Z", tostring(math.round(root.Position.Z * 100) / 100), function(v)
			local n = tonumber(v)
			if n then
				root.CFrame = CFrame.new(root.Position.X, root.Position.Y, n) * (root.CFrame - root.CFrame.Position)
				snapshotHistory()
				selectRoots({root}, false)
			end
		end, 22)
		createRow(InspectorScroll, "Size X", tostring(root.Size.X), function(v)
			local n = tonumber(v)
			if n then
				root.Size = Vector3.new(math.max(0.05, n), root.Size.Y, root.Size.Z)
				snapshotHistory()
			end
		end, 23)
		createRow(InspectorScroll, "Size Y", tostring(root.Size.Y), function(v)
			local n = tonumber(v)
			if n then
				root.Size = Vector3.new(root.Size.X, math.max(0.05, n), root.Size.Z)
				snapshotHistory()
			end
		end, 24)
		createRow(InspectorScroll, "Size Z", tostring(root.Size.Z), function(v)
			local n = tonumber(v)
			if n then
				root.Size = Vector3.new(root.Size.X, root.Size.Y, math.max(0.05, n))
				snapshotHistory()
			end
		end, 25)
		createRow(InspectorScroll, "R", tostring(math.floor(root.Color.R * 255)), function(v)
			local r = tonumber(v)
			if r then
				root.Color = Color3.fromRGB(math.clamp(r, 0, 255), math.floor(root.Color.G * 255), math.floor(root.Color.B * 255))
			end
		end, 26)
		createRow(InspectorScroll, "G", tostring(math.floor(root.Color.G * 255)), function(v)
			local g = tonumber(v)
			if g then
				root.Color = Color3.fromRGB(math.floor(root.Color.R * 255), math.clamp(g, 0, 255), math.floor(root.Color.B * 255))
			end
		end, 27)
		createRow(InspectorScroll, "B", tostring(math.floor(root.Color.B * 255)), function(v)
			local b = tonumber(v)
			if b then
				root.Color = Color3.fromRGB(math.floor(root.Color.R * 255), math.floor(root.Color.G * 255), math.clamp(b, 0, 255))
			end
		end, 28)
		createRow(InspectorScroll, "Transparency", tostring(root.Transparency), function(v)
			local n = tonumber(v)
			if n then
				root.Transparency = math.clamp(n, 0, 1)
			end
		end, 29)
		createRow(InspectorScroll, "Reflectance", tostring(root.Reflectance), function(v)
			local n = tonumber(v)
			if n then
				root.Reflectance = math.clamp(n, 0, 1)
			end
		end, 30)
		createRow(InspectorScroll, "Material", root.Material.Name, function(v)
			local mt = Enum.Material[v]
			if mt then
				root.Material = mt
			end
		end, 31)
		createRow(InspectorScroll, "Variant", root.MaterialVariant or "", function(v)
			pcall(function()
				root.MaterialVariant = v
			end)
		end, 32)
		createButton(InspectorScroll, "Anchored: " .. tostring(root.Anchored), Color3.fromRGB(50,90,180), Color3.fromRGB(70,120,220), function()
			root.Anchored = not root.Anchored
			refreshInspector()
		end)
		createButton(InspectorScroll, "Collidable: " .. tostring(root.CanCollide), Color3.fromRGB(50,90,180), Color3.fromRGB(70,120,220), function()
			root.CanCollide = not root.CanCollide
			refreshInspector()
		end)
		createButton(InspectorScroll, "Can Query: " .. tostring(root.CanQuery), Color3.fromRGB(50,90,180), Color3.fromRGB(70,120,220), function()
			root.CanQuery = not root.CanQuery
			refreshInspector()
		end)
		createButton(InspectorScroll, "Can Touch: " .. tostring(root.CanTouch), Color3.fromRGB(50,90,180), Color3.fromRGB(70,120,220), function()
			root.CanTouch = not root.CanTouch
			refreshInspector()
		end)
	end
	createButton(InspectorScroll, "Duplicate", Color3.fromRGB(60,120,220), Color3.fromRGB(80,150,245), function()
		local clones = {}
		for _, sel in ipairs(BuildMode.Selection) do
			local clone = sel:Clone()
			sanitizeClone(clone)
			clone.Parent = BuildMode.Root
			if clone:IsA("Model") or clone:IsA("Accessory") or clone:IsA("Tool") or clone:IsA("Folder") then
				clone:PivotTo(sel:GetPivot() * CFrame.new(BuildMode.Snap * 4, 0, 0))
			elseif clone:IsA("BasePart") then
				clone.CFrame = sel.CFrame * CFrame.new(BuildMode.Snap * 4, 0, 0)
			end
			table.insert(clones, clone)
		end
		selectRoots(clones, false)
		snapshotHistory()
		refreshInspector()
	end)
	createButton(InspectorScroll, "Delete", Color3.fromRGB(200,60,60), Color3.fromRGB(230,80,80), function()
		for _, sel in ipairs(BuildMode.Selection) do
			if sel and sel.Parent then
				sel:Destroy()
			end
		end
		BuildMode.Selection = {}
		clearSelectedBoxes()
		snapshotHistory()
		refreshInspector()
	end)
	createButton(InspectorScroll, "Group", Color3.fromRGB(90,140,70), Color3.fromRGB(120,170,90), function()
		if #BuildMode.Selection < 2 then
			return
		end
		local group = Instance.new("Model")
		group.Name = "Group"
		group.Parent = BuildMode.Root
		local center = getSelectionCenter()
		for _, sel in ipairs(BuildMode.Selection) do
			sel.Parent = group
		end
		pcall(function()
			group:PivotTo(CFrame.new(center))
		end)
		selectRoots({group}, false)
		snapshotHistory()
		refreshInspector()
	end)
	createButton(InspectorScroll, "Ungroup", Color3.fromRGB(90,140,70), Color3.fromRGB(120,170,90), function()
		local root = BuildMode.Selection[1]
		if not root or not root:IsA("Model") then
			return
		end
		local parent = root.Parent
		for _, child in ipairs(root:GetChildren()) do
			child.Parent = parent
		end
		root:Destroy()
		BuildMode.Selection = {}
		snapshotHistory()
		refreshInspector()
	end)
	createButton(InspectorScroll, "Save Handle Preset", Color3.fromRGB(160,100,220), Color3.fromRGB(190,130,245), function()
		local root = BuildMode.Selection[1]
		if root then
			BuildMode.HandlePreset = serializeInstance(root)
		end
	end)
	createButton(InspectorScroll, "Spawn Handle Preset", Color3.fromRGB(160,100,220), Color3.fromRGB(190,130,245), function()
		if BuildMode.HandlePreset then
			local inst = deserializeInstance(BuildMode.HandlePreset)
			if inst then
				inst.Parent = BuildMode.Root
				if inst:IsA("Model") or inst:IsA("Tool") or inst:IsA("Accessory") or inst:IsA("Folder") then
					inst:PivotTo(CFrame.new(getSelectionCenter()))
				elseif inst:IsA("BasePart") then
					inst.CFrame = CFrame.new(getSelectionCenter())
				end
				selectRoots({inst}, false)
				snapshotHistory()
				refreshInspector()
			end
		end
	end)
	MaterialPicker.Render(InspectorScroll, root)
	InspectorScroll.CanvasSize = UDim2.new(0,0,0, InspectorLayout.AbsoluteContentSize.Y + 8)
end

local function getRaycastParams()
	local params = RaycastParams.new()
	local blacklist = {BuildMode.Root, BuildMode.GizmoRoot, Players.LocalPlayer.Character}
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = blacklist
	params.IgnoreWater = true
	return params
end

local function getMouseHit()
	local x, y = UIS:GetMouseLocation().X, UIS:GetMouseLocation().Y
	local ray = Camera:ViewportPointToRay(x, y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, getRaycastParams())
	if result then
		return result.Position, result.Instance
	end
	return ray.Origin + ray.Direction * 100, nil
end

local CharacterLTM = {}
local function setCharacterInvisible(flag)
	local char = Players.LocalPlayer.Character
	if not char then
		return
	end
	if flag then
		table.clear(CharacterLTM)
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				CharacterLTM[d] = d.LocalTransparencyModifier
				d.LocalTransparencyModifier = 1
			elseif d:IsA("Decal") then
				CharacterLTM[d] = d.Transparency
				d.Transparency = 1
			end
		end
	else
		for inst, val in pairs(CharacterLTM) do
			if inst and inst.Parent then
				if inst:IsA("BasePart") then
					inst.LocalTransparencyModifier = val or 0
				elseif inst:IsA("Decal") then
					inst.Transparency = val or 0
				end
			end
		end
		table.clear(CharacterLTM)
	end
end

local originalCamType, originalCamSubject, originalCamCFrame, originalMouseBehavior
local freecamConn
local freecamLook = Vector2.new()
local freecamKeys = {W = false, A = false, S = false, D = false, Q = false, E = false, Shift = false}
local freecamRightDown = false
local freecamSpeed = 48

local function startFreecam()
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CameraSubject = nil
	freecamLook = Vector2.new(0,0)
	table.insert(Connections, UIS.InputBegan:Connect(function(inp, gp)
		if not BuildMode.Active then return end
		if inp.UserInputType == Enum.UserInputType.Keyboard then
			if freecamKeys[inp.KeyCode.Name] ~= nil then
				freecamKeys[inp.KeyCode.Name] = true
			end
			if inp.KeyCode == Enum.KeyCode.LeftShift or inp.KeyCode == Enum.KeyCode.RightShift then
				freecamKeys.Shift = true
			end
		elseif inp.UserInputType == Enum.UserInputType.MouseButton2 then
			freecamRightDown = true
			UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end))
	table.insert(Connections, UIS.InputEnded:Connect(function(inp)
		if not BuildMode.Active then return end
		if inp.UserInputType == Enum.UserInputType.Keyboard then
			if freecamKeys[inp.KeyCode.Name] ~= nil then
				freecamKeys[inp.KeyCode.Name] = false
			end
			if inp.KeyCode == Enum.KeyCode.LeftShift or inp.KeyCode == Enum.KeyCode.RightShift then
				freecamKeys.Shift = false
			end
		elseif inp.UserInputType == Enum.UserInputType.MouseButton2 then
			freecamRightDown = false
			UIS.MouseBehavior = Enum.MouseBehavior.Default
		end
	end))
	table.insert(Connections, UIS.InputChanged:Connect(function(inp)
		if not BuildMode.Active then return end
		if freecamRightDown and inp.UserInputType == Enum.UserInputType.MouseMovement then
			freecamLook = freecamLook + Vector2.new(-inp.Delta.Y, -inp.Delta.X) * 0.003
			freecamLook = Vector2.new(math.clamp(freecamLook.X, -1.45, 1.45), freecamLook.Y)
		end
	end))
	if freecamConn then freecamConn:Disconnect() end
	freecamConn = RS.RenderStepped:Connect(function(dt)
		if not BuildMode.Active then return end
		local rot = CFrame.fromOrientation(freecamLook.X, freecamLook.Y, 0)
		local move = Vector3.zero
		if freecamKeys.W then move += Vector3.new(0,0,-1) end
		if freecamKeys.S then move += Vector3.new(0,0,1) end
		if freecamKeys.A then move += Vector3.new(-1,0,0) end
		if freecamKeys.D then move += Vector3.new(1,0,0) end
		if freecamKeys.E then move += Vector3.new(0,1,0) end
		if freecamKeys.Q then move += Vector3.new(0,-1,0) end
		if move.Magnitude > 0 then move = move.Unit end
		local speed = freecamSpeed * (freecamKeys.Shift and 2.5 or 1)
		Camera.CFrame = Camera.CFrame + (Camera.CFrame:VectorToWorldSpace(move) * speed * dt)
		Camera.CFrame = CFrame.new(Camera.CFrame.Position) * rot
	end)
end

local function stopFreecam()
	if freecamConn then
		freecamConn:Disconnect()
		freecamConn = nil
	end
	UIS.MouseBehavior = originalMouseBehavior
	Camera.CameraType = originalCamType
	Camera.CameraSubject = originalCamSubject
	Camera.CFrame = originalCamCFrame
end

local function ensureBuildRoot()
	if BuildMode.Root and BuildMode.Root.Parent then
		return BuildMode.Root
	end
	local folder = Instance.new("Folder")
	folder.Name = "__LocalBuildRoot"
	folder.Parent = Workspace
	BuildMode.Root = folder
	local giz = Instance.new("Folder")
	giz.Name = "__LocalBuildSession"
	giz.Parent = folder
	BuildMode.GizmoRoot = giz
	GizmoSystem.SetGizmoRoot(giz)
	return folder
end

local function placeInitialHandle()
	local pos = Camera.CFrame.Position + Camera.CFrame.LookVector * 12
	local ray = Workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * 200, getRaycastParams())
	if ray then
		pos = ray.Position + Vector3.new(0,4,0)
	end
	GizmoSystem.PlaceHandle(CFrame.new(pos))
end

local function loadLastSession()
	if BuildMode.LastSave then
		importState(BuildMode.LastSave)
	end
	if #BuildMode.Root:GetChildren() == 0 then
		local p = makePartTemplate()
		p.Parent = BuildMode.Root
		p.CFrame = GizmoSystem.GetHandleCFrame()
	end
end

local function beginAutosave()
	BuildMode.AutosaveToken += 1
	local token = BuildMode.AutosaveToken
	task.spawn(function()
		while BuildMode.Active and BuildMode.AutosaveToken == token do
			task.wait(180)
			if BuildMode.Active and BuildMode.AutosaveToken == token then
				BuildMode.LastSave = exportState()
			end
		end
	end)
end

local function exitBuildMode()
	if not BuildMode.Active then return end
	BuildMode.LastSave = exportState()
	BuildMode.Active = false
	BuildMode.AutosaveToken += 1
	BuildModeGui.Enabled = false
	setCharacterInvisible(false)
	stopFreecam()
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	clearSelectedBoxes()
	GizmoSystem.Hide()
end

local BuildModeGui, BuildTopBar, BuildLeftPanel, BuildRightPanel, BuildBottomBar
local BuildTitle, ExitBuildBtn, ModeMoveBtn, ModeRotateBtn, ModeScaleBtn, ModeSelectBtn
local SnapBox, RotateSnapBox, ScaleSnapBox
local BrowserTitle, BrowserSearchBox, BrowserRefreshBtn, BrowserAddPartBtn, BrowserScroll, BrowserLayout
local InspectorTitle, InspectorScroll, InspectorLayout
local BottomInfo

local function buildUI()
	BuildModeGui = create("ScreenGui", {Name = "BuildModeGui", ResetOnSpawn = false, IgnoreGuiInset = false}, UI_PARENT)
	BuildTopBar = create("Frame", {Size = UDim2.new(1,0,0,44), BackgroundColor3 = Color3.fromRGB(20,20,25), BorderSizePixel = 0}, BuildModeGui)
	BuildLeftPanel = create("Frame", {Size = UDim2.new(0,320,1,-84), Position = UDim2.new(0,0,0,44), BackgroundColor3 = Color3.fromRGB(24,24,30), BorderSizePixel = 0}, BuildModeGui)
	BuildRightPanel = create("Frame", {Size = UDim2.new(0,320,1,-84), Position = UDim2.new(1,-320,0,44), BackgroundColor3 = Color3.fromRGB(24,24,30), BorderSizePixel = 0}, BuildModeGui)
	BuildBottomBar = create("Frame", {Size = UDim2.new(1,0,0,40), Position = UDim2.new(0,0,1,-40), BackgroundColor3 = Color3.fromRGB(20,20,25), BorderSizePixel = 0}, BuildModeGui)
	BuildTitle = create("TextLabel", {Size = UDim2.new(0,280,1,0), Position = UDim2.new(0,12,0,0), BackgroundTransparency = 1, Text = "Build Mode", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left}, BuildTopBar)
	ExitBuildBtn = create("TextButton", {Size = UDim2.new(0,110,0,30), Position = UDim2.new(1,-120,0,7), BackgroundColor3 = Color3.fromRGB(200,60,60), Text = "Exit", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 14}, BuildTopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, ExitBuildBtn)
	ModeMoveBtn = create("TextButton", {Size = UDim2.new(0,70,0,28), Position = UDim2.new(0,12,0,8), BackgroundColor3 = Color3.fromRGB(50,120,220), Text = "Move", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12}, BuildTopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, ModeMoveBtn)
	ModeRotateBtn = create("TextButton", {Size = UDim2.new(0,70,0,28), Position = UDim2.new(0,88,0,8), BackgroundColor3 = Color3.fromRGB(60,60,70), Text = "Rotate", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12}, BuildTopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, ModeRotateBtn)
	ModeScaleBtn = create("TextButton", {Size = UDim2.new(0,70,0,28), Position = UDim2.new(0,164,0,8), BackgroundColor3 = Color3.fromRGB(60,60,70), Text = "Scale", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12}, BuildTopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, ModeScaleBtn)
	ModeSelectBtn = create("TextButton", {Size = UDim2.new(0,70,0,28), Position = UDim2.new(0,240,0,8), BackgroundColor3 = Color3.fromRGB(60,60,70), Text = "Select", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12}, BuildTopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, ModeSelectBtn)
	SnapBox = create("TextBox", {Size = UDim2.new(0,90,0,26), Position = UDim2.new(0,330,0,9), BackgroundColor3 = Color3.fromRGB(35,35,42), TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, Text = "Snap 1"}, BuildTopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, SnapBox)
	RotateSnapBox = create("TextBox", {Size = UDim2.new(0,100,0,26), Position = UDim2.new(0,430,0,9), BackgroundColor3 = Color3.fromRGB(35,35,42), TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, Text = "Rot 15"}, BuildTopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, RotateSnapBox)
	ScaleSnapBox = create("TextBox", {Size = UDim2.new(0,100,0,26), Position = UDim2.new(0,540,0,9), BackgroundColor3 = Color3.fromRGB(35,35,42), TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, Text = "Scale .25"}, BuildTopBar)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, ScaleSnapBox)
	BrowserTitle = create("TextLabel", {Size = UDim2.new(1,-20,0,24), Position = UDim2.new(0,10,0,8), BackgroundTransparency = 1, Text = "Object Browser", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, BuildLeftPanel)
	BrowserSearchBox = create("TextBox", {Size = UDim2.new(1,-20,0,28), Position = UDim2.new(0,10,0,38), BackgroundColor3 = Color3.fromRGB(35,35,42), TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, Text = ""}, BuildLeftPanel)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, BrowserSearchBox)
	BrowserRefreshBtn = create("TextButton", {Size = UDim2.new(0.5,-15,0,28), Position = UDim2.new(0,10,0,72), BackgroundColor3 = Color3.fromRGB(45,140,220), Text = "Refresh Scan", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12}, BuildLeftPanel)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, BrowserRefreshBtn)
	BrowserAddPartBtn = create("TextButton", {Size = UDim2.new(0.5,-15,0,28), Position = UDim2.new(0.5,5,0,72), BackgroundColor3 = Color3.fromRGB(50,170,90), Text = "Add Part", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12}, BuildLeftPanel)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, BrowserAddPartBtn)
	BrowserScroll = create("ScrollingFrame", {Size = UDim2.new(1,-20,1,-118), Position = UDim2.new(0,10,0,110), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0,0,0,0)}, BuildLeftPanel)
	BrowserLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6)}, BrowserScroll)
	create("UIPadding", {PaddingTop = UDim.new(0,2), PaddingBottom = UDim.new(0,8)}, BrowserScroll)
	InspectorTitle = create("TextLabel", {Size = UDim2.new(1,-20,0,24), Position = UDim2.new(0,10,0,8), BackgroundTransparency = 1, Text = "Properties", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, BuildRightPanel)
	InspectorScroll = create("ScrollingFrame", {Size = UDim2.new(1,-20,1,-50), Position = UDim2.new(0,10,0,38), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0,0,0,0)}, BuildRightPanel)
	InspectorLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6)}, InspectorScroll)
	create("UIPadding", {PaddingTop = UDim.new(0,2), PaddingBottom = UDim.new(0,8)}, InspectorScroll)
	BottomInfo = create("TextLabel", {Size = UDim2.new(1,-20,1,0), Position = UDim2.new(0,10,0,0), BackgroundTransparency = 1, Text = "LMB select, drag to move. 1 Move, 2 Rotate, 3 Scale, Ctrl multi-select, Del delete, Ctrl+D duplicate, Ctrl+G group, Ctrl+Shift+G ungroup, Ctrl+Z undo, Ctrl+Y redo", TextColor3 = Color3.fromRGB(220,220,220), Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left}, BuildBottomBar)
end

local function createRow(parent, label, defaultText, callback, y)
	local row = create("Frame", {Size = UDim2.new(1,-8,0,28), BackgroundTransparency = 1, LayoutOrder = y or 0}, parent)
	local lab = create("TextLabel", {Size = UDim2.new(0.38,0,1,0), BackgroundTransparency = 1, Text = label, TextColor3 = Color3.fromRGB(230,230,230), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, row)
	local box = create("TextBox", {Size = UDim2.new(0.62,0,1,0), Position = UDim2.new(0.38,0,0,0), BackgroundColor3 = Color3.fromRGB(35,35,42), TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false, Text = tostring(defaultText or "")}, row)
	create("UICorner", {CornerRadius = UDim.new(0,5)}, box)
	table.insert(Connections, box.FocusLost:Connect(function()
		callback(box.Text)
	end))
	return row, box
end

local function createButton(parent, text, color, hover, callback)
	local btn = create("TextButton", {Size = UDim2.new(1,0,0,28), BackgroundColor3 = color, Text = text, TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 12}, parent)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, btn)
	addHoverEffect(btn, color, hover)
	table.insert(Connections, btn.MouseButton1Click:Connect(callback))
	return btn
end

local function refreshBrowser()
	for _, child in ipairs(BrowserScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	BrowserTree.Render(BrowserScroll, BuildMode.Root, function(inst)
		local clone = inst:Clone()
		sanitizeClone(clone)
		clone.Parent = BuildMode.Root
		local place = GizmoSystem.GetHandleCFrame()
		if clone:IsA("Model") or clone:IsA("Accessory") or clone:IsA("Tool") or clone:IsA("Folder") then
			clone:PivotTo(place)
		elseif clone:IsA("BasePart") then
			clone.CFrame = place
		end
		selectRoots({clone}, false)
		snapshotHistory()
		refreshInspector()
	end)
	local addPart = create("TextButton", {Size = UDim2.new(1,0,0,26), BackgroundColor3 = Color3.fromRGB(50,170,90), Text = "Basic Part", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, BrowserScroll)
	create("UICorner", {CornerRadius = UDim.new(0,5)}, addPart)
	table.insert(Connections, addPart.MouseButton1Click:Connect(function()
		local p = makePartTemplate()
		p.Parent = BuildMode.Root
		p.CFrame = GizmoSystem.GetHandleCFrame()
		selectRoots({p}, false)
		snapshotHistory()
		refreshInspector()
	end))
	BrowserScroll.CanvasSize = UDim2.new(0,0,0, BrowserLayout.AbsoluteContentSize.Y + 8)
end

local function beginDrag(action, mouseHit)
	if #BuildMode.Selection == 0 then return end
	BuildMode.Drag.Active = true
	BuildMode.Drag.Type = action
	BuildMode.Drag.StartPoint = mouseHit
	BuildMode.Drag.StartCenter = getSelectionCenter()
	BuildMode.Drag.StartTransforms = {}
	BuildMode.Drag.StartScale = {}
	BuildMode.Drag.StartYaw = {}
	for _, root in ipairs(BuildMode.Selection) do
		local info = {}
		if root:IsA("BasePart") then
			info.Pivot = root.CFrame
			info.IsPart = true
			info.Parts = {{Part = root, Size = root.Size, CFrame = root.CFrame}}
		else
			info.Pivot = root:GetPivot()
			info.IsPart = false
			info.Parts = {}
			for _, part in ipairs(gatherParts(root, {})) do
				table.insert(info.Parts, {Part = part, Size = part.Size, CFrame = part.CFrame})
			end
		end
		table.insert(BuildMode.Drag.StartTransforms, {Root = root, Info = info})
	end
end

local function applyMove(delta)
	for _, entry in ipairs(BuildMode.Drag.StartTransforms) do
		local root = entry.Root
		local info = entry.Info
		local start = info.Pivot
		local cf = CFrame.new(start.Position + delta) * (start - start.Position)
		if info.IsPart and root:IsA("BasePart") then
			root.CFrame = cf
		elseif root:IsA("Model") or root:IsA("Accessory") or root:IsA("Tool") or root:IsA("Folder") then
			pcall(function() root:PivotTo(cf) end)
		elseif root:IsA("BasePart") then
			root.CFrame = cf
		end
	end
end

local function applyRotate(deltaYaw)
	local center = BuildMode.Drag.StartCenter
	for _, entry in ipairs(BuildMode.Drag.StartTransforms) do
		local root = entry.Root
		local info = entry.Info
		local start = info.Pivot
		local rel = start.Position - center
		local rot = CFrame.Angles(0, deltaYaw, 0)
		local newPos = center + rot:VectorToWorldSpace(rel)
		local newCf = CFrame.new(newPos) * (rot * (start - start.Position))
		if info.IsPart and root:IsA("BasePart") then
			root.CFrame = newCf
		elseif root:IsA("Model") or root:IsA("Accessory") or root:IsA("Tool") or root:IsA("Folder") then
			pcall(function() root:PivotTo(newCf) end)
		elseif root:IsA("BasePart") then
			root.CFrame = newCf
		end
	end
end

local function applyScale(scaleFactor)
	scaleFactor = math.max(0.05, scaleFactor)
	local center = BuildMode.Drag.StartCenter
	for _, entry in ipairs(BuildMode.Drag.StartTransforms) do
		local root = entry.Root
		local info = entry.Info
		if info.IsPart and root:IsA("BasePart") then
			local startPart = info.Parts[1]
			root.Size = startPart.Size * scaleFactor
			local rel = startPart.CFrame.Position - center
			root.CFrame = CFrame.new(center + rel * scaleFactor) * (startPart.CFrame - startPart.CFrame.Position)
		else
			for _, partInfo in ipairs(info.Parts) do
				local part = partInfo.Part
				if part and part.Parent then
					part.Size = partInfo.Size * scaleFactor
					local rel = partInfo.CFrame.Position - center
					part.CFrame = CFrame.new(center + rel * scaleFactor) * (partInfo.CFrame - partInfo.CFrame.Position)
				end
			end
			if root:IsA("Model") or root:IsA("Accessory") or root:IsA("Tool") or root:IsA("Folder") then
				pcall(function() root:PivotTo(CFrame.new(center)) end)
			end
		end
	end
end

local function commitDrag()
	if BuildMode.Drag.Active then
		BuildMode.Drag.Active = false
		BuildMode.Drag.Type = nil
		BuildMode.Drag.StartPoint = nil
		BuildMode.Drag.StartCenter = nil
		BuildMode.Drag.StartTransforms = nil
		snapshotHistory()
		refreshInspector()
	end
end

local function startGizmoDrag(axis, mode)
	if #BuildMode.Selection == 0 then return end
	local center = getSelectionCenter()
	local startMouse = getMouseHit()
	beginDrag(mode, startMouse)
end

GizmoSystem.OnDragBegan = function(axis, mode)
	startGizmoDrag(axis, mode)
end

GizmoSystem.OnDragUpdate = function(axis, mode, delta)
	if not BuildMode.Drag.Active then return end
	if mode == "Move" then
		local deltaVec = Vector3.new(0,0,0)
		if axis == "X" then deltaVec = Vector3.new(delta, 0, 0)
		elseif axis == "Y" then deltaVec = Vector3.new(0, delta, 0)
		elseif axis == "Z" then deltaVec = Vector3.new(0, 0, delta) end
		deltaVec = snapVector(deltaVec, BuildMode.Snap)
		applyMove(deltaVec)
	elseif mode == "Rotate" then
		applyRotate(delta)
	elseif mode == "Scale" then
		applyScale(delta)
	end
	GizmoSystem.UpdateGizmo(BuildMode.Selection)
end

GizmoSystem.OnDragEnded = function()
	commitDrag()
end

local function wireEvents()
	table.insert(Connections, BrowserSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		BuildMode.BrowserSearch = BrowserSearchBox.Text
		refreshBrowser()
	end))
	table.insert(Connections, BrowserRefreshBtn.MouseButton1Click:Connect(refreshBrowser))
	table.insert(Connections, BrowserAddPartBtn.MouseButton1Click:Connect(function()
		local p = makePartTemplate()
		p.Parent = BuildMode.Root
		p.CFrame = GizmoSystem.GetHandleCFrame()
		selectRoots({p}, false)
		snapshotHistory()
		refreshInspector()
	end))
	table.insert(Connections, ModeMoveBtn.MouseButton1Click:Connect(function() setActiveMode("Move") end))
	table.insert(Connections, ModeRotateBtn.MouseButton1Click:Connect(function() setActiveMode("Rotate") end))
	table.insert(Connections, ModeScaleBtn.MouseButton1Click:Connect(function() setActiveMode("Scale") end))
	table.insert(Connections, ModeSelectBtn.MouseButton1Click:Connect(function() setActiveMode("Select") end))
	table.insert(Connections, SnapBox.FocusLost:Connect(readSnapBoxes))
	table.insert(Connections, RotateSnapBox.FocusLost:Connect(readSnapBoxes))
	table.insert(Connections, ScaleSnapBox.FocusLost:Connect(readSnapBoxes))
	table.insert(Connections, ExitBuildBtn.MouseButton1Click:Connect(exitBuildMode))
	table.insert(Connections, UIS.InputBegan:Connect(function(inp, gp)
		if gp or not BuildMode.Active then return end
		if inp.KeyCode == Enum.KeyCode.One then setActiveMode("Move")
		elseif inp.KeyCode == Enum.KeyCode.Two then setActiveMode("Rotate")
		elseif inp.KeyCode == Enum.KeyCode.Three then setActiveMode("Scale")
		elseif inp.KeyCode == Enum.KeyCode.Four then setActiveMode("Select")
		elseif inp.KeyCode == Enum.KeyCode.Delete or inp.KeyCode == Enum.KeyCode.Backspace then
			for _, sel in ipairs(BuildMode.Selection) do
				if sel and sel.Parent then sel:Destroy() end
			end
			BuildMode.Selection = {}
			clearSelectedBoxes()
			snapshotHistory()
			refreshInspector()
		elseif inp.KeyCode == Enum.KeyCode.Z and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			undo()
			refreshInspector()
		elseif inp.KeyCode == Enum.KeyCode.Y and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			redo()
			refreshInspector()
		elseif inp.KeyCode == Enum.KeyCode.D and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			local clones = {}
			for _, sel in ipairs(BuildMode.Selection) do
				local c = sel:Clone()
				sanitizeClone(c)
				c.Parent = BuildMode.Root
				if c:IsA("Model") or c:IsA("Accessory") or c:IsA("Tool") or c:IsA("Folder") then
					c:PivotTo(sel:GetPivot() * CFrame.new(BuildMode.Snap * 4, 0, 0))
				elseif c:IsA("BasePart") then
					c.CFrame = sel.CFrame * CFrame.new(BuildMode.Snap * 4, 0, 0)
				end
				table.insert(clones, c)
			end
			selectRoots(clones, false)
			snapshotHistory()
			refreshInspector()
		elseif inp.KeyCode == Enum.KeyCode.G and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
				local root = BuildMode.Selection[1]
				if root and root:IsA("Model") then
					local parent = root.Parent
					for _, child in ipairs(root:GetChildren()) do child.Parent = parent end
					root:Destroy()
					BuildMode.Selection = {}
					snapshotHistory()
					refreshInspector()
				end
			else
				if #BuildMode.Selection > 1 then
					local group = Instance.new("Model")
					group.Name = "Group"
					group.Parent = BuildMode.Root
					local center = getSelectionCenter()
					for _, sel in ipairs(BuildMode.Selection) do sel.Parent = group end
					pcall(function() group:PivotTo(CFrame.new(center)) end)
					selectRoots({group}, false)
					snapshotHistory()
					refreshInspector()
				end
			end
		elseif inp.KeyCode == Enum.KeyCode.S and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			BuildMode.LastSave = exportState()
			BuildModeGui.Enabled = true
		elseif inp.KeyCode == Enum.KeyCode.E and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			refreshInspector()
		elseif inp.KeyCode == Enum.KeyCode.O and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			if BuildMode.LastSave then
				importState(BuildMode.LastSave)
				refreshInspector()
			end
		end
	end))
	table.insert(Connections, UIS.InputEnded:Connect(function(inp, gp)
		if not BuildMode.Active then return end
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			commitDrag()
		end
	end))
	table.insert(Connections, UIS.InputChanged:Connect(function(inp, gp)
		if not BuildMode.Active then return end
		if BuildMode.Drag.Active then
			if inp.UserInputType == Enum.UserInputType.MouseMovement then
				local pos = getMouseHit()
				local delta = pos - BuildMode.Drag.StartPoint
				if BuildMode.Drag.Type == "Move" then
					delta = snapVector(delta, BuildMode.Snap)
					applyMove(delta)
				elseif BuildMode.Drag.Type == "Rotate" then
					local yaw = math.rad(math.round((inp.Delta.X * 0.25) / BuildMode.RotateSnap) * BuildMode.RotateSnap)
					applyRotate(yaw)
				elseif BuildMode.Drag.Type == "Scale" then
					local factor = 1 + (inp.Delta.Y * -0.01)
					local snapped = math.max(0.05, math.round(factor / BuildMode.ScaleSnap) * BuildMode.ScaleSnap)
					applyScale(snapped)
				end
				GizmoSystem.UpdateGizmo(BuildMode.Selection)
			end
		end
	end))
	table.insert(Connections, BuildModeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if BuildModeGui.Enabled and BuildMode.Active then
			refreshInspector()
			refreshBrowser()
		end
	end))
end

function module.EnterBuildMode(toolName)
	if BuildMode.Active then return end
	BuildMode.ToolName = toolName or BuildMode.ToolName
	ensureBuildRoot()
	BuildMode.GizmoRoot.Parent = BuildMode.Root
	BuildModeGui.Enabled = true
	BuildMode.Active = true
	setCharacterInvisible(true)
	originalCamType = Camera.CameraType
	originalCamSubject = Camera.CameraSubject
	originalCamCFrame = Camera.CFrame
	originalMouseBehavior = UIS.MouseBehavior
	startFreecam()
	placeInitialHandle()
	loadLastSession()
	setActiveMode("Move")
	selectRoots(BuildMode.Selection, false)
	if #BuildMode.History == 0 then snapshotHistory() end
	beginAutosave()
	refreshBrowser()
	refreshInspector()
end

function module.GiveTool()
	if not BuildMode.Active then return end
	local tool = ToolCompiler.Compile(BuildMode.Root, BuildMode.ToolName)
	if tool then
		tool.Parent = Players.LocalPlayer.Backpack
	end
end

function module.Create(parent, conns, deps)
	UI_PARENT = parent
	Connections = conns
	UIS = game:GetService("UserInputService")
	RS = game:GetService("RunService")
	Players = game:GetService("Players")
	TS = game:GetService("TweenService")
	HS = game:GetService("HttpService")
	CP = game:GetService("ContentProvider")
	Workspace = game:GetService("Workspace")
	Camera = Workspace.CurrentCamera
	GizmoSystem = deps.GizmoSystem
	MaterialPicker = deps.MaterialPicker
	BrowserTree = deps.BrowserTree
	ExportImport = deps.ExportImport
	ToolCompiler = deps.ToolCompiler
	buildUI()
	wireEvents()
	return module
end

return module
