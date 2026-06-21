local module = {}
local Connections

local VariantsByMaterial = {
	[Enum.Material.Wood] = {"", "Plywood", "Oak", "Walnut", "Cherry", "Mahogany", "Bamboo"},
	[Enum.Material.Metal] = {"", "DiamondPlate", "Corrugated", "Steel", "Gold", "Silver", "Copper", "Brass", "Chrome"},
	[Enum.Material.Plastic] = {"", "Glow", "SmoothPlastic", "Neon"},
	[Enum.Material.Concrete] = {"", "Bricks", "Pavement", "OldConcrete"},
	[Enum.Material.Granite] = {"", "Polished", "Rough"},
	[Enum.Material.Marble] = {"", "Polished", "Veined"},
	[Enum.Material.Glass] = {"", "Frosted", "Tinted"},
	[Enum.Material.Fabric] = {"", "Canvas", "Denim", "Silk", "Leather", "Carpet"},
	[Enum.Material.Sand] = {"", "Sandstone"},
	[Enum.Material.Grass] = {"", "Dirt", "Flowers"},
	[Enum.Material.Ice] = {"", "Glacier"},
	[Enum.Material.Snow] = {"", "Powder"},
}

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then inst[k] = v end
	end
	if parent then inst.Parent = parent end
	return inst
end

function module.Render(container, selectedPart)
	for _, c in ipairs(container:GetChildren()) do
		if c.Name == "MaterialPicker" then
			c:Destroy()
		end
	end
	if not selectedPart or not selectedPart:IsA("BasePart") then return end
	local frame = create("Frame", {Name = "MaterialPicker", Size = UDim2.new(1,0,0,260), BackgroundColor3 = Color3.fromRGB(30,30,36), BorderSizePixel = 0, LayoutOrder = 99}, container)
	create("UICorner", {CornerRadius = UDim.new(0,6)}, frame)
	local search = create("TextBox", {Size = UDim2.new(1,-10,0,24), Position = UDim2.new(0,5,0,5), BackgroundColor3 = Color3.fromRGB(40,40,48), TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false, Text = ""}, frame)
	create("UICorner", {CornerRadius = UDim.new(0,5)}, search)
	local matScroll = create("ScrollingFrame", {Size = UDim2.new(1,-10,0,120), Position = UDim2.new(0,5,0,34), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0,0,0,0)}, frame)
	local matLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,4)}, matScroll)
	local varScroll = create("ScrollingFrame", {Size = UDim2.new(1,-10,0,90), Position = UDim2.new(0,5,0,160), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0,0,0,0)}, frame)
	local varLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,4)}, varScroll)
	local populateVariants
	local populateMaterials
	populateVariants = function(mat)
		for _, child in ipairs(varScroll:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		local variants = VariantsByMaterial[mat] or {""}
		for _, var in ipairs(variants) do
			local btn = create("TextButton", {Size = UDim2.new(1,-4,0,22), BackgroundColor3 = Color3.fromRGB(45,45,52), Text = var == "" and "Default" or var, TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, varScroll)
			create("UICorner", {CornerRadius = UDim.new(0,4)}, btn)
			btn.MouseButton1Click:Connect(function()
				pcall(function() selectedPart.MaterialVariant = var end)
			end)
		end
		varScroll.CanvasSize = UDim2.new(0,0,0, varLayout.AbsoluteContentSize.Y + 6)
	end
	populateMaterials = function(filter)
		for _, child in ipairs(matScroll:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for _, mat in ipairs(Enum.Material:GetEnumItems()) do
			if filter == "" or mat.Name:lower():find(filter, 1, true) then
				local btn = create("TextButton", {Size = UDim2.new(1,-4,0,22), BackgroundColor3 = Color3.fromRGB(45,45,52), Text = mat.Name, TextColor3 = Color3.fromRGB(255,255,255), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left}, matScroll)
				create("UICorner", {CornerRadius = UDim.new(0,4)}, btn)
				btn.MouseButton1Click:Connect(function()
					selectedPart.Material = mat
					populateVariants(mat)
				end)
			end
		end
		matScroll.CanvasSize = UDim2.new(0,0,0, matLayout.AbsoluteContentSize.Y + 6)
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		populateMaterials(search.Text:lower())
	end)
	populateMaterials("")
	populateVariants(selectedPart.Material)
end

return module
