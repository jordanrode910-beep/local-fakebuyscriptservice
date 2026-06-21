local module = {}
local Players = game:GetService("Players")

function module.Compile(buildRoot, toolName)
	local tool = Instance.new("Tool")
	tool.Name = toolName
	tool.RequiresHandle = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = true
	handle.Size = Vector3.new(1, 1, 1)
	handle.Parent = tool
	for _, obj in ipairs(buildRoot:GetChildren()) do
		if obj ~= buildRoot:FindFirstChild("__LocalBuildSession") then
			obj.Parent = tool
			if obj:IsA("BasePart") then
				obj.Anchored = false
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = handle
				wc.Part1 = obj
				wc.Parent = obj
			elseif obj:IsA("Model") then
				for _, part in ipairs(obj:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
						local wc = Instance.new("WeldConstraint")
						wc.Part0 = handle
						wc.Part1 = part
						wc.Parent = part
					end
				end
			end
		end
	end
	return tool
end

return module
