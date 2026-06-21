local module = {}
local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then inst[k] = v end
	end
	if parent then inst.Parent = parent end
	return inst
end

function module.Render(container, buildRoot, onSpawn)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local function addNode(parentFrame, inst, depth)
		local frame = create("Frame", {Size = UDim2.new(1, -8, 0, 24), BackgroundColor3 = Color3.fromRGB(40,40,48), LayoutOrder = 0}, parentFrame)
		create("UICorner", {CornerRadius = UDim.new(0,4)}, frame)
		local btn = create("TextButton", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 20*depth, 0, 0), BackgroundTransparency = 1, Text = inst.Name .. " [" .. inst.ClassName .. "]", TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, frame)
		btn.MouseButton1Click:Connect(function()
			onSpawn(inst)
		end)
		if inst:IsA("Model") or inst:IsA("Folder") then
			for _, child in ipairs(inst:GetChildren()) do
				if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder") then
					addNode(parentFrame, child, depth + 1)
				end
			end
		end
	end
	local layout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,4)}, container)
	for _, obj in ipairs(buildRoot:GetChildren()) do
		if obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Folder") then
			addNode(container, obj, 0)
		end
	end
	container.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 8)
end

return module
